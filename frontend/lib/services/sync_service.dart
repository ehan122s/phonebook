import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

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

  /// Attempts to upload every pending / previously-failed report to
  /// the server using [LaporanService.submitReport].
  static Future<SyncResult> syncAll(String token) async {
    if (token.isEmpty ||
        token.startsWith('offline_') ||
        token.startsWith('google_session_')) {
      return const SyncResult(total: 0, synced: 0, failed: 0);
    }

    try {
      final db = OfflineDatabase.instance;
      final pending = await db.getPendingReports();

      int syncedCount = 0;
      int failedCount = 0;

      for (final report in pending) {
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
            'latitude': report['latitude'],
            'longitude': report['longitude'],
            'category_id': report['category_id'],
            'status': report['status'] ?? 'draft',
            if (photoBytes != null) 'photo_base64': base64Encode(photoBytes),
          };

          final response = await LaporanService.submitReport(
            token: token,
            payload: payload,
          );

          if (response.statusCode == 200 || response.statusCode == 201) {
            int? serverId;
            List<dynamic> serverPhotos = const [];
            try {
              final body = jsonDecode(response.body);
              serverId = body['data']?['id'] as int?;
              if (body['data']?['photos'] is List) {
                serverPhotos = body['data']['photos'] as List<dynamic>;
              }
            } catch (_) {}

            if (serverId != null &&
                photoBytes != null &&
                serverPhotos.isEmpty) {
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
                  address: (report['address'] ?? report['location'])?.toString(),
                );
              } catch (_) {}
            }

            await db.updateSyncStatus(
              report['id'] as int,
              'synced',
              serverId: serverId,
            );
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

      return SyncResult(
        total: pending.length,
        synced: syncedCount,
        failed: failedCount,
      );
    } catch (e) {
      return const SyncResult(total: 0, synced: 0, failed: 0);
    }
  }
}