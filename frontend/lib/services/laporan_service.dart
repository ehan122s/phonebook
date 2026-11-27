import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../constants/api_constants.dart';
import '../constants/laporan_constants.dart';
import 'device_file_storage_service.dart';
import 'monitoring_calculator.dart';
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
  const ForbiddenException([
    this.message = 'Anda tidak memiliki izin untuk mengakses data ini.',
  ]);
  @override
  String toString() => message;
}

/// Service class that handles all report-related API calls & offline persistence.
class LaporanService {
  static List<Map<String, dynamic>>? _cachedReports;
  static String? _cachedToken;
  static DateTime? _lastFetchTime;
  static const Duration cacheTtl = Duration(seconds: 45);
  static const Duration httpTimeout = Duration(seconds: 30);

  /// Mengubah exception mentah (termasuk TimeoutException) menjadi pesan ramah pengguna.
  static String friendlyErrorMessage(Object error) {
    final msg = error.toString().replaceFirst('Exception: ', '').trim();
    final lower = msg.toLowerCase();
    if (error is TimeoutException ||
        lower.contains('timeoutexception') ||
        lower.contains('future not completed')) {
      return 'Koneksi ke server memakan waktu terlalu lama. Pastikan internet stabil lalu tekan Coba Lagi.';
    }
    if (error is SocketException || lower.contains('socketexception')) {
      return 'Tidak ada koneksi internet. Periksa jaringan Anda lalu coba lagi.';
    }
    if (error is http.ClientException || lower.contains('clientexception')) {
      return 'Koneksi ke server terganggu. Periksa jaringan Anda lalu coba lagi.';
    }
    return msg.isNotEmpty
        ? msg
        : 'Terjadi kendala saat menghubungi server. Silakan coba lagi.';
  }

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
      return 'Ukuran data/berkas terlalu besar untuk dikirim ke server.';
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

  /// Mengambil URL foto terbaik dari object foto backend (memprioritaskan URL ImageKit).
  static String resolvePhotoUrl(Map photoMap) {
    final imagekitUrl = (photoMap['imagekit_url'] ?? '').toString().trim();
    if (imagekitUrl.startsWith('http://') || imagekitUrl.startsWith('https://')) {
      return imagekitUrl;
    }

    final directUrl = (photoMap['url'] ?? '').toString().trim();
    if (directUrl.startsWith('http://') || directUrl.startsWith('https://')) {
      return directUrl;
    }

    final rawPhoto = (photoMap['photo'] ?? '').toString().trim();
    if (rawPhoto.startsWith('http://') ||
        rawPhoto.startsWith('https://') ||
        rawPhoto.startsWith('data:image')) {
      return rawPhoto;
    }

    final b64 = (photoMap['photo_base64'] ?? '').toString().trim();
    if (b64.isNotEmpty) {
      return b64.startsWith('data:image') ? b64 : 'data:image/jpeg;base64,$b64';
    }

    final photoId = photoMap['id'];
    if (photoId != null) {
      return ApiConstants.reportPhotoFileUrl(photoId);
    }

    if (rawPhoto.isNotEmpty) {
      return '$baseUrl/storage/$rawPhoto';
    }

    return '';
  }

  /// Fetches all reports from the API and returns them as a
  /// list of mapped report data including attached photos, documents, and coordinates.
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

    // Maksimal 2 kali auto-retry (total 3 percobaan) saat terjadi TimeoutException
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        response = await http
            .get(
              Uri.parse('$baseUrl/api/reports'),
              headers: {
                'Accept': 'application/json',
                'Authorization': 'Bearer $token',
              },
            )
            .timeout(httpTimeout);
        break;
      } on TimeoutException catch (e) {
        lastError = e;
        if (attempt < 3) {
          await Future.delayed(Duration(milliseconds: 600 * attempt));
          continue;
        }
        throw Exception(
          'Koneksi ke server memakan waktu terlalu lama. Pastikan internet stabil lalu tekan Coba Lagi.',
        );
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
      final List<dynamic> rawFiles = (report['files'] is List)
          ? report['files']
          : [];

      String photoUrl = '';
      String photoBase64 = '';
      String photoAddress = '';
      String photoLat = '';
      String photoLng = '';

      if (rawPhotos.isNotEmpty) {
        final first = rawPhotos.first;
        if (first is Map) {
          photoUrl = resolvePhotoUrl(first);
          photoBase64 = (first['photo_base64'] ?? '').toString();
          photoAddress = (first['address'] ?? '').toString();
          photoLat = (first['latitude'] ?? '').toString();
          photoLng = (first['longitude'] ?? '').toString();
        }
      }

      final reportLat = report['latitude']?.toString() ?? '';
      final reportLng = report['longitude']?.toString() ?? '';
      final rawReportType = report['report_type']?.toString() ?? 'standard';
      final rawCategoryName = report['category']?['name']?.toString();
      final bool isMonitoring = MonitoringCalculator.isMonitoringReportType(
        rawCategoryName,
        rawReportType,
      );
      final Map<String, dynamic> monitoringData =
          MonitoringCalculator.extractMonitoringMap(
            Map<String, dynamic>.from(report),
          );

      return {
        'id': report['id'],
        'judul': report['title'] ?? 'Laporan tanpa judul',
        'jenis': isMonitoring
            ? 'Laporan Monitoring'
            : (rawCategoryName ?? 'Laporan Kegiatan'),
        'report_type': isMonitoring ? 'monitoring' : rawReportType,
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
        'files': rawFiles,
        'status': LaporanDateUtils.displayStatus(rawStatus),
        'statusApi': rawStatus,
        'activity_name': monitoringData['activity_name'],
        'monitoring_period': monitoringData['monitoring_period'],
        'officer_name': monitoringData['officer_name'],
        'target_value': monitoringData['target_value'],
        'target_unit': monitoringData['target_unit'],
        'target_period': monitoringData['target_period'],
        'actual_value': monitoringData['actual_value'],
        'achievement_percentage': monitoringData['achievement_percentage'],
        'remaining_target': monitoringData['remaining_target'],
        'achievement_status': monitoringData['achievement_status'],
        'field_facts': monitoringData['field_facts'],
        'obstacles': monitoringData['obstacles'],
        'failure_causes': monitoringData['failure_causes'],
        'recommendations': monitoringData['recommendations'],
        'follow_up_plan': monitoringData['follow_up_plan'],
        'next_target_date': monitoringData['next_target_date'],
        'monitoring_data': monitoringData,
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
              .timeout(httpTimeout)
        : await http
              .post(uri, headers: headers, body: jsonEncode(cleanPayload))
              .timeout(httpTimeout);

    return response;
  }

  /// Helper untuk mengirim MultipartRequest dengan pelaporan progres upload (0.0 .. 1.0).
  static Future<http.Response> _sendMultipartWithProgress(
    http.MultipartRequest multipartRequest, {
    void Function(double progress)? onProgress,
    Duration timeout = const Duration(seconds: 45),
  }) async {
    if (onProgress == null) {
      final streamed = await multipartRequest.send().timeout(timeout);
      return http.Response.fromStream(streamed);
    }

    final byteStream = multipartRequest.finalize();
    final totalBytes = multipartRequest.contentLength;
    int sentBytes = 0;

    final streamedRequest = http.StreamedRequest(
      multipartRequest.method,
      multipartRequest.url,
    );
    streamedRequest.headers.addAll(multipartRequest.headers);
    if (totalBytes > 0) {
      streamedRequest.contentLength = totalBytes;
    }

    final subscription = byteStream.listen(
      (chunk) {
        sentBytes += chunk.length;
        streamedRequest.sink.add(chunk);
        if (totalBytes > 0) {
          final pct = (sentBytes / totalBytes).clamp(0.0, 1.0);
          onProgress(pct);
        }
      },
      onDone: () => streamedRequest.sink.close(),
      onError: (Object err, StackTrace st) {
        streamedRequest.sink.addError(err, st);
      },
      cancelOnError: true,
    );

    try {
      final streamedResponse = await streamedRequest.send().timeout(timeout);
      onProgress(1.0);
      return await http.Response.fromStream(streamedResponse);
    } finally {
      await subscription.cancel();
    }
  }

  /// Uploads a photo attachment for a given [reportId] along with GPS coordinates & address.
  /// Backend Laravel mengunggah foto ke ImageKit dan menyimpan URL/metadata di PostgreSQL.
  static Future<http.Response> uploadReportPhoto({
    required String token,
    required int reportId,
    required List<int> photoBytes,
    required String filename,
    double? latitude,
    double? longitude,
    String? address,
    void Function(double progress)? onProgress,
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

    if (latitude != null) {
      request.fields['latitude'] = latitude.toString();
    }
    if (longitude != null) {
      request.fields['longitude'] = longitude.toString();
    }
    if (address != null && address.trim().isNotEmpty) {
      request.fields['address'] = address.trim();
    }

    final response = await _sendMultipartWithProgress(
      request,
      onProgress: onProgress,
    );
    clearCache();
    return response;
  }

  /// Mengambil daftar dokumen lampiran milik laporan dari API Laravel.
  static Future<List<Map<String, dynamic>>> fetchReportFiles(
    String token,
    int reportId,
  ) async {
    final response = await http
        .get(
          Uri.parse(ApiConstants.reportFilesUrl(reportId)),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(httpTimeout);

    if (response.statusCode == 401) {
      throw const UnauthorizedException();
    }
    if (response.statusCode != 200) {
      throw Exception(extractErrorMessage(response));
    }

    final decoded = jsonDecode(response.body);
    final list = decoded['data'] is List ? (decoded['data'] as List) : [];
    return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// Mengunggah dokumen pendukung laporan (PDF, Word, Excel, dll.) ke Supabase Storage melalui API Laravel.
  static Future<http.Response> uploadReportFile({
    required String token,
    required int reportId,
    required List<int> fileBytes,
    required String filename,
    String? title,
    String? description,
    void Function(double progress)? onProgress,
  }) async {
    final uri = Uri.parse(ApiConstants.reportFilesUrl(reportId));
    final request = http.MultipartRequest('POST', uri);
    request.headers['Accept'] = 'application/json';
    request.headers['Authorization'] = 'Bearer $token';

    final cleanFilename = filename.isNotEmpty
        ? filename
        : 'dokumen_laporan_${DateTime.now().millisecondsSinceEpoch}.pdf';

    final guessedMime = DeviceFileStorageService.guessMimeType(cleanFilename);
    final parts = guessedMime.split('/');
    final mediaType = parts.length == 2
        ? MediaType(parts[0], parts[1])
        : MediaType('application', 'octet-stream');

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: cleanFilename,
        contentType: mediaType,
      ),
    );

    if (title != null && title.trim().isNotEmpty) {
      request.fields['title'] = title.trim();
    }
    if (description != null && description.trim().isNotEmpty) {
      request.fields['description'] = description.trim();
    }

    final response = await _sendMultipartWithProgress(
      request,
      onProgress: onProgress,
      timeout: const Duration(seconds: 60),
    );
    clearCache();
    return response;
  }

  /// Mengunduh dokumen laporan dari Supabase Storage melalui API Laravel yang terautentikasi.
  static Future<StorageSaveResult> downloadReportFile({
    required String token,
    required int fileId,
    required String filename,
  }) async {
    final response = await http
        .get(
          Uri.parse(ApiConstants.reportFileDownloadUrl(fileId)),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode == 401) {
      throw const UnauthorizedException();
    }
    if (response.statusCode == 403) {
      throw ForbiddenException(extractErrorMessage(response));
    }
    if (response.statusCode != 200) {
      throw Exception(extractErrorMessage(response));
    }

    final bytes = response.bodyBytes;
    final cleanName = DeviceFileStorageService.sanitizeFileName(filename);

    if (kIsWeb) {
      final mime = DeviceFileStorageService.guessMimeType(cleanName);
      final xf = XFile.fromData(bytes, name: cleanName, mimeType: mime);
      await xf.saveTo(cleanName);
      return StorageSaveResult(
        success: true,
        fileName: cleanName,
        fileSizeBytes: bytes.length,
        message: 'Dokumen $cleanName berhasil diunduh.',
      );
    }

    return DeviceFileStorageService.instance.saveToDownloads(
      bytes: bytes,
      fileName: cleanName,
      subfolder: 'Phonebook/Dokumen',
    );
  }

  /// Menghapus dokumen lampiran laporan di Supabase Storage melalui API Laravel.
  static Future<void> deleteReportFile(String token, int fileId) async {
    clearCache();
    final response = await http
        .delete(
          Uri.parse(ApiConstants.reportFileDetailUrl(fileId)),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(httpTimeout);

    if (response.statusCode == 401) {
      throw const UnauthorizedException();
    }
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(extractErrorMessage(response));
    }
  }

  /// Deletes a report from the API by its [id].
  static Future<void> deleteReport(String token, dynamic id) async {
    clearCache();
    final response = await http
        .delete(
          Uri.parse('$baseUrl/api/reports/$id'),
          headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
        )
        .timeout(httpTimeout);

    if (response.statusCode != 200 && response.statusCode != 204) {
      final lower = response.body.toLowerCase();
      if (lower.contains('project is paused')) {
        throw Exception('Database Supabase sedang tidak aktif (Paused).');
      }
      throw Exception(extractErrorMessage(response));
    }
  }

  /// Saves a report locally for offline use (supporting Android/Desktop file system and Web/Base64).
  static Future<int> saveOffline({
    required Map<String, dynamic> payload,
    required String jenisLaporan,
    Uint8List? photoBytes,
    String? photoFilename,
    Uint8List? documentBytes,
    String? documentFilename,
  }) async {
    String? localPhotoPath;
    String? photoBase64;
    String? localDocPath;

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

    if (documentBytes != null && documentBytes.isNotEmpty && !kIsWeb) {
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final docDir = Directory('${appDir.path}/offline_report_docs');
        if (!docDir.existsSync()) {
          docDir.createSync(recursive: true);
        }
        final safeDocName =
            documentFilename != null && documentFilename.isNotEmpty
                ? documentFilename.replaceAll(RegExp(r'[^\w\.-]'), '_')
                : 'offline_doc_${DateTime.now().millisecondsSinceEpoch}.pdf';
        final docFile = File('${docDir.path}/$safeDocName');
        await docFile.writeAsBytes(documentBytes, flush: true);
        localDocPath = docFile.path;
      } catch (_) {}
    }

    final monitoringMap = MonitoringCalculator.extractMonitoringMap(payload);
    final bool isMonitoring = MonitoringCalculator.isMonitoringReportType(
      jenisLaporan,
      payload['report_type']?.toString(),
    );

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
      'report_type': isMonitoring ? 'monitoring' : (payload['report_type'] ?? 'standard'),
      'monitoring_data': monitoringMap.isNotEmpty ? jsonEncode(monitoringMap) : null,
      'sync_status': 'pending',
      'photo_path': localPhotoPath ?? photoBase64,
      'photo_base64': photoBase64,
      'document_path': localDocPath,
      'document_name': documentFilename,
    };

    try {
      return await OfflineDatabase.instance.insertReport(data);
    } catch (_) {
      return DateTime.now().millisecondsSinceEpoch;
    }
  }
}
