// ============================================================================
// [KHUSUS ADMIN - HALAMAN DASHBOARD ADMIN & MANAJEMEN PENGGUNA]
// Simpan file ini di: lib/pages/admin/admin_page.dart
//
// Pembaruan Desain ("Soft Green Forest - Modern & Responsif"):
// - Selaras dengan DashboardPage, KategoriPage, LaporanPage, JadwalPage, MateriPage,
//   dan ProfilPage (palet #245C3A / #4F8A5B / #E8F2E8 / #F2F7F0 & dukungan Dark Mode).
// - Navigasi adaptif: Sidebar modern pada layar lebar (>= 840px) serta BottomNav
//   terpadu + Drawer pada perangkat mobile (< 840px).
// - Tampilan Manajemen Pengguna adaptif: Kartu pengguna ergonomis di layar mobile
//   dan tabel proporsional di layar desktop, dilengkapi filter status/peran dan
//   konfirmasi hapus.
// ============================================================================

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/api_constants.dart';
import '../../services/google_auth_service.dart';
import '../jadwal/jadwal.dart';
import '../laporan/laporan.dart';
import '../login/login.dart';
import '../materi/materi.dart';
import '../profil/profil.dart';
import 'admin_folder_page.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  // Palet Warna Modern Soft Green Forest (Selaras dengan DashboardPage & KategoriPage)
  static const Color kPrimary = Color(0xFF245C3A);
  static const Color kSecondary = Color(0xFF4F8A5B);
  static const Color kLightGreen = Color(0xFFE8F2E8);
  static const Color kSoftGreen = Color(0xFFF2F7F0);
  static const Color kBackground = Color(0xFFF7F9F6);
  static const Color kWhite = Color(0xFFFFFFFF);
  static const Color kTextPrimary = Color(0xFF24352A);
  static const Color kTextSecondary = Color(0xFF758278);
  static const Color kBorder = Color(0xFFE1EAE0);

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  static const String _usersStorageKey = 'phonebook_admin_users_v1';
  static const String _archiveStorageKey = 'phonebook_folder_archives_v1';
  static const String _jadwalStorageKey = 'phonebook_jadwal_items_v1';
  static const String _laporanDraftKey = 'phonebook_laporan_drafts_v1';
  static const String _materiStorageKey = 'phonebook_shared_materials_v2';

  /// 0 = Beranda Admin
  /// 1 = Kelola Pengguna
  /// 2 = Folder Seluruh User (AdminFolderPage)
  /// 3 = Laporan Kegiatan (LaporanPage)
  /// 4 = Jadwal Lapangan (JadwalPage)
  /// 5 = Materi Penyuluhan (MateriPage)
  /// 6 = Profil & Pengaturan (ProfilPage)
  int _selectedMenu = 0;

  String _adminName = 'Administrator';
  String _adminEmail = 'admin@kehutanan.go.id';
  String _searchUserQuery = '';
  String _userFilterStatus = 'Semua';
  String _reportFilterStatus = 'Semua';
  bool _isSyncingUsers = false;

  int _totalJadwalCount = 6;
  int _totalMateriCount = 4;

  final List<Map<String, String>> _defaultUsers = [
    {
      'id': 'USR-001',
      'nip': '19940812 202012 1 004',
      'name': 'Rizky Pratama, S.Hut.',
      'email': 'rizky@kehutanan.go.id',
      'whatsapp': '0812-3456-7890',
      'wilayah': 'CDK Wilayah Garut',
      'role': 'Penyuluh',
      'status': 'Aktif',
    },
    {
      'id': 'USR-002',
      'nip': '19910523 201903 2 008',
      'name': 'Siti Nurhaliza, S.Hut.',
      'email': 'siti.nur@kehutanan.go.id',
      'whatsapp': '0813-2244-6688',
      'wilayah': 'Kecamatan Cisurupan',
      'role': 'Penyuluh',
      'status': 'Aktif',
    },
    {
      'id': 'USR-003',
      'nip': '19891104 201801 1 002',
      'name': 'Budi Santoso, M.Si.',
      'email': 'budi.santoso@kehutanan.go.id',
      'whatsapp': '0857-9876-5432',
      'wilayah': 'Kawasan Hutan Cikuray',
      'role': 'Koordinator',
      'status': 'Aktif',
    },
    {
      'id': 'USR-004',
      'nip': '19960219 202203 1 011',
      'name': 'Andi Wijaya, S.Hut.',
      'email': 'andi.wijaya@kehutanan.go.id',
      'whatsapp': '0821-1122-3344',
      'wilayah': 'Lereng Gunung Guntur',
      'role': 'Penyuluh',
      'status': 'Nonaktif',
    },
  ];

  final List<Map<String, String>> _defaultRecentReports = [
    {
      'id': 'rep_1',
      'judul': 'Penyuluhan Perhutanan Sosial KTH Makmur',
      'pelapor': 'Rizky Pratama, S.Hut.',
      'lokasi': 'Kecamatan Garut',
      'kategori': 'Penyuluhan',
      'tanggal': '20 Oktober 2026',
      'status': 'Selesai',
    },
    {
      'id': 'rep_2',
      'judul': 'Monitoring Patok Batas Kawasan Hutan',
      'pelapor': 'Siti Nurhaliza, S.Hut.',
      'lokasi': 'Kecamatan Cisurupan',
      'kategori': 'Monitoring & Patroli',
      'tanggal': '19 Oktober 2026',
      'status': 'Diproses',
    },
    {
      'id': 'rep_3',
      'judul': 'Rehabilitasi Lahan Kritis Blok Selatan',
      'pelapor': 'Budi Santoso, M.Si.',
      'lokasi': 'Kawasan Hutan Cikuray',
      'kategori': 'Rehabilitasi Hutan',
      'tanggal': '18 Oktober 2026',
      'status': 'Selesai',
    },
    {
      'id': 'rep_4',
      'judul': 'Pendataan Produksi Madu Hutan Lestari',
      'pelapor': 'Andi Wijaya, S.Hut.',
      'lokasi': 'Lereng Gunung Guntur',
      'kategori': 'Ekosistem & Konservasi',
      'tanggal': '16 Oktober 2026',
      'status': 'Draft',
    },
  ];

  final List<Map<String, String>> _users = [];
  final List<Map<String, String>> _recentReports = [];

  // Helpers untuk tema terang / gelap
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bgColor => _isDark ? const Color(0xFF121814) : AdminPage.kBackground;
  Color get _cardBg => _isDark ? const Color(0xFF1E2822) : AdminPage.kWhite;
  Color get _surfaceBg => _isDark ? const Color(0xFF18221B) : const Color(0xFFF2F6F2);
  Color get _borderColor => _isDark ? const Color(0xFF2E3D34) : AdminPage.kBorder;
  Color get _textPrimary => _isDark ? AdminPage.kWhite : AdminPage.kTextPrimary;
  Color get _textSecondary => _isDark ? Colors.white70 : AdminPage.kTextSecondary;
  Color get _primaryAccent => _isDark ? const Color(0xFF81C784) : AdminPage.kPrimary;
  Color get _lightGreenBg => _isDark ? const Color(0xFF233829) : AdminPage.kLightGreen;
  Color get _softGreenBg => _isDark ? const Color(0xFF1B2B20) : AdminPage.kSoftGreen;

  @override
  void initState() {
    super.initState();
    _loadAdminAndUsers();
  }

  Future<void> _loadAdminAndUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString('profil_nama') ?? prefs.getString('name');
    final savedEmail = prefs.getString('email');
    final rawUsers = prefs.getString(_usersStorageKey);

    List<Map<String, String>> loadedUsers = List.from(_defaultUsers);
    if (rawUsers != null && rawUsers.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(rawUsers);
        loadedUsers = decoded
            .map(
              (item) => Map<String, String>.from(
                (item as Map).map(
                  (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
                ),
              ),
            )
            .toList();
      } catch (_) {}
    }

    // Muat & sinkronkan ringkasan laporan, jadwal, dan materi dari penyimpanan lokal
    final List<Map<String, String>> loadedReports = List.from(_defaultRecentReports);
    final rawLaporan = prefs.getString(_laporanDraftKey);
    if (rawLaporan != null && rawLaporan.isNotEmpty) {
      try {
        final List<dynamic> decodedLaporan = jsonDecode(rawLaporan);
        final userName = savedName ?? 'Rizky Pratama, S.Hut.';
        for (final item in decodedLaporan.reversed) {
          final map = Map<String, dynamic>.from(item);
          final id = 'local_${map['id'] ?? map['judul']}';
          if (!loadedReports.any((r) => r['id'] == id)) {
            loadedReports.insert(0, {
              'id': id,
              'judul': (map['judul'] ?? 'Laporan Kegiatan').toString(),
              'pelapor': userName,
              'lokasi': (map['lokasi'] ?? 'Kawasan Hutan Garut').toString(),
              'kategori': (map['jenis'] ?? 'Penyuluhan').toString(),
              'tanggal': (map['tanggal'] ?? 'Baru saja').toString(),
              'status': (map['status'] ?? 'Draft').toString(),
            });
          }
        }
      } catch (_) {}
    }

    final rawArchives = prefs.getString(_archiveStorageKey);
    if (rawArchives != null && rawArchives.isNotEmpty) {
      try {
        final List<dynamic> decodedArc = jsonDecode(rawArchives);
        for (final item in decodedArc) {
          final map = Map<String, dynamic>.from(item);
          if (map['tipe'] == 'Laporan') {
            final id = (map['id'] ?? '').toString();
            if (id.isNotEmpty && !loadedReports.any((r) => r['id'] == id)) {
              loadedReports.add({
                'id': id,
                'judul': (map['judul'] ?? 'Laporan Kegiatan').toString(),
                'pelapor': (map['userName'] ?? 'Penyuluh').toString(),
                'lokasi': (map['wilayah'] ?? 'CDK Wilayah Garut').toString(),
                'kategori': (map['kategori'] ?? 'Penyuluhan').toString(),
                'tanggal': (map['tanggal'] ?? '-').toString(),
                'status': (map['status'] ?? 'Selesai').toString(),
              });
            }
          }
        }
      } catch (_) {}
    }

    int jadwalCount = 6;
    final rawJadwal = prefs.getString(_jadwalStorageKey);
    if (rawJadwal != null && rawJadwal.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(rawJadwal);
        if (list.isNotEmpty) jadwalCount = list.length;
      } catch (_) {}
    }

    int materiCount = 4;
    final rawMateri = prefs.getString(_materiStorageKey);
    if (rawMateri != null && rawMateri.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(rawMateri);
        if (list.isNotEmpty) materiCount = list.length;
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      if (savedName != null && savedName.trim().isNotEmpty) {
        _adminName = savedName.trim();
      }
      if (savedEmail != null && savedEmail.trim().isNotEmpty) {
        _adminEmail = savedEmail.trim();
      }
      _users
        ..clear()
        ..addAll(loadedUsers);
      _recentReports
        ..clear()
        ..addAll(loadedReports);
      _totalJadwalCount = jadwalCount;
      _totalMateriCount = materiCount;
    });

    _fetchUsersFromBackend();
  }

  Future<void> _fetchUsersFromBackend({bool showFeedback = false}) async {
    if (mounted) {
      setState(() => _isSyncingUsers = true);
    }
    try {
      final response = await http
          .get(
            Uri.parse('${ApiConstants.baseUrl}/api/users'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> serverUsers = data['data'];
          if (serverUsers.isNotEmpty && mounted) {
            setState(() {
              final existingEmails = <String>{};
              final merged = <Map<String, String>>[];

              for (final su in serverUsers) {
                final email =
                    (su['email'] ?? '').toString().trim().toLowerCase();
                if (email.isNotEmpty && !existingEmails.contains(email)) {
                  existingEmails.add(email);
                  merged.add({
                    'id': (su['id'] ??
                            'USR-${DateTime.now().millisecondsSinceEpoch}')
                        .toString(),
                    'nip': (su['nip'] ?? '').toString(),
                    'name': (su['name'] ?? '').toString(),
                    'email': email,
                    'whatsapp': (su['whatsapp'] ?? '').toString(),
                    'wilayah':
                        (su['wilayah'] ?? 'CDK Wilayah Garut').toString(),
                    'role': (su['role'] ?? 'Penyuluh').toString(),
                    'status': (su['status'] ?? 'Aktif').toString(),
                  });
                }
              }

              for (final lu in _users) {
                final email =
                    (lu['email'] ?? '').toString().trim().toLowerCase();
                if (email.isNotEmpty && !existingEmails.contains(email)) {
                  existingEmails.add(email);
                  merged.add(lu);
                }
              }

              _users
                ..clear()
                ..addAll(merged);
            });
            await _persistUsers();
          }
        }
      }
      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data panel admin berhasil diperbarui.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Sync users from backend error: $e');
      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Menampilkan data tersimpan (mode lokal/offline).'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncingUsers = false);
      }
    }
  }

  Future<void> _persistUsers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usersStorageKey, jsonEncode(_users));
  }

  Future<void> _syncUserToBackend(Map<String, String> user) async {
    try {
      await http
          .post(
            Uri.parse('${ApiConstants.baseUrl}/api/users'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'name': user['name'],
              'email': user['email'],
              'nip': user['nip'],
              'whatsapp': user['whatsapp'],
              'wilayah': user['wilayah'],
              'role': user['role'],
              'status': user['status'],
            }),
          )
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('Sync user to backend error: $e');
    }
  }

  List<Map<String, String>> get _filteredUsers {
    return _users.where((u) {
      if (_userFilterStatus != 'Semua') {
        final statusMatch =
            (u['status'] ?? 'Aktif').toLowerCase() ==
            _userFilterStatus.toLowerCase();
        final roleMatch =
            (u['role'] ?? 'Penyuluh').toLowerCase() ==
            _userFilterStatus.toLowerCase();
        if (!statusMatch && !roleMatch) return false;
      }

      if (_searchUserQuery.trim().isEmpty) return true;
      final q = _searchUserQuery.toLowerCase();
      return (u['name'] ?? '').toLowerCase().contains(q) ||
          (u['email'] ?? '').toLowerCase().contains(q) ||
          (u['nip'] ?? '').toLowerCase().contains(q) ||
          (u['wilayah'] ?? '').toLowerCase().contains(q) ||
          (u['role'] ?? '').toLowerCase().contains(q);
    }).toList();
  }

  List<Map<String, String>> get _filteredRecentReports {
    if (_reportFilterStatus == 'Semua') return _recentReports;
    return _recentReports
        .where(
          (r) =>
              (r['status'] ?? '').toLowerCase() ==
              _reportFilterStatus.toLowerCase(),
        )
        .toList();
  }

  void _openUserFormSheet({Map<String, String>? existing}) {
    final isEditing = existing != null;

    String nip = existing?['nip'] ?? '';
    String name = existing?['name'] ?? '';
    String email = existing?['email'] ?? '';
    String whatsapp = existing?['whatsapp'] ?? '';
    String wilayah = existing?['wilayah'] ?? 'CDK Wilayah Garut';
    String role = existing?['role'] ?? 'Penyuluh';
    if (!['Penyuluh', 'Koordinator', 'Admin'].contains(role)) {
      role = 'Penyuluh';
    }
    String status = existing?['status'] ?? 'Aktif';
    if (!['Aktif', 'Nonaktif'].contains(status)) {
      status = 'Aktif';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: _cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            final bottomInset = MediaQuery.of(sheetCtx).viewInsets.bottom;
            final isNarrow = MediaQuery.of(sheetCtx).size.width < 520;

            InputDecoration fieldDecoration(
              String label,
              String hint,
              IconData icon,
            ) {
              return InputDecoration(
                labelText: label,
                hintText: hint,
                prefixIcon: Icon(icon, color: _primaryAccent, size: 20),
                filled: true,
                fillColor: _softGreenBg,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: _borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: _borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: _primaryAccent, width: 1.6),
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(22, 6, 22, bottomInset + 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: _lightGreenBg,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              isEditing
                                  ? Icons.manage_accounts_rounded
                                  : Icons.person_add_alt_1_rounded,
                              color: _primaryAccent,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEditing
                                      ? 'Edit Data Pengguna'
                                      : 'Tambah Pengguna Baru',
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    color: _textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Lengkapi identitas dan wilayah tugas penyuluh kehutanan.',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: _textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        initialValue: name,
                        onChanged: (v) => name = v,
                        style: TextStyle(color: _textPrimary),
                        decoration: fieldDecoration(
                          'Nama Lengkap & Gelar',
                          'Contoh: Rizky Pratama, S.Hut.',
                          Icons.badge_outlined,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (isNarrow) ...[
                        TextFormField(
                          initialValue: nip,
                          onChanged: (v) => nip = v,
                          style: TextStyle(color: _textPrimary),
                          decoration: fieldDecoration(
                            'NIP / ID Petugas',
                            '19940812 202012 1 004',
                            Icons.numbers_rounded,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          initialValue: whatsapp,
                          onChanged: (v) => whatsapp = v,
                          style: TextStyle(color: _textPrimary),
                          decoration: fieldDecoration(
                            'No. WhatsApp',
                            '0812-xxxx-xxxx',
                            Icons.chat_outlined,
                          ),
                        ),
                      ] else
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                initialValue: nip,
                                onChanged: (v) => nip = v,
                                style: TextStyle(color: _textPrimary),
                                decoration: fieldDecoration(
                                  'NIP / ID Petugas',
                                  '19940812 202012 1 004',
                                  Icons.numbers_rounded,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                initialValue: whatsapp,
                                onChanged: (v) => whatsapp = v,
                                style: TextStyle(color: _textPrimary),
                                decoration: fieldDecoration(
                                  'No. WhatsApp',
                                  '0812-xxxx-xxxx',
                                  Icons.chat_outlined,
                                ),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: email,
                        onChanged: (v) => email = v,
                        style: TextStyle(color: _textPrimary),
                        decoration: fieldDecoration(
                          'Alamat Email Dinas / Akun',
                          'nama@kehutanan.go.id',
                          Icons.alternate_email_rounded,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: wilayah,
                        onChanged: (v) => wilayah = v,
                        style: TextStyle(color: _textPrimary),
                        decoration: fieldDecoration(
                          'Wilayah Tugas / Kawasan',
                          'Contoh: CDK Wilayah Garut',
                          Icons.location_on_outlined,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: role,
                              dropdownColor: _cardBg,
                              style: TextStyle(
                                color: _textPrimary,
                                fontSize: 14,
                              ),
                              decoration: fieldDecoration(
                                'Peran / Jabatan',
                                '',
                                Icons.work_outline_rounded,
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'Penyuluh',
                                  child: Text('Penyuluh'),
                                ),
                                DropdownMenuItem(
                                  value: 'Koordinator',
                                  child: Text('Koordinator'),
                                ),
                                DropdownMenuItem(
                                  value: 'Admin',
                                  child: Text('Admin'),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setSheetState(() => role = val);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: status,
                              dropdownColor: _cardBg,
                              style: TextStyle(
                                color: _textPrimary,
                                fontSize: 14,
                              ),
                              decoration: fieldDecoration(
                                'Status Akun',
                                '',
                                Icons.verified_user_outlined,
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'Aktif',
                                  child: Text('Aktif'),
                                ),
                                DropdownMenuItem(
                                  value: 'Nonaktif',
                                  child: Text('Nonaktif'),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setSheetState(() => status = val);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(sheetCtx),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _textPrimary,
                                side: BorderSide(color: _borderColor),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                'Batal',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AdminPage.kPrimary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: () {
                                if (name.trim().isEmpty) return;

                                final item = <String, String>{
                                  'id': existing?['id'] ??
                                      'USR-00${_users.length + 1}',
                                  'nip': nip.trim().isEmpty
                                      ? '19950101 202301 1 001'
                                      : nip.trim(),
                                  'name': name.trim(),
                                  'email': email.trim().isEmpty
                                      ? 'petugas@kehutanan.go.id'
                                      : email.trim(),
                                  'whatsapp': whatsapp.trim().isEmpty
                                      ? '0812-0000-0000'
                                      : whatsapp.trim(),
                                  'wilayah': wilayah.trim().isEmpty
                                      ? 'CDK Wilayah Garut'
                                      : wilayah.trim(),
                                  'role': role,
                                  'status': status,
                                };

                                Navigator.pop(sheetCtx);
                                setState(() {
                                  if (isEditing) {
                                    final idx = _users.indexWhere(
                                      (u) => u['id'] == existing['id'],
                                    );
                                    if (idx >= 0) _users[idx] = item;
                                  } else {
                                    _users.insert(0, item);
                                  }
                                });
                                _persistUsers();
                                _syncUserToBackend(item);

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      isEditing
                                          ? 'Data ${item['name']} berhasil diperbarui.'
                                          : 'Pengguna ${item['name']} berhasil ditambahkan.',
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.save_outlined, size: 18),
                              label: const Text(
                                'Simpan Pengguna',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeleteUser(Map<String, String> user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Hapus Data Pengguna',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: Text(
            'Apakah Anda yakin ingin menghapus akun "${user['name'] ?? '-'}" dari daftar pengguna?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      _deleteUser(user);
    }
  }

  void _deleteUser(Map<String, String> user) {
    setState(() {
      _users.removeWhere(
        (u) => u['id'] == user['id'] || u['email'] == user['email'],
      );
    });
    _persistUsers();
    _deleteUserFromBackend(user);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pengguna ${user['name'] ?? ''} telah dihapus.'),
        ),
      );
    }
  }

  Future<void> _deleteUserFromBackend(Map<String, String> user) async {
    try {
      final identifier = user['id'] ?? user['email'] ?? '';
      if (identifier.isNotEmpty) {
        await http
            .delete(
              Uri.parse('${ApiConstants.baseUrl}/api/users/$identifier'),
              headers: {'Accept': 'application/json'},
            )
            .timeout(const Duration(seconds: 6));
      }
    } catch (e) {
      debugPrint('Delete user from backend error: $e');
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Keluar Panel Admin',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Apakah Anda yakin ingin keluar dari sesi Administrator?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    if (token.isNotEmpty &&
        !token.startsWith('offline_') &&
        !token.startsWith('google_session_')) {
      try {
        await http
            .post(
              Uri.parse('${ApiConstants.baseUrl}/api/logout'),
              headers: {
                'Accept': 'application/json',
                'Authorization': 'Bearer $token',
              },
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

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  String get _currentMenuTitle => switch (_selectedMenu) {
    0 => 'Beranda Admin',
    1 => 'Manajemen Pengguna',
    2 => 'Folder Seluruh User',
    3 => 'Laporan Kegiatan',
    4 => 'Jadwal Lapangan',
    5 => 'Materi Penyuluhan',
    6 => 'Profil & Pengaturan',
    _ => 'Panel Admin',
  };

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth >= 840;

    return Scaffold(
      backgroundColor: _bgColor,
      drawer: isWideScreen
          ? null
          : Drawer(
              backgroundColor: _surfaceBg,
              child: SafeArea(child: _buildSidebar(isDrawer: true)),
            ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isWideScreen)
            SizedBox(
              width: 262,
              child: SafeArea(
                right: false,
                child: _buildSidebar(isDrawer: false),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Pada layar lebar selalu tampilkan top bar;
                // Pada layar mobile, untuk Beranda Admin (index 0) header menyatu
                // dengan ilustrasi hutan seperti DashboardPage.
                if (isWideScreen || _selectedMenu != 0)
                  _buildTopProfileHeader(isWideScreen: isWideScreen),
                Expanded(
                  child: _buildMainContent(isWideScreen: isWideScreen),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isWideScreen
          ? null
          : SizedBox(
              height: 74 + MediaQuery.paddingOf(context).bottom,
              child: _buildMobileBottomNav(),
            ),
    );
  }

  // ===========================================================================
  // SIDEBAR (DESKTOP & DRAWER MOBILE)
  // ===========================================================================

  Widget _buildSidebar({required bool isDrawer}) {
    final menuItems = [
      (
        icon: Icons.dashboard_rounded,
        label: 'Beranda Admin',
        badge: null,
      ),
      (
        icon: Icons.people_alt_rounded,
        label: 'Kelola Pengguna',
        badge: '${_users.length}',
      ),
      (
        icon: Icons.folder_shared_rounded,
        label: 'Folder Seluruh User',
        badge: null,
      ),
      (
        icon: Icons.description_rounded,
        label: 'Laporan Kegiatan',
        badge: null,
      ),
      (
        icon: Icons.calendar_month_rounded,
        label: 'Jadwal Lapangan',
        badge: null,
      ),
      (
        icon: Icons.menu_book_rounded,
        label: 'Materi Penyuluhan',
        badge: null,
      ),
      (
        icon: Icons.person_rounded,
        label: 'Profil & Pengaturan',
        badge: null,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: _surfaceBg,
        border: Border(
          right: BorderSide(color: _borderColor, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Brand Header Forest Green
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1B462B),
                  AdminPage.kPrimary,
                  AdminPage.kSecondary,
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AdminPage.kPrimary.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.forest_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PHONEBOOK',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Panel Administrator',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'MENU NAVIGASI',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: _textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: menuItems.length,
              itemBuilder: (context, index) {
                final item = menuItems[index];
                final isSelected = _selectedMenu == index;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        setState(() => _selectedMenu = index);
                        if (isDrawer) Navigator.pop(context);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (_isDark
                                    ? const Color(0xFF243B2B)
                                    : AdminPage.kPrimary)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              item.icon,
                              size: 20,
                              color: isSelected
                                  ? Colors.white
                                  : _textSecondary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item.label,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : _textPrimary,
                                ),
                              ),
                            ),
                            if (item.badge != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white.withValues(alpha: 0.22)
                                      : _lightGreenBg,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  item.badge!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? Colors.white
                                        : _primaryAccent,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _handleLogout,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _isDark
                    ? const Color(0xFF331E1E)
                    : const Color(0xFFFDECEA),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFD32F2F).withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.logout_rounded,
                    size: 19,
                    color: Color(0xFFD32F2F),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Keluar Panel Admin',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFD32F2F),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // BOTTOM NAVIGATION BAR (KHUSUS MOBILE - SELARAS DENGAN BOTTOMNAV USER)
  // ===========================================================================

  Widget _buildMobileBottomNav() {
    final barBg = _isDark ? const Color(0xFF18221B) : const Color(0xFFF1F3EA);
    final activeGreen =
        _isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32);
    final inactiveCenterBg =
        _isDark ? const Color(0xFF26352B) : const Color(0xFFDCE8D8);
    final inactiveColor = _isDark ? Colors.white60 : Colors.grey.shade600;

    Widget navItem(int menuIndex, IconData icon, String label) {
      final active = _selectedMenu == menuIndex;
      return Expanded(
        child: InkWell(
          onTap: () => setState(() => _selectedMenu = menuIndex),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: active ? activeGreen : inactiveColor,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: active ? activeGreen : inactiveColor,
                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: barBg,
        border: Border(
          top: BorderSide(color: _borderColor, width: 0.8),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
          child: Row(
            children: [
              navItem(1, Icons.people_outline_rounded, 'Pengguna'),
              navItem(2, Icons.folder_shared_outlined, 'Folder'),
              Expanded(
                child: Center(
                  child: InkWell(
                    onTap: () => setState(() => _selectedMenu = 0),
                    customBorder: const CircleBorder(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: _selectedMenu == 0
                            ? activeGreen
                            : inactiveCenterBg,
                        shape: BoxShape.circle,
                        boxShadow: [
                          if (_selectedMenu == 0)
                            BoxShadow(
                              color: activeGreen.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                        ],
                      ),
                      child: Icon(
                        Icons.home_rounded,
                        size: 26,
                        color: _selectedMenu == 0
                            ? (_isDark ? const Color(0xFF121814) : Colors.white)
                            : activeGreen,
                      ),
                    ),
                  ),
                ),
              ),
              navItem(3, Icons.description_outlined, 'Laporan'),
              navItem(6, Icons.person_outline_rounded, 'Profil'),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // TOP PROFILE HEADER (UNTUK DESKTOP & SUB-HALAMAN MOBILE)
  // ===========================================================================

  Widget _buildTopProfileHeader({required bool isWideScreen}) {
    return SafeArea(
      bottom: false,
      child: Container(
        height: 64,
        padding: EdgeInsets.symmetric(horizontal: isWideScreen ? 26 : 14),
        decoration: BoxDecoration(
          color: _cardBg,
          border: Border(
            bottom: BorderSide(color: _borderColor, width: 1),
          ),
        ),
        child: Row(
          children: [
            if (!isWideScreen) ...[
              Builder(
                builder: (ctx) => IconButton(
                  tooltip: 'Buka Menu Navigasi',
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                  icon: Icon(Icons.menu_rounded, color: _textPrimary),
                ),
              ),
              if (_selectedMenu != 0)
                IconButton(
                  tooltip: 'Kembali ke Beranda Admin',
                  onPressed: () => setState(() => _selectedMenu = 0),
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    color: _primaryAccent,
                    size: 22,
                  ),
                ),
            ],
            Expanded(
              child: Text(
                _currentMenuTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Segarkan Data',
              onPressed: _isSyncingUsers
                  ? null
                  : () => _fetchUsersFromBackend(showFeedback: true),
              icon: _isSyncingUsers
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _primaryAccent,
                      ),
                    )
                  : Icon(
                      Icons.refresh_rounded,
                      color: _primaryAccent,
                      size: 22,
                    ),
            ),
            if (isWideScreen) ...[
              const SizedBox(width: 6),
              InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: () => setState(() => _selectedMenu = 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _softGreenBg,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: _borderColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: AdminPage.kPrimary,
                        child: Text(
                          _adminName.isNotEmpty
                              ? _adminName[0].toUpperCase()
                              : 'A',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _adminName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // MAIN CONTENT SWITCHER
  // ===========================================================================

  Widget _buildMainContent({required bool isWideScreen}) {
    return switch (_selectedMenu) {
      0 => _buildDashboardAdminView(isWideScreen: isWideScreen),
      1 => _buildPenggunaView(isWideScreen: isWideScreen),
      2 => const AdminFolderPage(),
      3 => const LaporanPage(isAdminMode: true),
      4 => JadwalPage(
          onBack: () => setState(() => _selectedMenu = 0),
          onNavigate: (idx) => setState(() => _selectedMenu = idx),
        ),
      5 => const MateriPage(),
      6 => const ProfilPage(),
      _ => _buildDashboardAdminView(isWideScreen: isWideScreen),
    };
  }

  // ===========================================================================
  // 0. BERANDA ADMIN (SELARAS DENGAN DASHBOARD USER)
  // ===========================================================================

  Widget _buildDashboardAdminView({required bool isWideScreen}) {
    final horizontalPad = isWideScreen ? 28.0 : 20.0;

    return Container(
      color: _bgColor,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. HEADER SAMBUTAN BERILUSTRASI HUTAN (SAMA SEPERTI DASHBOARD USER)
              _buildWelcomeHeader(context, isWideScreen: isWideScreen),

              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 22),

                    // 2. RINGKASAN SISTEM (DALAM CONTAINER PUTIH ROUNDED)
                    _buildRingkasanSection(),

                    const SizedBox(height: 26),

                    // 3. MENU UTAMA ADMIN (GRID KARTU MENU SEPERTI DASHBOARD USER)
                    _buildSectionHeader(
                      icon: Icons.eco_rounded,
                      title: 'Menu Utama Admin',
                      actionText: 'Folder User',
                      onActionTap: () => setState(() => _selectedMenu = 2),
                    ),
                    const SizedBox(height: 14),
                    _buildMainMenuGrid(),

                    const SizedBox(height: 26),

                    // 4. MONITORING LAPORAN TERBARU (KARTU BERGAYA DASHBOARD USER)
                    _buildSectionHeader(
                      icon: Icons.assignment_rounded,
                      title: 'Monitoring Laporan Terbaru',
                      actionText: 'Lihat Semua',
                      onActionTap: () => setState(() => _selectedMenu = 2),
                    ),
                    const SizedBox(height: 12),
                    _buildReportStatusFilterChips(),
                    const SizedBox(height: 12),
                    ..._filteredRecentReports.take(4).map(
                      (lap) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildLaporanTerbaruCard(lap),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 5. DIREKTORI ARSIP & MANAJEMEN AKUN (KARTU AKSI SEPERTI DASHBOARD USER)
                    _buildSectionHeader(
                      icon: Icons.inventory_2_rounded,
                      title: 'Direktori & Manajemen Pegawai',
                    ),
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isVeryNarrow = constraints.maxWidth < 340;
                        if (isVeryNarrow) {
                          return Column(
                            children: [
                              _AdminArchiveActionCard(
                                icon: Icons.folder_special_rounded,
                                title: 'Folder Seluruh User',
                                description:
                                    'Pantau seluruh folder laporan dan arsip kegiatan penyuluh',
                                buttonText: 'Buka Direktori',
                                isPrimary: true,
                                onTap: () => setState(() => _selectedMenu = 2),
                              ),
                              const SizedBox(height: 14),
                              _AdminArchiveActionCard(
                                icon: Icons.manage_accounts_rounded,
                                title: 'Manajemen Pengguna',
                                description:
                                    'Kelola akun, NIP, wilayah tugas, dan status aktif penyuluh',
                                buttonText: 'Kelola Akun',
                                isPrimary: false,
                                onTap: () => setState(() => _selectedMenu = 1),
                              ),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(
                              child: _AdminArchiveActionCard(
                                icon: Icons.folder_special_rounded,
                                title: 'Folder Seluruh User',
                                description:
                                    'Pantau seluruh folder laporan dan arsip kegiatan penyuluh',
                                buttonText: 'Buka Direktori',
                                isPrimary: true,
                                onTap: () => setState(() => _selectedMenu = 2),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _AdminArchiveActionCard(
                                icon: Icons.manage_accounts_rounded,
                                title: 'Manajemen Pengguna',
                                description:
                                    'Kelola akun, NIP, wilayah tugas, dan status aktif penyuluh',
                                buttonText: 'Kelola Akun',
                                isPrimary: false,
                                onTap: () => setState(() => _selectedMenu = 1),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader(
    BuildContext context, {
    required bool isWideScreen,
  }) {
    final topPadding = isWideScreen ? 0.0 : MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 215),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1B462B),
            AdminPage.kPrimary,
            AdminPage.kSecondary,
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x1F245C3A),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _AdminForestHeaderPainter(),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                isWideScreen ? 28 : 22,
                topPadding + 22,
                isWideScreen ? 28 : 22,
                26,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isWideScreen) ...[
                        Builder(
                          builder: (ctx) => InkWell(
                            onTap: () => Scaffold.of(ctx).openDrawer(),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              width: 44,
                              height: 44,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.24),
                                ),
                              ),
                              child: const Icon(
                                Icons.menu_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.24),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.verified_user_rounded,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'Panel Administrator • $_adminEmail',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Selamat Datang, $_adminName 👋',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Kelola akun penyuluh, pantau laporan masuk,\ndan periksa direktori arsip kegiatan lapangan.',
                              style: TextStyle(
                                color: Color(0xFFE8F2E8),
                                fontSize: 14,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Tombol Aksi Cepat (Refresh & Profil)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: () =>
                                _fetchUsersFromBackend(showFeedback: true),
                            borderRadius: BorderRadius.circular(24),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.92),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Icon(
                                _isSyncingUsers
                                    ? Icons.sync_rounded
                                    : Icons.refresh_rounded,
                                color: AdminPage.kPrimary,
                                size: 22,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: _handleLogout,
                            borderRadius: BorderRadius.circular(24),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.92),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.logout_rounded,
                                color: Color(0xFFD32F2F),
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRingkasanSection() {
    final activeUsersCount = _users
        .where((u) => (u['status'] ?? 'Aktif') == 'Aktif')
        .length;
    final completedReportsCount = _recentReports
        .where((r) => (r['status'] ?? '') == 'Selesai')
        .length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AdminPage.kPrimary.withValues(alpha: _isDark ? 0.2 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.bar_chart_rounded,
                    color: _primaryAccent,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Ringkasan Sistem',
                    style: TextStyle(
                      fontSize: 18.5,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => setState(() => _selectedMenu = 1),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Kelola Data',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: _textSecondary,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: _textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 680;
              if (isWide) {
                return Row(
                  children: [
                    Expanded(
                      child: _AdminStatCard(
                        icon: Icons.people_alt_rounded,
                        title: 'Pengguna',
                        value: '${_users.length}',
                        subtitle: '$activeUsersCount Akun Aktif',
                        onTap: () => setState(() => _selectedMenu = 1),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _AdminStatCard(
                        icon: Icons.folder_shared_rounded,
                        title: 'Folder User',
                        value: '${_users.length}',
                        subtitle: 'Direktori Penyuluh',
                        onTap: () => setState(() => _selectedMenu = 2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _AdminStatCard(
                        icon: Icons.description_rounded,
                        title: 'Laporan',
                        value: '${_recentReports.length}',
                        subtitle: '$completedReportsCount Selesai',
                        onTap: () => setState(() => _selectedMenu = 3),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _AdminStatCard(
                        icon: Icons.calendar_today_rounded,
                        title: 'Jadwal & Materi',
                        value: '$_totalJadwalCount',
                        subtitle: '$_totalMateriCount Modul Materi',
                        onTap: () => setState(() => _selectedMenu = 4),
                      ),
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _AdminStatCard(
                          icon: Icons.people_alt_rounded,
                          title: 'Pengguna',
                          value: '${_users.length}',
                          subtitle: '$activeUsersCount Akun Aktif',
                          onTap: () => setState(() => _selectedMenu = 1),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _AdminStatCard(
                          icon: Icons.folder_shared_rounded,
                          title: 'Folder User',
                          value: '${_users.length}',
                          subtitle: 'Direktori Penyuluh',
                          onTap: () => setState(() => _selectedMenu = 2),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _AdminStatCard(
                          icon: Icons.description_rounded,
                          title: 'Laporan',
                          value: '${_recentReports.length}',
                          subtitle: '$completedReportsCount Selesai',
                          onTap: () => setState(() => _selectedMenu = 3),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _AdminStatCard(
                          icon: Icons.calendar_today_rounded,
                          title: 'Jadwal & Materi',
                          value: '$_totalJadwalCount',
                          subtitle: '$_totalMateriCount Modul Materi',
                          onTap: () => setState(() => _selectedMenu = 4),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMainMenuGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 720;
        final cards = [
          _AdminMainMenuCard(
            icon: Icons.people_alt_rounded,
            title: 'Pengguna',
            subtitle: 'Kelola akun & NIP penyuluh',
            isPrimaryVariant: true,
            onTap: () => setState(() => _selectedMenu = 1),
          ),
          _AdminMainMenuCard(
            icon: Icons.folder_shared_rounded,
            title: 'Folder User',
            subtitle: 'Buka seluruh arsip pegawai',
            isPrimaryVariant: false,
            onTap: () => setState(() => _selectedMenu = 2),
          ),
          _AdminMainMenuCard(
            icon: Icons.description_rounded,
            title: 'Laporan',
            subtitle: 'Atur template & pantau laporan',
            isPrimaryVariant: true,
            onTap: () => setState(() => _selectedMenu = 3),
          ),
          _AdminMainMenuCard(
            icon: Icons.calendar_month_rounded,
            title: 'Jadwal',
            subtitle: 'Agenda kegiatan lapangan',
            isPrimaryVariant: false,
            onTap: () => setState(() => _selectedMenu = 4),
          ),
          _AdminMainMenuCard(
            icon: Icons.menu_book_rounded,
            title: 'Materi',
            subtitle: 'Unggah modul penyuluhan',
            isPrimaryVariant: true,
            onTap: () => setState(() => _selectedMenu = 5),
          ),
          _AdminMainMenuCard(
            icon: Icons.person_rounded,
            title: 'Profil Admin',
            subtitle: 'Pengaturan akun & tema',
            isPrimaryVariant: false,
            onTap: () => setState(() => _selectedMenu = 6),
          ),
        ];

        if (isDesktop) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 14),
                  Expanded(child: cards[1]),
                  const SizedBox(width: 14),
                  Expanded(child: cards[2]),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: cards[3]),
                  const SizedBox(width: 14),
                  Expanded(child: cards[4]),
                  const SizedBox(width: 14),
                  Expanded(child: cards[5]),
                ],
              ),
            ],
          );
        }

        return Column(
          children: [
            Row(
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 12),
                Expanded(child: cards[1]),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: cards[2]),
                const SizedBox(width: 12),
                Expanded(child: cards[3]),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: cards[4]),
                const SizedBox(width: 12),
                Expanded(child: cards[5]),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    String? actionText,
    VoidCallback? onActionTap,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Icon(icon, color: _primaryAccent, size: 22),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18.5,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (actionText != null)
          InkWell(
            onTap: onActionTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                children: [
                  Text(
                    actionText,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: _textSecondary,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: _textSecondary,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildReportStatusFilterChips() {
    final filters = ['Semua', 'Selesai', 'Diproses', 'Draft'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = _reportFilterStatus == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(f),
              selected: isSelected,
              showCheckmark: false,
              selectedColor: AdminPage.kPrimary,
              backgroundColor: _cardBg,
              side: BorderSide(
                color: isSelected ? AdminPage.kPrimary : _borderColor,
              ),
              labelStyle: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : _textPrimary,
              ),
              onSelected: (_) => setState(() => _reportFilterStatus = f),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLaporanTerbaruCard(Map<String, String> lap) {
    final status = lap['status'] ?? 'Draft';

    return Material(
      color: _cardBg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => setState(() => _selectedMenu = 2),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _borderColor),
            boxShadow: [
              BoxShadow(
                color: AdminPage.kPrimary.withValues(
                  alpha: _isDark ? 0.18 : 0.04,
                ),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _lightGreenBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.description_rounded,
                  color: _primaryAccent,
                  size: 25,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            lap['judul'] ?? '-',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusChip(status: status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person_outline_rounded,
                              size: 14,
                              color: _primaryAccent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              lap['pelapor'] ?? '-',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: _textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Text('|', style: TextStyle(color: _textSecondary)),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 13,
                              color: _textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              lap['tanggal'] ?? '-',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: _textSecondary,
                              ),
                            ),
                          ],
                        ),
                        Text('|', style: TextStyle(color: _textSecondary)),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              size: 14,
                              color: AdminPage.kSecondary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              lap['lokasi'] ?? 'CDK Wilayah Garut',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: _textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Kategori: ${lap['kategori'] ?? 'Penyuluhan'}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: _textSecondary,
                          ),
                        ),
                        if (status != 'Selesai')
                          InkWell(
                            onTap: () {
                              setState(() {
                                lap['status'] = 'Selesai';
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Laporan "${lap['judul']}" diverifikasi Selesai.',
                                  ),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.verified_outlined,
                                    size: 15,
                                    color: _primaryAccent,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Verifikasi',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _primaryAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. MANAJEMEN PENGGUNA (RESPONSIF: KARTU DI MOBILE & TABEL DI DESKTOP)
  // ===========================================================================

  Widget _buildPenggunaView({required bool isWideScreen}) {
    final users = _filteredUsers;
    final activeCount = _users
        .where((u) => (u['status'] ?? 'Aktif') == 'Aktif')
        .length;
    final horizontalPad = isWideScreen ? 28.0 : 18.0;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(horizontalPad, 20, horizontalPad, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Banner Manajemen Pengguna (Selaras dengan LaporanHeader & AdminFolderPage)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1B462B),
                  AdminPage.kPrimary,
                  AdminPage.kSecondary,
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: AdminPage.kPrimary.withValues(alpha: 0.16),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.people_alt_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Manajemen Akun Penyuluh',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Kelola data pegawai, wilayah tugas, dan akses pelaporan lapangan.',
                            style: TextStyle(
                              color: Color(0xFFE8F2E8),
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _HeaderPillBadge(
                      icon: Icons.groups_rounded,
                      label: '${_users.length} Total Pegawai',
                    ),
                    _HeaderPillBadge(
                      icon: Icons.check_circle_outline_rounded,
                      label: '$activeCount Status Aktif',
                    ),
                    _HeaderPillBadge(
                      icon: Icons.folder_shared_outlined,
                      label: '${_users.length} Direktori Folder',
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Baris Pencarian & Tombol Tambah Pengguna (Responsif)
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 600;
              final searchField = TextField(
                onChanged: (val) => setState(() => _searchUserQuery = val),
                style: TextStyle(color: _textPrimary, fontSize: 13.5),
                decoration: InputDecoration(
                  hintText:
                      'Cari nama penyuluh, NIP, email, atau wilayah tugas...',
                  hintStyle: TextStyle(fontSize: 13, color: _textSecondary),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: _primaryAccent,
                  ),
                  suffixIcon: _searchUserQuery.isNotEmpty
                      ? IconButton(
                          onPressed: () =>
                              setState(() => _searchUserQuery = ''),
                          icon: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: _textSecondary,
                          ),
                        )
                      : null,
                  filled: true,
                  fillColor: _cardBg,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: _borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: _borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: _primaryAccent, width: 1.5),
                  ),
                ),
              );

              final addButton = ElevatedButton.icon(
                onPressed: () => _openUserFormSheet(),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 19),
                label: const Text(
                  'Tambah Pengguna',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminPage.kPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              );

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    searchField,
                    const SizedBox(height: 10),
                    addButton,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: searchField),
                  const SizedBox(width: 14),
                  addButton,
                ],
              );
            },
          ),

          const SizedBox(height: 14),

          // Filter Chips Status & Peran
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['Semua', 'Aktif', 'Nonaktif', 'Penyuluh', 'Koordinator']
                  .map((filter) {
                    final selected = _userFilterStatus == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(filter),
                        selected: selected,
                        showCheckmark: false,
                        selectedColor: AdminPage.kPrimary,
                        backgroundColor: _cardBg,
                        side: BorderSide(
                          color: selected ? AdminPage.kPrimary : _borderColor,
                        ),
                        labelStyle: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : _textPrimary,
                        ),
                        onSelected: (_) =>
                            setState(() => _userFilterStatus = filter),
                      ),
                    );
                  })
                  .toList(),
            ),
          ),

          const SizedBox(height: 16),

          // Daftar Pengguna: Tabel di layar lebar (>= 780px), Kartu nyaman di layar mobile (< 780px)
          if (users.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(36),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _borderColor),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.person_search_rounded,
                    size: 46,
                    color: _textSecondary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tidak ada data pengguna yang cocok dengan pencarian.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _textSecondary,
                    ),
                  ),
                ],
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final useTableLayout = constraints.maxWidth >= 780;
                if (useTableLayout) {
                  return _buildDesktopUsersTable(users);
                }
                return Column(
                  children: List.generate(
                    users.length,
                    (index) => _buildMobileUserCard(users[index], index),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMobileUserCard(Map<String, String> u, int index) {
    final name = u['name'] ?? '-';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'P';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: AdminPage.kPrimary.withValues(alpha: _isDark ? 0.18 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _lightGreenBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: _primaryAccent,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'NIP: ${u['nip'] ?? '-'}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusChip(status: u['status'] ?? 'Aktif'),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: _borderColor),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              _UserMetaItem(
                icon: Icons.work_outline_rounded,
                text: u['role'] ?? 'Penyuluh',
                textColor: _textPrimary,
                iconColor: _primaryAccent,
              ),
              _UserMetaItem(
                icon: Icons.location_on_outlined,
                text: u['wilayah'] ?? 'CDK Wilayah Garut',
                textColor: _textSecondary,
                iconColor: AdminPage.kSecondary,
              ),
              _UserMetaItem(
                icon: Icons.email_outlined,
                text: u['email'] ?? '-',
                textColor: _textSecondary,
                iconColor: _primaryAccent,
              ),
              _UserMetaItem(
                icon: Icons.phone_outlined,
                text: u['whatsapp'] ?? '-',
                textColor: _textSecondary,
                iconColor: AdminPage.kSecondary,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _selectedMenu = 2),
                  icon: Icon(
                    Icons.folder_shared_outlined,
                    size: 17,
                    color: _primaryAccent,
                  ),
                  label: Text(
                    'Folder',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _primaryAccent,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _borderColor),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openUserFormSheet(existing: u),
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 17,
                    color: AdminPage.kSecondary,
                  ),
                  label: const Text(
                    'Edit',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AdminPage.kSecondary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _borderColor),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Hapus Pengguna',
                onPressed: () => _confirmDeleteUser(u),
                style: IconButton.styleFrom(
                  backgroundColor: _isDark
                      ? const Color(0xFF331E1E)
                      : const Color(0xFFFDECEA),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 19,
                  color: Color(0xFFD32F2F),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopUsersTable(List<Map<String, String>> users) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: AdminPage.kPrimary.withValues(alpha: _isDark ? 0.18 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _softGreenBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 36,
                  child: Text(
                    'No',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      color: _textPrimary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Nama & NIP Penyuluh',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      color: _textPrimary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Email & WhatsApp',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      color: _textPrimary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Wilayah & Peran',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      color: _textPrimary,
                    ),
                  ),
                ),
                SizedBox(
                  width: 90,
                  child: Text(
                    'Status',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      color: _textPrimary,
                    ),
                  ),
                ),
                SizedBox(
                  width: 126,
                  child: Text(
                    'Aksi / Folder',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      color: _textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ...List.generate(users.length, (index) {
            final u = users[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _isDark
                    ? const Color(0xFF18211C)
                    : const Color(0xFFFAFBF9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _borderColor),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: _textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            u['name'] ?? '-',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: _textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'NIP: ${u['nip'] ?? '-'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: _textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            u['email'] ?? '-',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: _textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            u['whatsapp'] ?? '-',
                            style: TextStyle(
                              fontSize: 12,
                              color: _textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            u['wilayah'] ?? '-',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: _textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            u['role'] ?? 'Penyuluh',
                            style: TextStyle(
                              fontSize: 12,
                              color: _textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 90,
                    child: _StatusChip(status: u['status'] ?? 'Aktif'),
                  ),
                  SizedBox(
                    width: 126,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          tooltip: 'Buka Folder User Ini',
                          onPressed: () => setState(() => _selectedMenu = 2),
                          icon: Icon(
                            Icons.folder_shared_outlined,
                            size: 19,
                            color: _primaryAccent,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Edit Pengguna',
                          onPressed: () => _openUserFormSheet(existing: u),
                          icon: const Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: AdminPage.kSecondary,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Hapus Pengguna',
                          onPressed: () => _confirmDeleteUser(u),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: Color(0xFFD32F2F),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ============================================================================
// KOMPONEN PENDUKUNG ADMIN PAGE (SELARAS DENGAN DASHBOARD USER)
// ============================================================================

class _AdminStatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final VoidCallback onTap;

  const _AdminStatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF223026) : AdminPage.kSoftGreen;
    final borderCol = isDark ? const Color(0xFF2E3D34) : AdminPage.kLightGreen;
    final iconBg = isDark ? const Color(0xFF2B3E31) : AdminPage.kLightGreen;
    final primaryCol = isDark ? const Color(0xFF81C784) : AdminPage.kPrimary;
    final valueColor = isDark ? AdminPage.kWhite : AdminPage.kTextPrimary;
    final subColor = isDark ? Colors.white70 : AdminPage.kTextSecondary;

    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderCol, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: primaryCol, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: subColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: valueColor,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: subColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminMainMenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isPrimaryVariant;
  final VoidCallback onTap;

  const _AdminMainMenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isPrimaryVariant,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? const Color(0xFF1E2822)
        : (isPrimaryVariant ? AdminPage.kLightGreen : AdminPage.kSoftGreen);
    final titleCol = isDark ? AdminPage.kWhite : AdminPage.kTextPrimary;
    final subCol = isDark ? Colors.white70 : AdminPage.kTextSecondary;
    final accentCol = isPrimaryVariant
        ? AdminPage.kSecondary.withValues(alpha: 0.15)
        : AdminPage.kPrimary.withValues(alpha: 0.10);

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 98,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF2E3D34)
                  : (isPrimaryVariant
                        ? AdminPage.kSecondary.withValues(alpha: 0.25)
                        : AdminPage.kPrimary.withValues(alpha: 0.15)),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Positioned(
                  right: -20,
                  bottom: isPrimaryVariant ? -20 : null,
                  top: isPrimaryVariant ? null : -20,
                  child: Container(
                    width: 75,
                    height: 75,
                    decoration: BoxDecoration(
                      color: accentCol,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isPrimaryVariant
                              ? AdminPage.kPrimary
                              : AdminPage.kSecondary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          icon,
                          color: AdminPage.kWhite,
                          size: 23,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                color: titleCol,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                height: 1.2,
                                color: subCol,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: isDark
                            ? const Color(0xFF81C784)
                            : AdminPage.kPrimary,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminArchiveActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String buttonText;
  final bool isPrimary;
  final VoidCallback onTap;

  const _AdminArchiveActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonText,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1A241E) : AdminPage.kWhite;
    final titleColor = isDark ? AdminPage.kWhite : AdminPage.kTextPrimary;
    final subColor = isDark ? Colors.white70 : AdminPage.kTextSecondary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPrimary
              ? AdminPage.kPrimary.withValues(alpha: 0.25)
              : AdminPage.kSecondary.withValues(alpha: 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AdminPage.kPrimary.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF24382B)
                  : (isPrimary
                        ? AdminPage.kLightGreen
                        : AdminPage.kSoftGreen),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isDark
                  ? const Color(0xFF81C784)
                  : (isPrimary ? AdminPage.kPrimary : AdminPage.kSecondary),
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: subColor,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: isPrimary
                    ? AdminPage.kPrimary
                    : AdminPage.kLightGreen,
                foregroundColor: isPrimary
                    ? AdminPage.kWhite
                    : AdminPage.kPrimary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      buttonText,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderPillBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeaderPillBadge({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _UserMetaItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color textColor;
  final Color iconColor;

  const _UserMetaItem({
    required this.icon,
    required this.text,
    required this.textColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: iconColor),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            style: TextStyle(fontSize: 12.5, color: textColor),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (status) {
      'Selesai' || 'Aktif' => (
        AdminPage.kLightGreen,
        AdminPage.kPrimary,
      ),
      'Diproses' || 'Terjadwal' => (
        const Color(0xFFFFF4E5),
        const Color(0xFFB26A00),
      ),
      _ => (
        const Color(0xFFECEFF1),
        const Color(0xFF546E7A),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class _AdminForestHeaderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final backHillPaint = Paint()
      ..color = const Color(0xFF81C784).withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    final backHillPath = Path()
      ..moveTo(size.width * 0.35, size.height)
      ..quadraticBezierTo(
        size.width * 0.65,
        size.height * 0.35,
        size.width,
        size.height * 0.55,
      )
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(backHillPath, backHillPaint);

    final midHillPaint = Paint()
      ..color = const Color(0xFF387A4D).withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;

    final midHillPath = Path()
      ..moveTo(size.width * 0.45, size.height)
      ..quadraticBezierTo(
        size.width * 0.78,
        size.height * 0.48,
        size.width,
        size.height * 0.72,
      )
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(midHillPath, midHillPaint);

    final frontHillPaint = Paint()
      ..color = const Color(0xFF1B4B2A).withValues(alpha: 0.75)
      ..style = PaintingStyle.fill;

    final frontHillPath = Path()
      ..moveTo(size.width * 0.55, size.height)
      ..quadraticBezierTo(
        size.width * 0.85,
        size.height * 0.68,
        size.width,
        size.height * 0.82,
      )
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(frontHillPath, frontHillPaint);

    _drawPineTree(
      canvas,
      Offset(size.width * 0.58, size.height * 0.82),
      26,
      const Color(0xFF1B4B2A),
    );
    _drawPineTree(
      canvas,
      Offset(size.width * 0.65, size.height * 0.75),
      36,
      const Color(0xFF163D22),
    );
    _drawPineTree(
      canvas,
      Offset(size.width * 0.72, size.height * 0.78),
      30,
      const Color(0xFF245C3A),
    );
    _drawPineTree(
      canvas,
      Offset(size.width * 0.88, size.height * 0.72),
      38,
      const Color(0xFF163D22),
    );
  }

  void _drawPineTree(
    Canvas canvas,
    Offset baseCenter,
    double height,
    Color color,
  ) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final width = height * 0.55;
    final path = Path()
      ..moveTo(baseCenter.dx, baseCenter.dy - height)
      ..lineTo(baseCenter.dx - width / 2, baseCenter.dy)
      ..lineTo(baseCenter.dx + width / 2, baseCenter.dy)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}