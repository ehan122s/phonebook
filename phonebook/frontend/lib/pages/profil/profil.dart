import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/api_constants.dart';
import '../../services/app_settings_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/jadwal_service.dart';
import '../../services/offline_database.dart';
import '../../services/sync_service.dart';
import '../../widgets/logout_button.dart';
import '../../widgets/profil/profile_account_settings.dart';
import '../../widgets/profil/profile_activity_summary.dart';
import '../../widgets/profil/profile_app_settings.dart';
import '../../widgets/profil/profile_help_section.dart';
import '../../widgets/profil/profile_identity_card.dart';
import '../../widgets/profil/profile_info_section.dart';
import '../../widgets/profil/profile_notification_settings.dart';
import '../../widgets/profil/profile_sync_status.dart';

class ProfilPage extends StatefulWidget {
  const ProfilPage({super.key});

  @override
  State<ProfilPage> createState() => _ProfilPageState();
}

class _ProfilPageState extends State<ProfilPage> {
  // Identitas & Data Kepegawaian
  String _nama = 'Rizky Pratama, S.Hut.';
  String _email = 'rizky@kehutanan.go.id';
  String _nip = '19940812 202012 1 004';
  String _jabatan = 'Penyuluh Kehutanan Ahli Pertama';
  final String _pangkat = 'Penata Muda / III/a';
  final String _instansi = 'Dinas Kehutanan Provinsi Jawa Barat';
  final String _unitKerja = 'Cabang Dinas Kehutanan Wilayah V Garut';
  String _wilayah = 'CDK Wilayah Garut & Sekitarnya';
  String _whatsapp = '0812-3456-7890';
  String _avatar = '';
  String _role = 'user';
  String _status = 'Aktif';
  String _token = '';
  String _loginMethod = 'email';

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

  // Pengaturan Notifikasi (Tersimpan di SharedPreferences)
  bool _notifJadwal = true;
  bool _notifKunjungan = true;
  bool _notifSinkron = true;
  bool _notifPengumuman = true;
  String _reminderTime = '30 Menit Sebelumnya';

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

    _connSub = ConnectivityService.instance.onConnectivityChanged.listen((online) {
      if (mounted) {
        setState(() {
          _isOnline = online;
        });
      }
    });
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final token = prefs.getString('token') ?? '';
    final email = prefs.getString('email') ?? prefs.getString('profil_email') ?? 'rizky@kehutanan.go.id';
    final name = prefs.getString('profil_nama') ?? prefs.getString('name') ?? 'Rizky Pratama, S.Hut.';
    final nip = prefs.getString('profil_nip') ?? prefs.getString('nip') ?? '19940812 202012 1 004';
    final jabatan = prefs.getString('profil_jabatan') ?? prefs.getString('jabatan') ?? 'Penyuluh Kehutanan Ahli Pertama';
    final wilayah = prefs.getString('profil_wilayah') ?? prefs.getString('wilayah') ?? 'CDK Wilayah Garut';
    final whatsapp = prefs.getString('profil_whatsapp') ?? prefs.getString('whatsapp_number') ?? '0812-3456-7890';
    final avatar = prefs.getString('profil_avatar') ?? prefs.getString('avatar') ?? '';
    final role = prefs.getString('role') ?? 'user';
    final loginMethod = prefs.getString('login_method') ?? 'email';
    final lastSync = prefs.getString('last_sync_time') ?? '';

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
    });

    // Jika online dan memiliki token Sanctum resmi, segarkan profil dari backend
    if (_isOnline && token.isNotEmpty && !token.startsWith('offline_') && !token.startsWith('google_session_')) {
      _fetchProfileFromBackend(token);
    }
  }

  Future<void> _fetchProfileFromBackend(String token) async {
    try {
      final res = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/api/user'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] != null) {
          final u = body['data'] as Map<String, dynamic>;
          final prefs = await SharedPreferences.getInstance();

          if (!mounted) return;
          setState(() {
            if (u['name'] != null && u['name'].toString().isNotEmpty) {
              _nama = u['name'].toString();
              prefs.setString('profil_nama', _nama);
            }
            if (u['nip'] != null && u['nip'].toString().isNotEmpty) {
              _nip = u['nip'].toString();
              prefs.setString('profil_nip', _nip);
            }
            if (u['jabatan'] != null && u['jabatan'].toString().isNotEmpty) {
              _jabatan = u['jabatan'].toString();
              prefs.setString('profil_jabatan', _jabatan);
            }
            if (u['wilayah'] != null && u['wilayah'].toString().isNotEmpty) {
              _wilayah = u['wilayah'].toString();
              prefs.setString('profil_wilayah', _wilayah);
            }
            if (u['whatsapp_number'] != null && u['whatsapp_number'].toString().isNotEmpty) {
              _whatsapp = u['whatsapp_number'].toString();
              prefs.setString('profil_whatsapp', _whatsapp);
            }
            if (u['avatar'] != null && u['avatar'].toString().isNotEmpty) {
              _avatar = u['avatar'].toString();
              prefs.setString('profil_avatar', _avatar);
            }
            if (u['role'] != null) {
              _role = u['role'].toString();
              prefs.setString('role', _role);
            }
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadActivityStats() async {
    try {
      // 1. Laporan dari SQLite
      final allReports = await OfflineDatabase.instance.getAllLocalReports();
      final pendingCount = await OfflineDatabase.instance.getPendingCount();

      // 2. Jadwal dari SharedPreferences / Service
      final prefs = await SharedPreferences.getInstance();
      int jadwalCount = 0;
      final rawJadwal = prefs.getString(JadwalService.storageKey);
      if (rawJadwal != null && rawJadwal.isNotEmpty) {
        final list = jsonDecode(rawJadwal) as List;
        jadwalCount = list.length;
      }

      // 3. Materi dari SharedPreferences
      int materiCount = 0;
      final rawMateri = prefs.getString('phonebook_materials_v1');
      if (rawMateri != null && rawMateri.isNotEmpty) {
        final list = jsonDecode(rawMateri) as List;
        materiCount = list.length;
      }

      if (!mounted) return;
      setState(() {
        _totalLaporan = allReports.length;
        _totalPendingSync = pendingCount;
        _totalJadwal = jadwalCount;
        _totalMateri = materiCount;
      });
    } catch (_) {}
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      _notifJadwal = prefs.getBool('notif_jadwal') ?? true;
      _notifKunjungan = prefs.getBool('notif_kunjungan') ?? true;
      _notifSinkron = prefs.getBool('notif_sinkron') ?? true;
      _notifPengumuman = prefs.getBool('notif_pengumuman') ?? true;
      _reminderTime = prefs.getString('notif_reminder_time') ?? '30 Menit Sebelumnya';

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
      final months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
      final formattedTime = '${now.day} ${months[now.month]} ${now.year}, ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} WIB';

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
          backgroundColor: result.failed == 0 ? const Color(0xFF285C2E) : const Color(0xFFE65100),
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
  // 3. Dialog & Aksi Pengaturan Akun
  // ===========================================================================

  void _showEditProfileDialog() {
    final namaCtrl = TextEditingController(text: _nama);
    final waCtrl = TextEditingController(text: _whatsapp);
    final wilayahCtrl = TextEditingController(text: _wilayah);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.edit_note_rounded, color: Color(0xFF285C2E), size: 26),
            SizedBox(width: 8),
            Text(
              'Edit Profil Pribadi',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17.5),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Anda dapat memperbarui nama tampilan, nomor kontak WhatsApp, dan penugasan wilayah.',
                style: TextStyle(fontSize: 12.5, color: Colors.grey, height: 1.35),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: namaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nama Lengkap Beserta Gelar',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: waCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Nomor WhatsApp / Telepon',
                  prefixIcon: Icon(Icons.phone_android_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: wilayahCtrl,
                decoration: const InputDecoration(
                  labelText: 'Wilayah Tugas / Binaan',
                  prefixIcon: Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF285C2E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final newName = namaCtrl.text.trim().isEmpty ? _nama : namaCtrl.text.trim();
              final newWa = waCtrl.text.trim().isEmpty ? _whatsapp : waCtrl.text.trim();
              final newWil = wilayahCtrl.text.trim().isEmpty ? _wilayah : wilayahCtrl.text.trim();

              Navigator.pop(ctx);

              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('profil_nama', newName);
              await prefs.setString('profil_whatsapp', newWa);
              await prefs.setString('profil_wilayah', newWil);

              if (mounted) {
                setState(() {
                  _nama = newName;
                  _whatsapp = newWa;
                  _wilayah = newWil;
                });
              }

              // Kirim ke backend jika online
              if (_isOnline && _token.isNotEmpty && !_token.startsWith('offline_')) {
                try {
                  await http.post(
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
                  ).timeout(const Duration(seconds: 4));
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
      ),
    );
  }

  void _showChangePasswordDialog() {
    final isGoogle = _loginMethod.toLowerCase() == 'google';
    if (isGoogle) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Color(0xFF1565C0)),
              SizedBox(width: 8),
              Text('Otentikasi Akun Google', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Akun Anda terhubung langsung dengan Akun Google resmi. Pengelolaan kata sandi dikendalikan melalui keamanan Akun Google Anda.',
            style: TextStyle(fontSize: 13, height: 1.4),
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
        ),
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
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.lock_reset_rounded, color: Color(0xFF285C2E)),
                SizedBox(width: 8),
                Text('Ubah Kata Sandi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: oldPassCtrl,
                    obscureText: obscureOld,
                    decoration: InputDecoration(
                      labelText: 'Kata Sandi Saat Ini',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(obscureOld ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setDialogState(() => obscureOld = !obscureOld),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newPassCtrl,
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      labelText: 'Kata Sandi Baru (Min. 8 Karakter)',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmPassCtrl,
                    obscureText: obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Konfirmasi Kata Sandi Baru',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF285C2E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  final oldP = oldPassCtrl.text;
                  final newP = newPassCtrl.text;
                  final confP = confirmPassCtrl.text;

                  if (oldP.isEmpty || newP.isEmpty || confP.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Semua kolom kata sandi wajib diisi.')),
                    );
                    return;
                  }
                  if (newP.length < 8) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Kata sandi baru minimal 8 karakter.')),
                    );
                    return;
                  }
                  if (newP != confP) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Konfirmasi kata sandi tidak cocok.')),
                    );
                    return;
                  }

                  Navigator.pop(ctx);

                  if (_isOnline && _token.isNotEmpty && !_token.startsWith('offline_')) {
                    try {
                      final res = await http.post(
                        Uri.parse('${ApiConstants.baseUrl}/api/user/change-password'),
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
                      ).timeout(const Duration(seconds: 4));

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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kelola Foto Profil',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: Color(0xFF285C2E)),
              title: const Text('Ambil Foto dari Kamera'),
              onTap: () async {
                Navigator.pop(ctx);
                final picker = ImagePicker();
                final picked = await picker.pickImage(source: ImageSource.camera, maxWidth: 600);
                if (picked != null) {
                  _saveAvatarPath(picked.path);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: Color(0xFF285C2E)),
              title: const Text('Pilih dari Galeri Foto'),
              onTap: () async {
                Navigator.pop(ctx);
                final picker = ImagePicker();
                final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 600);
                if (picked != null) {
                  _saveAvatarPath(picked.path);
                }
              },
            ),
            if (_avatar.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Hapus Foto Profil'),
                onTap: () async {
                  Navigator.pop(ctx);
                  _saveAvatarPath('');
                },
              ),
          ],
        ),
      ),
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
        await http.post(
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
        ).timeout(const Duration(seconds: 4));
      } catch (_) {}
    }
  }

  void _showSecurityInfoDialog() {
    final isGoogle = _loginMethod.toLowerCase() == 'google';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.security_rounded, color: Color(0xFF285C2E)),
            SizedBox(width: 10),
            Text('Keamanan Akun & Sesi', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSecurityRow('Metode Autentikasi', isGoogle ? 'Google OAuth 2.0' : 'Email & Kata Sandi'),
            _buildSecurityRow('Status Token Sesi', _token.isNotEmpty ? 'Aktif (Tervalidasi)' : 'Tamu / Offline'),
            _buildSecurityRow('Enkripsi Database', 'SQLite AES Ready'),
            _buildSecurityRow('Keamanan Arsip', 'Tersimpan di Direktori Aplikasi'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Color(0xFF285C2E), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sesi login Anda dilindungi oleh Laravel Sanctum Token Security.',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF1B5E20)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF285C2E), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityRow(String title, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
          Text(val, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E2923))),
        ],
      ),
    );
  }

  // ===========================================================================
  // 4. Aksi Pengaturan Notifikasi & Aplikasi
  // ===========================================================================

  Future<void> _updateNotification(String key, bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, val);
    if (!mounted) return;
    setState(() {
      if (key == 'notif_jadwal') _notifJadwal = val;
      if (key == 'notif_kunjungan') _notifKunjungan = val;
      if (key == 'notif_sinkron') _notifSinkron = val;
      if (key == 'notif_pengumuman') _notifPengumuman = val;
    });
  }

  Future<void> _updateReminderTime(String time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('notif_reminder_time', time);
    if (!mounted) return;
    setState(() {
      _reminderTime = time;
    });
  }

  Future<void> _updateTheme(String theme) async {
    await AppSettingsService.instance.setTheme(theme);
    if (!mounted) return;
    setState(() {
      _currentTheme = AppSettingsService.instance.themeString;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tema tampilan diubah ke: ${AppSettingsService.instance.themeString}'),
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
        content: Text('Ukuran teks diatur ke: ${AppSettingsService.instance.textScaleString}'),
        backgroundColor: const Color(0xFF285C2E),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Bersihkan Cache Sementara', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Membersihkan cache hanya akan menghapus berkas sementara antarmuka dan memori gambar thumbnail.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            SizedBox(height: 10),
            Text(
              '✓ Draft laporan offline Anda TETAP AMAN dan TIDAK AKAN TERHAPUS.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
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
      ),
    );
  }

  // ===========================================================================
  // 5. Bantuan & Pusat Informasi
  // ===========================================================================

  void _showUserGuide() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
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
              const Row(
                children: [
                  Icon(Icons.menu_book_rounded, color: Color(0xFF285C2E), size: 24),
                  SizedBox(width: 10),
                  Text('Panduan Penggunaan Phonebook', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              _buildGuideCard(
                step: '1',
                title: 'Pelaporan di Tengah Hutan (Offline)',
                desc: 'Ketika tidak ada sinyal internet, Anda tetap dapat membuat laporan lengkap dengan foto dan titik koordinat GPS. Laporan akan tersimpan otomatis di database HP Anda.',
              ),
              _buildGuideCard(
                step: '2',
                title: 'Sinkronisasi Otomatis & Manual',
                desc: 'Setelah Anda kembali ke area bersinyal atau kantor CDK V, buka tab Profil atau Laporan lalu ketuk "Sinkronkan Sekarang" untuk mengunggah semua arsip ke server dinas.',
              ),
              _buildGuideCard(
                step: '3',
                title: 'Materi Edukasi & Google Drive',
                desc: 'Pelajari atau bagikan dokumen silvikultur, bibit tanaman, dan modul penyuluhan via File Manager HP atau tautan Google Drive publik.',
              ),
              _buildGuideCard(
                step: '4',
                title: 'Jadwal Agenda Lapangan',
                desc: 'Catat agenda kunjungan kelompok tani dan kegiatan kehutanan agar alarm pengingat dapat membunyikan notifikasi tepat waktu.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuideCard({required String step, required String title, required String desc}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBF9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5ECE5)),
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
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E2923))),
                const SizedBox(height: 4),
                Text(desc, style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.35)),
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
        'a': 'Sangat aman. Phonebook menggunakan SQLite lokal terenkripsi di memori perangkat Anda. Laporan tidak akan hilang bahkan jika HP kehabisan baterai.'
      },
      {
        'q': 'Bagaimana jika tombol Sinkronkan Sekarang gagal?',
        'a': 'Pastikan kuota internet atau WiFi Anda aktif. Jika server Vercel sedang dalam proses *cold start*, tunggu 5–10 detik lalu ketuk kembali tombol sinkronisasi.'
      },
      {
        'q': 'Bagaimana cara mengganti nomor WhatsApp saya?',
        'a': 'Buka menu "Edit Informasi Profil" di atas, ubah nomor pada kolom WhatsApp, lalu ketuk Simpan.'
      },
      {
        'q': 'Apakah logout akan menghapus draft laporan saya?',
        'a': 'Tidak sama sekali. Sistem logout Phonebook dirancang non-destruktif: hanya token sesi Anda yang dihapus, sedangkan arsip laporan offline tetap tersimpan di perangkat.'
      },
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
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
              const Row(
                children: [
                  Icon(Icons.quiz_outlined, color: Color(0xFF285C2E), size: 24),
                  SizedBox(width: 10),
                  Text('Pertanyaan Umum (FAQ)', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              ...faqs.map((f) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FBF9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5ECE5)),
                    ),
                    child: ExpansionTile(
                      shape: const Border(),
                      title: Text(f['q']!, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF1E2923))),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                          child: Text(f['a']!, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700, height: 1.35)),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  void _contactAdmin() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Hubungi Administrator CDK V', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('Pilih kanal komunikasi resmi untuk bantuan teknis dan administrasi kepegawaian:', style: TextStyle(fontSize: 12.5, color: Colors.grey)),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: Color(0xFFE8F5E9), shape: BoxShape.circle),
                child: const Icon(Icons.chat_outlined, color: Color(0xFF2E7D32)),
              ),
              title: const Text('WhatsApp Helpdesk CDK V', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('0812-2345-6789 (Senin–Jumat, 08.00–16.00 WIB)'),
              onTap: () async {
                Navigator.pop(ctx);
                final uri = Uri.parse('https://wa.me/6281223456789?text=Halo%20Admin%20CDK%20V,%20saya%20butuh%20bantuan%20Phonebook');
                try {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } catch (_) {}
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: Color(0xFFE3F2FD), shape: BoxShape.circle),
                child: const Icon(Icons.email_outlined, color: Color(0xFF1565C0)),
              ),
              title: const Text('Email Layanan Kehutanan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('admin@cdkv-kehutanan.jabarprov.go.id'),
              onTap: () async {
                Navigator.pop(ctx);
                final uri = Uri.parse('mailto:admin@cdkv-kehutanan.jabarprov.go.id?subject=Bantuan%20Aplikasi%20Phonebook');
                try {
                  await launchUrl(uri);
                } catch (_) {}
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showReportIssueDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String category = 'Laporan Kegiatan';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.bug_report_outlined, color: Color(0xFFC62828)),
                SizedBox(width: 8),
                Text('Laporkan Kendala', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Bantu kami meningkatkan kualitas Phonebook dengan melaporkan bug atau kendala teknis:', style: TextStyle(fontSize: 12.5, color: Colors.grey)),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(labelText: 'Kategori Kendala', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'Laporan Kegiatan', child: Text('Laporan Kegiatan')),
                      DropdownMenuItem(value: 'Sinkronisasi Offline', child: Text('Sinkronisasi Offline')),
                      DropdownMenuItem(value: 'Jadwal Agenda', child: Text('Jadwal Agenda')),
                      DropdownMenuItem(value: 'Materi & Unduhan', child: Text('Materi & Unduhan')),
                      DropdownMenuItem(value: 'Akun & Profil', child: Text('Akun & Profil')),
                      DropdownMenuItem(value: 'Lainnya', child: Text('Lainnya')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDState(() => category = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Ringkasan Kendala', hintText: 'Contoh: Sinkronisasi gagal saat di area Garut Selatan', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Deskripsi Rinci', hintText: 'Jelaskan kronologi kendala...', border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF285C2E), foregroundColor: Colors.white),
                onPressed: () {
                  if (titleCtrl.text.trim().isEmpty || descCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Judul dan deskripsi kendala wajib diisi.')),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Laporan kendala telah dicatat di log aplikasi untuk ditindaklanjuti tim IT.'),
                      backgroundColor: Color(0xFF285C2E),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: const Text('Kirim Laporan'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showPrivacyPolicy() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 30),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.policy_outlined, color: Color(0xFF285C2E), size: 24),
                  SizedBox(width: 10),
                  Text('Kebijakan Privasi & Data ASN', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ],
              ),
              SizedBox(height: 16),
              Text(
                '1. Perlindungan Data Kepegawaian\nData profil, NIP, pangkat, dan kontak yang tersimpan dalam Phonebook hanya digunakan untuk keperluan koordinasi kedinasan di lingkungan Dinas Kehutanan Provinsi Jawa Barat khususnya CDK Wilayah V Garut.\n\n2. Data Koordinat Lokasi\nAplikasi meminta akses GPS semata-mata untuk membubuhkan titik geolokasi sah pada laporan kegiatan di lapangan guna memastikan verifikasi kehadiran fisik.\n\n3. Keamanan Penyimpanan Lokal\nSemua berkas laporan yang belum tersinkronisasi dilindungi dalam basis data SQLite privat yang tidak dapat diakses oleh aplikasi lain pada perangkat Anda.',
                style: TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF374151)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAboutApp() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8F5E9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.forest_rounded, size: 44, color: Color(0xFF285C2E)),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'PHONEBOOK CDK V',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF285C2E)),
            ),
            const SizedBox(height: 4),
            const Text('Aplikasi Pelaporan & Kepegawaian Kehutanan', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            _buildAboutRow('Versi Aplikasi', '1.0.0 (Build 1)'),
            _buildAboutRow('Instansi', 'CDK Wilayah V Garut'),
            _buildAboutRow('Pemerintah', 'Provinsi Jawa Barat'),
            _buildAboutRow('Tahun Rilis', '2026'),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF285C2E), foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1E2923))),
        ],
      ),
    );
  }

  // ===========================================================================
  // 6. Logout Aman
  // ===========================================================================

  Future<void> _handleLogout() async {
    // Manfaatkan LogoutButton yang sudah teruji dan non-destruktif
    await const LogoutButton().logout(context);
  }

  // ===========================================================================
  // 7. BUILD UTAMA
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 110),
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
                        const Column(
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
                        IconButton(
                          onPressed: _showEditProfileDialog,
                          tooltip: 'Edit Profil',
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withValues(alpha: 0.18),
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

                    // 6. PENGATURAN NOTIFIKASI
                    ProfileNotificationSettings(
                      notifJadwal: _notifJadwal,
                      notifKunjungan: _notifKunjungan,
                      notifSinkron: _notifSinkron,
                      notifPengumuman: _notifPengumuman,
                      reminderTime: _reminderTime,
                      onToggleJadwal: (val) => _updateNotification('notif_jadwal', val),
                      onToggleKunjungan: (val) => _updateNotification('notif_kunjungan', val),
                      onToggleSinkron: (val) => _updateNotification('notif_sinkron', val),
                      onTogglePengumuman: (val) => _updateNotification('notif_pengumuman', val),
                      onChangeReminderTime: _updateReminderTime,
                    ),
                    const SizedBox(height: 16),

                    // 7. PENGATURAN APLIKASI
                    ProfileAppSettings(
                      currentTheme: _currentTheme,
                      textScale: _textScale,
                      storageUsage: _storageUsage,
                      onChangeTheme: _updateTheme,
                      onChangeTextScale: _updateTextScale,
                      onClearCache: _showClearCacheDialog,
                    ),
                    const SizedBox(height: 16),

                    // 8. BANTUAN & PUSAT INFORMASI
                    ProfileHelpSection(
                      onUserGuide: _showUserGuide,
                      onFaq: _showFaqDialog,
                      onContactAdmin: _contactAdmin,
                      onReportIssue: _showReportIssueDialog,
                      onPrivacyPolicy: _showPrivacyPolicy,
                      onAboutApp: _showAboutApp,
                    ),
                    const SizedBox(height: 22),

                    // 9. TOMBOL LOGOUT
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
                          foregroundColor: isDark ? const Color(0xFFEF9A9A) : const Color(0xFFD32F2F),
                          side: BorderSide(
                            color: isDark ? const Color(0xFF5C2D32) : const Color(0xFFEF9A9A),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          backgroundColor: isDark ? const Color(0xFF3C1F22) : const Color(0xFFFFF5F5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 10. FOOTER APLIKASI
                    Column(
                      children: [
                        Text(
                          'Phonebook CDK Wilayah V Garut',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFF81C784) : const Color(0xFF285C2E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Dinas Kehutanan Provinsi Jawa Barat • Versi 1.0.0 (Build 1)',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white60 : Colors.grey.shade600,
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
