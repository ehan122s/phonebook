// ============================================================================
// [KHUSUS ADMIN - HALAMAN FOLDER SELURUH USER]
// Simpan file ini di: lib/pages/admin_folder_page.dart
// Hanya untuk Admin: Melihat SELURUH FOLDER USER, laporan, & arsip kegiatan
// ============================================================================

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminFolderPage extends StatefulWidget {
  const AdminFolderPage({super.key});

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

  void _showAdminArchiveDetail(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
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
                      color: isLaporan
                          ? const Color(0xFFE8F5E9)
                          : const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      isLaporan
                          ? Icons.description_outlined
                          : Icons.event_available_rounded,
                      color: isLaporan
                          ? const Color(0xFF285C2E)
                          : const Color(0xFF1565C0),
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
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E2923),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item['tipe']} • Kategori ${item['kategori']}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF5A655E),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusBadge(status: (item['status'] ?? 'Selesai').toString()),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 14),
              _DetailRow(
                icon: Icons.folder_shared_outlined,
                label: 'Folder Milik User',
                value: (item['userName'] ?? '-').toString(),
              ),
              const SizedBox(height: 8),
              _DetailRow(
                icon: Icons.location_on_outlined,
                label: 'Wilayah / Lokasi',
                value: (item['wilayah'] ?? '-').toString(),
              ),
              const SizedBox(height: 8),
              _DetailRow(
                icon: Icons.calendar_today_outlined,
                label: 'Tanggal & Waktu',
                value: '${item['tanggal']} • ${item['waktu'] ?? '08:00'} WIB',
              ),
              const SizedBox(height: 14),
              const Text(
                'Ringkasan Laporan / Arsip:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6E7A72),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                (item['deskripsi'] ?? '-').toString(),
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: Color(0xFF1E2923),
                ),
              ),
              const SizedBox(height: 22),
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
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: Colors.red,
                    ),
                    label: const Text(
                      'Hapus Berkas',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (item['status'] != 'Selesai')
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF285C2E),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          Navigator.pop(sheetCtx);
                          setState(() {
                            final idx = _allItems
                                .indexWhere((e) => e['id'] == item['id']);
                            if (idx >= 0) {
                              _allItems[idx]['status'] = 'Selesai';
                            }
                          });
                          _persistArchives();
                        },
                        icon: const Icon(Icons.verified_outlined, size: 18),
                        label: const Text('Verifikasi Selesai'),
                      ),
                    )
                  else
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF285C2E),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(sheetCtx),
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Tutup'),
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
      backgroundColor: const Color(0xFFF6F8F5),
      appBar: _openedFolder != null
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                onPressed: () => setState(() => _openedFolder = null),
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: Color(0xFF285C2E),
                ),
              ),
              title: Text(
                (_openedFolder!['title'] ?? 'Folder User').toString(),
                style: const TextStyle(
                  color: Color(0xFF1E2923),
                  fontSize: 19,
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

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Direktori Seluruh Folder User
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF285C2E), Color(0xFF3E7B46)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.folder_shared_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Direktori Folder Seluruh User (Admin)',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Pantau dan periksa seluruh folder laporan serta arsip jadwal kegiatan milik setiap penyuluh.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 13,
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
            decoration: InputDecoration(
              hintText:
                  'Cari nama folder user, NIP, wilayah, atau judul laporan...',
              hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Color(0xFF285C2E),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFDCE4DD)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFDCE4DD)),
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Switcher Tampilan Admin
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFE4ECE4),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _TabSwitchButton(
                    label: 'Folder Seluruh User',
                    icon: Icons.folder_shared_outlined,
                    isSelected: _viewMode == 0,
                    onTap: () => setState(() => _viewMode = 0),
                  ),
                ),
                Expanded(
                  child: _TabSwitchButton(
                    label: 'Folder per Kategori',
                    icon: Icons.folder_outlined,
                    isSelected: _viewMode == 1,
                    onTap: () => setState(() => _viewMode = 1),
                  ),
                ),
                Expanded(
                  child: _TabSwitchButton(
                    label: 'Semua Berkas User',
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
                const Text(
                  'Daftar Folder Milik Setiap User',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E2923),
                  ),
                ),
                Text(
                  '${_usersList.length} Penyuluh',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6E7A72),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._buildUserFolderList(),
          ] else if (_viewMode == 1) ...[
            const Text(
              'Folder Kategori (Gabungan Seluruh User)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E2923),
              ),
            ),
            const SizedBox(height: 12),
            ..._buildCategoryFolderList(),
          ] else ...[
            const Text(
              'Seluruh Laporan & Arsip Kegiatan Semua User',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E2923),
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFDCE4DD)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
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
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.folder_shared_rounded,
                    color: Color(0xFF285C2E),
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Folder $userName',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E2923),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'NIP: ${user['nip'] ?? '-'} • ${user['wilayah'] ?? '-'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6E7A72),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _CountTag(
                            label: '$countLaporan Laporan Kegiatan',
                            bg: const Color(0xFFE8F5E9),
                            fg: const Color(0xFF285C2E),
                          ),
                          _CountTag(
                            label: '$countJadwal Arsip Jadwal',
                            bg: const Color(0xFFE3F2FD),
                            fg: const Color(0xFF1565C0),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF6E7A72),
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2EAE3)),
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.folder_rounded,
              color: Color(0xFFF57C00),
              size: 26,
            ),
          ),
          title: Text(
            'Folder $cat',
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E2923),
            ),
          ),
          subtitle: Text(
            '$countLaporan Laporan • $countJadwal Arsip Jadwal (Seluruh User)',
            style: const TextStyle(fontSize: 12, color: Color(0xFF6E7A72)),
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
      );
    }).toList();
  }

  Widget _buildOpenedUserFolderView(Map<String, dynamic> folder) {
    final isUserFolder = folder['folderType'] == 'user';
    final filterKey = (folder['filterKey'] ?? '').toString();

    final docs = _allItems.where((item) {
      return isUserFolder
          ? item['userName'] == filterKey
          : item['kategori'] == filterKey;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFE6F2E7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFB7D7B9)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF285C2E),
                    borderRadius: BorderRadius.circular(13),
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
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E2923),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        (folder['subtitle'] ?? '').toString(),
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF4A584E),
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
      children: filters.map((f) {
        final selected = _selectedTypeFilter == f;
        return ChoiceChip(
          label: Text(f),
          selected: selected,
          selectedColor: const Color(0xFF285C2E),
          labelStyle: TextStyle(
            color: selected ? Colors.white : const Color(0xFF1E2923),
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: const Text(
            'Belum ada berkas laporan atau arsip pada folder ini.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ];
    }

    return filtered.map((item) {
      final isLaporan = item['tipe'] == 'Laporan';
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2EAE3)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
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
                    color: isLaporan
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    isLaporan
                        ? Icons.description_outlined
                        : Icons.event_available_rounded,
                    color: isLaporan
                        ? const Color(0xFF285C2E)
                        : const Color(0xFF1565C0),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              (item['judul'] ?? '-').toString(),
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E2923),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _StatusBadge(
                            status: (item['status'] ?? 'Selesai').toString(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '📁 Folder User: ${item['userName']} • Kategori: ${item['kategori']}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF285C2E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item['tipe']} • ${item['tanggal']} • ${item['wilayah']}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6E7A72),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? const Color(0xFF285C2E)
                  : const Color(0xFF5A655E),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? const Color(0xFF285C2E)
                      : const Color(0xFF5A655E),
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
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
      'Selesai' => (const Color(0xFFE8F5E9), const Color(0xFF2E7D32)),
      'Diproses' || 'Terjadwal' => (
        const Color(0xFFFFF4E5),
        const Color(0xFFE65100),
      ),
      _ => (const Color(0xFFECEFF1), const Color(0xFF546E7A)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
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

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: const Color(0xFF285C2E)),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 13, color: Color(0xFF6E7A72)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E2923),
            ),
          ),
        ),
      ],
    );
  }
}