import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/api_constants.dart';
import '../widgets/app_update_dialog.dart';

/// Model representasi data pembaruan aplikasi Phonebook
class AppUpdateInfo {
  final int id;
  final String version;
  final String title;
  final String description;
  final String apkUrl;
  final String type; // 'optional' atau 'mandatory'
  final bool isPublished;
  final DateTime? publishedAt;
  final String? minSupportedVersion;

  const AppUpdateInfo({
    required this.id,
    required this.version,
    required this.title,
    required this.description,
    required this.apkUrl,
    required this.type,
    required this.isPublished,
    this.publishedAt,
    this.minSupportedVersion,
  });

  bool get isMandatory => type.toLowerCase() == 'mandatory';

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      version: (json['version'] ?? '').toString().trim(),
      title: (json['title'] ?? 'Pembaruan Phonebook').toString().trim(),
      description: (json['description'] ?? '').toString().trim(),
      apkUrl: (json['apk_url'] ?? '').toString().trim(),
      type: (json['type'] ?? 'optional').toString().trim().toLowerCase(),
      isPublished: json['is_published'] == true || json['is_published'] == 1 || json['is_published'] == '1',
      publishedAt: json['published_at'] != null ? DateTime.tryParse(json['published_at'].toString()) : null,
      minSupportedVersion: json['min_supported_version']?.toString(),
    );
  }
}

/// Service untuk memeriksa dan mengelola pembaruan aplikasi secara non-blocking
class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  static const String _dismissedUpdateKey = 'phonebook_dismissed_update_version';

  String? _cachedAppVersion;
  bool _isChecking = false;

  /// Mengambil nomor versi aplikasi yang sedang terpasang (dari package_info_plus)
  Future<String> getCurrentVersion() async {
    if (_cachedAppVersion != null && _cachedAppVersion!.isNotEmpty) {
      return _cachedAppVersion!;
    }

    try {
      final info = await PackageInfo.fromPlatform();
      final ver = info.version.trim();
      if (ver.isNotEmpty) {
        _cachedAppVersion = ver;
        return ver;
      }
    } catch (e) {
      debugPrint('[AppUpdateService] Gagal membaca versi dari platform: $e');
    }

    _cachedAppVersion = '1.0.0';
    return _cachedAppVersion!;
  }

  /// Membandingkan dua nomor versi secara semantik (SemVer)
  /// Mengembalikan true jika [serverVersion] lebih baru daripada [currentVersion]
  static bool isNewerVersion(String serverVersion, String currentVersion) {
    try {
      final cleanServer = serverVersion.replaceAll(RegExp(r'[^0-9.]'), '').split('.');
      final cleanCurrent = currentVersion.replaceAll(RegExp(r'[^0-9.]'), '').split('.');

      final maxLen = cleanServer.length > cleanCurrent.length ? cleanServer.length : cleanCurrent.length;

      for (int i = 0; i < maxLen; i++) {
        final serverPart = i < cleanServer.length ? (int.tryParse(cleanServer[i]) ?? 0) : 0;
        final currentPart = i < cleanCurrent.length ? (int.tryParse(cleanCurrent[i]) ?? 0) : 0;

        if (serverPart > currentPart) return true;
        if (serverPart < currentPart) return false;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  /// Mengambil informasi update aplikasi terbaru dari backend Laravel
  Future<AppUpdateInfo?> fetchLatestUpdate() async {
    try {
      final response = await http
          .get(
            Uri.parse(ApiConstants.latestAppUpdateUrl),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final updateInfo = AppUpdateInfo.fromJson(Map<String, dynamic>.from(data['data']));
          if (updateInfo.isPublished) {
            return updateInfo;
          }
        }
      }
    } on TimeoutException {
      debugPrint('[AppUpdateService] Timeout saat mengecek pembaruan aplikasi (silent).');
    } on SocketException {
      debugPrint('[AppUpdateService] Perangkat offline, lewati pengecekan pembaruan.');
    } catch (e) {
      debugPrint('[AppUpdateService] Pengecekan pembaruan dilewati: $e');
    }

    return null;
  }

  /// Menyimpan status bahwa pengguna telah memilih "Nanti Saja" untuk versi tertentu
  Future<void> dismissUpdate(String version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_dismissedUpdateKey, version);
    } catch (_) {}
  }

  /// Memeriksa apakah ada update baru dan menampilkan pop-up dialog jika tersedia
  /// [isManualCheck] bernilai true jika dipicu dari tombol pengaturan oleh user
  Future<void> checkAndShowUpdateDialog(
    BuildContext context, {
    bool isManualCheck = false,
  }) async {
    if (_isChecking) return;
    _isChecking = true;

    try {
      final currentVersion = await getCurrentVersion();
      final latestUpdate = await fetchLatestUpdate();

      if (!context.mounted) return;

      if (latestUpdate != null) {
        final hasUpdate = isNewerVersion(latestUpdate.version, currentVersion);

        if (hasUpdate) {
          // Jika update opsional dan bukan pengecekan manual, periksa apakah sudah pernah ditolak
          if (!isManualCheck && !latestUpdate.isMandatory) {
            final prefs = await SharedPreferences.getInstance();
            final dismissedVersion = prefs.getString(_dismissedUpdateKey);
            if (dismissedVersion == latestUpdate.version) {
              // Pengguna sudah memilih "Nanti Saja" untuk versi ini
              return;
            }
          }

          if (context.mounted) {
            await showDialog(
              context: context,
              barrierDismissible: !latestUpdate.isMandatory,
              builder: (ctx) => AppUpdateDialog(
                updateInfo: latestUpdate,
                currentVersion: currentVersion,
              ),
            );
          }
          return;
        }
      }

      // Jika pengecekan manual dan tidak ada update, tampilkan pesan informatif
      if (isManualCheck && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF245C3A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Aplikasi Phonebook sudah menggunakan versi terbaru (v$currentVersion).',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('[AppUpdateService] Error saat checkAndShowUpdateDialog: $e');
    } finally {
      _isChecking = false;
    }
  }
}
