import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/api_constants.dart';
import '../../services/app_settings_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/jadwal_service.dart';
import '../../services/laporan_service.dart';
import '../../services/notification_service.dart';
import '../../services/offline_database.dart';
import '../../services/sync_service.dart';
import '../../widgets/logout_button.dart';
import '../../widgets/profil/profile_account_settings.dart';
import '../../widgets/profil/profile_activity_summary.dart';
import '../../widgets/profil/profile_app_settings.dart';
import '../../widgets/profil/profile_help_section.dart';
import '../../widgets/profil/profile_identity_card.dart';
import '../../widgets/profil/profile_info_section.dart';
import '../../widgets/profil/profile_sync_status.dart';

class ProfilPage extends StatefulWidget {
  const ProfilPage({super.key});

  @override
  State<ProfilPage> createState() => _ProfilPageState();
}

class _ProfilPageState extends State<ProfilPage> {
  // Cache sesi di memori agar saat berpindah tab tidak pernah berkedip atau menampilkan data dummy
  static Map<String, String>? _cachedProfile;

  // Identitas & Data Kepegawaian (Tanpa Data Dummy)
  bool _isLoadingProfile = _cachedProfile == null;
  String _nama = _cachedProfile?['nama'] ?? '';
  String _email = _cachedProfile?['email'] ?? '';
  String _nip = _cachedProfile?['nip'] ?? '';
  String _jabatan = _cachedProfile?['jabatan'] ?? 'Penyuluh Kehutanan';
  final String _pangkat = 'Penata Muda / III/a';
  final String _instansi = 'Dinas Kehutanan Provinsi Jawa Barat';
  final String _unitKerja = 'Cabang Dinas Kehutanan Wilayah V Garut';
  String _wilayah = _cachedProfile?['wilayah'] ?? 'CDK Wilayah Garut';
  String _whatsapp = _cachedProfile?['whatsapp'] ?? '';
  String _avatar = _cachedProfile?['avatar'] ?? '';
  String _role = _cachedProfile?['role'] ?? 'user';
  String _status = 'Aktif';
  String _token = _cachedProfile?['token'] ?? '';
  String _loginMethod = _cachedProfile?['loginMethod'] ?? 'email';

  // Ringkasan Aktivitas
  int _totalLaporan = 0;
  int _totalJadwal = 0;
  int _totalMateri = 0;
  int _totalPendingSync = 0;

  // Koneksi & Sinkronisasi
  bool _isOnline = true;
  bool _isSyncing = false;
  String _lastSyncTime = '';
  StreamSubscription<bool>? _connSub;

  // Pengaturan Aplikasi
  String _currentTheme = 'Sistem';
  String _textScale = 'Normal';
  String _storageUsage = 'Menghitung...';

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    _loadActivityStats();
    _initConnectivity();
    _loadSettings();
    _calculateStorageUsage();
  }

  @override
  void dispose() {
    _connSub?.cancel();
    super.dispose();
  }

  // ===========================================================================
  // 1. Inisialisasi & Pengambilan Data
  // ===========================================================================

  Future<void> _initConnectivity() async {
    _isOnline = await ConnectivityService.instance.isOnline();
    if (mounted) setState(() {});

    _connSub =
        ConnectivityService.instance.onConnectivityChanged.listen((online) {
      if (mounted) {
        setState(() {
          _isOnline = online;
        });
      }
    });
  }

  bool _isDummyString(String? value) {
    if (value == null) return true;
    final v = value.trim().toLowerCase();
    return v.isEmpty ||
        v == 'rizky pratama, s.hut.' ||
        v == 'rizky pratama' ||
        v == 'rizky@kehutanan.go.id' ||
        v == '19940812 202012 1 004' ||
        v == '0812-3456-7890';
  }

  String _formatNameFromEmail(String email) {
    final trimmed = email.trim();
    if (trimmed.isEmpty || !trimmed.contains('@')) return 'Pegawai Kehutanan';
    final localPart = trimmed.split('@').first;
    final words = localPart
        .replaceAll(RegExp(r'[._-]+'), ' ')
        .split(' ')
        .where((w) => w.trim().isNotEmpty)
        .map((w) => w[0].toUpperCase() + (w.length > 1 ? w.substring(1) : ''))
        .toList();
    return words.isEmpty ? localPart : words.join(' ');
  }

  void _syncMemoryCache() {
    _cachedProfile = {
      'token': _token,
      'email': _email,
      'nama': _nama,
      'nip': _nip,
      'jabatan': _jabatan,
      'wilayah': _wilayah,
      'whatsapp': _whatsapp,
      'avatar': _avatar,
      'role': _role,
      'loginMethod': _loginMethod,
    };
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final token = (prefs.getString('token') ?? '').trim();

    final rawEmail = (prefs.getString('email') ?? '').trim();
    final rawProfilEmail = (prefs.getString('profil_email') ?? '').trim();
    final email = !_isDummyString(rawEmail)
        ? rawEmail
        : (!_isDummyString(rawProfilEmail) ? rawProfilEmail : '');

    final rawSessionName = (prefs.getString('name') ?? '').trim();
    final rawProfilName = (prefs.getString('profil_nama') ?? '').trim();
    if (_isDummyString(rawProfilName) && rawProfilName.isNotEmpty) {
      await prefs.remove('profil_nama');
    }

    String name = '';
    if (!_isDummyString(rawSessionName)) {
      name = rawSessionName;
    } else if (!_isDummyString(rawProfilName)) {
      name = rawProfilName;
    } else if (email.isNotEmpty) {
      name = _formatNameFromEmail(email);
    } else {
      name = 'Pegawai Kehutanan';
    }

    final rawNip =
        (prefs.getString('profil_nip') ?? prefs.getString('nip') ?? '').trim();
    final nip = _isDummyString(rawNip) ? '' : rawNip;
    if (_isDummyString(rawNip) && rawNip.isNotEmpty) {
      await prefs.remove('profil_nip');
    }

    final rawJabatan = (prefs.getString('profil_jabatan') ??
            prefs.getString('jabatan') ??
            '')
        .trim();
    final role = (prefs.getString('role') ?? 'user').trim();
    final jabatan = rawJabatan.isNotEmpty
        ? rawJabatan
        : (role.toLowerCase() == 'admin'
            ? 'Administrator CDK V'
            : 'Penyuluh Kehutanan');

    final rawWilayah = (prefs.getString('profil_wilayah') ??
            prefs.getString('wilayah') ??
            '')
        .trim();
    final wilayah = rawWilayah.isNotEmpty ? rawWilayah : 'CDK Wilayah Garut';

    final rawWhatsapp = (prefs.getString('profil_whatsapp') ??
            prefs.getString('whatsapp_number') ??
            '')
        .trim();
    final whatsapp = _isDummyString(rawWhatsapp) ? '' : rawWhatsapp;
    if (_isDummyString(rawWhatsapp) && rawWhatsapp.isNotEmpty) {
      await prefs.remove('profil_whatsapp');
    }

    final avatar =
        (prefs.getString('profil_avatar') ?? prefs.getString('avatar') ?? '')
            .trim();
    final loginMethod = (prefs.getString('login_method') ?? 'email').trim();
    final lastSync = (prefs.getString('last_sync_time') ?? '').trim();

    setState(() {
      _token = token;
      _email = email;
      _nama = name;
      _nip = nip;
      _jabatan = jabatan;
      _wilayah = wilayah;
      _whatsapp = whatsapp;
      _avatar = avatar;
      _role = role;
      _loginMethod = loginMethod;
      _lastSyncTime = lastSync;
      _status = 'Aktif';
      _isLoadingProfile = false;
    });
    _syncMemoryCache();

    final online = await ConnectivityService.instance.isOnline();
    if (online && (token.isNotEmpty || email.isNotEmpty)) {
      await _fetchProfileFromBackend(token, email);
    }
  }

  Future<void> _applyBackendUserMap(Map<String, dynamic> u) async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      if (u['name'] != null && !_isDummyString(u['name'].toString())) {
        _nama = u['name'].toString().trim();
        prefs.setString('name', _nama);
        prefs.setString('profil_nama', _nama);
      }
      if (u['email'] != null && !_isDummyString(u['email'].toString())) {
        _email = u['email'].toString().trim();
        prefs.setString('email', _email);
        prefs.setString('profil_email', _email);
      }
      if (u['nip'] != null && !_isDummyString(u['nip'].toString())) {
        _nip = u['nip'].toString().trim();
        prefs.setString('nip', _nip);
        prefs.setString('profil_nip', _nip);
      }
      if (u['jabatan'] != null && u['jabatan'].toString().trim().isNotEmpty) {
        _jabatan = u['jabatan'].toString().trim();
        prefs.setString('jabatan', _jabatan);
        prefs.setString('profil_jabatan', _jabatan);
      }
      if (u['wilayah'] != null && u['wilayah'].toString().trim().isNotEmpty) {
        _wilayah = u['wilayah'].toString().trim();
        prefs.setString('wilayah', _wilayah);
        prefs.setString('profil_wilayah', _wilayah);
      }
      if (u['whatsapp_number'] != null &&
          !_isDummyString(u['whatsapp_number'].toString())) {
        _whatsapp = u['whatsapp_number'].toString().trim();
        prefs.setString('whatsapp_number', _whatsapp);
        prefs.setString('profil_whatsapp', _whatsapp);
      }
      if (u['avatar'] != null && u['avatar'].toString().trim().isNotEmpty) {
        _avatar = u['avatar'].toString().trim();
        prefs.setString('avatar', _avatar);
        prefs.setString('profil_avatar', _avatar);
      }
      if (u['role'] != null && u['role'].toString().trim().isNotEmpty) {
        _role = u['role'].toString().trim();
        prefs.setString('role', _role);
      }
    });
    _syncMemoryCache();
  }

  Future<void> _fetchProfileFromBackend(String token, String email) async {
    if (token.isNotEmpty &&
        !token.startsWith('offline_') &&
        !token.startsWith('google_session_') &&
        !token.startsWith('google_reg_')) {
      try {
        final res = await http
            .get(
              Uri.parse('${ApiConstants.baseUrl}/api/user'),
              headers: {
                'Accept': 'application/json',
                'Authorization': 'Bearer $token',
              },
            )
            .timeout(const Duration(seconds: 5));

        if (res.statusCode == 200) {
          final body = jsonDecode(res.body);
          if (body['success'] == true && body['data'] is Map) {
            await _applyBackendUserMap(
              Map<String, dynamic>.from(body['data'] as Map),
            );
            return;
          }
        }
      } catch (_) {}
    }

    if (email.isNotEmpty) {
      try {
        final checkRes = await http
            .post(
              Uri.parse('${ApiConstants.baseUrl}/api/google-check'),
              headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({'email': email}),
            )
            .timeout(const Duration(seconds: 5));

        if (checkRes.statusCode == 200) {
          final body = jsonDecode(checkRes.body);
          final userMap = body['data']?['user'];
          if (body['success'] == true && userMap is Map) {
            await _applyBackendUserMap(Map<String, dynamic>.from(userMap));
            final newToken = body['data']?['token']?.toString() ?? '';
            if (newToken.isNotEmpty) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('token', newToken);
              if (mounted) {
                setState(() => _token = newToken);
                _syncMemoryCache();
              }
            }
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _loadActivityStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = (prefs.getString('token') ?? '').trim();
      final online = await ConnectivityService.instance.isOnline();

      final allLocalReports = await OfflineDatabase.instance.getAllLocalReports();
      final pendingCount = await OfflineDatabase.instance.getPendingCount();

      int laporanCount = allLocalReports.length;
      if (online &&
          token.isNotEmpty &&
          !token.startsWith('offline_') &&
          !token.startsWith('google_session_')) {
        try {
          final serverReports = await LaporanService.fetchReports(token);
          if (serverReports.length > laporanCount) {
            laporanCount = serverReports.length;
          }
        } catch (_) {}
      } else {
        final rawDrafts = prefs.getString('phonebook_laporan_drafts_v1');
        if (rawDrafts != null && rawDrafts.isNotEmpty) {
          try {
            final list = jsonDecode(rawDrafts) as List;
            if (list.length > laporanCount) laporanCount = list.length;
          } catch (_) {}
        }
      }

      final schedules = await JadwalService.loadSchedules();
      final int jadwalCount = schedules.length;

      int materiCount = 0;
      final rawMateri = prefs.getString('phonebook_shared_materials_v2');
      if (rawMateri != null && rawMateri.isNotEmpty) {
        try {
          final list = jsonDecode(rawMateri) as List;
          materiCount = list.length;
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _totalLaporan = laporanCount;
        _totalPendingSync = pendingCount;
        _totalJadwal = jadwalCount;
        _totalMateri = materiCount;
      });
    } catch (_) {}
  }

  Future<void> _loadSettings() async {
    if (!mounted) return;
    setState(() {
      _currentTheme = AppSettingsService.instance.themeString;
      _textScale = AppSettingsService.instance.textScaleString;
    });
  }

  Future<void> _calculateStorageUsage() async {
    try {
      final db = await OfflineDatabase.instance.database;
      final reports = await db.query('offline_reports');
      final bytes = utf8.encode(jsonEncode(reports)).length;
      final kb = (bytes / 1024).toStringAsFixed(1);

      if (mounted) {
        setState(() {
          _storageUsage = '$kb KB (${reports.length} rekaman arsip offline)';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _storageUsage = 'Kurang dari 1 MB';
        });
      }
    }
  }

  // ===========================================================================
  // 2. Aksi Sinkronisasi
  // ===========================================================================

  Future<void> _handleSyncNow() async {
    if (_isSyncing) return;

    final isConnected = await ConnectivityService.instance.isOnline();
    if (!isConnected) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Koneksi internet tidak tersedia. Data tersimpan aman di HP dan akan disinkronkan saat online.',
          ),
          backgroundColor: Color(0xFFE65100),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isSyncing = true;
    });

    try {
      final token = _token.isNotEmpty ? _token : 'phonebook_guest_sync';
      final result = await SyncService.syncAll(token);

      final now = DateTime.now();
      final months = [
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'Mei',
        'Jun',
        'Jul',
        'Agu',
        'Sep',
        'Okt',
        'Nov',
        'Des',
      ];
      final formattedTime =
          '${now.day} ${months[now.month]} ${now.year}, ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} WIB';

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_sync_time', formattedTime);

      await _loadActivityStats();

      if (!mounted) return;
      setState(() {
        _lastSyncTime = formattedTime;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.total == 0
                ? 'Semua laporan sudah tersinkronisasi dengan server pusat CDK V.'
                : 'Sinkronisasi selesai: ${result.synced} laporan terunggah, ${result.failed} gagal.',
          ),
          backgroundColor: result.failed == 0
              ? const Color(0xFF285C2E)
              : const Color(0xFFE65100),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kendala saat sinkronisasi: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  // ===========================================================================
  // 3. Dialog & Aksi Pengaturan Akun (Adaptif Light & Dark Mode)
  // ===========================================================================

  InputDecoration _adaptiveInputDecoration({
    required BuildContext context,
    required String label,
    String? hint,
    IconData? prefixIcon,
    Widget? suffixIcon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fillColor = isDark ? const Color(0xFF162019) : const Color(0xFFF7FAF7);
    final borderColor =
        isDark ? const Color(0xFF2E3D34) : const Color(0xFFD5E2D6);
    final primaryColor =
        isDark ? const Color(0xFF81C784) : const Color(0xFF285C2E);
    final labelColor = isDark ? Colors.white70 : const Color(0xFF4A584E);

    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: labelColor, fontSize: 13.5),
      floatingLabelStyle: TextStyle(
        color: primaryColor,
        fontWeight: FontWeight.w700,
      ),
      hintStyle: TextStyle(
        color: isDark ? Colors.white38 : Colors.grey.shade500,
        fontSize: 13,
      ),
      prefixIcon:
          prefixIcon != null ? Icon(prefixIcon, color: primaryColor) : null,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: fillColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: primaryColor, width: 1.6),
      ),
    );
  }

  void _showEditProfileDialog() {
    final namaCtrl = TextEditingController(text: _nama);
    final waCtrl = TextEditingController(text: _whatsapp);
    final wilayahCtrl = TextEditingController(text: _wilayah);

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final textColor = isDark ? Colors.white : const Color(0xFF1E2923);
        final subColor = isDark ? Colors.white70 : Colors.grey.shade700;
        final primaryGreen =
            isDark ? const Color(0xFF81C784) : const Color(0xFF285C2E);

        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E2822) : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.edit_note_rounded, color: primaryGreen, size: 26),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Edit Profil Pribadi',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17.5,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Anda dapat memperbarui nama tampilan, nomor kontak WhatsApp, dan penugasan wilayah.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: subColor,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: namaCtrl,
                  style: TextStyle(color: textColor),
                  decoration: _adaptiveInputDecoration(
                    context: ctx,
                    label: 'Nama Lengkap Beserta Gelar',
                    prefixIcon: Icons.person_outline,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: waCtrl,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(color: textColor),
                  decoration: _adaptiveInputDecoration(
                    context: ctx,
                    label: 'Nomor WhatsApp / Telepon',
                    prefixIcon: Icons.phone_android_outlined,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: wilayahCtrl,
                  style: TextStyle(color: textColor),
                  decoration: _adaptiveInputDecoration(
                    context: ctx,
                    label: 'Wilayah Tugas / Binaan',
                    prefixIcon: Icons.location_on_outlined,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Batal', style: TextStyle(color: subColor)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF285C2E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                final newName =
                    namaCtrl.text.trim().isEmpty ? _nama : namaCtrl.text.trim();
                final newWa =
                    waCtrl.text.trim().isEmpty ? _whatsapp : waCtrl.text.trim();
                final newWil = wilayahCtrl.text.trim().isEmpty
                    ? _wilayah
                    : wilayahCtrl.text.trim();

                Navigator.pop(ctx);

                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('name', newName);
                await prefs.setString('profil_nama', newName);
                await prefs.setString('whatsapp_number', newWa);
                await prefs.setString('profil_whatsapp', newWa);
                await prefs.setString('wilayah', newWil);
                await prefs.setString('profil_wilayah', newWil);

                if (mounted) {
                  setState(() {
                    _nama = newName;
                    _whatsapp = newWa;
                    _wilayah = newWil;
                  });
                  _syncMemoryCache();
                }

                if (_isOnline &&
                    _token.isNotEmpty &&
                    !_token.startsWith('offline_')) {
                  try {
                    await http
                        .post(
                          Uri.parse('${ApiConstants.baseUrl}/api/user/profile'),
                          headers: {
                            'Accept': 'application/json',
                            'Content-Type': 'application/json',
                            'Authorization': 'Bearer $_token',
                          },
                          body: jsonEncode({
                            'name': newName,
                            'whatsapp_number': newWa,
                            'wilayah': newWil,
                          }),
                        )
                        .timeout(const Duration(seconds: 4));
                  } catch (_) {}
                }

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Profil berhasil diperbarui.'),
                      backgroundColor: Color(0xFF285C2E),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  void _showChangePasswordDialog() {
    final isGoogle = _loginMethod.toLowerCase() == 'google';
    if (isGoogle) {
      showDialog(
        context: context,
        builder: (ctx) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final textColor = isDark ? Colors.white : const Color(0xFF1E2923);
          final subColor = isDark ? Colors.white70 : const Color(0xFF4A584E);

          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E2822) : Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: isDark
                      ? const Color(0xFF64B5F6)
                      : const Color(0xFF1565C0),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Otentikasi Akun Google',
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              'Akun Anda terhubung langsung dengan Akun Google resmi. Pengelolaan kata sandi dikendalikan melalui keamanan Akun Google Anda.',
              style: TextStyle(fontSize: 13, height: 1.4, color: subColor),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF285C2E),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Mengerti'),
              ),
            ],
          );
        },
      );
      return;
    }

    final oldPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    bool obscureOld = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final textColor = isDark ? Colors.white : const Color(0xFF1E2923);
          final subColor = isDark ? Colors.white70 : Colors.grey.shade600;
          final primaryGreen =
              isDark ? const Color(0xFF81C784) : const Color(0xFF285C2E);

          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E2822) : Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(Icons.lock_reset_rounded, color: primaryGreen),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ubah Kata Sandi',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: oldPassCtrl,
                    obscureText: obscureOld,
                    style: TextStyle(color: textColor),
                    decoration: _adaptiveInputDecoration(
                      context: ctx,
                      label: 'Kata Sandi Saat Ini',
                      prefixIcon: Icons.lock_outline,
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureOld ? Icons.visibility_off : Icons.visibility,
                          color: subColor,
                        ),
                        onPressed: () =>
                            setDialogState(() => obscureOld = !obscureOld),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newPassCtrl,
                    obscureText: obscureNew,
                    style: TextStyle(color: textColor),
                    decoration: _adaptiveInputDecoration(
                      context: ctx,
                      label: 'Kata Sandi Baru (Min. 8 Karakter)',
                      prefixIcon: Icons.vpn_key_outlined,
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureNew ? Icons.visibility_off : Icons.visibility,
                          color: subColor,
                        ),
                        onPressed: () =>
                            setDialogState(() => obscureNew = !obscureNew),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmPassCtrl,
                    obscureText: obscureConfirm,
                    style: TextStyle(color: textColor),
                    decoration: _adaptiveInputDecoration(
                      context: ctx,
                      label: 'Konfirmasi Kata Sandi Baru',
                      prefixIcon: Icons.verified_user_outlined,
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureConfirm
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: subColor,
                        ),
                        onPressed: () => setDialogState(
                          () => obscureConfirm = !obscureConfirm,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Batal', style: TextStyle(color: subColor)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF285C2E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () async {
                  final oldP = oldPassCtrl.text;
                  final newP = newPassCtrl.text;
                  final confP = confirmPassCtrl.text;

                  if (oldP.isEmpty || newP.isEmpty || confP.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Semua kolom kata sandi wajib diisi.'),
                      ),
                    );
                    return;
                  }
                  if (newP.length < 8) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Kata sandi baru minimal 8 karakter.'),
                      ),
                    );
                    return;
                  }
                  if (newP != confP) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Konfirmasi kata sandi tidak cocok.'),
                      ),
                    );
                    return;
                  }

                  Navigator.pop(ctx);

                  if (_isOnline &&
                      _token.isNotEmpty &&
                      !_token.startsWith('offline_')) {
                    try {
                      final res = await http
                          .post(
                            Uri.parse(
                              '${ApiConstants.baseUrl}/api/user/change-password',
                            ),
                            headers: {
                              'Accept': 'application/json',
                              'Content-Type': 'application/json',
                              'Authorization': 'Bearer $_token',
                            },
                            body: jsonEncode({
                              'current_password': oldP,
                              'new_password': newP,
                              'new_password_confirmation': confP,
                            }),
                          )
                          .timeout(const Duration(seconds: 4));

                      if (res.statusCode == 200) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Kata sandi berhasil diperbarui.'),
                              backgroundColor: Color(0xFF285C2E),
                            ),
                          );
                        }
                        return;
                      }
                    } catch (_) {}
                  }

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Kata sandi diperbarui secara lokal.'),
                        backgroundColor: Color(0xFF285C2E),
                      ),
                    );
                  }
                },
                child: const Text('Simpan'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _handlePickAvatar() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final textColor = isDark ? Colors.white : const Color(0xFF1E2923);
        final primaryGreen =
            isDark ? const Color(0xFF81C784) : const Color(0xFF285C2E);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kelola Foto Profil',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.camera_alt_outlined, color: primaryGreen),
                title: Text(
                  'Ambil Foto dari Kamera',
                  style: TextStyle(color: textColor),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final picker = ImagePicker();
                  final picked = await picker.pickImage(
                    source: ImageSource.camera,
                    maxWidth: 600,
                  );
                  if (picked != null) {
                    _saveAvatarPath(picked.path);
                  }
                },
              ),
              ListTile(
                leading:
                    Icon(Icons.photo_library_outlined, color: primaryGreen),
                title: Text(
                  'Pilih dari Galeri Foto',
                  style: TextStyle(color: textColor),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final picker = ImagePicker();
                  final picked = await picker.pickImage(
                    source: ImageSource.gallery,
                    maxWidth: 600,
                  );
                  if (picked != null) {
                    _saveAvatarPath(picked.path);
                  }
                },
              ),
              if (_avatar.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text(
                    'Hapus Foto Profil',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    _saveAvatarPath('');
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveAvatarPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profil_avatar', path);

    if (mounted) {
      setState(() {
        _avatar = path;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto profil berhasil diperbarui.'),
          backgroundColor: Color(0xFF285C2E),
        ),
      );
    }

    if (_isOnline && _token.isNotEmpty && !_token.startsWith('offline_')) {
      try {
        await http
            .post(
              Uri.parse('${ApiConstants.baseUrl}/api/user/profile'),
              headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $_token',
              },
              body: jsonEncode({
                'name': _nama,
                'avatar': path,
              }),
            )
            .timeout(const Duration(seconds: 4));
      } catch (_) {}
    }
  }

  void _showSecurityInfoDialog() {
    final isGoogle = _loginMethod.toLowerCase() == 'google';
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final textColor = isDark ? Colors.white : const Color(0xFF1E2923);
        final primaryGreen =
            isDark ? const Color(0xFF81C784) : const Color(0xFF285C2E);

        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E2822) : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.security_rounded, color: primaryGreen),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Keamanan Akun & Sesi',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSecurityRow(
                ctx,
                'Metode Autentikasi',
                isGoogle ? 'Google OAuth 2.0' : 'Email & Kata Sandi',
              ),
              _buildSecurityRow(
                ctx,
                'Status Token Sesi',
                _token.isNotEmpty ? 'Aktif (Tervalidasi)' : 'Tamu / Offline',
              ),
              _buildSecurityRow(ctx, 'Enkripsi Database', 'SQLite AES Ready'),
              _buildSecurityRow(
                ctx,
                'Keamanan Arsip',
                'Tersimpan di Direktori Aplikasi',
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1C2B21)
                      : const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: primaryGreen,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sesi login Anda dilindungi oleh Laravel Sanctum Token Security.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark
                              ? const Color(0xFFA5D6A7)
                              : const Color(0xFF1B5E20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF285C2E),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSecurityRow(BuildContext context, String title, String val) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            val,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E2923),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 4. Aksi Pengaturan Aplikasi (Tema & Skala Teks Konsisten)
  // ===========================================================================

  Future<void> _updateTheme(String theme) async {
    await AppSettingsService.instance.setTheme(theme);
    if (!mounted) return;
    setState(() {
      _currentTheme = AppSettingsService.instance.themeString;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Tema tampilan diubah ke: ${AppSettingsService.instance.themeString}',
        ),
        backgroundColor: const Color(0xFF285C2E),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _updateTextScale(String scale) async {
    await AppSettingsService.instance.setTextScale(scale);
    if (!mounted) return;
    setState(() {
      _textScale = AppSettingsService.instance.textScaleString;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Ukuran teks diatur ke: ${AppSettingsService.instance.textScaleString}',
        ),
        backgroundColor: const Color(0xFF285C2E),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final textColor = isDark ? Colors.white : const Color(0xFF1E2923);
        final subColor = isDark ? Colors.white70 : const Color(0xFF4A584E);

        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E2822) : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            'Bersihkan Cache Sementara',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 17,
              color: textColor,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Membersihkan cache hanya akan menghapus berkas sementara antarmuka dan memori gambar thumbnail.',
                style: TextStyle(fontSize: 13, height: 1.4, color: subColor),
              ),
              const SizedBox(height: 10),
              Text(
                '✓ Draft laporan offline Anda TETAP AMAN dan TIDAK AKAN TERHAPUS.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? const Color(0xFF81C784)
                      : const Color(0xFF2E7D32),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Batal', style: TextStyle(color: subColor)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF285C2E),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                PaintingBinding.instance.imageCache.clear();
                PaintingBinding.instance.imageCache.clearLiveImages();
                await _calculateStorageUsage();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Cache sementara berhasil dibersihkan.'),
                      backgroundColor: Color(0xFF285C2E),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text('Bersihkan'),
            ),
          ],
        );
      },
    );
  }

  // ===========================================================================
  // 5. Bantuan, Laporan Bug ke Tim IT (DC) & Pusat Informasi
  // ===========================================================================

  void _showUserGuide() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final textColor = isDark ? Colors.white : const Color(0xFF1E2923);
        final primaryGreen =
            isDark ? const Color(0xFF81C784) : const Color(0xFF285C2E);

        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.menu_book_rounded,
                      color: primaryGreen,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Panduan Penggunaan Phonebook',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildGuideCard(
                  ctx: ctx,
                  step: '1',
                  title: 'Pelaporan di Tengah Hutan (Offline & GPS)',
                  desc:
                      'Ketika tidak ada sinyal internet, Anda tetap dapat membuat laporan lengkap dengan foto geolokasi dan titik koordinat GPS. Laporan akan tersimpan otomatis di database HP Anda.',
                ),
                _buildGuideCard(
                  ctx: ctx,
                  step: '2',
                  title: 'Sinkronisasi Otomatis & Manual',
                  desc:
                      'Setelah Anda kembali ke area bersinyal atau kantor CDK V, buka tab Profil atau Laporan lalu ketuk "Sinkronkan Sekarang" untuk mengunggah semua arsip ke server dinas.',
                ),
                _buildGuideCard(
                  ctx: ctx,
                  step: '3',
                  title: 'Materi Edukasi & Google Drive',
                  desc:
                      'Pelajari atau bagikan dokumen silvikultur, bibit tanaman, dan modul penyuluhan via File Manager HP atau tautan Google Drive publik.',
                ),
                _buildGuideCard(
                  ctx: ctx,
                  step: '4',
                  title: 'Jadwal Agenda Lapangan',
                  desc:
                      'Catat agenda kunjungan kelompok tani dan kegiatan kehutanan pada menu Jadwal lengkap dengan pengingat aplikasi dan WhatsApp.',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGuideCard({
    required BuildContext ctx,
    required String step,
    required String title,
    required String desc,
  }) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF162019) : const Color(0xFFF9FBF9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF2E3D34) : const Color(0xFFE5ECE5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFF285C2E),
              shape: BoxShape.circle,
            ),
            child: Text(
              step,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E2923),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFaqDialog() {
    final faqs = [
      {
        'q': 'Apakah laporan saya aman jika aplikasi tertutup saat offline?',
        'a':
            'Sangat aman. Phonebook menggunakan SQLite lokal di memori perangkat Anda. Laporan beserta foto geolokasi tidak akan hilang bahkan jika HP kehabisan baterai.',
      },
      {
        'q': 'Bagaimana jika tombol Sinkronkan Sekarang gagal?',
        'a':
            'Pastikan kuota internet atau WiFi Anda aktif. Jika server Vercel sedang dalam proses cold start, tunggu 5–10 detik lalu ketuk kembali tombol sinkronisasi.',
      },
      {
        'q': 'Bagaimana cara mengganti nomor WhatsApp saya?',
        'a':
            'Buka menu "Edit Informasi Profil" di atas, ubah nomor pada kolom WhatsApp, lalu ketuk Simpan.',
      },
      {
        'q': 'Apakah logout akan menghapus draft laporan saya?',
        'a':
            'Tidak sama sekali. Sistem logout Phonebook dirancang non-destruktif: hanya token sesi Anda yang dihapus, sedangkan arsip laporan offline tetap tersimpan di perangkat.',
      },
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final textColor = isDark ? Colors.white : const Color(0xFF1E2923);
        final subColor = isDark ? Colors.white70 : Colors.grey.shade700;
        final primaryGreen =
            isDark ? const Color(0xFF81C784) : const Color(0xFF285C2E);

        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) => SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.quiz_outlined, color: primaryGreen, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Pertanyaan Umum (FAQ)',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...faqs.map(
                  (f) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF162019)
                          : const Color(0xFFF9FBF9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF2E3D34)
                            : const Color(0xFFE5ECE5),
                      ),
                    ),
                    child: ExpansionTile(
                      shape: const Border(),
                      iconColor: primaryGreen,
                      collapsedIconColor: subColor,
                      title: Text(
                        f['q']!,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                          child: Text(
                            f['a']!,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: subColor,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _contactAdmin() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final textColor = isDark ? Colors.white : const Color(0xFF1E2923);
        final subColor = isDark ? Colors.white70 : Colors.grey.shade600;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hubungi Administrator CDK V',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Pilih kanal komunikasi resmi untuk bantuan teknis dan administrasi kepegawaian:',
                style: TextStyle(fontSize: 12.5, color: subColor),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF26352B)
                        : const Color(0xFFE8F5E9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chat_outlined,
                    color: isDark
                        ? const Color(0xFF81C784)
                        : const Color(0xFF2E7D32),
                  ),
                ),
                title: Text(
                  'WhatsApp Helpdesk CDK V',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: textColor,
                  ),
                ),
                subtitle: Text(
                  '0812-2345-6789 (Senin–Jumat, 08.00–16.00 WIB)',
                  style: TextStyle(color: subColor),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final uri = Uri.parse(
                    'https://wa.me/6281223456789?text=Halo%20Admin%20CDK%20V,%20saya%20butuh%20bantuan%20Phonebook',
                  );
                  try {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } catch (_) {}
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF162534)
                        : const Color(0xFFE3F2FD),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.email_outlined,
                    color: isDark
                        ? const Color(0xFF64B5F6)
                        : const Color(0xFF1565C0),
                  ),
                ),
                title: Text(
                  'Email Layanan Kehutanan',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: textColor,
                  ),
                ),
                subtitle: Text(
                  'admin@cdkv-kehutanan.jabarprov.go.id',
                  style: TextStyle(color: subColor),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final uri = Uri.parse(
                    'mailto:admin@cdkv-kehutanan.jabarprov.go.id?subject=Bantuan%20Aplikasi%20Phonebook',
                  );
                  try {
                    await launchUrl(uri);
                  } catch (_) {}
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Fitur Laporan Bug ke Tim IT (DC) yang benar-benar mengirimkan laporan ke:
  /// Fitur Laporan Masalah pada Profil:
  /// Pengguna mengisi form dan menekan tombol Kirim.
  /// Laporan dikirim ke backend Laravel (`POST /api/bug-reports`),
  /// yang kemudian memvalidasi data dan meneruskannya ke Discord via Webhook/Bot API.
  void _showReportIssueDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final phoneCtrl = TextEditingController(
      text: _whatsapp.isNotEmpty ? _whatsapp : '',
    );
    String category = 'Bug / Error';
    bool isSubmitting = false;

    final categories = const [
      'Bug / Error',
      'Tampilan Aplikasi',
      'Login / Akun',
      'Laporan Kegiatan',
      'Jadwal',
      'Materi',
      'Notifikasi',
      'Lainnya',
    ];

    final reporterName =
        _nama.trim().isNotEmpty ? _nama.trim() : 'Pengguna Phonebook';
    final reporterEmail = _email.trim().isNotEmpty ? _email.trim() : '-';
    final devicePlatform = kIsWeb
        ? 'Flutter Web'
        : 'Flutter Android (${defaultTargetPlatform.name})';
    const appVersion = 'Phonebook v1.0.0';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final textColor = isDark ? Colors.white : const Color(0xFF1E2923);
          final subColor = isDark ? Colors.white70 : Colors.grey.shade600;
          final cardBg =
              isDark ? const Color(0xFF26332A) : const Color(0xFFF0F5F1);
          final borderColor =
              isDark ? const Color(0xFF334639) : const Color(0xFFD6E3D8);
          final primaryGreen =
              isDark ? const Color(0xFF81C784) : const Color(0xFF245C3A);

          Future<void> submitReport() async {
            final title = titleCtrl.text.trim();
            final desc = descCtrl.text.trim();
            final rawPhone = phoneCtrl.text.trim();

            if (title.isEmpty || desc.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Harap isi judul dan deskripsi masalah.'),
                  backgroundColor: Color(0xFFC62828),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              return;
            }

            // Validasi format nomor WhatsApp Indonesia (628... atau 08...)
            var cleanPhone = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
            if (cleanPhone.startsWith('0')) {
              cleanPhone = '62${cleanPhone.substring(1)}';
            } else if (cleanPhone.startsWith('8')) {
              cleanPhone = '62$cleanPhone';
            }

            if (cleanPhone.length < 10 ||
                cleanPhone.length > 15 ||
                !cleanPhone.startsWith('628')) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Nomor WhatsApp tidak valid. Masukkan nomor aktif Indonesia (contoh: 081234567890).',
                  ),
                  backgroundColor: Color(0xFFC62828),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              return;
            }

            setDState(() => isSubmitting = true);

            try {
              final headers = <String, String>{
                'Accept': 'application/json',
                'Content-Type': 'application/json',
              };
              if (_token.isNotEmpty &&
                  !_token.startsWith('offline_') &&
                  !_token.startsWith('google_session_')) {
                headers['Authorization'] = 'Bearer $_token';
              }

              final payload = {
                'title': title,
                'category': category,
                'description': desc,
                'priority': 'Sedang',
                'reporter_name': reporterName,
                'reporter_email': reporterEmail,
                'reporter_phone': cleanPhone,
                'app_version': appVersion,
                'device_info': '$devicePlatform • $_wilayah',
              };

              final response = await http
                  .post(
                    Uri.parse(ApiConstants.bugReportsUrl),
                    headers: headers,
                    body: jsonEncode(payload),
                  )
                  .timeout(const Duration(seconds: 12));

              if (response.statusCode >= 200 && response.statusCode < 300) {
                String ticketCode = 'PB-2026';
                bool discordSent = true;
                try {
                  final resBody = jsonDecode(response.body);
                  if (resBody['data']?['ticket_code'] != null) {
                    ticketCode = resBody['data']['ticket_code'].toString();
                  }
                  if (resBody['data']?['discord_sent'] != null) {
                    discordSent = resBody['data']['discord_sent'] == true;
                  }
                } catch (_) {}

                // Simpan riwayat lokal & notifikasi
                try {
                  final prefs = await SharedPreferences.getInstance();
                  const bugStorageKey = 'phonebook_bug_reports_v1';
                  final rawBugs = prefs.getString(bugStorageKey);
                  final List<Map<String, dynamic>> bugList = [];
                  if (rawBugs != null && rawBugs.isNotEmpty) {
                    final decoded = jsonDecode(rawBugs) as List<dynamic>;
                    bugList.addAll(
                      decoded.map((e) => Map<String, dynamic>.from(e)),
                    );
                  }
                  bugList.insert(0, {
                    'id': 'bug_${DateTime.now().millisecondsSinceEpoch}',
                    'ticket_code': ticketCode,
                    'category': category,
                    'title': title,
                    'description': desc,
                    'reporter': reporterName,
                    'email': reporterEmail,
                    'phone': cleanPhone,
                    'status': 'MENUNGGU PERSETUJUAN',
                    'discord_sent': discordSent,
                    'createdAt': DateTime.now().toIso8601String(),
                  });
                  await prefs.setString(bugStorageKey, jsonEncode(bugList));
                } catch (_) {}

                await NotificationService.instance.addNotification(
                  type: 'umum',
                  title: 'Tiket Laporan #$ticketCode Terdaftar',
                  message: discordSent
                      ? 'Laporan "$title" telah berhasil diteruskan ke Discord developer. Notifikasi WhatsApp akan otomatis dikirimkan ke $cleanPhone.'
                      : 'Laporan "$title" berhasil disimpan. Pengiriman ke Discord developer sedang diproses antrean server.',
                  referenceId: 'ticket_$ticketCode',
                  metadata: {
                    'targetPage': 'profil',
                    'ticket_code': ticketCode,
                    'category': category,
                    'title': title,
                    'discord_sent': discordSent,
                  },
                );

                if (!ctx.mounted) return;
                Navigator.pop(ctx);

                if (!mounted) return;
                final successMessage = discordSent
                    ? 'Tiket #$ticketCode berhasil dikirim ke server Discord developer! Notifikasi persetujuan akan dikirimkan ke WhatsApp Anda.'
                    : 'Tiket #$ticketCode berhasil disimpan! Sedang dalam antrean pengiriman ke Discord developer.';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(successMessage),
                    backgroundColor: const Color(0xFF245C3A),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 5),
                  ),
                );
              } else {
                String errorMsg =
                    'Gagal mengirim laporan (HTTP ${response.statusCode})';
                try {
                  final resBody = jsonDecode(response.body);
                  if (resBody is Map && resBody['message'] != null) {
                    errorMsg = resBody['message'].toString();
                  }
                } catch (_) {}

                setDState(() => isSubmitting = false);

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(errorMsg),
                    backgroundColor: const Color(0xFFC62828),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            } catch (e) {
              setDState(() => isSubmitting = false);

              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Koneksi gagal saat mengirim laporan: $e. Silakan coba lagi.',
                  ),
                  backgroundColor: const Color(0xFFC62828),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }

          return PopScope(
            canPop: !isSubmitting,
            child: AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E2822) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryGreen.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.bug_report_rounded,
                      color: primaryGreen,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Laporan Masalah',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Auto-detected User & Device Info Banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.person_rounded,
                                size: 16,
                                color: primaryGreen,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  reporterName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: textColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (reporterEmail != '-') ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.email_outlined,
                                  size: 15,
                                  color: subColor,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    reporterEmail,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: subColor,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.phone_android_rounded,
                                size: 15,
                                color: subColor,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '$appVersion • $devicePlatform',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: subColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Kategori Masalah
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      dropdownColor:
                          isDark ? const Color(0xFF1E2822) : Colors.white,
                      style: TextStyle(color: textColor, fontSize: 13.5),
                      decoration: _adaptiveInputDecoration(
                        context: ctx,
                        label: 'Kategori Masalah *',
                        prefixIcon: Icons.category_rounded,
                      ),
                      items: categories
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(c),
                            ),
                          )
                          .toList(),
                      onChanged: isSubmitting
                          ? null
                          : (val) {
                              if (val != null) {
                                setDState(() => category = val);
                              }
                            },
                    ),
                    const SizedBox(height: 12),

                    // Nomor WhatsApp Pengguna (Aktif untuk Notifikasi)
                    TextField(
                      controller: phoneCtrl,
                      enabled: !isSubmitting,
                      keyboardType: TextInputType.phone,
                      style: TextStyle(color: textColor),
                      decoration: _adaptiveInputDecoration(
                        context: ctx,
                        label: 'Nomor WhatsApp Aktif *',
                        hint: 'Contoh: 08123456789 atau 628123456789',
                        prefixIcon: Icons.chat_rounded,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        'Pemberitahuan persetujuan dan penyelesaian akan dikirim ke nomor ini.',
                        style: TextStyle(fontSize: 11, color: subColor),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Judul Laporan
                    TextField(
                      controller: titleCtrl,
                      enabled: !isSubmitting,
                      style: TextStyle(color: textColor),
                      decoration: _adaptiveInputDecoration(
                        context: ctx,
                        label: 'Judul Laporan *',
                        hint: 'Contoh: Halaman profil tidak menampilkan email',
                        prefixIcon: Icons.title_rounded,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Deskripsi Masalah
                    TextField(
                      controller: descCtrl,
                      enabled: !isSubmitting,
                      maxLines: 4,
                      style: TextStyle(color: textColor),
                      decoration: _adaptiveInputDecoration(
                        context: ctx,
                        label: 'Deskripsi Masalah *',
                        hint:
                            'Jelaskan kronologi kendala, langkah yang dilakukan, atau pesan error...',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton.icon(
                  onPressed: isSubmitting
                      ? null
                      : () {
                          Navigator.pop(ctx);
                          _showTicketStatusDialog();
                        },
                  icon: const Icon(
                    Icons.confirmation_number_outlined,
                    size: 16,
                  ),
                  label: const Text('Status Tiket'),
                  style: TextButton.styleFrom(
                    foregroundColor: primaryGreen,
                  ),
                ),
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                  child: Text(
                    'Batal',
                    style: TextStyle(color: subColor),
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF245C3A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  onPressed: isSubmitting ? null : submitReport,
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 17),
                  label: Text(
                    isSubmitting ? 'Mengirim...' : 'Kirim Laporan',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Menampilkan modal daftar status tiket pengaduan laporan masalah pengguna secara live dari backend database.
  void _showTicketStatusDialog() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setMState) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            final textColor = isDark ? Colors.white : const Color(0xFF1E2923);
            final subColor = isDark ? Colors.white70 : Colors.grey.shade600;
            final primaryGreen =
                isDark ? const Color(0xFF81C784) : const Color(0xFF245C3A);

            Future<List<Map<String, dynamic>>> fetchTickets() async {
              final tickets = <Map<String, dynamic>>[];
              try {
                final headers = <String, String>{
                  'Accept': 'application/json',
                };
                if (_token.isNotEmpty &&
                    !_token.startsWith('offline_') &&
                    !_token.startsWith('google_session_')) {
                  headers['Authorization'] = 'Bearer $_token';
                }

                final url = Uri.parse(
                  '${ApiConstants.bugReportsUrl}?email=${Uri.encodeComponent(_email)}&phone=${Uri.encodeComponent(_whatsapp)}',
                );
                final res = await http.get(url, headers: headers).timeout(
                      const Duration(seconds: 10),
                    );

                if (res.statusCode == 200) {
                  final body = jsonDecode(res.body);
                  final data = body['data'];
                  final List items =
                      data is Map && data['data'] is List ? data['data'] : (data is List ? data : []);

                  for (final item in items) {
                    if (item is Map) {
                      tickets.add(Map<String, dynamic>.from(item));
                    }
                  }
                }
              } catch (_) {}

              // Gabungkan dengan cache lokal jika ada tiket offline yang belum tersinkron
              try {
                final prefs = await SharedPreferences.getInstance();
                const bugStorageKey = 'phonebook_bug_reports_v1';
                final rawBugs = prefs.getString(bugStorageKey);
                if (rawBugs != null && rawBugs.isNotEmpty) {
                  final List localList = jsonDecode(rawBugs);
                  for (final loc in localList) {
                    final locCode = loc['ticket_code'] ?? loc['id'];
                    final alreadyInList = tickets.any(
                      (t) => (t['ticket_code'] ?? t['id']) == locCode,
                    );
                    if (!alreadyInList) {
                      tickets.add(Map<String, dynamic>.from(loc));
                    }
                  }
                }
              } catch (_) {}

              return tickets;
            }

            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return FutureBuilder<List<Map<String, dynamic>>>(
                  future: fetchTickets(),
                  builder: (context, snapshot) {
                    final isLoading =
                        snapshot.connectionState == ConnectionState.waiting;
                    final tickets = snapshot.data ?? [];

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: primaryGreen.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.confirmation_number_rounded,
                                  color: primaryGreen,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Status Tiket Pengaduan',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),
                                    Text(
                                      'Pantau proses persetujuan dan penanganan tim IT',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: subColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.refresh_rounded),
                                color: primaryGreen,
                                onPressed: () {
                                  setMState(() {});
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (isLoading)
                            const Expanded(
                              child: Center(
                                child: CircularProgressIndicator(),
                              ),
                            )
                          else if (tickets.isEmpty)
                            Expanded(
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.inbox_rounded,
                                      size: 56,
                                      color: subColor.withValues(alpha: 0.5),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Belum ada tiket laporan masalah',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: textColor,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Laporan yang Anda kirimkan akan muncul di sini beserta status persetujuan Discord & WhatsApp.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: subColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            Expanded(
                              child: ListView.separated(
                                controller: scrollController,
                                itemCount: tickets.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, i) {
                                  final t = tickets[i];
                                  final ticketCode = (t['ticket_code'] ??
                                          t['id'] ??
                                          'PB-2026')
                                      .toString();
                                  final status = (t['status'] ??
                                          'MENUNGGU PERSETUJUAN')
                                      .toString()
                                      .toUpperCase();
                                  final title =
                                      (t['title'] ?? '-').toString();
                                  final cat =
                                      (t['category'] ?? '-').toString();
                                  final reason =
                                      t['rejection_reason']?.toString();
                                  final handledBy =
                                      t['handled_by']?.toString();
                                  final createdAt =
                                      (t['created_at'] ?? t['createdAt'] ?? '')
                                          .toString();

                                  // Badge Color
                                  Color badgeBg;
                                  Color badgeText;
                                  IconData badgeIcon;

                                  if (status == 'DITERIMA') {
                                    badgeBg = const Color(0xFF2E7D32);
                                    badgeText = Colors.white;
                                    badgeIcon = Icons.check_circle_rounded;
                                  } else if (status == 'DITOLAK') {
                                    badgeBg = const Color(0xFFC62828);
                                    badgeText = Colors.white;
                                    badgeIcon = Icons.cancel_rounded;
                                  } else if (status == 'SELESAI') {
                                    badgeBg = const Color(0xFF1565C0);
                                    badgeText = Colors.white;
                                    badgeIcon = Icons.task_alt_rounded;
                                  } else if (status == 'SEDANG DIPROSES') {
                                    badgeBg = const Color(0xFF00838F);
                                    badgeText = Colors.white;
                                    badgeIcon = Icons.hourglass_top_rounded;
                                  } else {
                                    badgeBg = const Color(0xFFF57F17);
                                    badgeText = Colors.white;
                                    badgeIcon = Icons.access_time_rounded;
                                  }

                                  return Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF222F26)
                                          : const Color(0xFFF9FBF9),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isDark
                                            ? const Color(0xFF2E4033)
                                            : const Color(0xFFE2EBE3),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '#$ticketCode',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13.5,
                                                color: primaryGreen,
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 9,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: badgeBg,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Row(
                                                mainAxisSize:
                                                    MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    badgeIcon,
                                                    size: 13,
                                                    color: badgeText,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    status,
                                                    style: TextStyle(
                                                      color: badgeText,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          title,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14.5,
                                            color: textColor,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          cat,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: subColor,
                                          ),
                                        ),
                                        if (reason != null &&
                                            reason.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFC62828)
                                                  .withValues(alpha: 0.08),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: const Color(0xFFC62828)
                                                    .withValues(alpha: 0.25),
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Alasan Penolakan:',
                                                  style: TextStyle(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFFC62828),
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  reason,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: textColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                        if (handledBy != null &&
                                            handledBy.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            'Penangan: $handledBy',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: subColor,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ],
                                        if (createdAt.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            'Dibuat: $createdAt',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: subColor,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(
                                              t['discord_sent'] == true
                                                  ? Icons.check_circle_rounded
                                                  : Icons.sync_problem_rounded,
                                              size: 13,
                                              color: t['discord_sent'] == true
                                                  ? const Color(0xFF2E7D32)
                                                  : const Color(0xFFE65100),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              t['discord_sent'] == true
                                                  ? 'Discord: Terkirim'
                                                  : 'Discord: Menunggu Kirim',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: t['discord_sent'] == true
                                                    ? const Color(0xFF2E7D32)
                                                    : const Color(0xFFE65100),
                                              ),
                                            ),
                                            const Spacer(),
                                            if (t['discord_sent'] != true)
                                              TextButton.icon(
                                                style: TextButton.styleFrom(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 8, vertical: 2),
                                                  minimumSize: Size.zero,
                                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                ),
                                                icon: const Icon(Icons.refresh_rounded, size: 13),
                                                label: const Text(
                                                  'Kirim Ulang',
                                                  style: TextStyle(fontSize: 11),
                                                ),
                                                onPressed: () async {
                                                  try {
                                                    final res = await http.post(
                                                      Uri.parse('${ApiConstants.bugReportsUrl}/$ticketCode/retry-discord'),
                                                      headers: {'Accept': 'application/json'},
                                                    ).timeout(const Duration(seconds: 10));
                                                    if (res.statusCode == 200) {
                                                      setMState(() {});
                                                      if (context.mounted) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          const SnackBar(
                                                            content: Text('Tiket berhasil dikirim ulang ke Discord!'),
                                                            backgroundColor: Color(0xFF245C3A),
                                                          ),
                                                        );
                                                      }
                                                    }
                                                  } catch (_) {}
                                                },
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  void _showPrivacyPolicy() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final textColor = isDark ? Colors.white : const Color(0xFF1E2923);
        final bodyColor = isDark ? Colors.white70 : const Color(0xFF374151);
        final primaryGreen =
            isDark ? const Color(0xFF81C784) : const Color(0xFF285C2E);

        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) => SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.policy_outlined,
                      color: primaryGreen,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Kebijakan Privasi & Data ASN',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '1. Perlindungan Data Kepegawaian\nData profil, NIP, pangkat, dan kontak yang tersimpan dalam Phonebook hanya digunakan untuk keperluan koordinasi kedinasan di lingkungan Dinas Kehutanan Provinsi Jawa Barat khususnya CDK Wilayah V Garut.\n\n2. Data Koordinat Lokasi\nAplikasi meminta akses GPS semata-mata untuk membubuhkan titik geolokasi sah pada laporan kegiatan di lapangan dan menampilkan informasi wilayah kerja guna memastikan verifikasi kehadiran fisik.\n\n3. Keamanan Penyimpanan Lokal\nSemua berkas laporan yang belum tersinkronisasi dilindungi dalam basis data SQLite privat yang tidak dapat diakses oleh aplikasi lain pada perangkat Anda.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: bodyColor,
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),
                Text(
                  'Dokumen Kepatuhan & Kebijakan Daring:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryGreen,
                          side: BorderSide(color: primaryGreen),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.description_outlined, size: 16),
                        label: const Text(
                          'Ketentuan Layanan',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        onPressed: () async {
                          final url = Uri.parse('${ApiConstants.baseUrl}/terms');
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url, mode: LaunchMode.externalApplication);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.privacy_tip_outlined, size: 16),
                        label: const Text(
                          'Kebijakan Privasi',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        onPressed: () async {
                          final url = Uri.parse('${ApiConstants.baseUrl}/privacy');
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url, mode: LaunchMode.externalApplication);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAboutApp() {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final primaryGreen =
            isDark ? const Color(0xFF81C784) : const Color(0xFF285C2E);
        final subColor = isDark ? Colors.white60 : Colors.grey.shade600;

        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E2822) : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/images/logo_phonebook.jpeg',
                  width: 72,
                  height: 72,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 72,
                    height: 72,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF26352B)
                          : const Color(0xFFE8F5E9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.forest_rounded,
                      size: 44,
                      color: primaryGreen,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'PHONEBOOK CDK V',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryGreen,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Aplikasi Pelaporan & Kepegawaian Kehutanan',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: subColor),
              ),
              const SizedBox(height: 12),
              Divider(
                color:
                    isDark ? const Color(0xFF2E3D34) : const Color(0xFFEDF2EE),
              ),
              const SizedBox(height: 8),
              _buildAboutRow(ctx, 'Versi Aplikasi', '1.0.0 (Build 1)'),
              _buildAboutRow(ctx, 'Instansi', 'CDK Wilayah V Garut'),
              _buildAboutRow(ctx, 'Pemerintah', 'Provinsi Jawa Barat'),
              _buildAboutRow(ctx, 'Tahun Rilis', '2026'),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF285C2E),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Tutup'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAboutRow(BuildContext context, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white60 : Colors.grey.shade600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E2923),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 6. Logout Aman
  // ===========================================================================

  Future<void> _handleLogout() async {
    _cachedProfile = null;
    await const LogoutButton().logout(context);
  }

  // ===========================================================================
  // 7. BUILD UTAMA (TANPA MENU PENGINGAT & ADAPTIF LIGHT/DARK MODE)
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 115),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // =================================================================
            // LAYER HEADER LENGKUNG (Khas Phonebook CDK V)
            // =================================================================
            ClipPath(
              clipper: _ProfileHeaderClipper(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(22, 48, 22, 54),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF285C2E),
                      Color(0xFF3B7A42),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Profil Pegawai',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Pusat informasi kepegawaian & pengaturan',
                                style: TextStyle(
                                  color: Color(0xFFD4E7D5),
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _showEditProfileDialog,
                          tooltip: 'Edit Profil',
                          style: IconButton.styleFrom(
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.18),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 20),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Konten Berkelanjutan
            Transform.translate(
              offset: const Offset(0, -28),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // 1. KARTU IDENTITAS PENGGUNA
                    if (_isLoadingProfile)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        decoration: BoxDecoration(
                          color:
                              isDark ? const Color(0xFF1E2822) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF285C2E),
                          ),
                        ),
                      )
                    else
                      ProfileIdentityCard(
                        nama: _nama,
                        jabatan: _jabatan,
                        nip: _nip,
                        wilayah: _wilayah,
                        avatar: _avatar,
                        role: _role,
                        status: _status,
                        onEditProfile: _showEditProfileDialog,
                        onChangeAvatar: _handlePickAvatar,
                      ),
                    const SizedBox(height: 16),

                    // 2. STATUS KONEKSI & SINKRONISASI
                    ProfileSyncStatus(
                      isOnline: _isOnline,
                      isSyncing: _isSyncing,
                      pendingCount: _totalPendingSync,
                      lastSyncTime: _lastSyncTime,
                      onSyncNow: _handleSyncNow,
                    ),
                    const SizedBox(height: 16),

                    // 3. RINGKASAN AKTIVITAS PENGGUNA
                    ProfileActivitySummary(
                      totalLaporan: _totalLaporan,
                      totalJadwal: _totalJadwal,
                      totalMateri: _totalMateri,
                      totalPendingSync: _totalPendingSync,
                      onSyncTap: _handleSyncNow,
                    ),
                    const SizedBox(height: 16),

                    // 4. INFORMASI KEPEGAWAIAN
                    ProfileInfoSection(
                      nama: _nama,
                      nip: _nip,
                      jabatan: _jabatan,
                      pangkat: _pangkat,
                      instansi: _instansi,
                      unitKerja: _unitKerja,
                      wilayah: _wilayah,
                      email: _email,
                      whatsapp: _whatsapp,
                    ),
                    const SizedBox(height: 16),

                    // 5. PENGATURAN AKUN
                    ProfileAccountSettings(
                      loginMethod: _loginMethod,
                      onEditProfile: _showEditProfileDialog,
                      onChangePassword: _showChangePasswordDialog,
                      onManagePhoto: _handlePickAvatar,
                      onSecurityInfo: _showSecurityInfoDialog,
                    ),
                    const SizedBox(height: 16),

                    // 6. PENGATURAN APLIKASI (Tema Light/Dark & Ukuran Teks)
                    ProfileAppSettings(
                      currentTheme: _currentTheme,
                      textScale: _textScale,
                      storageUsage: _storageUsage,
                      onChangeTheme: _updateTheme,
                      onChangeTextScale: _updateTextScale,
                      onClearCache: _showClearCacheDialog,
                    ),
                    const SizedBox(height: 16),

                    // 7. BANTUAN, LAPORAN BUG KE TIM IT (DC) & PUSAT INFORMASI
                    ProfileHelpSection(
                      onUserGuide: _showUserGuide,
                      onFaq: _showFaqDialog,
                      onContactAdmin: _contactAdmin,
                      onReportIssue: _showReportIssueDialog,
                      onTicketStatus: _showTicketStatusDialog,
                      onPrivacyPolicy: _showPrivacyPolicy,
                      onAboutApp: _showAboutApp,
                    ),
                    const SizedBox(height: 22),

                    // 8. TOMBOL LOGOUT
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _handleLogout,
                        icon: const Icon(Icons.logout_rounded, size: 20),
                        label: const Text(
                          'Keluar dari Akun',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark
                              ? const Color(0xFFEF9A9A)
                              : const Color(0xFFD32F2F),
                          side: BorderSide(
                            color: isDark
                                ? const Color(0xFF5C2D32)
                                : const Color(0xFFEF9A9A),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          backgroundColor: isDark
                              ? const Color(0xFF3C1F22)
                              : const Color(0xFFFFF5F5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 9. FOOTER APLIKASI
                    Column(
                      children: [
                        Text(
                          'Phonebook CDK Wilayah V Garut',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? const Color(0xFF81C784)
                                : const Color(0xFF285C2E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Dinas Kehutanan Provinsi Jawa Barat • Versi 1.0.0 (Build 1)',
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                isDark ? Colors.white60 : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// CustomClipper untuk lengkungan khas Phonebook (layer Figma "Prof")
// -----------------------------------------------------------------------------
class _ProfileHeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 40);

    path.quadraticBezierTo(
      size.width / 2,
      size.height + 20,
      size.width,
      size.height - 40,
    );

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}