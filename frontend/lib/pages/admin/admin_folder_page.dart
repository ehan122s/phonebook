// ============================================================================
// [KHUSUS ADMIN - HALAMAN FOLDER SELURUH USER]
// Simpan file ini di: lib/pages/admin/admin_folder_page.dart
// Hanya untuk Admin: Melihat SELURUH FOLDER USER, laporan, & arsip kegiatan
//
// Pembaruan Desain ("Soft Green Forest - Modern & Responsif"):
// - Selaras dengan KategoriPage & DashboardPage (palet #245C3A / #4F8A5B /
//   #E8F2E8 / #F2F7F0 tanpa warna mencolok yang bertabrakan, plus dukungan Dark Mode).
// - Padding dan tab switcher adaptif untuk layar mobile maupun desktop.
// ============================================================================

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../widgets/laporan/report_dialogs.dart';

class AdminFolderPage extends StatefulWidget {
  const AdminFolderPage({super.key});

  static const Color kPrimary = Color(0xFF245C3A);
  static const Color kSecondary = Color(0xFF4F8A5B);
  static const Color kLightGreen = Color(0xFFE8F2E8);
  static const Color kSoftGreen = Color(0xFFF2F7F0);
  static const Color kBackground = Color(0xFFF7F9F6);
  static const Color kCard = Color(0xFFFFFFFF);
  static const Color kTextPrimary = Color(0xFF24352A);
  static const Color kTextSecondary = Color(0xFF758278);
  static const Color kBorder = Color(0xFFE1EAE0);

  @override
  State<AdminFolderPage> createState() => _AdminFolderPageState();
}

class _AdminFolderPageState extends State<AdminFolderPage> {
  static const String _archiveStorageKey = 'phonebook_folder_archives_v1';
  static const String _usersStorageKey = 'phonebook_admin_users_v1';
  static const String _jadwalStorageKey = 'phonebook_jadwal_items_v1';
  static const String _laporanDraftKey = 'phonebook_laporan_drafts_v1';

  String _searchQuery = '';
  String _selectedTypeFilter = 'Semua';

  /// 0 = Folder Seluruh User, 1 = Folder per Kategori, 2 = Semua Berkas
  int _viewMode = 0;

  /// Folder yang sedang dibuka oleh Admin (null = tampilan daftar folder utama)
  Map<String, dynamic>? _openedFolder;

  final List<Map<String, String>> _usersList = [];
  final List<Map<String, dynamic>> _allItems = [];
  final List<String> _categories = [
    'Penyuluhan',
    'Monitoring & Patroli',
    'Rehabilitasi Hutan',
    'Ekosistem & Konservasi',
    'Kelembagaan KTH',
  ];

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg => _isDark ? const Color(0xFF121814) : AdminFolderPage.kBackground;
  Color get _cardBg => _isDark ? const Color(0xFF1E2822) : AdminFolderPage.kCard;
  Color get _borderCol => _isDark ? const Color(0xFF2E3D34) : AdminFolderPage.kBorder;
  Color get _textPrimaryCol => _isDark ? Colors.white : AdminFolderPage.kTextPrimary;
  Color get _textSecondaryCol => _isDark ? Colors.white70 : AdminFolderPage.kTextSecondary;
  Color get _softGreenCol => _isDark ? const Color(0xFF26352B) : AdminFolderPage.kSoftGreen;
  Color get _lightGreenCol => _isDark ? const Color(0xFF1B3B22) : AdminFolderPage.kLightGreen;
  Color get _primaryCol => _isDark ? const Color(0xFF81C784) : AdminFolderPage.kPrimary;

  @override
  void initState() {
    super.initState();
    _loadAllUsersAndArchives();
  }

  Future<void> _loadAllUsersAndArchives() async {
    final prefs = await SharedPreferences.getInstance();

    final defaultUsers = <Map<String, String>>[
      {
        'id': 'USR-001',
        'nip': '19940812 202012 1 004',
        'name': 'Rizky Pratama, S.Hut.',
        'email': 'rizky@kehutanan.go.id',
        'wilayah': 'CDK Wilayah Garut',
        'role': 'Penyuluh',
      },
      {
        'id': 'USR-002',
        'nip': '19910523 201903 2 008',
        'name': 'Siti Nurhaliza, S.Hut.',
        'email': 'siti.nur@kehutanan.go.id',
        'wilayah': 'Kecamatan Cisurupan',
        'role': 'Penyuluh',
      },
      {
        'id': 'USR-003',
        'nip': '19891104 201801 1 002',
        'name': 'Budi Santoso, M.Si.',
        'email': 'budi.santoso@kehutanan.go.id',
        'wilayah': 'Kawasan Hutan Cikuray',
        'role': 'Koordinator',
      },
      {
        'id': 'USR-004',
        'nip': '19960219 202203 1 011',
        'name': 'Andi Wijaya, S.Hut.',
        'email': 'andi.wijaya@kehutanan.go.id',
        'wilayah': 'Lereng Gunung Guntur',
        'role': 'Penyuluh',
      },
    ];

    List<Map<String, String>> loadedUsers = defaultUsers;
    final rawUsers = prefs.getString(_usersStorageKey);
    if (rawUsers != null && rawUsers.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(rawUsers);
        loadedUsers = decoded
            .map(
              (e) => Map<String, String>.from(
                (e as Map).map((k, v) => MapEntry(k.toString(), '$v')),
              ),
            )
            .toList();
      } catch (_) {}
    }

    List<Map<String, dynamic>> items = _buildDefaultAllUserArchives();
    final rawArchives = prefs.getString(_archiveStorageKey);
    if (rawArchives != null && rawArchives.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(rawArchives);
        items = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {}
    }

    // Sinkronkan juga jadwal & laporan yang dibuat oleh user di perangkat ini
    final lastUserName =
        prefs.getString('profil_nama') ?? 'Rizky Pratama, S.Hut.';

    final rawJadwal = prefs.getString(_jadwalStorageKey);
    if (rawJadwal != null && rawJadwal.isNotEmpty) {
      try {
        final List<dynamic> jadwalList = jsonDecode(rawJadwal);
        for (final j in jadwalList) {
          final map = Map<String, dynamic>.from(j);
          final id = 'sync_jadwal_${map['id']}';
          if (!items.any((e) => e['id'] == id)) {
            items.insert(0, {
              'id': id,
              'judul': map['judul'] ?? 'Kegiatan Terjadwal',
              'tipe': 'Arsip Jadwal',
              'kategori': _normalizeCategory(
                (map['kategori'] ?? 'Penyuluhan').toString(),
              ),
              'userName': lastUserName,
              'wilayah': map['lokasi'] ?? 'Kecamatan Garut',
              'tanggal': map['tanggalIso'] ?? '20 Oktober 2026',
              'waktu': map['waktu'] ?? '08:00',
              'status': (map['isCompleted'] ?? false) ? 'Selesai' : 'Terjadwal',
              'deskripsi': map['catatan'] ??
                  'Arsip pelaksanaan jadwal kegiatan lapangan.',
            });
          }
        }
      } catch (_) {}
    }

    final rawLaporan = prefs.getString(_laporanDraftKey);
    if (rawLaporan != null && rawLaporan.isNotEmpty) {
      try {
        final List<dynamic> laporanList = jsonDecode(rawLaporan);
        for (final l in laporanList) {
          final map = Map<String, dynamic>.from(l);
          final id = 'sync_laporan_${map['id']}';
          if (!items.any((e) => e['id'] == id)) {
            items.insert(0, {
              'id': id,
              'judul': map['judul'] ?? 'Laporan Kegiatan',
              'tipe': 'Laporan',
              'kategori': _normalizeCategory(
                (map['jenis'] ?? 'Penyuluhan').toString(),
              ),
              'userName': lastUserName,
              'wilayah': map['lokasi'] ?? 'Garut',
              'tanggal': map['tanggal'] ?? '20 Oktober 2026',
              'waktu': '09:00',
              'status': map['status'] ?? 'Draft',
              'deskripsi':
                  map['isi'] ?? 'Dokumen laporan hasil kegiatan lapangan.',
            });
          }
        }
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _usersList
        ..clear()
        ..addAll(loadedUsers);
      _allItems
        ..clear()
        ..addAll(items);
    });
  }

  Future<void> _persistArchives() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_archiveStorageKey, jsonEncode(_allItems));
  }

  String _normalizeCategory(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('monitor') || lower.contains('patroli')) {
      return 'Monitoring & Patroli';
    }
    if (lower.contains('rehab') || lower.contains('tanam')) {
      return 'Rehabilitasi Hutan';
    }
    if (lower.contains('ekosistem') || lower.contains('konservasi')) {
      return 'Ekosistem & Konservasi';
    }
    if (lower.contains('kth') || lower.contains('kelembagaan')) {
      return 'Kelembagaan KTH';
    }
    return 'Penyuluhan';
  }

  IconData _categoryIcon(String category) {
    return switch (category) {
      'Penyuluhan' => Icons.campaign_outlined,
      'Monitoring & Patroli' => Icons.travel_explore_outlined,
      'Rehabilitasi Hutan' => Icons.park_outlined,
      'Ekosistem & Konservasi' => Icons.eco_outlined,
      'Kelembagaan KTH' => Icons.groups_outlined,
      _ => Icons.folder_outlined,
    };
  }

  void _showAdminArchiveDetail(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: _cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        final isLaporan = item['tipe'] == 'Laporan';
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: isLaporan ? _lightGreenCol : _softGreenCol,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      isLaporan
                          ? Icons.description_outlined
                          : Icons.event_available_rounded,
                      color: _primaryCol,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (item['judul'] ?? '-').toString(),
                          style: TextStyle(
                            fontSize: 17.5,
                            fontWeight: FontWeight.bold,
                            color: _textPrimaryCol,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item['tipe']} • Kategori ${item['kategori']}',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: _textSecondaryCol,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusBadge(
                    status: (item['status'] ?? 'Selesai').toString(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: _borderCol),
              const SizedBox(height: 14),
              _DetailRow(
                icon: Icons.folder_shared_outlined,
                label: 'Folder Milik User',
                value: (item['userName'] ?? '-').toString(),
                textColor: _textPrimaryCol,
                subColor: _textSecondaryCol,
                iconColor: _primaryCol,
              ),
              const SizedBox(height: 8),
              _DetailRow(
                icon: Icons.location_on_outlined,
                label: 'Wilayah / Lokasi',
                value: (item['wilayah'] ?? '-').toString(),
                textColor: _textPrimaryCol,
                subColor: _textSecondaryCol,
                iconColor: _primaryCol,
              ),
              const SizedBox(height: 8),
              _DetailRow(
                icon: Icons.calendar_today_outlined,
                label: 'Tanggal & Waktu',
                value: '${item['tanggal']} • ${item['waktu'] ?? '08:00'} WIB',
                textColor: _textPrimaryCol,
                subColor: _textSecondaryCol,
                iconColor: _primaryCol,
              ),
              const SizedBox(height: 14),
              Text(
                'Ringkasan Laporan / Arsip:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _textSecondaryCol,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                (item['deskripsi'] ?? '-').toString(),
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: _textPrimaryCol,
                ),
              ),
              const SizedBox(height: 18),
              if (isLaporan) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetCtx);
                      showReportDownloadSheet(
                        context,
                        laporan: {
                          'id': item['id'],
                          'judul': item['judul'],
                          'jenis': 'Laporan ${item['kategori'] ?? 'Penyuluhan'}',
                          'pelapor': item['userName'] ?? 'Penyuluh Kehutanan',
                          'userName': item['userName'] ?? 'Penyuluh Kehutanan',
                          'tanggal': item['tanggal'] ?? '-',
                          'lokasi': item['wilayah'] ?? '-',
                          'isi': item['deskripsi'] ?? '',
                          'status': item['status'] ?? 'Selesai',
                        },
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _primaryCol,
                      side: BorderSide(color: _primaryCol),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                    label: const Text(
                      'Unduh & Cetak Laporan (PDF / Word)',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetCtx);
                      setState(() {
                        _allItems.removeWhere((e) => e['id'] == item['id']);
                      });
                      _persistArchives();
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: Colors.red.withValues(alpha: 0.4),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: Colors.red,
                    ),
                    label: const Text(
                      'Hapus Berkas',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (item['status'] != 'Selesai')
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AdminFolderPage.kPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(sheetCtx);
                          setState(() {
                            final idx = _allItems.indexWhere(
                              (e) => e['id'] == item['id'],
                            );
                            if (idx >= 0) {
                              _allItems[idx]['status'] = 'Selesai';
                            }
                          });
                          _persistArchives();
                        },
                        icon: const Icon(Icons.verified_outlined, size: 18),
                        label: const Text(
                          'Verifikasi Selesai',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AdminFolderPage.kPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.pop(sheetCtx),
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text(
                          'Tutup',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _openedFolder != null
          ? AppBar(
              backgroundColor: _cardBg,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                onPressed: () => setState(() => _openedFolder = null),
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: _primaryCol,
                ),
              ),
              title: Text(
                (_openedFolder!['title'] ?? 'Folder User').toString(),
                style: TextStyle(
                  color: _textPrimaryCol,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
      body: SafeArea(
        child: _openedFolder != null
            ? _buildOpenedUserFolderView(_openedFolder!)
            : _buildAllUserFoldersRoot(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tampilan Utama Admin: Direktori Seluruh Folder User
  // ---------------------------------------------------------------------------

  Widget _buildAllUserFoldersRoot() {
    final totalLaporan =
        _allItems.where((e) => e['tipe'] == 'Laporan').length;
    final totalJadwal =
        _allItems.where((e) => e['tipe'] == 'Arsip Jadwal').length;
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPad = screenWidth >= 760 ? 28.0 : 18.0;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(horizontalPad, 20, horizontalPad, 60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Direktori Seluruh Folder User (Selaras dengan KategoriPage & LaporanHeader)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF1B462B),
                  AdminFolderPage.kPrimary,
                  AdminFolderPage.kSecondary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: AdminFolderPage.kPrimary.withValues(alpha: 0.16),
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
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.folder_shared_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Direktori Folder Seluruh User',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Pantau dan periksa seluruh folder laporan serta arsip jadwal kegiatan milik setiap penyuluh.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
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
                    _PillStat(
                      icon: Icons.people_alt_outlined,
                      label: '${_usersList.length} Folder User',
                    ),
                    _PillStat(
                      icon: Icons.description_outlined,
                      label: '$totalLaporan Total Laporan Masuk',
                    ),
                    _PillStat(
                      icon: Icons.event_available_outlined,
                      label: '$totalJadwal Total Arsip Jadwal',
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Pencarian Folder User / Laporan
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            style: TextStyle(color: _textPrimaryCol, fontSize: 13.5),
            decoration: InputDecoration(
              hintText:
                  'Cari nama folder user, NIP, wilayah, atau judul laporan...',
              hintStyle: TextStyle(fontSize: 13, color: _textSecondaryCol),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: _primaryCol,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      onPressed: () => setState(() => _searchQuery = ''),
                      icon: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: _textSecondaryCol,
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
                borderSide: BorderSide(color: _borderCol),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _borderCol),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _primaryCol, width: 1.5),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Switcher Tampilan Admin
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: _softGreenCol,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _borderCol),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _TabSwitchButton(
                    label: 'Per User',
                    icon: Icons.folder_shared_outlined,
                    isSelected: _viewMode == 0,
                    onTap: () => setState(() => _viewMode = 0),
                  ),
                ),
                Expanded(
                  child: _TabSwitchButton(
                    label: 'Per Kategori',
                    icon: Icons.folder_outlined,
                    isSelected: _viewMode == 1,
                    onTap: () => setState(() => _viewMode = 1),
                  ),
                ),
                Expanded(
                  child: _TabSwitchButton(
                    label: 'Semua Berkas',
                    icon: Icons.list_alt_rounded,
                    isSelected: _viewMode == 2,
                    onTap: () => setState(() => _viewMode = 2),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          if (_viewMode == 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Daftar Folder Milik Setiap User',
                    style: TextStyle(
                      fontSize: 17.5,
                      fontWeight: FontWeight.w800,
                      color: _textPrimaryCol,
                    ),
                  ),
                ),
                Text(
                  '${_usersList.length} Penyuluh',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _textSecondaryCol,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._buildUserFolderList(),
          ] else if (_viewMode == 1) ...[
            Text(
              'Folder Kategori (Gabungan Seluruh User)',
              style: TextStyle(
                fontSize: 17.5,
                fontWeight: FontWeight.w800,
                color: _textPrimaryCol,
              ),
            ),
            const SizedBox(height: 12),
            ..._buildCategoryFolderList(),
          ] else ...[
            Text(
              'Seluruh Laporan & Arsip Kegiatan Semua User',
              style: TextStyle(
                fontSize: 17.5,
                fontWeight: FontWeight.w800,
                color: _textPrimaryCol,
              ),
            ),
            const SizedBox(height: 10),
            _buildFilterChips(),
            const SizedBox(height: 12),
            ..._buildArchiveCards(_allItems),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildUserFolderList() {
    final q = _searchQuery.trim().toLowerCase();
    final users = _usersList.where((u) {
      if (q.isEmpty) return true;
      final matchUser = (u['name'] ?? '').toLowerCase().contains(q) ||
          (u['nip'] ?? '').toLowerCase().contains(q) ||
          (u['wilayah'] ?? '').toLowerCase().contains(q);
      final matchDoc = _allItems.any(
        (item) =>
            item['userName'] == u['name'] &&
            (item['judul'] ?? '').toString().toLowerCase().contains(q),
      );
      return matchUser || matchDoc;
    }).toList();

    return users.map((user) {
      final userName = user['name'] ?? 'Penyuluh';
      final userDocs =
          _allItems.where((e) => e['userName'] == userName).toList();
      final countLaporan =
          userDocs.where((e) => e['tipe'] == 'Laporan').length;
      final countJadwal =
          userDocs.where((e) => e['tipe'] == 'Arsip Jadwal').length;

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _borderCol),
          boxShadow: [
            BoxShadow(
              color: AdminFolderPage.kPrimary.withValues(
                alpha: _isDark ? 0.18 : 0.04,
              ),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            setState(() {
              _openedFolder = {
                'folderType': 'user',
                'title': 'Folder $userName',
                'subtitle':
                    'NIP: ${user['nip'] ?? '-'} • Wilayah: ${user['wilayah'] ?? '-'}',
                'filterKey': userName,
              };
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _lightGreenCol,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    Icons.folder_shared_rounded,
                    color: _primaryCol,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Folder $userName',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: _textPrimaryCol,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'NIP: ${user['nip'] ?? '-'} • ${user['wilayah'] ?? '-'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: _textSecondaryCol,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _CountTag(
                            label: '$countLaporan Laporan Kegiatan',
                            bg: _lightGreenCol,
                            fg: _primaryCol,
                          ),
                          _CountTag(
                            label: '$countJadwal Arsip Jadwal',
                            bg: _softGreenCol,
                            fg: AdminFolderPage.kSecondary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: _textSecondaryCol,
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildCategoryFolderList() {
    return _categories.map((cat) {
      final docs = _allItems.where((e) => e['kategori'] == cat).toList();
      final countLaporan = docs.where((e) => e['tipe'] == 'Laporan').length;
      final countJadwal =
          docs.where((e) => e['tipe'] == 'Arsip Jadwal').length;

      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _borderCol),
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          onTap: () {
            setState(() {
              _openedFolder = {
                'folderType': 'category',
                'title': 'Folder Kategori: $cat',
                'subtitle':
                    'Menampilkan laporan & arsip kategori $cat dari seluruh user',
                'filterKey': cat,
              };
            });
          },
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _lightGreenCol,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _categoryIcon(cat),
              color: _primaryCol,
              size: 25,
            ),
          ),
          title: Text(
            'Folder $cat',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: _textPrimaryCol,
            ),
          ),
          subtitle: Text(
            '$countLaporan Laporan • $countJadwal Arsip Jadwal (Seluruh User)',
            style: TextStyle(fontSize: 12, color: _textSecondaryCol),
          ),
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: _textSecondaryCol,
          ),
        ),
      );
    }).toList();
  }

  Widget _buildOpenedUserFolderView(Map<String, dynamic> folder) {
    final isUserFolder = folder['folderType'] == 'user';
    final filterKey = (folder['filterKey'] ?? '').toString();
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPad = screenWidth >= 760 ? 28.0 : 18.0;

    final docs = _allItems.where((item) {
      return isUserFolder
          ? item['userName'] == filterKey
          : item['kategori'] == filterKey;
    }).toList();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(horizontalPad, 16, horizontalPad, 60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _softGreenCol,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _borderCol),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AdminFolderPage.kPrimary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isUserFolder
                        ? Icons.folder_shared_rounded
                        : Icons.folder_special_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (folder['title'] ?? '').toString(),
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.bold,
                          color: _textPrimaryCol,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        (folder['subtitle'] ?? '').toString(),
                        style: TextStyle(
                          fontSize: 12.5,
                          color: _textSecondaryCol,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildFilterChips(),
          const SizedBox(height: 14),
          ..._buildArchiveCards(docs),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = ['Semua', 'Laporan', 'Arsip Jadwal'];
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: filters.map((f) {
        final selected = _selectedTypeFilter == f;
        return ChoiceChip(
          label: Text(f),
          selected: selected,
          showCheckmark: false,
          selectedColor: AdminFolderPage.kPrimary,
          backgroundColor: _cardBg,
          side: BorderSide(
            color: selected ? AdminFolderPage.kPrimary : _borderCol,
          ),
          labelStyle: TextStyle(
            color: selected ? Colors.white : _textPrimaryCol,
            fontWeight: FontWeight.w600,
            fontSize: 12.5,
          ),
          onSelected: (_) => setState(() => _selectedTypeFilter = f),
        );
      }).toList(),
    );
  }

  List<Widget> _buildArchiveCards(List<Map<String, dynamic>> source) {
    final q = _searchQuery.trim().toLowerCase();

    final filtered = source.where((item) {
      if (_selectedTypeFilter != 'Semua' &&
          item['tipe'] != _selectedTypeFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return (item['judul'] ?? '').toString().toLowerCase().contains(q) ||
          (item['userName'] ?? '').toString().toLowerCase().contains(q) ||
          (item['kategori'] ?? '').toString().toLowerCase().contains(q) ||
          (item['wilayah'] ?? '').toString().toLowerCase().contains(q);
    }).toList();

    if (filtered.isEmpty) {
      return [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _borderCol),
          ),
          alignment: Alignment.center,
          child: Text(
            'Belum ada berkas laporan atau arsip pada folder ini.',
            style: TextStyle(color: _textSecondaryCol),
          ),
        ),
      ];
    }

    return filtered.map((item) {
      final isLaporan = item['tipe'] == 'Laporan';
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _borderCol),
          boxShadow: [
            BoxShadow(
              color: AdminFolderPage.kPrimary.withValues(
                alpha: _isDark ? 0.16 : 0.03,
              ),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _showAdminArchiveDetail(item),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isLaporan ? _lightGreenCol : _softGreenCol,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isLaporan
                        ? Icons.description_outlined
                        : Icons.event_available_rounded,
                    color: _primaryCol,
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
                              (item['judul'] ?? '-').toString(),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: _textPrimaryCol,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _StatusBadge(
                            status: (item['status'] ?? 'Selesai').toString(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Folder: ${item['userName']} • ${item['kategori']}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _primaryCol,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item['tipe']} • ${item['tanggal']} • ${item['wilayah']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: _textSecondaryCol,
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
    }).toList();
  }

  List<Map<String, dynamic>> _buildDefaultAllUserArchives() {
    return [
      {
        'id': 'arc_1',
        'judul': 'Laporan Penyuluhan Perhutanan Sosial KTH Makmur',
        'tipe': 'Laporan',
        'kategori': 'Penyuluhan',
        'userName': 'Rizky Pratama, S.Hut.',
        'wilayah': 'Kecamatan Garut',
        'tanggal': '20 Oktober 2026',
        'waktu': '08:00',
        'status': 'Selesai',
        'deskripsi':
            'Pendampingan penyusunan rencana kerja tahunan dan pembagian bibit produktif pada KTH Makmur.',
      },
      {
        'id': 'arc_2',
        'judul': 'Arsip Kegiatan Monitoring Lapangan Blok Utara',
        'tipe': 'Arsip Jadwal',
        'kategori': 'Monitoring & Patroli',
        'userName': 'Rizky Pratama, S.Hut.',
        'wilayah': 'Kawasan Hutan Garut',
        'tanggal': '18 Oktober 2026',
        'waktu': '13:00',
        'status': 'Selesai',
        'deskripsi':
            'Pengecekan kondisi patok batas kawasan hutan dan pemantauan titik rawan kebakaran.',
      },
      {
        'id': 'arc_3',
        'judul': 'Laporan Rehabilitasi Lahan Kritis Cisurupan',
        'tipe': 'Laporan',
        'kategori': 'Rehabilitasi Hutan',
        'userName': 'Siti Nurhaliza, S.Hut.',
        'wilayah': 'Kecamatan Cisurupan',
        'tanggal': '19 Oktober 2026',
        'waktu': '09:00',
        'status': 'Selesai',
        'deskripsi':
            'Penanaman 600 bibit pohon endemik bersama masyarakat desa sekitar hutan.',
      },
      {
        'id': 'arc_4',
        'judul': 'Arsip Jadwal Evaluasi Kelembagaan KTH Mandiri',
        'tipe': 'Arsip Jadwal',
        'kategori': 'Kelembagaan KTH',
        'userName': 'Siti Nurhaliza, S.Hut.',
        'wilayah': 'Kecamatan Cisurupan',
        'tanggal': '15 Oktober 2026',
        'waktu': '10:00',
        'status': 'Selesai',
        'deskripsi':
            'Verifikasi kelengkapan buku administrasi kelompok tani hutan.',
      },
      {
        'id': 'arc_5',
        'judul': 'Laporan Inventarisasi Keanekaragaman Hayati Cikuray',
        'tipe': 'Laporan',
        'kategori': 'Ekosistem & Konservasi',
        'userName': 'Budi Santoso, M.Si.',
        'wilayah': 'Kawasan Hutan Cikuray',
        'tanggal': '17 Oktober 2026',
        'waktu': '08:30',
        'status': 'Diproses',
        'deskripsi':
            'Pendataan flora dan fauna dilindungi pada petak konservasi lereng selatan.',
      },
      {
        'id': 'arc_6',
        'judul': 'Laporan Patroli Terpadu Pencegahan Pembalakan',
        'tipe': 'Laporan',
        'kategori': 'Monitoring & Patroli',
        'userName': 'Andi Wijaya, S.Hut.',
        'wilayah': 'Lereng Gunung Guntur',
        'tanggal': '14 Oktober 2026',
        'waktu': '07:30',
        'status': 'Selesai',
        'deskripsi':
            'Patroli gabungan bersama Polhut dan MMP, kondisi kawasan aman terkendali.',
      },
    ];
  }
}

class _PillStat extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PillStat({required this.icon, required this.label});

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

class _TabSwitchButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabSwitchButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeBg = isDark ? AdminFolderPage.kPrimary : Colors.white;
    final activeFg = isDark ? Colors.white : AdminFolderPage.kPrimary;
    final inactiveFg = isDark ? Colors.white70 : AdminFolderPage.kTextSecondary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? activeFg : inactiveFg,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? activeFg : inactiveFg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountTag extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;

  const _CountTag({
    required this.label,
    required this.bg,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (status) {
      'Selesai' => (AdminFolderPage.kLightGreen, AdminFolderPage.kPrimary),
      'Diproses' || 'Terjadwal' => (
        const Color(0xFFFFF4E5),
        const Color(0xFFB26A00),
      ),
      _ => (const Color(0xFFECEFF1), const Color(0xFF546E7A)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color textColor;
  final Color subColor;
  final Color iconColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.textColor,
    required this.subColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: iconColor),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 13, color: subColor),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }
}