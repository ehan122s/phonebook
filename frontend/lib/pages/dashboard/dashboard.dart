// ============================================================================
// [KHUSUS USER - DASHBOARD USER DENGAN LOKASI GPS REAL-TIME & DATA ASLI]
// Simpan file ini di: lib/pages/dashboard/dashboard.dart
// ============================================================================

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/jadwal_constants.dart';
import '../../services/jadwal_service.dart';
import '../../services/laporan_service.dart';
import '../../services/location_service.dart';
import '../../services/notification_service.dart';
import '../../services/offline_database.dart';
import '../../widgets/location_dashboard_widget.dart';
import '../ai/ai_agent_page.dart';
import '../jadwal/jadwal.dart';
import '../laporan/laporan.dart';
import '../notifikasi/notifikasi_page.dart';
import 'kategori.dart';

class DashboardPage extends StatefulWidget {
  final Function(int)? onNavigate;

  const DashboardPage({super.key, this.onNavigate});

  /// Bersihkan seluruh cache in-memory dashboard saat logout atau ganti akun
  static void clearStaticCache() {
    _DashboardPageState.clearStaticCache();
  }

  // Palet Warna Modern Soft Green Forest
  static const Color kPrimary = Color(0xFF245C3A);
  static const Color kSecondary = Color(0xFF4F8A5B);
  static const Color kLightGreen = Color(0xFFE8F2E8);
  static const Color kSoftGreen = Color(0xFFF2F7F0);
  static const Color kBackground = Color(0xFFF7F9F6);
  static const Color kWhite = Color(0xFFFFFFFF);
  static const Color kTextPrimary = Color(0xFF24352A);
  static const Color kTextSecondary = Color(0xFF758278);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  static List<Map<String, dynamic>>? _staticReports;
  static List<Map<String, dynamic>>? _staticSchedules;
  static String? _staticUserName;
  static String? _staticUserId;

  static void clearStaticCache() {
    _staticReports = null;
    _staticSchedules = null;
    _staticUserName = null;
    _staticUserId = null;
  }

  bool _isLoadingData = true;
  String? _loadError;
  String _userName = '';
  List<Map<String, dynamic>> _reports = [];
  List<Map<String, dynamic>> _schedules = [];

  @override
  void initState() {
    super.initState();
    // Gunakan in-memory cache jika ada sehingga navigasi tab ke Dashboard instan (0ms)
    if (_staticReports != null && _staticSchedules != null) {
      _reports = List.from(_staticReports!);
      _schedules = List.from(_staticSchedules!);
      _userName = _staticUserName ?? '';
      _isLoadingData = false;
    }
    // Inisialisasi tunggal LocationService (digunakan bersama oleh Header & Widget Lokasi)
    LocationService.instance.ensureInitialized();
    _loadDashboardData(silent: _reports.isNotEmpty || _schedules.isNotEmpty);
  }

  Future<void> _loadDashboardData({bool silent = false}) async {
    final hasExistingData = _reports.isNotEmpty || _schedules.isNotEmpty;
    if (!hasExistingData && !silent && mounted) {
      setState(() {
        _isLoadingData = true;
        _loadError = null;
      });
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final savedName =
          (prefs.getString('profil_nama') ?? prefs.getString('name') ?? '')
              .trim();
      final currentUserId = (prefs.getString('user_id') ?? '').trim();
      final currentUserEmail = (prefs.getString('email') ?? '')
          .trim()
          .toLowerCase();

      // Reset cache jika akun pengguna yang login berbeda dari sesi sebelumnya
      if (currentUserId.isNotEmpty &&
          _staticUserId != null &&
          _staticUserId != currentUserId) {
        clearStaticCache();
        _reports = [];
        _schedules = [];
      }

      // FAST PATH 1: Muat jadwal dari cache lokal secara instan (<5ms) khusus akun ini
      final rawLocalSchedules = await JadwalService.getLocalCachedSchedules();
      final localSchedules = rawLocalSchedules.where((s) {
        final sUid = (s['user_id'] ?? s['userId'] ?? '').toString().trim();
        if (currentUserId.isNotEmpty && sUid.isNotEmpty && sUid != currentUserId) {
          return false;
        }
        return true;
      }).toList();

      // FAST PATH 2: Muat laporan asli dari SQLite lokal & drafts
      final List<Map<String, dynamic>> localCombinedReports = [];
      final Set<String> seenReportKeys = {};

      void addReportItemToList(
        Map<String, dynamic> raw,
        List<Map<String, dynamic>> targetList,
      ) {
        final title = (raw['title'] ?? raw['judul'] ?? '').toString().trim();
        if (title.isEmpty) return;

        final idStr = (raw['server_id'] ?? raw['id'] ?? title)
            .toString()
            .trim();
        final dateStr =
            (raw['report_date'] ??
                    raw['date'] ??
                    raw['activity_date'] ??
                    raw['tanggal'] ??
                    raw['created_at'] ??
                    '')
                .toString()
                .trim();
        final dedupKey = '${idStr.toLowerCase()}|${title.toLowerCase()}';
        if (seenReportKeys.contains(dedupKey)) return;

        // Filter laporan agar sesuai dengan akun pengguna yang sedang login
        final reportUserId = (raw['user_id'] ?? '').toString().trim();
        final reportUserEmail =
            (raw['user'] is Map
                    ? (raw['user']['email'] ?? '')
                    : (raw['email'] ?? ''))
                .toString()
                .trim()
                .toLowerCase();
        if (currentUserId.isNotEmpty &&
            reportUserId.isNotEmpty &&
            reportUserId != currentUserId) {
          return;
        }
        if (currentUserEmail.isNotEmpty &&
            reportUserEmail.isNotEmpty &&
            reportUserEmail != currentUserEmail) {
          return;
        }

        seenReportKeys.add(dedupKey);
        targetList.add({
          'id': idStr,
          'judul': title,
          'kategori':
              (raw['category_name'] ??
                      (raw['category'] is Map
                          ? raw['category']['name']
                          : null) ??
                      raw['jenis'] ??
                      'Penyuluhan')
                  .toString(),
          'lokasi': (raw['location'] ?? raw['lokasi'] ?? '-').toString(),
          'tanggal': _formatDisplayDate(dateStr),
          'status': _normalizeStatus((raw['status'] ?? 'Terkirim').toString()),
          'deskripsi': (raw['description'] ?? raw['isi'] ?? '')
              .toString()
              .trim(),
        });
      }

      try {
        final localReports =
            await OfflineDatabase.instance.getAllLocalReports();
        for (final item in localReports) {
          addReportItemToList(item, localCombinedReports);
        }
      } catch (_) {}

      final rawDrafts = prefs.getString('phonebook_laporan_drafts_v1');
      if (rawDrafts != null && rawDrafts.isNotEmpty) {
        try {
          final List<dynamic> draftList = jsonDecode(rawDrafts);
          for (final d in draftList) {
            if (d is Map) {
              addReportItemToList(
                Map<String, dynamic>.from(d),
                localCombinedReports,
              );
            }
          }
        } catch (_) {}
      }

      // Check if LaporanService already has cached reports in memory
      final cachedApiReports = LaporanService.getCachedReports();
      if (cachedApiReports != null) {
        for (final item in cachedApiReports) {
          addReportItemToList(item, localCombinedReports);
        }
      }

      // RENDER FAST CACHE: Tampilkan data lokal/cache SEGERA tanpa menunggu request jaringan!
      if (mounted &&
          (localCombinedReports.isNotEmpty ||
              localSchedules.isNotEmpty ||
              _reports.isEmpty)) {
        setState(() {
          _userName = savedName;
          if (localCombinedReports.isNotEmpty) {
            _reports = List.from(localCombinedReports);
          }
          if (localSchedules.isNotEmpty) {
            _schedules = List.from(localSchedules);
          }
          _isLoadingData = false;
        });
      }

      // BACKGROUND SYNC PARALLEL: Ambil data terbaru dari server secara paralel (tidak serial)
      final results = await Future.wait([
        JadwalService.loadSchedules(),
        LaporanService.fetchReports(token),
      ]);

      final rawLoadedSchedules = results[0];
      final loadedSchedules = rawLoadedSchedules.where((s) {
        final sUid = (s['user_id'] ?? s['userId'] ?? '').toString().trim();
        if (currentUserId.isNotEmpty && sUid.isNotEmpty && sUid != currentUserId) {
          return false;
        }
        return true;
      }).toList();
      final apiReports = results[1];

      for (final item in apiReports) {
        addReportItemToList(item, localCombinedReports);
      }

      if (!mounted) return;
      setState(() {
        _userName = savedName;
        _reports = localCombinedReports;
        _schedules = loadedSchedules;
        _isLoadingData = false;
        _staticReports = localCombinedReports;
        _staticSchedules = loadedSchedules;
        _staticUserName = savedName;
        _staticUserId = currentUserId;
      });
    } catch (e) {
      if (!mounted) return;
      if (_reports.isEmpty && _schedules.isEmpty) {
        setState(() {
          _isLoadingData = false;
          _loadError = 'Gagal memuat ringkasan data: $e';
        });
      } else {
        setState(() {
          _isLoadingData = false;
        });
      }
    }
  }

  String _normalizeStatus(String raw) {
    final lower = raw.toLowerCase().trim();
    if (lower == 'draft') return 'Draft';
    if (lower == 'pending' || lower == 'menunggu') return 'Menunggu';
    if (lower == 'submitted' || lower == 'terkirim' || lower == 'selesai') {
      return 'Selesai';
    }
    return raw.isEmpty ? 'Tercatat' : raw;
  }

  String _formatDisplayDate(String raw) {
    if (raw.isEmpty) return 'Baru saja';
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) {
      return JadwalDateUtils.formatTanggal(parsed.toLocal());
    }
    return raw;
  }

  void _openUserFolders(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const KategoriPage()))
        .then((_) => _loadDashboardData());
  }

  void _openNotificationPage(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const NotificationPage()))
        .then((_) => _loadDashboardData());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? const Color(0xFF121A15)
        : DashboardPage.kBackground;
    final textColor = isDark
        ? DashboardPage.kWhite
        : DashboardPage.kTextPrimary;

    return Container(
      color: bgColor,
      child: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: DashboardPage.kPrimary,
          onRefresh: () async {
            await Future.wait([
              _loadDashboardData(),
              LocationService.instance.refreshLocation(),
            ]);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ==========================================
                // 1. WELCOME HEADER + KOMPONEN LOKASI PENGGUNA (KONSEP GOJEK)
                // ==========================================
                _buildWelcomeHeader(context),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),

                      // ==========================================
                      // 2. WIDGET LOKASI DASHBOARD (SINKRON DENGAN HEADER)
                      // ==========================================
                      const LocationDashboardWidget(),

                      const SizedBox(height: 20),

                      // ==========================================
                      // 3. RINGKASAN (DATA ASLI DARI DATABASE / PENGGUNA)
                      // ==========================================
                      _buildRingkasanSection(isDark, textColor),

                      const SizedBox(height: 26),

                      // ==========================================
                      // 4. MENU UTAMA (2 KARTU BERDAMPINGAN)
                      // ==========================================
                      _buildSectionHeader(
                        icon: Icons.eco_rounded,
                        title: 'Menu Utama',
                        textColor: textColor,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _MainMenuCard(
                              icon: Icons.description_rounded,
                              title: 'Laporan',
                              subtitle: 'Buat laporan kegiatan',
                              primaryColor: DashboardPage.kPrimary,
                              bgColor: isDark
                                  ? const Color(0xFF1E2D24)
                                  : DashboardPage.kLightGreen,
                              accentColor: DashboardPage.kSecondary.withValues(
                                alpha: 0.15,
                              ),
                              isPrimaryVariant: true,
                              onTap: () => widget.onNavigate?.call(1),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _MainMenuCard(
                              icon: Icons.calendar_month_rounded,
                              title: 'Jadwal',
                              subtitle: 'Lihat jadwal kegiatan',
                              primaryColor: DashboardPage.kPrimary,
                              bgColor: isDark
                                  ? const Color(0xFF1A2820)
                                  : DashboardPage.kSoftGreen,
                              accentColor: DashboardPage.kPrimary.withValues(
                                alpha: 0.10,
                              ),
                              isPrimaryVariant: false,
                              onTap: () => widget.onNavigate?.call(2),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),
                      Material(
                        color: isDark ? const Color(0xFF1A2820) : DashboardPage.kLightGreen,
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AiAgentPage(),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: DashboardPage.kPrimary.withValues(
                                  alpha: isDark ? 0.45 : 0.18,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: DashboardPage.kPrimary,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.auto_awesome_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Asisten AI Phonebook',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: textColor,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Tanya fitur, susun & rangkum laporan kehutanan',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: isDark
                                              ? Colors.white70
                                              : DashboardPage.kTextSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 16,
                                  color: isDark
                                      ? const Color(0xFF81C784)
                                      : DashboardPage.kPrimary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 26),

                      // ==========================================
                      // 5. LAPORAN TERBARU (DATA ASLI / EMPTY STATE)
                      // ==========================================
                      _buildSectionHeader(
                        icon: Icons.assignment_rounded,
                        title: 'Laporan Terbaru',
                        actionText: 'Lihat Semua',
                        onActionTap: () => widget.onNavigate?.call(1),
                        textColor: textColor,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 14),
                      _buildLaporanTerbaruCard(isDark),

                      const SizedBox(height: 26),

                      // ==========================================
                      // 6. JURNAL KEGIATAN (DATA JADWAL ASLI / EMPTY STATE)
                      // ==========================================
                      _buildSectionHeader(
                        icon: Icons.history_rounded,
                        title: 'Jurnal Kegiatan',
                        actionText: 'Lihat Semua',
                        onActionTap: () => widget.onNavigate?.call(2),
                        textColor: textColor,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 14),
                      _buildJurnalKegiatanCard(isDark),

                      const SizedBox(height: 26),

                      // ==========================================
                      // 7. MENU ARSIP & HASIL LAPORAN
                      // ==========================================
                      _buildSectionHeader(
                        icon: Icons.inventory_2_rounded,
                        title: 'Arsip & Hasil Laporan',
                        textColor: textColor,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _ArchiveActionCard(
                              icon: Icons.folder_special_rounded,
                              title: 'Arsip Laporan',
                              description:
                                  'Lihat dan kelola seluruh laporan tersimpan',
                              buttonText: 'Buka Arsip',
                              isPrimary: true,
                              onTap: () => _openUserFolders(context),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _ArchiveActionCard(
                              icon: Icons.fact_check_rounded,
                              title: 'Hasil Laporan',
                              description:
                                  'Lihat hasil dan riwayat laporan kegiatan',
                              buttonText: 'Lihat Hasil',
                              isPrimary: false,
                              onTap: () => _openUserFolders(context),
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
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // WIDGET BUILDERS
  // ---------------------------------------------------------------------------

  Widget _buildWelcomeHeader(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final greetingName = _userName.isNotEmpty
        ? 'Halo, $_userName 👋'
        : 'Selamat Datang 👋';

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 230),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1B462B),
            DashboardPage.kPrimary,
            DashboardPage.kSecondary,
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
              child: CustomPaint(painter: _ForestHeaderPainter()),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(22, topPadding + 20, 22, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              greetingName,
                              style: const TextStyle(
                                color: DashboardPage.kWhite,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Kelola kegiatan dan laporan lapangan dengan mudah.',
                              style: TextStyle(
                                color: Color(0xFFE8F2E8),
                                fontSize: 14,
                                height: 1.4,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Ikon Lonceng Notifikasi dengan Badge Jumlah Belum Dibaca
                      ListenableBuilder(
                        listenable: NotificationService.instance,
                        builder: (context, _) {
                          final unreadCount =
                              NotificationService.instance.unreadCount;

                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => _openNotificationPage(context),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: DashboardPage.kWhite.withValues(
                                        alpha: 0.92,
                                      ),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.1,
                                          ),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.notifications_rounded,
                                      color: DashboardPage.kPrimary,
                                      size: 24,
                                    ),
                                  ),
                                  if (unreadCount > 0)
                                    Positioned(
                                      right: -2,
                                      top: -2,
                                      child: Container(
                                        constraints: const BoxConstraints(
                                          minWidth: 20,
                                          minHeight: 20,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE53935),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: DashboardPage.kWhite,
                                            width: 1.8,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            unreadCount > 99
                                                ? '99+'
                                                : '$unreadCount',
                                            style: const TextStyle(
                                              color: DashboardPage.kWhite,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Komponen Lokasi Pengguna ala Gojek ("Kamu sedang berada di...")
                  const LocationHeaderBanner(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRingkasanSection(bool isDark, Color textColor) {
    final containerBg = isDark ? const Color(0xFF1A241E) : DashboardPage.kWhite;
    final subColor = isDark ? Colors.white70 : DashboardPage.kTextSecondary;

    final laporanCountText = _isLoadingData ? '...' : '${_reports.length}';
    final jadwalCountText = _isLoadingData ? '...' : '${_schedules.length}';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(24),
        border: isDark ? Border.all(color: const Color(0xFF2E3D34)) : null,
        boxShadow: [
          BoxShadow(
            color: DashboardPage.kPrimary.withValues(
              alpha: isDark ? 0.2 : 0.05,
            ),
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
                    color: isDark
                        ? const Color(0xFF81C784)
                        : DashboardPage.kPrimary,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Ringkasan',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => _openUserFolders(context),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Lihat Detail',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: subColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: subColor,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.description_rounded,
                  title: 'Laporan',
                  value: laporanCountText,
                  onTap: () => widget.onNavigate?.call(1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.calendar_today_rounded,
                  title: 'Jadwal',
                  value: jadwalCountText,
                  onTap: () => widget.onNavigate?.call(2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color textColor,
    required bool isDark,
    String? actionText,
    VoidCallback? onActionTap,
  }) {
    final subColor = isDark ? Colors.white70 : DashboardPage.kTextSecondary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(
              icon,
              color: isDark ? const Color(0xFF81C784) : DashboardPage.kPrimary,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ],
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
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: subColor,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.chevron_right_rounded, size: 20, color: subColor),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLaporanTerbaruCard(bool isDark) {
    final cardBg = isDark ? const Color(0xFF1A241E) : DashboardPage.kWhite;
    final titleColor = isDark
        ? DashboardPage.kWhite
        : DashboardPage.kTextPrimary;
    final subColor = isDark ? Colors.white70 : DashboardPage.kTextSecondary;
    final borderCol = isDark ? const Color(0xFF2E3D34) : Colors.transparent;

    if (_isLoadingData) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderCol),
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: DashboardPage.kPrimary,
            ),
          ),
        ),
      );
    }

    if (_loadError != null && _reports.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderCol),
        ),
        child: Column(
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Colors.orange.shade400,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              _loadError!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: subColor),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: _loadDashboardData,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Muat Ulang'),
            ),
          ],
        ),
      );
    }

    if (_reports.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderCol),
          boxShadow: [
            BoxShadow(
              color: DashboardPage.kPrimary.withValues(
                alpha: isDark ? 0.2 : 0.05,
              ),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF26352B)
                    : DashboardPage.kLightGreen,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.description_outlined,
                color: isDark
                    ? const Color(0xFF81C784)
                    : DashboardPage.kPrimary,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Belum Ada Laporan Kegiatan',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Laporan kegiatan yang Anda buat beserta foto geolokasi akan tampil di sini.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: subColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => widget.onNavigate?.call(1),
              child: const Text(
                'Buat',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    final latest = _reports.first;
    final judul = (latest['judul'] ?? 'Laporan Kegiatan').toString();
    final status = (latest['status'] ?? 'Selesai').toString();
    final tanggal = (latest['tanggal'] ?? '-').toString();
    final lokasi = (latest['lokasi'] ?? '-').toString();
    final kategori = (latest['kategori'] ?? 'Penyuluhan').toString();
    final reportId = (latest['id'] ?? '').toString();

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        Navigator.of(context)
            .push(
              MaterialPageRoute(
                builder: (_) => LaporanPage(
                  initialReportId: reportId.isNotEmpty ? reportId : null,
                  initialReportTitle: judul,
                ),
              ),
            )
            .then((_) => _loadDashboardData());
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderCol),
          boxShadow: [
            BoxShadow(
              color: DashboardPage.kPrimary.withValues(
                alpha: isDark ? 0.2 : 0.05,
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
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF26352B)
                    : DashboardPage.kLightGreen,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.description_rounded,
                color: isDark
                    ? const Color(0xFF81C784)
                    : DashboardPage.kPrimary,
                size: 26,
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
                          judul,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: titleColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF26352B)
                              : DashboardPage.kLightGreen,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? const Color(0xFF81C784)
                                : DashboardPage.kPrimary,
                          ),
                        ),
                      ),
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
                            Icons.calendar_today_outlined,
                            size: 13,
                            color: subColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            tanggal,
                            style: TextStyle(fontSize: 13, color: subColor),
                          ),
                        ],
                      ),
                      Text('|', style: TextStyle(color: subColor)),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            size: 14,
                            color: DashboardPage.kSecondary,
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              lokasi,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, color: subColor),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Kategori: $kategori',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: subColor,
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

  Widget _buildJurnalKegiatanCard(bool isDark) {
    final cardBg = isDark ? const Color(0xFF1A241E) : DashboardPage.kWhite;
    final titleColor = isDark
        ? DashboardPage.kWhite
        : DashboardPage.kTextPrimary;
    final subColor = isDark ? Colors.white70 : DashboardPage.kTextSecondary;
    final borderCol = isDark ? const Color(0xFF2E3D34) : Colors.transparent;

    if (_isLoadingData) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderCol),
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: DashboardPage.kPrimary,
            ),
          ),
        ),
      );
    }

    if (_schedules.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderCol),
          boxShadow: [
            BoxShadow(
              color: DashboardPage.kPrimary.withValues(
                alpha: isDark ? 0.2 : 0.05,
              ),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF26352B)
                    : DashboardPage.kLightGreen,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.event_note_outlined,
                color: isDark
                    ? const Color(0xFF81C784)
                    : DashboardPage.kPrimary,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Belum Ada Jurnal / Jadwal Kegiatan',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Jadwal kegiatan lapangan yang Anda tambahkan akan tercatat di sini.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: subColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => widget.onNavigate?.call(2),
              child: const Text(
                'Jadwalkan',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    final latestSchedule = _schedules.first;
    final judul =
        (latestSchedule['judul'] ?? latestSchedule['title'] ?? 'Kegiatan')
            .toString();
    final isCompleted = latestSchedule['isCompleted'] == true;
    final statusLabel = isCompleted ? 'Selesai' : 'Terjadwal';
    final tanggalIso = (latestSchedule['tanggalIso'] ?? '').toString();
    final tanggalFormatted = tanggalIso.isNotEmpty
        ? JadwalDateUtils.formatTanggal(
            JadwalDateUtils.parseIsoDate(tanggalIso),
          )
        : '-';
    final waktu = (latestSchedule['waktu'] ?? latestSchedule['time'] ?? '08:00')
        .toString();
    final lokasi =
        (latestSchedule['lokasi'] ?? latestSchedule['location'] ?? '-')
            .toString();
    final catatan =
        (latestSchedule['catatan'] ?? latestSchedule['description'] ?? '')
            .toString()
            .trim();
    final scheduleId = (latestSchedule['id'] ?? '').toString();

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        Navigator.of(context)
            .push(
              MaterialPageRoute(
                builder: (_) => JadwalPage(
                  initialScheduleId: scheduleId.isNotEmpty ? scheduleId : null,
                  initialScheduleTitle: judul,
                ),
              ),
            )
            .then((_) => _loadDashboardData());
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderCol),
          boxShadow: [
            BoxShadow(
              color: DashboardPage.kPrimary.withValues(
                alpha: isDark ? 0.2 : 0.05,
              ),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(
                children: [
                  const SizedBox(height: 6),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF81C784)
                          : DashboardPage.kPrimary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: isDark
                          ? const Color(0xFF26352B)
                          : DashboardPage.kLightGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF26352B)
                        : DashboardPage.kLightGreen,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.park_rounded,
                    color: isDark
                        ? const Color(0xFF81C784)
                        : DashboardPage.kPrimary,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            judul,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: titleColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1A2D34)
                                : const Color(0xFFE1F0F7),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? const Color(0xFF80DEEA)
                                  : const Color(0xFF1E6B7B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 13,
                              color: subColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$tanggalFormatted • $waktu WIB',
                              style: TextStyle(fontSize: 13, color: subColor),
                            ),
                          ],
                        ),
                        Text('|', style: TextStyle(color: subColor)),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              size: 14,
                              color: DashboardPage.kSecondary,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                lokasi,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 13, color: subColor),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (catatan.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        catatan,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13.5, color: subColor),
                      ),
                    ],
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

// ============================================================================
// KOMPONEN KARTU RINGKASAN (_StatCard)
// ============================================================================
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF223026) : DashboardPage.kSoftGreen;
    final valueColor = isDark
        ? DashboardPage.kWhite
        : DashboardPage.kTextPrimary;
    final subColor = isDark ? Colors.white70 : DashboardPage.kTextSecondary;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? const Color(0xFF2E3D34) : DashboardPage.kLightGreen,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1B3B22)
                    : DashboardPage.kLightGreen,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: isDark
                    ? const Color(0xFF81C784)
                    : DashboardPage.kPrimary,
                size: 26,
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
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: subColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: valueColor,
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

// ============================================================================
// KOMPONEN KARTU MENU UTAMA (_MainMenuCard)
// ============================================================================
class _MainMenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color primaryColor;
  final Color bgColor;
  final Color accentColor;
  final bool isPrimaryVariant;
  final VoidCallback onTap;

  const _MainMenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.primaryColor,
    required this.bgColor,
    required this.accentColor,
    required this.isPrimaryVariant,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleCol = isDark ? Colors.white : DashboardPage.kTextPrimary;
    final subCol = isDark ? Colors.white70 : DashboardPage.kTextSecondary;

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isPrimaryVariant
                  ? DashboardPage.kSecondary.withValues(alpha: 0.25)
                  : DashboardPage.kPrimary.withValues(alpha: 0.15),
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
                      color: accentColor,
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
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: isPrimaryVariant
                              ? primaryColor
                              : DashboardPage.kSecondary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          icon,
                          color: DashboardPage.kWhite,
                          size: 24,
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
                              style: TextStyle(
                                fontSize: 16,
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
                                fontSize: 12,
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
                            : DashboardPage.kPrimary,
                        size: 22,
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

// ============================================================================
// KOMPONEN KARTU ARSIP & HASIL LAPORAN (_ArchiveActionCard)
// ============================================================================
class _ArchiveActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String buttonText;
  final bool isPrimary;
  final VoidCallback onTap;

  const _ArchiveActionCard({
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
    final cardBg = isDark ? const Color(0xFF1A241E) : DashboardPage.kWhite;
    final titleColor = isDark
        ? DashboardPage.kWhite
        : DashboardPage.kTextPrimary;
    final subColor = isDark ? Colors.white70 : DashboardPage.kTextSecondary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPrimary
              ? DashboardPage.kPrimary.withValues(alpha: 0.25)
              : DashboardPage.kSecondary.withValues(alpha: 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: DashboardPage.kPrimary.withValues(
              alpha: isDark ? 0.2 : 0.05,
            ),
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
                  ? const Color(0xFF26352B)
                  : (isPrimary
                        ? DashboardPage.kLightGreen
                        : DashboardPage.kSoftGreen),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isDark
                  ? const Color(0xFF81C784)
                  : (isPrimary
                        ? DashboardPage.kPrimary
                        : DashboardPage.kSecondary),
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
            style: TextStyle(fontSize: 13, height: 1.35, color: subColor),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: isPrimary
                    ? DashboardPage.kPrimary
                    : (isDark
                          ? const Color(0xFF26352B)
                          : DashboardPage.kLightGreen),
                foregroundColor: isPrimary
                    ? DashboardPage.kWhite
                    : (isDark
                          ? const Color(0xFF81C784)
                          : DashboardPage.kPrimary),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    buttonText,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
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

// ============================================================================
// CUSTOM PAINTER: ILUSTRASI PEGUNUNGAN & HUTAN PADA HEADER
// ============================================================================
class _ForestHeaderPainter extends CustomPainter {
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
