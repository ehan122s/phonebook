import 'dart:io'; // <-- Tambahan import untuk baca file dari memori HP
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../models/activity.dart';
import '../models/stored_file.dart';
import 'activity_repository.dart';
import 'connectivity_service.dart';
import 'offline_queue_service.dart';

/// Ringkasan hasil satu kali proses sinkronisasi, dipakai untuk kasih tahu
/// user lewat SnackBar ("3 berhasil, 1 gagal").
class SyncResult {
  const SyncResult({required this.success, required this.failed});
  final int success;
  final int failed;
  bool get hasFailure => failed > 0;
  bool get isEmpty => success == 0 && failed == 0;
}

/// Pembungkus [ActivityRepository] yang menambahkan dukungan mode offline.
class OfflineActivityRepository {
  OfflineActivityRepository(this._remote, this._connectivity, this._queue) {
    pendingCountNotifier.value = _queue.totalPendingCount;
    // Auto-sync begitu koneksi kembali tersedia.
    _connectivity.onStatusChange.listen((online) {
      if (online) syncPending();
    });
  }

  final ActivityRepository _remote;
  final ConnectivityService _connectivity;
  final OfflineQueueService _queue;

  /// Jumlah item yang masih menunggu disinkronkan. Widget UI (mis.
  /// [SyncStatusBanner]) bisa `ValueListenableBuilder` ke sini.
  final ValueNotifier<int> pendingCountNotifier = ValueNotifier(0);

  void _refreshPendingCount() {
    pendingCountNotifier.value = _queue.totalPendingCount;
  }

  // ---------------------------------------------------------------------
  // LIST — gabungan data server + antrian lokal
  // ---------------------------------------------------------------------

  Future<List<Activity>> list({String? query, int? month, int? year}) async {
    List<Activity> remote = [];
    try {
      remote = await _remote.list(query: query, month: month, year: year);
    } catch (_) {
      // Offline atau request gagal -> tetap tampilkan yang lokal saja,
      // jangan lempar error supaya halaman tidak crash saat tidak ada
      // internet.
    }

    final pending = _queue.pendingActivities.map((p) {
      final payload = Map<String, dynamic>.from(p['payload'] as Map);
      return Activity.fromMap({
        ...payload,
        'id': p['localId'],
        'isPendingSync': true,
      });
    }).toList();

    final filteredPending = (query == null || query.isEmpty)
        ? pending
        : pending
            .where((a) =>
                a.title.toLowerCase().contains(query.toLowerCase()) ||
                a.village.toLowerCase().contains(query.toLowerCase()) ||
                a.district.toLowerCase().contains(query.toLowerCase()))
            .toList();

    // Kegiatan pending ditaruh paling atas supaya kelihatan jelas.
    return [...filteredPending, ...remote];
  }

  Future<Activity> getById(String id) => _remote.getById(id);

  // ---------------------------------------------------------------------
  // CREATE — offline-aware
  // ---------------------------------------------------------------------

  Future<void> create(Map<String, dynamic> values) async {
    if (!_connectivity.isOnline) {
      await _queue.queueActivity(values);
      _refreshPendingCount();
      return;
    }
    try {
      await _remote.create(values);
    } catch (_) {
      // Sempat kelihatan online tapi request gagal (mis. sinyal putus
      // di tengah submit) -> jangan sampai data hilang, taruh ke antrian.
      await _queue.queueActivity(values);
      _refreshPendingCount();
    }
  }

  Future<void> update(String id, Map<String, dynamic> values) =>
      _remote.update(id, values);

  // ---------------------------------------------------------------------
  // FILE (FOTO/DOKUMEN) — offline-aware
  // ---------------------------------------------------------------------

  Future<void> uploadFile({
    required String activityId,
    required String name,
    required Uint8List bytes,
    required String contentType,
    required bool isPhoto,
  }) async {
    final isLocalActivity = activityId.startsWith('local_');
    if (isLocalActivity || !_connectivity.isOnline) {
      await _queue.queueUpload(
        activityId: activityId,
        name: name,
        bytes: bytes,
        contentType: contentType,
        isPhoto: isPhoto,
      );
      _refreshPendingCount();
      return;
    }
    try {
      await _remote.uploadFile(
        activityId: activityId,
        name: name,
        bytes: bytes,
        contentType: contentType,
        isPhoto: isPhoto,
      );
    } catch (_) {
      await _queue.queueUpload(
        activityId: activityId,
        name: name,
        bytes: bytes,
        contentType: contentType,
        isPhoto: isPhoto,
      );
      _refreshPendingCount();
    }
  }

  Future<List<StoredFile>> media(String activityId, {required bool photos}) =>
      _remote.media(activityId, photos: photos);

  Future<String> signedUrl(StoredFile file, {required bool photo}) =>
      _remote.signedUrl(file, photo: photo);

  Future<void> deleteMedia(StoredFile file, {required bool photo}) =>
      _remote.deleteMedia(file, photo: photo);

  Future<Map<String, dynamic>?> createReport(String activityId, String format) =>
      _remote.createReport(activityId, format);

  Future<void> delete(String activityId) => _remote.delete(activityId);

  // ---------------------------------------------------------------------
  // SINKRONISASI
  // ---------------------------------------------------------------------

  bool _sedangSinkron = false;

  /// Jalankan sinkronisasi semua kegiatan & file yang masih diantre.
  /// Aman dipanggil berkali-kali — kalau sedang berjalan, panggilan
  /// berikutnya diabaikan.
  Future<SyncResult> syncPending() async {
    if (_sedangSinkron || !_connectivity.isOnline) {
      return const SyncResult(success: 0, failed: 0);
    }
    _sedangSinkron = true;
    int success = 0, failed = 0;

    try {
      // 1) Sinkronkan kegiatan dulu, supaya file yang nempel ke localId
      //    bisa ikut "dipindah" ke id asli sebelum ikut disinkron.
      for (final item in _queue.pendingActivities) {
        final localId = item['localId'] as String;
        try {
          await _queue.markActivityStatus(localId, 'syncing');
          final payload = Map<String, dynamic>.from(item['payload'] as Map);
          final newId = await _remote.createAndReturnId(payload);
          await _queue.reassignUploads(localId, newId);
          await _queue.removeActivity(localId);
          success++;
        } catch (e) {
          await _queue.markActivityStatus(localId, 'failed', error: '$e');
          failed++;
        }
      }

      // 2) Baru sinkronkan file — di titik ini semua activityId yang
      //    tadinya "local_..." seharusnya sudah diganti id asli (kecuali
      //    kegiatan induknya masih gagal sinkron di langkah 1).
      for (final item in _queue.pendingUploads) {
        final key = item['key'] as String;
        final activityId = item['activityId'] as String;
        if (activityId.startsWith('local_')) {
          // Induknya belum berhasil sinkron, coba lagi di sesi sync berikutnya.
          continue;
        }
        
        try {
          // BACA FILE FISIK DARI HP
          final localPath = item['localPath'] as String?;
          Uint8List bytesToUpload;

          if (localPath != null) {
            final file = File(localPath);
            bytesToUpload = await file.readAsBytes();
          } else {
            // Fallback jaga-jaga kalau ada file sisaan dari error sebelumnya
            bytesToUpload = item['bytes'] as Uint8List;
          }

          await _remote.uploadFile(
            activityId: activityId,
            name: item['name'] as String,
            bytes: bytesToUpload, // Gunakan bytes yang dibaca tadi
            contentType: item['contentType'] as String,
            isPhoto: item['isPhoto'] as bool,
          );
          
          await _queue.removeUpload(key); // Ini akan hapus file fisiknya juga
          success++;
        } catch (_) {
          failed++;
        }
      }
    } finally {
      _sedangSinkron = false;
      _refreshPendingCount();
    }

    return SyncResult(success: success, failed: failed);
  }
}