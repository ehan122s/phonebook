import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'laporan_service.dart';
import 'offline_database.dart';

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

/// Synchronises locally stored offline reports (along with local photos -> ImageKit
/// and local documents -> Supabase Storage) with the remote Laravel API.
class SyncService {
  const SyncService._();

  static bool _isSyncing = false;

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
        int? serverId = report['server_id'] != null
            ? int.tryParse(report['server_id'].toString())
            : null;

        try {
          // 1. Jika laporan belum dibuat di server, kirim data laporan terlebih dahulu
          if (serverId == null) {
            final Map<String, dynamic> extraMonitoring = <String, dynamic>{};
            final rawMonData = report['monitoring_data'];
            if (rawMonData is String && rawMonData.trim().isNotEmpty) {
              try {
                final decoded = jsonDecode(rawMonData);
                if (decoded is Map) {
                  for (final e in decoded.entries) {
                    extraMonitoring[e.key.toString()] = e.value;
                  }
                }
              } catch (_) {}
            } else if (rawMonData is Map) {
              for (final e in rawMonData.entries) {
                extraMonitoring[e.key.toString()] = e.value;
              }
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
              'report_type': report['report_type'] ?? 'standard',
              ...extraMonitoring,
              if (extraMonitoring.isNotEmpty) 'monitoring_data': extraMonitoring,
            };

            final response = await LaporanService.submitReport(
              token: token,
              payload: payload,
            );

            if (response.statusCode != 200 && response.statusCode != 201) {
              await db.updateSyncStatus(localId, 'failed');
              failedCount++;
              continue;
            }

            try {
              final body = jsonDecode(response.body);
              serverId = body['data']?['id'] != null
                  ? int.tryParse(body['data']['id'].toString())
                  : null;
            } catch (_) {}

            if (serverId != null) {
              await db.updateSyncStatus(
                localId,
                'attachment_pending',
                serverId: serverId,
              );
            }
          }

          // 2. Unggah foto lokal ke backend -> ImageKit jika ada
          bool allAttachmentsOk = true;
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

          if (serverId != null && photoBytes != null && photoBytes.isNotEmpty) {
            try {
              final photoRes = await LaporanService.uploadReportPhoto(
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
                address: (report['address'] ?? report['location'])?.toString(),
              );
              if (photoRes.statusCode != 200 && photoRes.statusCode != 201) {
                allAttachmentsOk = false;
              }
            } catch (_) {
              allAttachmentsOk = false;
            }
          }

          // 3. Unggah dokumen lokal ke backend -> Supabase Storage jika ada
          final String? localDocPath = report['document_path'] as String?;
          final String? localDocName = report['document_name'] as String?;
          if (allAttachmentsOk &&
              serverId != null &&
              !kIsWeb &&
              localDocPath != null &&
              localDocPath.isNotEmpty) {
            final docFile = File(localDocPath);
            if (docFile.existsSync()) {
              try {
                final docBytes = await docFile.readAsBytes();
                final docRes = await LaporanService.uploadReportFile(
                  token: token,
                  reportId: serverId,
                  fileBytes: docBytes,
                  filename: localDocName?.isNotEmpty == true
                      ? localDocName!
                      : docFile.uri.pathSegments.last,
                );
                if (docRes.statusCode != 200 && docRes.statusCode != 201) {
                  allAttachmentsOk = false;
                }
              } catch (_) {
                allAttachmentsOk = false;
              }
            }
          }

          if (allAttachmentsOk) {
            await db.updateSyncStatus(localId, 'synced', serverId: serverId);
            await _removeLocalDraftMirror('local_$localId');
            syncedCount++;
          } else {
            await db.updateSyncStatus(
              localId,
              'attachment_pending',
              serverId: serverId,
            );
            failedCount++;
          }
        } catch (_) {
          await db.updateSyncStatus(
            localId,
            serverId != null ? 'attachment_pending' : 'failed',
            serverId: serverId,
          );
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
