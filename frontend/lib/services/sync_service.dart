import 'dart:convert';

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
  ///
  /// Each report is processed independently so that a single failure
  /// does not prevent the remaining reports from being synced.
  static Future<SyncResult> syncAll(String token) async {
    final db = OfflineDatabase.instance;
    final pending = await db.getPendingReports();

    int syncedCount = 0;
    int failedCount = 0;

    for (final report in pending) {
      try {
        final payload = <String, dynamic>{
          'title': report['title'],
          'activity_date': report['activity_date'],
          'location': report['location'],
          'description': report['description'],
          'latitude': report['latitude'],
          'longitude': report['longitude'],
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
            serverId = body['data']?['id'] as int?;
          } catch (_) {}

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
  }
}
