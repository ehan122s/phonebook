import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/api_constants.dart';
import '../constants/laporan_constants.dart';
import 'offline_database.dart';

/// Base URL for the Laravel API (mengacu ke [ApiConstants.baseUrl]).
String get baseUrl => ApiConstants.baseUrl;

/// Service class that handles all report-related API calls.
class LaporanService {
  /// Fetches all reports from the API and returns them as a
  /// list of mapped report data.
  static Future<List<Map<String, dynamic>>> fetchReports(
    String token,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/reports'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Gagal mengambil laporan (${response.statusCode}): '
        '${response.body}',
      );
    }

    final body = jsonDecode(response.body);
    final List<dynamic> data = body['data'] ?? [];

    return data.map<Map<String, dynamic>>((report) {
      final String activityDate =
          report['activity_date']?.toString() ?? '';
      final String rawStatus =
          report['status']?.toString() ?? 'draft';

      return {
        'id': report['id'],
        'judul': report['title'] ?? 'Laporan tanpa judul',
        'jenis':
            report['category']?['name'] ?? 'Laporan Kegiatan',
        'tanggal':
            LaporanDateUtils.formatApiDate(activityDate),
        'tanggalApi': activityDate,
        'lokasi': report['location'] ?? 'Belum diisi',
        'isi': report['description'] ?? '',
        'latitude':
            report['latitude']?.toString() ?? '',
        'longitude':
            report['longitude']?.toString() ?? '',
        'foto': '',
        'photos': report['photos'] ?? [],
        'status': LaporanDateUtils.displayStatus(rawStatus),
        'statusApi': rawStatus,
      };
    }).toList();
  }

  /// Submits a report to the API. Creates a new report via
  /// POST or updates an existing one via PUT based on whether
  /// [existingId] is provided.
  static Future<http.Response> submitReport({
    required String token,
    required Map<String, dynamic> payload,
    int? existingId,
  }) async {
    final isEditing = existingId != null;

    final uri = isEditing
        ? Uri.parse('$baseUrl/api/reports/$existingId')
        : Uri.parse('$baseUrl/api/reports');

    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final response = isEditing
        ? await http.put(
            uri,
            headers: headers,
            body: jsonEncode(payload),
          )
        : await http.post(
            uri,
            headers: headers,
            body: jsonEncode(payload),
          );

    return response;
  }

  /// Deletes a report from the API by its [id].
  static Future<void> deleteReport(
    String token,
    dynamic id,
  ) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/reports/$id'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(
        'Gagal menghapus laporan (${response.statusCode}): '
        '${response.body}',
      );
    }
  }

  /// Saves a report locally for offline use.
  ///
  /// The report is stored in the local SQLite database and will be
  /// synchronised with the server once connectivity is restored.
  static Future<int> saveOffline({
    required Map<String, dynamic> payload,
    required String jenisLaporan,
  }) async {
    final data = <String, dynamic>{
      'title': payload['title'],
      'activity_date': payload['activity_date'],
      'location': payload['location'],
      'description': payload['description'],
      'latitude': payload['latitude'],
      'longitude': payload['longitude'],
      'category_id': payload['category_id'],
      'status': payload['status'] ?? 'draft',
      'jenis_laporan': jenisLaporan,
      'sync_status': 'pending',
    };

    return OfflineDatabase.instance.insertReport(data);
  }
}