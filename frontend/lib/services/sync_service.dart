import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'offline_database.dart';
import 'laporan_service.dart';

/// Result returned after a synchronisation attempt.
class SyncResult {
  const SyncResult({
    required this.total,
    required this.synced,
    required this.failed,
  });

  final int total;
  final int synced;
  final int failed;

  @override
  String toString() =>
      'SyncResult(total: $total, synced: $synced, failed: $failed)';
}

/// Synchronises locally stored offline reports with the remote API.
class SyncService {
  const SyncService._();

  static bool _isSyncing = false;

  /// Attempts to upload every pending / previously-failed report to
  /// the server using [LaporanService.submitReport].
  static Future<SyncResult> syncAll(String token) async {
    if (_isSyncing ||
        token.isEmpty ||
        token.startsWith('offline_') ||
        token.startsWith('google_session_')) {
      return const SyncResult(total: 0, synced: 0, failed: 0);
    }

    _isSyncing = true;
    try {
      final db = OfflineDatabase.instance;
      final pending = await db.getPendingReports();

      int syncedCount = 0;
      int failedCount = 0;

      for (final report in pending) {
        final localId = report['id'] as int;
        if (report['server_id'] != null) {
          await db.updateSyncStatus(localId, 'synced');
          continue;
        }

        try {
          final String? rawPhotoB64 = report['photo_base64'] as String?;
          final String? localPhotoPath = report['photo_path'] as String?;
          Uint8List? photoBytes;
          String filename = 'offline_photo.jpg';

          if (!kIsWeb &&
              localPhotoPath != null &&
              localPhotoPath.isNotEmpty &&
              !localPhotoPath.startsWith('data:image')) {
            final photoFile = File(localPhotoPath);
            if (photoFile.existsSync()) {
              photoBytes = await photoFile.readAsBytes();
              filename = photoFile.uri.pathSegments.last;
            }
          }

          if (photoBytes == null &&
              rawPhotoB64 != null &&
              rawPhotoB64.isNotEmpty) {
            try {
              final clean = rawPhotoB64.contains(',')
                  ? rawPhotoB64.split(',').last
                  : rawPhotoB64;
              photoBytes = base64Decode(clean);
            } catch (_) {}
          }

          final payload = <String, dynamic>{
            'title': report['title'],
            'activity_date': report['activity_date'],
            'location': report['location'],
            'address': report['address'] ?? report['location'],
            'description': report['description'],
            'latitude': report['latitude'] != null
                ? double.tryParse(report['latitude'].toString())
                : null,
            'longitude': report['longitude'] != null
                ? double.tryParse(report['longitude'].toString())
                : null,
            'category_id': report['category_id'],
            'status': report['status'] ?? 'draft',
          };

          final response = await LaporanService.submitReport(
            token: token,
            payload: payload,
          );

          if (response.statusCode == 200 || response.statusCode == 201) {
            int? serverId;
            try {
              final body = jsonDecode(response.body);
              serverId = body['data']?['id'] != null
                  ? int.tryParse(body['data']['id'].toString())
                  : null;
            } catch (_) {}

            if (serverId != null &&
                photoBytes != null &&
                photoBytes.isNotEmpty) {
              try {
                await LaporanService.uploadReportPhoto(
                  token: token,
                  reportId: serverId,
                  photoBytes: photoBytes,
                  filename: filename,
                  latitude: report['latitude'] != null
                      ? double.tryParse(report['latitude'].toString())
                      : null,
                  longitude: report['longitude'] != null
                      ? double.tryParse(report['longitude'].toString())
                      : null,
                  address: (report['address'] ?? report['location'])
                      ?.toString(),
                );
              } catch (_) {}
            }

            await db.updateSyncStatus(
              report['id'] as int,
              'synced',
              serverId: serverId,
            );
            await _removeLocalDraftMirror('local_$localId');
            syncedCount++;
          } else {
            await db.updateSyncStatus(report['id'] as int, 'failed');
            failedCount++;
          }
        } catch (_) {
          await db.updateSyncStatus(report['id'] as int, 'failed');
          failedCount++;
        }
      }

      if (syncedCount > 0) {
        LaporanService.clearCache();
      }

      return SyncResult(
        total: pending.length,
        synced: syncedCount,
        failed: failedCount,
      );
    } catch (_) {
      return const SyncResult(total: 0, synced: 0, failed: 0);
    } finally {
      _isSyncing = false;
    }
  }

  static Future<void> _removeLocalDraftMirror(String localRecordId) async {
    try {
      const draftKey = 'phonebook_laporan_drafts_v1';
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(draftKey);
      if (raw == null || raw.isEmpty) return;
      final list = (jsonDecode(raw) as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e))
          .where((e) => e['id'].toString() != localRecordId)
          .toList();
      await prefs.setString(draftKey, jsonEncode(list));
    } catch (_) {}
  }
}
