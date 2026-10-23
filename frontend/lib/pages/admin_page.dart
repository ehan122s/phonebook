// ============================================================================
// [KHUSUS ADMIN - HALAMAN DASHBOARD ADMIN & MANAJEMEN PENGGUNA]
// Simpan file ini di: lib/pages/admin_page.dart
// Memanggil AdminFolderPage (admin_folder_page.dart) untuk melihat seluruh folder user
// ============================================================================

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'admin_folder_page.dart';
import 'jadwal.dart';
import 'laporan.dart';
import 'login.dart';
import 'materi.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  static const String _usersStorageKey = 'phonebook_admin_users_v1';

  /// 0 = Dashboard Admin, 1 = Pengguna, 2 = Folder Seluruh User (AdminFolderPage),
  /// 3 = Laporan, 4 = Jadwal, 5 = Materi
  int _selectedMenu = 0;

  String _adminName = 'Administrator';
  String _searchUserQuery = '';

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

  final List<Map<String, String>> _recentReports = [
    {
      'judul': 'Penyuluhan Perhutanan Sosial KTH Makmur',
      'pelapor': 'Rizky Pratama • Kec. Garut',
      'tanggal': '20 Oktober 2026',
      'status': 'Selesai',
    },
    {
      'judul': 'Monitoring Patok Batas Kawasan Hutan',
      'pelapor': 'Siti Nurhaliza • Cisurupan',
      'tanggal': '19 Oktober 2026',
      'status': 'Diproses',
    },
    {
      'judul': 'Rehabilitasi Lahan Kritis Blok Selatan',
      'pelapor': 'Budi Santoso • Cikuray',
      'tanggal': '18 Oktober 2026',
      'status': 'Selesai',
    },
    {
      'judul': 'Pendataan Produksi Madu Hutan Lestari',
      'pelapor': 'Andi Wijaya • Guntur',
      'tanggal': '16 Oktober 2026',
      'status': 'Draft',
    },
  ];

  final List<Map<String, String>> _users = [];

  @override
  void initState() {
    super.initState();
    _loadAdminAndUsers();
  }

  Future<void> _loadAdminAndUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString('name');
    final rawUsers = prefs.getString(_usersStorageKey);

    List<Map<String, String>> loadedUsers = _defaultUsers;
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

    if (!mounted) return;
    setState(() {
      if (savedName != null && savedName.trim().isNotEmpty) {
        _adminName = savedName;
      }
      _users
        ..clear()
        ..addAll(loadedUsers);
    });
  }

  Future<void> _persistUsers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usersStorageKey, jsonEncode(_users));
  }

  List<Map<String, String>> get _filteredUsers {
    if (_searchUserQuery.trim().isEmpty) return _users;
    final q = _searchUserQuery.toLowerCase();
    return _users.where((u) {
      return (u['name'] ?? '').toLowerCase().contains(q) ||
          (u['email'] ?? '').toLowerCase().contains(q) ||
          (u['nip'] ?? '').toLowerCase().contains(q) ||
          (u['wilayah'] ?? '').toLowerCase().contains(q);
    }).toList();
  }

  void _openUserFormSheet({Map<String, String>? existing}) {
    final isEditing = existing != null;

    String nip = existing?['nip'] ?? '';
    String name = existing?['name'] ?? '';
    String email = existing?['email'] ?? '';
    String whatsapp = existing?['whatsapp'] ?? '';
    String wilayah = existing?['wilayah'] ?? 'CDK Wilayah Garut';
    String role = existing?['role'] ?? 'Penyuluh';
    String status = existing?['status'] ?? 'Aktif';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            final bottomInset = MediaQuery.of(sheetCtx).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, bottomInset + 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEditing ? 'Edit Data Pengguna' : 'Tambah Pengguna Baru',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E2923),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        initialValue: name,
                        onChanged: (v) => name = v,
                        decoration: const InputDecoration(
                          labelText: 'Nama Lengkap',
                          hintText: 'Contoh: Rizky Pratama, S.Hut.',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: nip,
                              onChanged: (v) => nip = v,
                              decoration: const InputDecoration(
                                labelText: 'NIP / ID Petugas',
                                hintText: '19940812 202012 1 004',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              initialValue: whatsapp,
                              onChanged: (v) => whatsapp = v,
                              decoration: const InputDecoration(
                                labelText: 'No. WhatsApp',
                                hintText: '0812-xxxx-xxxx',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: email,
                        onChanged: (v) => email = v,
                        decoration: const InputDecoration(
                          labelText: 'Alamat Email',
                          hintText: 'nama@kehutanan.go.id',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              initialValue: wilayah,
                              onChanged: (v) => wilayah = v,
                              decoration: const InputDecoration(
                                labelText: 'Wilayah Tugas',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: status,
                              decoration: const InputDecoration(
                                labelText: 'Status',
                                border: OutlineInputBorder(),
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
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(sheetCtx),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text('Batal'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF285C2E),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
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
                              },
                              icon: const Icon(Icons.save_outlined, size: 18),
                              label: const Text('Simpan Pengguna'),
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

  void _deleteUser(Map<String, String> user) {
    setState(() {
      _users.removeWhere((u) => u['id'] == user['id']);
    });
    _persistUsers();
  }

  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width >= 760;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F5),
      drawer: isWideScreen
          ? null
          : Drawer(
              child: _buildSidebar(isDrawer: true),
            ),
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isWideScreen)
              SizedBox(
                width: 248,
                child: _buildSidebar(isDrawer: false),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTopProfileHeader(isWideScreen: isWideScreen),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFDCE4DD),
                  ),
                  Expanded(
                    child: _buildMainContent(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar({required bool isDrawer}) {
    final menuItems = [
      (icon: Icons.dashboard_outlined, label: 'Dashboard Admin'),
      (icon: Icons.people_outline_rounded, label: 'Pengguna'),
      (icon: Icons.folder_shared_outlined, label: 'Folder Seluruh User'),
      (icon: Icons.description_outlined, label: 'Laporan Kegiatan'),
      (icon: Icons.calendar_month_outlined, label: 'Jadwal Lapangan'),
      (icon: Icons.menu_book_outlined, label: 'Materi Penyuluhan'),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFE9EFEA),
        border: Border(
          right: BorderSide(color: Color(0xFFD5E0D6), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF285C2E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.forest_rounded, color: Colors.white, size: 24),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'PHONEBOOK ADMIN',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          ...List.generate(menuItems.length, (index) {
            final item = menuItems[index];
            final isSelected = _selectedMenu == index;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  setState(() => _selectedMenu = index);
                  if (isDrawer) Navigator.pop(context);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white
                        : const Color(0xFFDCE6DD).withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(10),
                    border: isSelected
                        ? Border.all(
                            color: const Color(0xFF285C2E),
                            width: 1.3,
                          )
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        item.icon,
                        size: 19,
                        color: isSelected
                            ? const Color(0xFF285C2E)
                            : const Color(0xFF4E5D52),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isSelected
                                ? const Color(0xFF285C2E)
                                : const Color(0xFF37433A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          InkWell(
            onTap: _handleLogout,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFBE9E7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.logout_rounded,
                    size: 18,
                    color: Colors.red.shade700,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Keluar Admin',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
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

  Widget _buildTopProfileHeader({required bool isWideScreen}) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      color: const Color(0xFFEEF3EE),
      child: Row(
        children: [
          if (!isWideScreen)
            Builder(
              builder: (ctx) => IconButton(
                onPressed: () => Scaffold.of(ctx).openDrawer(),
                icon: const Icon(Icons.menu_rounded),
              ),
            ),
          Text(
            _selectedMenu == 0
                ? 'Dashboard Admin'
                : _selectedMenu == 1
                    ? 'Manajemen Pengguna'
                    : _selectedMenu == 2
                        ? 'Direktori Folder Seluruh User'
                        : 'Panel Administrasi',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4A584E),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFD5E0D6)),
            ),
            child: Text(
              _adminName,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF285C2E),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const CircleAvatar(
            radius: 18,
            backgroundColor: Color(0xFF285C2E),
            child: Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    switch (_selectedMenu) {
      case 0:
        return _buildDashboardAdminView();
      case 1:
        return _buildPenggunaView();
      case 2:
        return const AdminFolderPage();
      case 3:
        return const LaporanPage();
      case 4:
        return const JadwalPage();
      case 5:
        return const MateriPage();
      default:
        return _buildDashboardAdminView();
    }
  }

  Widget _buildDashboardAdminView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selamat Datang, $_adminName',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E2923),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Ringkasan sistem informasi pelaporan dan arsip folder seluruh penyuluh kehutanan.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF6E7A72),
            ),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 640;
              final cardWidth = isDesktop
                  ? (constraints.maxWidth - 32) / 3
                  : constraints.maxWidth;

              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _AdminSummaryCard(
                      title: 'Total Pengguna',
                      value: '${_users.length}',
                      subtitle: 'Penyuluh & Koordinator terdaftar',
                      icon: Icons.people_alt_outlined,
                      accentColor: const Color(0xFF285C2E),
                      onTap: () => setState(() => _selectedMenu = 1),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _AdminSummaryCard(
                      title: 'Folder Seluruh User',
                      value: '${_users.length} Folder',
                      subtitle: 'Buka seluruh laporan & arsip user',
                      icon: Icons.folder_shared_outlined,
                      accentColor: const Color(0xFF1565C0),
                      onTap: () => setState(() => _selectedMenu = 2),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _AdminSummaryCard(
                      title: 'Jadwal Kegiatan',
                      value: '6',
                      subtitle: 'Agenda aktif & riwayat jadwal',
                      icon: Icons.calendar_month_outlined,
                      accentColor: const Color(0xFFE65100),
                      onTap: () => setState(() => _selectedMenu = 4),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _AdminSummaryCard(
                      title: 'Materi Penyuluhan',
                      value: '4',
                      subtitle: 'Dokumen & modul siap unduh',
                      icon: Icons.menu_book_outlined,
                      accentColor: const Color(0xFF6A1B9A),
                      onTap: () => setState(() => _selectedMenu = 5),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Riwayat Laporan Terbaru',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E2923),
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _selectedMenu = 2),
                icon: const Icon(Icons.folder_open_rounded, size: 18),
                label: const Text('Buka Seluruh Folder User'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF285C2E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEAEFEA),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFD5E0D6)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCE5DD),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Judul Laporan',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF1E2923),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Penyuluh / Lokasi',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF1E2923),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Tanggal',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF1E2923),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          'Status',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF1E2923),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                ..._recentReports.map((lap) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            lap['judul'] ?? '-',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E2923),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            lap['pelapor'] ?? '-',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF5A655E),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            lap['tanggal'] ?? '-',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF5A655E),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: _StatusChip(status: lap['status'] ?? 'Draft'),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPenggunaView() {
    final users = _filteredUsers;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Data Pengguna',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E2923),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (val) => setState(() => _searchUserQuery = val),
                  decoration: InputDecoration(
                    hintText:
                        'Cari nama penyuluh, NIP, email, atau wilayah tugas...',
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
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
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFD5E0D6)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFD5E0D6)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => _openUserFormSheet(),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text(
                  'Tambah Pengguna',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF285C2E),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEAEFEA),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFD5E0D6)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 850),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCE5DD),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          SizedBox(
                            width: 40,
                            child: Text(
                              'No',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 150,
                            child: Text(
                              'NIP / ID',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 170,
                            child: Text(
                              'Nama Pengguna',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 175,
                            child: Text(
                              'Email',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 120,
                            child: Text(
                              'WhatsApp',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 145,
                            child: Text(
                              'Wilayah Tugas',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            child: Text(
                              'Status',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 120,
                            child: Text(
                              'Aksi / Folder',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 40,
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 150,
                              child: Text(
                                u['nip'] ?? '-',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF4A584E),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 170,
                              child: Text(
                                u['name'] ?? '-',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E2923),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 175,
                              child: Text(
                                u['email'] ?? '-',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF4A584E),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 120,
                              child: Text(
                                u['whatsapp'] ?? '-',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF4A584E),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 145,
                              child: Text(
                                u['wilayah'] ?? '-',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF4A584E),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 80,
                              child: _StatusChip(
                                status: u['status'] ?? 'Aktif',
                              ),
                            ),
                            SizedBox(
                              width: 120,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    tooltip: 'Buka Folder User Ini',
                                    onPressed: () =>
                                        setState(() => _selectedMenu = 2),
                                    icon: const Icon(
                                      Icons.folder_shared_outlined,
                                      size: 19,
                                      color: Color(0xFF285C2E),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Edit Pengguna',
                                    onPressed: () =>
                                        _openUserFormSheet(existing: u),
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 18,
                                      color: Color(0xFF1565C0),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Hapus Pengguna',
                                    onPressed: () => _deleteUser(u),
                                    icon: Icon(
                                      Icons.delete_outline_rounded,
                                      size: 18,
                                      color: Colors.red.shade700,
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminSummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  const _AdminSummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFDCE4DD)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accentColor, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF5A655E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E2923),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF7A877E),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
        const Color(0xFFE8F5E9),
        const Color(0xFF2E7D32),
      ),
      'Diproses' => (
        const Color(0xFFFFF4E5),
        const Color(0xFFE65100),
      ),
      _ => (
        const Color(0xFFECEFF1),
        const Color(0xFF546E7A),
      ),
    };

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
      ),
    );
  }
}