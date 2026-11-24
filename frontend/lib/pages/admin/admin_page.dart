// ============================================================================
// [KHUSUS ADMIN - HALAMAN UTAMA PANEL ADMINISTRATOR]
// Lokasi: frontend/lib/pages/admin/admin_page.dart
//
// File ini hanya bertugas mengatur state utama, sinkronisasi data,
// dan navigasi antar modul admin yang telah dipisahkan secara modular.
// ============================================================================

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/app_update_service.dart';
import '../laporan/laporan.dart';
import '../login/login.dart';
import '../materi/materi.dart';
import 'admin_folder_page.dart';
import 'admin_theme.dart';
import 'sections/admin_dashboard_section.dart';
import 'sections/admin_monitoring_section.dart';
import 'sections/admin_users_section.dart';
import 'services/admin_service.dart';
import 'widgets/admin_navigation.dart';
import 'widgets/user_form_sheet.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  // Backward-compatible color constants (tetap dipertahankan jika diacu file lain)
  static const Color kPrimary = AdminTheme.kPrimary;
  static const Color kSecondary = AdminTheme.kSecondary;
  static const Color kLightGreen = AdminTheme.kLightGreen;
  static const Color kSoftGreen = AdminTheme.kSoftGreen;
  static const Color kBackground = AdminTheme.kBackground;
  static const Color kWhite = AdminTheme.kWhite;
  static const Color kTextPrimary = AdminTheme.kTextPrimary;
  static const Color kTextSecondary = AdminTheme.kTextSecondary;
  static const Color kBorder = AdminTheme.kBorder;

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
  /// 4 = Monitoring Aktivitas Pengguna
  /// 5 = Materi Penyuluhan (MateriPage)
  int _selectedMenu = 0;

  String _adminName = 'Administrator';
  String _adminEmail = 'admin@kehutanan.go.id';
  String _searchUserQuery = '';
  String _userFilterStatus = 'Semua';
  String _reportFilterStatus = 'Semua';
  bool _isSyncingUsers = false;

  Map<String, dynamic> _monitoringSummary = const {};
  List<dynamic> _monitoringReports = [];
  List<dynamic> _monitoringPeriodStats = [];
  List<dynamic> _lastActiveUsers = [];
  String _monitoringStatusFilter = 'Semua';
  DateTime? _monitoringDateFrom;
  DateTime? _monitoringDateTo;
  bool _isLoadingMonitoring = false;

  int _totalJadwalCount = 0;
  int _totalMateriCount = 0;

  final List<Map<String, String>> _users = [];
  final List<Map<String, String>> _recentReports = [];

  static bool _isDummyUser(String email, String id) {
    final lower = email.toLowerCase().trim();
    final lowerId = id.toLowerCase().trim();
    return lower == 'rizky@kehutanan.go.id' ||
        lower == 'siti.nur@kehutanan.go.id' ||
        lower == 'budi.santoso@kehutanan.go.id' ||
        lower == 'andi.wijaya@kehutanan.go.id' ||
        lower == 'ehan@gmail.com' ||
        lower == 'petugas@kehutanan.go.id' ||
        lower == 'atmin@gmail.com' ||
        lower == 'r4yy73@gmailcom' ||
        lower == 'test@example.com' ||
        lowerId == 'usr-001' ||
        lowerId == 'usr-002' ||
        lowerId == 'usr-003' ||
        lowerId == 'usr-004' ||
        lowerId == 'rep_1' ||
        lowerId == 'rep_2' ||
        lowerId == 'rep_3' ||
        lowerId == 'rep_4';
  }

  @override
  void initState() {
    super.initState();
    _loadAdminAndLocalCache();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AppUpdateService.instance.checkAndShowUpdateDialog(context);
      }
    });
  }

  Future<void> _loadAdminAndLocalCache() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString('profil_nama') ?? prefs.getString('name');
    final savedEmail = prefs.getString('email');
    final rawUsers = prefs.getString(_usersStorageKey);

    List<Map<String, String>> loadedUsers = [];
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
            .where((u) => !_isDummyUser(u['email'] ?? '', u['id'] ?? ''))
            .toList();
      } catch (_) {}
    }

    final List<Map<String, String>> loadedReports = [];
    final rawLaporan = prefs.getString(_laporanDraftKey);
    if (rawLaporan != null && rawLaporan.isNotEmpty) {
      try {
        final List<dynamic> decodedLaporan = jsonDecode(rawLaporan);
        final userName = savedName ?? 'Pengguna';
        for (final item in decodedLaporan.reversed) {
          final map = Map<String, dynamic>.from(item);
          final id = 'local_${map['id'] ?? map['judul']}';
          if (!loadedReports.any((r) => r['id'] == id)) {
            loadedReports.insert(0, {
              'id': id,
              'judul': (map['judul'] ?? 'Laporan Kegiatan').toString(),
              'pelapor': (map['pelapor'] ?? map['userName'] ?? userName)
                  .toString(),
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

    int jadwalCount = 0;
    final rawJadwal = prefs.getString(_jadwalStorageKey);
    if (rawJadwal != null && rawJadwal.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(rawJadwal);
        jadwalCount = list.where((j) {
          final jid = (j is Map ? (j['id'] ?? '') : '')
              .toString()
              .trim()
              .toLowerCase();
          return !{
            'jadwal_1',
            'jadwal_2',
            'jadwal_3',
            'jadwal_4',
            'jadwal_5',
            'jadwal_6',
          }.contains(jid);
        }).length;
      } catch (_) {}
    }

    int materiCount = 0;
    final rawMateri = prefs.getString(_materiStorageKey);
    if (rawMateri != null && rawMateri.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(rawMateri);
        materiCount = list.where((m) {
          final mid = (m is Map ? (m['id'] ?? '') : '')
              .toString()
              .trim()
              .toUpperCase();
          return !{
            'MAT-001',
            'MAT-002',
            'MAT-003',
            'MAT-004',
            'MAT-005',
          }.contains(mid);
        }).length;
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

    await _fetchUsersFromBackend();
  }

  Future<void> _persistUsers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usersStorageKey, jsonEncode(_users));
  }

  Future<void> _fetchUsersFromBackend({bool showFeedback = false}) async {
    if (mounted) setState(() => _isSyncingUsers = true);
    final result = await AdminService.fetchUsers();
    if (result.success && result.data != null && mounted) {
      setState(() {
        _users
          ..clear()
          ..addAll(result.data!);
      });
      await _persistUsers();
    }
    await _fetchMonitoringData();
    if (mounted) {
      setState(() => _isSyncingUsers = false);
      if (showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.success
                  ? 'Data panel admin berhasil diperbarui dari database.'
                  : result.message,
            ),
          ),
        );
      }
    }
  }

  Future<void> _fetchMonitoringData() async {
    if (mounted) setState(() => _isLoadingMonitoring = true);
    final result = await AdminService.fetchMonitoring(
      dateFrom: _monitoringDateFrom,
      dateTo: _monitoringDateTo,
      status: _monitoringStatusFilter,
    );
    if (result.success && result.data != null && mounted) {
      final data = result.data!;
      setState(() {
        _monitoringSummary = data['summary'] is Map
            ? Map<String, dynamic>.from(data['summary'])
            : const {};
        _monitoringReports = data['recent_reports'] is List
            ? data['recent_reports']
            : [];
        _monitoringPeriodStats = data['stats_by_period'] is List
            ? data['stats_by_period']
            : [];
        _lastActiveUsers = data['last_active_users'] is List
            ? data['last_active_users']
            : [];
      });
    }
    if (mounted) setState(() => _isLoadingMonitoring = false);
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

  void _openUserForm({Map<String, String>? existing}) {
    final isEditing = existing != null;
    showUserFormSheet(
      context,
      existing: existing,
      onSubmit: (userData, {password, passwordConfirmation}) async {
        final result = await AdminService.saveUser(
          userData,
          isEditing: isEditing,
          password: password,
          passwordConfirmation: passwordConfirmation,
        );
        if (result.success && result.data != null && mounted) {
          final serverUser = result.data!;
          setState(() {
            if (isEditing) {
              final idx = _users.indexWhere(
                (u) =>
                    u['id'] == existing['id'] ||
                    u['email'] == existing['email'],
              );
              if (idx >= 0) _users[idx] = serverUser;
            } else {
              _users.insert(0, serverUser);
            }
          });
          await _persistUsers();
          await _fetchMonitoringData();
        }
        return result;
      },
    );
  }

  Future<void> _confirmDeleteUser(Map<String, String> user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Hapus Data Pengguna',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus akun "${user['name'] ?? '-'}" dari daftar pengguna?\n\n'
          'Catatan: Jika akun memiliki relasi laporan/jadwal/materi, status akun akan diubah menjadi Nonaktif agar data tetap aman.',
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
      ),
    );

    if (confirmed != true) return;

    final identifier = user['id'] ?? user['email'] ?? '';
    if (identifier.isEmpty) return;

    final result = await AdminService.deleteUser(identifier);
    if (!mounted) return;

    if (result.success) {
      setState(() {
        if (result.deactivated) {
          final idx = _users.indexWhere((u) => u['id'] == user['id']);
          if (idx >= 0) _users[idx]['status'] = 'Nonaktif';
        } else {
          _users.removeWhere(
            (u) => u['id'] == user['id'] || u['email'] == user['email'],
          );
        }
      });
      await _persistUsers();
      await _fetchMonitoringData();
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> _updateReportStatus(Map<String, dynamic> report) async {
    const statuses = ['draft', 'terkirim', 'diperiksa', 'disetujui', 'ditolak'];
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Verifikasi Status Laporan'),
        children: statuses
            .map(
              (status) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, status),
                child: Text(status[0].toUpperCase() + status.substring(1)),
              ),
            )
            .toList(),
      ),
    );
    if (selected == null) return;

    final ok = await AdminService.updateReportStatus(report['id'], selected);
    if (ok && mounted) {
      await _fetchMonitoringData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status laporan diubah menjadi $selected.')),
      );
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
    await AdminService.logout();
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
    4 => 'Monitoring Aktivitas Pengguna',
    5 => 'Materi Penyuluhan',
    _ => 'Panel Admin',
  };

  Widget _buildMainContent({required bool isWideScreen}) {
    return switch (_selectedMenu) {
      0 => AdminDashboardSection(
        isWideScreen: isWideScreen,
        adminName: _adminName,
        adminEmail: _adminEmail,
        isSyncingUsers: _isSyncingUsers,
        users: _users,
        recentReports: _recentReports,
        filteredRecentReports: _filteredRecentReports,
        reportFilterStatus: _reportFilterStatus,
        totalJadwalCount: _totalJadwalCount,
        totalMateriCount: _totalMateriCount,
        onSelectMenu: (i) => setState(() => _selectedMenu = i),
        onRefresh: () => _fetchUsersFromBackend(showFeedback: true),
        onLogout: _handleLogout,
        onReportFilterChanged: (f) => setState(() => _reportFilterStatus = f),
        onVerifyReport: (lap) {
          setState(() => lap['status'] = 'Selesai');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Laporan "${lap['judul']}" diverifikasi Selesai.'),
            ),
          );
        },
      ),
      1 => AdminUsersSection(
        isWideScreen: isWideScreen,
        allUsers: _users,
        filteredUsers: _filteredUsers,
        searchQuery: _searchUserQuery,
        filterStatus: _userFilterStatus,
        onSearchChanged: (q) => setState(() => _searchUserQuery = q),
        onFilterChanged: (f) => setState(() => _userFilterStatus = f),
        onAddUser: () => _openUserForm(),
        onEditUser: (u) => _openUserForm(existing: u),
        onDeleteUser: _confirmDeleteUser,
        onOpenFolder: () => setState(() => _selectedMenu = 2),
      ),
      2 => const AdminFolderPage(),
      3 => const LaporanPage(isAdminMode: true),
      4 => AdminMonitoringSection(
        isWideScreen: isWideScreen,
        isLoading: _isLoadingMonitoring,
        summary: _monitoringSummary,
        reports: _monitoringReports,
        periodStats: _monitoringPeriodStats,
        lastActiveUsers: _lastActiveUsers,
        statusFilter: _monitoringStatusFilter,
        dateFrom: _monitoringDateFrom,
        dateTo: _monitoringDateTo,
        onRefresh: _fetchMonitoringData,
        onDateFromChanged: (d) {
          setState(() => _monitoringDateFrom = d);
          _fetchMonitoringData();
        },
        onDateToChanged: (d) {
          setState(() => _monitoringDateTo = d);
          _fetchMonitoringData();
        },
        onStatusFilterChanged: (s) {
          setState(() => _monitoringStatusFilter = s);
          _fetchMonitoringData();
        },
        onUpdateReportStatus: _updateReportStatus,
      ),
      5 => const MateriPage(hasBottomNav: false),
      _ => const SizedBox.shrink(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = AdminTheme.of(context);
    final isWideScreen = MediaQuery.of(context).size.width >= 840;

    return Scaffold(
      backgroundColor: t.bgColor,
      drawer: isWideScreen
          ? null
          : Drawer(
              backgroundColor: t.surfaceBg,
              child: SafeArea(
                child: AdminSidebar(
                  selectedMenu: _selectedMenu,
                  usersCount: _users.length,
                  isDrawer: true,
                  onSelectMenu: (i) => setState(() => _selectedMenu = i),
                  onLogout: _handleLogout,
                ),
              ),
            ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isWideScreen)
            SizedBox(
              width: 262,
              child: SafeArea(
                right: false,
                child: AdminSidebar(
                  selectedMenu: _selectedMenu,
                  usersCount: _users.length,
                  isDrawer: false,
                  onSelectMenu: (i) => setState(() => _selectedMenu = i),
                  onLogout: _handleLogout,
                ),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isWideScreen || _selectedMenu != 0)
                  AdminTopProfileHeader(
                    isWideScreen: isWideScreen,
                    selectedMenu: _selectedMenu,
                    title: _currentMenuTitle,
                    adminName: _adminName,
                    isSyncing: _isSyncingUsers,
                    onBackHome: () => setState(() => _selectedMenu = 0),
                    onRefresh: () => _fetchUsersFromBackend(showFeedback: true),
                  ),
                Expanded(child: _buildMainContent(isWideScreen: isWideScreen)),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isWideScreen
          ? null
          : SizedBox(
              height: 74 + MediaQuery.paddingOf(context).bottom,
              child: AdminMobileBottomNav(
                selectedMenu: _selectedMenu,
                onSelectMenu: (i) => setState(() => _selectedMenu = i),
              ),
            ),
    );
  }
}
