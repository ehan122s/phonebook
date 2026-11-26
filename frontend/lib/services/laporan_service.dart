import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';

import '../constants/api_constants.dart';
import '../constants/laporan_constants.dart';
import 'offline_database.dart';

/// Base URL for the Laravel API (mengacu ke [ApiConstants.baseUrl]).
String get baseUrl => ApiConstants.baseUrl;

/// Exception thrown when authentication fails or token has expired (HTTP 401).
class UnauthorizedException implements Exception {
  final String message;
  const UnauthorizedException([this.message = 'Sesi login telah berakhir.']);
  @override
  String toString() => message;
}

/// Exception thrown when user lacks permission (HTTP 403).
class ForbiddenException implements Exception {
  final String message;
  const ForbiddenException([this.message = 'Anda tidak memiliki izin untuk mengakses data ini.']);
  @override
  String toString() => message;
}

/// Service class that handles all report-related API calls & offline persistence.
class LaporanService {
  static List<Map<String, dynamic>>? _cachedReports;
  static String? _cachedToken;
  static DateTime? _lastFetchTime;
  static const Duration cacheTtl = Duration(seconds: 45);

  /// Mengekstrak pesan error yang jelas dari response JSON Laravel.
  static String extractErrorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        if (decoded['errors'] is Map) {
          final errors = decoded['errors'] as Map;
          if (errors.isNotEmpty) {
            final firstVal = errors.values.first;
            if (firstVal is List && firstVal.isNotEmpty) {
              return firstVal.first.toString();
            }
            return firstVal.toString();
          }
        }
        if (decoded['message'] != null &&
            decoded['message'].toString().trim().isNotEmpty) {
          return decoded['message'].toString();
        }
      }
    } catch (_) {}
    if (response.statusCode == 401) {
      return 'Sesi login telah berakhir. Silakan login kembali.';
    }
    if (response.statusCode == 413) {
      return 'Ukuran data/foto terlalu besar untuk dikirim ke server.';
    }
    return 'Server menolak permintaan (HTTP ${response.statusCode}).';
  }

  /// Invalidate report cache (e.g. after adding/editing/deleting a report)
  static void clearCache() {
    _cachedReports = null;
    _cachedToken = null;
    _lastFetchTime = null;
  }

  /// Get cached reports if available and belongs to the active token.
  static List<Map<String, dynamic>>? getCachedReports({String? token}) {
    if (_cachedReports != null &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < cacheTtl) {
      if (token == null || _cachedToken == token) {
        return _cachedReports;
      }
    }
    return null;
  }

  /// Fetches all reports from the API and returns them as a
  /// list of mapped report data including attached photos and coordinates.
  static Future<List<Map<String, dynamic>>> fetchReports(
    String token, {
    bool forceRefresh = false,
  }) async {
    if (token.isEmpty ||
        token.startsWith('offline_') ||
        token.startsWith('google_session_')) {
      return [];
    }

    if (!forceRefresh) {
      final cached = getCachedReports(token: token);
      if (cached != null) {
        return cached;
      }
    }

    http.Response? response;
    Object? lastError;

    for (int attempt = 1; attempt <= 2; attempt++) {
      try {
        response = await http
            .get(
              Uri.parse('$baseUrl/api/reports'),
              headers: {
                'Accept': 'application/json',
                'Authorization': 'Bearer $token',
              },
            )
            .timeout(const Duration(seconds: 25));
        break;
      } on TimeoutException catch (e) {
        lastError = e;
        if (attempt == 2) {
          throw Exception(
            'Server membutuhkan waktu terlalu lama untuk merespons. Silakan ketuk Coba Lagi.',
          );
        }
      } on SocketException catch (_) {
        throw Exception(
          'Tidak ada koneksi internet. Periksa jaringan Anda lalu coba lagi.',
        );
      } on http.ClientException catch (_) {
        throw Exception(
          'Koneksi ke server terganggu. Periksa jaringan Anda lalu coba lagi.',
        );
      }
    }

    if (response == null) {
      throw Exception('Gagal menghubungi server: $lastError');
    }

    if (response.statusCode == 401) {
      clearCache();
      throw const UnauthorizedException(
        'Sesi login telah berakhir. Silakan login kembali.',
      );
    }

    if (response.statusCode == 403) {
      throw ForbiddenException(extractErrorMessage(response));
    }

    if (response.statusCode != 200) {
      final body = response.body;
      final lower = body.toLowerCase();
      if (lower.contains('project is paused')) {
        throw Exception(
          'Layanan database sedang tidak aktif sementara. Hubungi administrator.',
        );
      }
      throw Exception(extractErrorMessage(response));
    }

    final body = jsonDecode(response.body);
    final List<dynamic> data = body['data'] ?? [];

    final reportsList = data.map<Map<String, dynamic>>((report) {
      final String activityDate = report['activity_date']?.toString() ?? '';
      final String rawStatus = report['status']?.toString() ?? 'draft';

      final List<dynamic> rawPhotos = (report['photos'] is List)
          ? report['photos']
          : [];
      String photoUrl = '';
      String photoBase64 = '';
      String photoAddress = '';
      String photoLat = '';
      String photoLng = '';

      if (rawPhotos.isNotEmpty) {
        final first = rawPhotos.first;
        if (first is Map) {
          final photoId = first['id'];
          final rawUrl = (first['url'] ?? first['photo'] ?? '').toString();
          photoBase64 = (first['photo_base64'] ?? '').toString();
          photoAddress = (first['address'] ?? '').toString();
          photoLat = (first['latitude'] ?? '').toString();
          photoLng = (first['longitude'] ?? '').toString();

          if (photoBase64.isNotEmpty) {
            photoUrl = photoBase64.startsWith('data:image')
                ? photoBase64
                : 'data:image/jpeg;base64,$photoBase64';
          } else if (photoId != null) {
            photoUrl = ApiConstants.reportPhotoFileUrl(photoId);
          } else if (rawUrl.isNotEmpty) {
            photoUrl = rawUrl.startsWith('http') || rawUrl.startsWith('data:')
                ? rawUrl
                : '$baseUrl/storage/$rawUrl';
          }
        }
      }

      final reportLat = report['latitude']?.toString() ?? '';
      final reportLng = report['longitude']?.toString() ?? '';

      return {
        'id': report['id'],
        'judul': report['title'] ?? 'Laporan tanpa judul',
        'jenis': report['category']?['name'] ?? 'Laporan Kegiatan',
        'pelapor': report['user']?['name'],
        'tanggal': LaporanDateUtils.formatApiDate(activityDate),
        'tanggalApi': activityDate,
        'lokasi': report['location'] ?? 'Belum diisi',
        'alamatGeolokasi': photoAddress.isNotEmpty
            ? photoAddress
            : (report['location']?.toString() ?? ''),
        'isi': report['description'] ?? '',
        'latitude': reportLat.isNotEmpty ? reportLat : photoLat,
        'longitude': reportLng.isNotEmpty ? reportLng : photoLng,
        'foto': photoUrl,
        'photo_base64': photoBase64,
        'photos': rawPhotos,
        'status': LaporanDateUtils.displayStatus(rawStatus),
        'statusApi': rawStatus,
      };
    }).toList();

    _cachedReports = reportsList;
    _cachedToken = token;
    _lastFetchTime = DateTime.now();

    return reportsList;
  }

  /// Submits a report to the API. Creates a new report via
  /// POST or updates an existing one via PUT based on whether
  /// [existingId] is provided.
  static Future<http.Response> submitReport({
    required String token,
    required Map<String, dynamic> payload,
    int? existingId,
  }) async {
    clearCache();
    final isEditing = existingId != null;

    final uri = isEditing
        ? Uri.parse('$baseUrl/api/reports/$existingId')
        : Uri.parse('$baseUrl/api/reports');

    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final cleanPayload = Map<String, dynamic>.from(payload)
      ..remove('photo_base64');

    final response = isEditing
        ? await http
              .put(uri, headers: headers, body: jsonEncode(cleanPayload))
              .timeout(const Duration(seconds: 20))
        : await http
              .post(uri, headers: headers, body: jsonEncode(cleanPayload))
              .timeout(const Duration(seconds: 20));

    return response;
  }

  /// Uploads a photo attachment for a given [reportId] along with GPS coordinates & address.
  static Future<http.Response> uploadReportPhoto({
    required String token,
    required int reportId,
    required List<int> photoBytes,
    required String filename,
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    final uri = Uri.parse('$baseUrl/api/reports/$reportId/photos');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Accept'] = 'application/json';
    request.headers['Authorization'] = 'Bearer $token';

    final cleanFilename = filename.isNotEmpty
        ? filename
        : 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final lower = cleanFilename.toLowerCase();
    final mimeType = lower.endsWith('.png')
        ? MediaType('image', 'png')
        : lower.endsWith('.webp')
        ? MediaType('image', 'webp')
        : lower.endsWith('.gif')
        ? MediaType('image', 'gif')
        : MediaType('image', 'jpeg');

    request.files.add(
      http.MultipartFile.fromBytes(
        'photo',
        photoBytes,
        filename: cleanFilename,
        contentType: mimeType,
      ),
    );

    request.fields['photo_base64'] = base64Encode(photoBytes);

    if (latitude != null) {
      request.fields['latitude'] = latitude.toString();
    }
    if (longitude != null) {
      request.fields['longitude'] = longitude.toString();
    }
    if (address != null && address.trim().isNotEmpty) {
      request.fields['address'] = address.trim();
    }

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 30),
    );
    clearCache();
    return http.Response.fromStream(streamedResponse);
  }

  /// Deletes a report from the API by its [id].
  static Future<void> deleteReport(String token, dynamic id) async {
    clearCache();
    final response = await http.delete(
      Uri.parse('$baseUrl/api/reports/$id'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      final lower = response.body.toLowerCase();
      if (lower.contains('project is paused')) {
        throw Exception('Database Supabase sedang tidak aktif (Paused).');
      }
      throw Exception(extractErrorMessage(response));
    }
  }

  /// Saves a report locally for offline use (supporting both Android file system and Web/Base64).
  static Future<int> saveOffline({
    required Map<String, dynamic> payload,
    required String jenisLaporan,
    Uint8List? photoBytes,
    String? photoFilename,
  }) async {
    String? localPhotoPath;
    String? photoBase64;

    if (photoBytes != null && photoBytes.isNotEmpty) {
      photoBase64 = 'data:image/jpeg;base64,${base64Encode(photoBytes)}';

      if (!kIsWeb) {
        try {
          final appDir = await getApplicationDocumentsDirectory();
          final photoDir = Directory('${appDir.path}/offline_report_photos');
          if (!photoDir.existsSync()) {
            photoDir.createSync(recursive: true);
          }
          final safeName = photoFilename != null && photoFilename.isNotEmpty
              ? photoFilename.replaceAll(RegExp(r'[^\w\.-]'), '_')
              : 'offline_photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final file = File('${photoDir.path}/$safeName');
          await file.writeAsBytes(photoBytes, flush: true);
          localPhotoPath = file.path;
        } catch (_) {}
      }
    }

    final data = <String, dynamic>{
      'title': payload['title'],
      'activity_date': payload['activity_date'],
      'location': payload['location'],
      'address': payload['address'] ?? payload['location'],
      'description': payload['description'],
      'latitude': payload['latitude'],
      'longitude': payload['longitude'],
      'category_id': payload['category_id'],
      'status': payload['status'] ?? 'draft',
      'jenis_laporan': jenisLaporan,
      'sync_status': 'pending',
      'photo_path': localPhotoPath ?? photoBase64,
      'photo_base64': photoBase64,
    };

    try {
      return await OfflineDatabase.instance.insertReport(data);
    } catch (_) {
      return DateTime.now().millisecondsSinceEpoch;
    }
  }
}
