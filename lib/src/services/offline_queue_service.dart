import 'dart:io';
import 'dart:typed_data';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart'; // Tambahan baru

class OfflineQueueService {
  static const _boxActivities = 'pending_activities';
  static const _boxUploads = 'pending_uploads';

  late Box<Map> _activitiesBox;
  late Box<Map> _uploadsBox;

  Future<void> init() async {
    _activitiesBox = await Hive.openBox<Map>(_boxActivities);
    _uploadsBox = await Hive.openBox<Map>(_boxUploads);
  }

  // === KEGIATAN ===
  Future<String> queueActivity(Map<String, dynamic> payload) async {
    final localId = 'local_${DateTime.now().millisecondsSinceEpoch}';
    await _activitiesBox.put(localId, {
      'localId': localId,
      'payload': payload,
      'createdAt': DateTime.now().toIso8601String(),
      'status': 'pending',
      'errorMessage': null,
    });
    return localId;
  }

  List<Map<String, dynamic>> get pendingActivities => _activitiesBox.values
      .map((e) => Map<String, dynamic>.from(e))
      .toList()
    ..sort((a, b) =>
        (a['createdAt'] as String).compareTo(b['createdAt'] as String));

  Future<void> markActivityStatus(String localId, String status, {String? error}) async {
    final current = _activitiesBox.get(localId);
    if (current == null) return;
    await _activitiesBox.put(localId, {
      ...Map<String, dynamic>.from(current),
      'status': status,
      'errorMessage': error,
    });
  }

  Future<void> removeActivity(String localId) => _activitiesBox.delete(localId);

  // === FILE UPLOADS (YANG BIKIN FREEZE TADI, SUDAH DIPERBAIKI) ===
  Future<void> queueUpload({
    required String activityId,
    required String name,
    required Uint8List bytes,
    required String contentType,
    required bool isPhoto,
  }) async {
    final key = '${DateTime.now().millisecondsSinceEpoch}_$name';

    // 1. Simpan fisik file-nya ke folder sementara HP (Jauh lebih enteng)
    final dir = await getApplicationDocumentsDirectory();
    final localFile = File('${dir.path}/$key');
    await localFile.writeAsBytes(bytes); // Asinkron, nggak bikin layar macet!

    // 2. Cukup simpan alamat file-nya (localPath) di dalam Hive
    await _uploadsBox.put(key, {
      'key': key,
      'activityId': activityId,
      'name': name,
      'localPath': localFile.path, // <--- Perubahan Kunci
      'contentType': contentType,
      'isPhoto': isPhoto,
    });
  }

  List<Map<String, dynamic>> get pendingUploads =>
      _uploadsBox.values.map((e) => Map<String, dynamic>.from(e)).toList();

  Future<void> reassignUploads(String oldActivityId, String newActivityId) async {
    for (final key in _uploadsBox.keys.toList()) {
      final data = Map<String, dynamic>.from(_uploadsBox.get(key) ?? {});
      if (data['activityId'] == oldActivityId) {
        await _uploadsBox.put(key, {...data, 'activityId': newActivityId});
      }
    }
  }

  Future<void> removeUpload(String key) async {
    final data = _uploadsBox.get(key);
    // Hapus juga file fisiknya biar memori HP nggak penuh
    if (data != null && data['localPath'] != null) {
      final file = File(data['localPath']);
      if (await file.exists()) {
        await file.delete();
      }
    }
    await _uploadsBox.delete(key);
  }

  int get totalPendingCount => _activitiesBox.length + _uploadsBox.length;
}