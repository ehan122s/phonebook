import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../constants/api_constants.dart';
import '../../../services/google_auth_service.dart';

class AdminApiResult<T> {
  final bool success;
  final String message;
  final T? data;
  final bool deactivated;

  const AdminApiResult({
    required this.success,
    required this.message,
    this.data,
    this.deactivated = false,
  });
}

class AdminService {
  static Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ?? '';
  }

  static Map<String, String> _authHeaders(String token, {bool json = false}) {
    return {
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static String _extractErrorMessage(
    String responseBody, {
    String fallback = 'Terjadi kesalahan pada server.',
  }) {
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map) {
        if (decoded['errors'] is Map) {
          final errors = decoded['errors'] as Map;
          for (final entry in errors.values) {
            if (entry is List && entry.isNotEmpty) {
              return entry.first.toString();
            }
          }
        }
        if (decoded['message'] != null &&
            decoded['message'].toString().trim().isNotEmpty) {
          return decoded['message'].toString();
        }
      }
    } catch (_) {}
    return fallback;
  }

  static Map<String, String> _mapUser(Map<String, dynamic> raw) {
    return {
      'id': (raw['id'] ?? '').toString(),
      'nip': (raw['nip'] ?? '').toString(),
      'name': (raw['name'] ?? '').toString(),
      'email': (raw['email'] ?? '').toString(),
      'whatsapp': (raw['whatsapp'] ?? '').toString(),
      'jabatan': (raw['jabatan'] ?? '').toString(),
      'wilayah': (raw['wilayah'] ?? 'CDK Wilayah Garut').toString(),
      'role': (raw['role'] ?? 'user').toString(),
      'status': (raw['status'] ?? 'Aktif').toString(),
    };
  }

  /// Ambil daftar seluruh pengguna dari database backend.
  static Future<AdminApiResult<List<Map<String, String>>>> fetchUsers() async {
    try {
      final token = await _getToken();
      final response = await http
          .get(
            Uri.parse('${ApiConstants.usersUrl}?per_page=100'),
            headers: _authHeaders(token),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true && decoded['data'] is List) {
          final list = (decoded['data'] as List)
              .map((u) => _mapUser(Map<String, dynamic>.from(u as Map)))
              .toList();
          return AdminApiResult(
            success: true,
            message: 'Daftar pengguna berhasil dimuat.',
            data: list,
          );
        }
      }

      return AdminApiResult(
        success: false,
        message: _extractErrorMessage(
          response.body,
          fallback: 'Gagal memuat daftar pengguna (${response.statusCode}).',
        ),
      );
    } catch (e) {
      debugPrint('AdminService.fetchUsers error: $e');
      return AdminApiResult(
        success: false,
        message: 'Gagal terhubung ke server: $e',
      );
    }
  }

  /// Tambah pengguna baru atau perbarui data pengguna (termasuk password).
  static Future<AdminApiResult<Map<String, String>>> saveUser(
    Map<String, String> user, {
    required bool isEditing,
    String? password,
    String? passwordConfirmation,
  }) async {
    try {
      final token = await _getToken();
      final uri = isEditing
          ? Uri.parse(ApiConstants.userDetailUrl(user['id']))
          : Uri.parse(ApiConstants.usersUrl);

      final payload = <String, dynamic>{
        'name': user['name'],
        'email': user['email'],
        'nip': user['nip'] == '-' ? '' : user['nip'],
        'whatsapp': user['whatsapp'] == '-' ? '' : user['whatsapp'],
        'wilayah': user['wilayah'],
        'role': user['role'],
        'status': user['status'],
      };

      if (password != null && password.isNotEmpty) {
        payload['password'] = password;
        payload['password_confirmation'] = passwordConfirmation ?? '';
      }

      final response = isEditing
          ? await http
                .put(
                  uri,
                  headers: _authHeaders(token, json: true),
                  body: jsonEncode(payload),
                )
                .timeout(const Duration(seconds: 12))
          : await http
                .post(
                  uri,
                  headers: _authHeaders(token, json: true),
                  body: jsonEncode(payload),
                )
                .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        final serverUser = decoded['data'] is Map
            ? _mapUser(Map<String, dynamic>.from(decoded['data']))
            : user;
        return AdminApiResult(
          success: true,
          message:
              decoded['message']?.toString() ??
              (isEditing
                  ? 'Data pengguna berhasil diperbarui.'
                  : 'Pengguna berhasil ditambahkan.'),
          data: serverUser,
        );
      }

      return AdminApiResult(
        success: false,
        message: _extractErrorMessage(
          response.body,
          fallback: 'Gagal menyimpan data pengguna (${response.statusCode}).',
        ),
      );
    } catch (e) {
      debugPrint('AdminService.saveUser error: $e');
      return AdminApiResult(
        success: false,
        message: 'Gagal terhubung ke server: $e',
      );
    }
  }

  /// Hapus pengguna (atau nonaktifkan otomatis jika memiliki relasi data).
  static Future<AdminApiResult<Map<String, String>>> deleteUser(
    String identifier,
  ) async {
    try {
      final token = await _getToken();
      final response = await http
          .delete(
            Uri.parse(ApiConstants.userDetailUrl(identifier)),
            headers: _authHeaders(token),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final updatedUser = decoded['data'] is Map
            ? _mapUser(Map<String, dynamic>.from(decoded['data']))
            : null;
        return AdminApiResult(
          success: true,
          deactivated: decoded['deactivated'] == true,
          message:
              decoded['message']?.toString() ?? 'Pengguna berhasil dihapus.',
          data: updatedUser,
        );
      }

      return AdminApiResult(
        success: false,
        message: _extractErrorMessage(
          response.body,
          fallback: 'Gagal menghapus pengguna (${response.statusCode}).',
        ),
      );
    } catch (e) {
      debugPrint('AdminService.deleteUser error: $e');
      return AdminApiResult(
        success: false,
        message: 'Gagal terhubung ke server: $e',
      );
    }
  }

  /// Ambil data monitoring aktivitas & statistik.
  static Future<AdminApiResult<Map<String, dynamic>>> fetchMonitoring({
    DateTime? dateFrom,
    DateTime? dateTo,
    String status = 'Semua',
  }) async {
    try {
      final token = await _getToken();
      final params = <String, String>{};
      if (dateFrom != null) {
        params['date_from'] =
            '${dateFrom.year}-${dateFrom.month.toString().padLeft(2, '0')}-${dateFrom.day.toString().padLeft(2, '0')}';
      }
      if (dateTo != null) {
        params['date_to'] =
            '${dateTo.year}-${dateTo.month.toString().padLeft(2, '0')}-${dateTo.day.toString().padLeft(2, '0')}';
      }
      if (status != 'Semua') {
        params['status'] = status;
      }

      final uri = Uri.parse('${ApiConstants.baseUrl}/api/admin/monitoring')
          .replace(queryParameters: params);

      final response = await http
          .get(uri, headers: _authHeaders(token))
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final data = decoded['data'] is Map
            ? Map<String, dynamic>.from(decoded['data'])
            : <String, dynamic>{};
        return AdminApiResult(
          success: true,
          message: 'Data monitoring berhasil dimuat.',
          data: data,
        );
      }

      return AdminApiResult(
        success: false,
        message: _extractErrorMessage(
          response.body,
          fallback: 'Gagal memuat data monitoring.',
        ),
      );
    } catch (e) {
      debugPrint('AdminService.fetchMonitoring error: $e');
      return AdminApiResult(
        success: false,
        message: 'Gagal terhubung ke server: $e',
      );
    }
  }

  /// Perbarui status verifikasi laporan dari halaman monitoring.
  static Future<bool> updateReportStatus(
    dynamic reportId,
    String status,
  ) async {
    try {
      final token = await _getToken();
      final response = await http
          .put(
            Uri.parse(ApiConstants.reportDetailUrl(reportId)),
            headers: _authHeaders(token, json: true),
            body: jsonEncode({'status': status}),
          )
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Logout sesi Administrator.
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    if (token.isNotEmpty &&
        !token.startsWith('offline_') &&
        !token.startsWith('google_session_')) {
      try {
        await http
            .post(
              Uri.parse('${ApiConstants.baseUrl}/api/logout'),
              headers: _authHeaders(token),
            )
            .timeout(const Duration(seconds: 3));
      } catch (_) {}
    }

    await GoogleAuthService.signOut();

    const sessionKeys = [
      'token',
      'name',
      'email',
      'role',
      'login_method',
      'profil_nama',
      'profil_nip',
      'profil_jabatan',
      'profil_wilayah',
      'profil_email_nip',
      'profil_whatsapp',
      'profil_avatar',
    ];
    for (final key in sessionKeys) {
      await prefs.remove(key);
    }
  }
}
