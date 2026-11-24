import 'package:flutter/material.dart';

import '../admin_theme.dart';
import '../widgets/admin_shared_widgets.dart';

class AdminDashboardSection extends StatelessWidget {
  final bool isWideScreen;
  final String adminName;
  final String adminEmail;
  final bool isSyncingUsers;
  final List<Map<String, String>> users;
  final List<Map<String, String>> recentReports;
  final List<Map<String, String>> filteredRecentReports;
  final String reportFilterStatus;
  final int totalJadwalCount;
  final int totalMateriCount;
  final ValueChanged<int> onSelectMenu;
  final VoidCallback onRefresh;
  final VoidCallback onLogout;
  final ValueChanged<String> onReportFilterChanged;
  final ValueChanged<Map<String, dynamic>> onVerifyReport;

  const AdminDashboardSection({
    super.key,
    required this.isWideScreen,
    required this.adminName,
    required this.adminEmail,
    required this.isSyncingUsers,
    required this.users,
    required this.recentReports,
    required this.filteredRecentReports,
    required this.reportFilterStatus,
    required this.totalJadwalCount,
    required this.totalMateriCount,
    required this.onSelectMenu,
    required this.onRefresh,
    required this.onLogout,
    required this.onReportFilterChanged,
    required this.onVerifyReport,
  });

  @override
  Widget build(BuildContext context) {
    final t = AdminTheme.of(context);
    final horizontalPad = isWideScreen ? 28.0 : 20.0;

    return Container(
      color: t.bgColor,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeHeader(context),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 22),
                    _buildRingkasanSection(t),
                    const SizedBox(height: 26),
                    _buildSectionHeader(
                      t: t,
                      icon: Icons.eco_rounded,
                      title: 'Menu Utama Admin',
                      actionText: 'Folder User',
                      onActionTap: () => onSelectMenu(2),
                    ),
                    const SizedBox(height: 14),
                    _buildMainMenuGrid(),
                    const SizedBox(height: 26),
                    _buildSectionHeader(
                      t: t,
                      icon: Icons.assignment_rounded,
                      title: 'Monitoring Laporan Terbaru',
                      actionText: 'Lihat Semua',
                      onActionTap: () => onSelectMenu(2),
                    ),
                    const SizedBox(height: 12),
                    _buildReportStatusFilterChips(t),
                    const SizedBox(height: 12),
                    ...filteredRecentReports
                        .take(4)
                        .map(
                          (lap) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildLaporanTerbaruCard(t, lap),
                          ),
                        ),
                    const SizedBox(height: 16),
                    _buildSectionHeader(
                      t: t,
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
                              AdminArchiveActionCard(
                                icon: Icons.folder_special_rounded,
                                title: 'Folder Seluruh User',
                                description: 'Pantau seluruh folder laporan dan arsip kegiatan penyuluh',
                                buttonText: 'Buka Direktori',
                                isPrimary: true,
                                onTap: () => onSelectMenu(2),
                              ),
                              const SizedBox(height: 14),
                              AdminArchiveActionCard(
                                icon: Icons.manage_accounts_rounded,
                                title: 'Manajemen Pengguna',
                                description: 'Kelola akun, NIP, wilayah tugas, dan status aktif penyuluh',
                                buttonText: 'Kelola Akun',
                                isPrimary: false,
                                onTap: () => onSelectMenu(1),
                              ),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(
                              child: AdminArchiveActionCard(
                                icon: Icons.folder_special_rounded,
                                title: 'Folder Seluruh User',
                                description: 'Pantau seluruh folder laporan dan arsip kegiatan penyuluh',
                                buttonText: 'Buka Direktori',
                                isPrimary: true,
                                onTap: () => onSelectMenu(2),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: AdminArchiveActionCard(
                                icon: Icons.manage_accounts_rounded,
                                title: 'Manajemen Pengguna',
                                description: 'Kelola akun, NIP, wilayah tugas, dan status aktif penyuluh',
                                buttonText: 'Kelola Akun',
                                isPrimary: false,
                                onTap: () => onSelectMenu(1),
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

  Widget _buildWelcomeHeader(BuildContext context) {
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
            AdminTheme.kPrimary,
            AdminTheme.kSecondary,
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
              child: CustomPaint(painter: AdminForestHeaderPainter()),
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
                      if (!isWideScreen)
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
                                      'Panel Administrator • $adminEmail',
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
                              'Selamat Datang, $adminName 👋',
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
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: onRefresh,
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
                                isSyncingUsers
                                    ? Icons.sync_rounded
                                    : Icons.refresh_rounded,
                                color: AdminTheme.kPrimary,
                                size: 22,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: onLogout,
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

  Widget _buildRingkasanSection(AdminTheme t) {
    final activeUsersCount = users
        .where((u) => (u['status'] ?? 'Aktif') == 'Aktif')
        .length;
    final completedReportsCount = recentReports
        .where((r) => (r['status'] ?? '') == 'Selesai')
        .length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AdminTheme.kPrimary.withValues(alpha: t.isDark ? 0.2 : 0.05),
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
                    color: t.primaryAccent,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Ringkasan Sistem',
                    style: TextStyle(
                      fontSize: 18.5,
                      fontWeight: FontWeight.w700,
                      color: t.textPrimary,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => onSelectMenu(1),
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
                          color: t.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: t.textSecondary,
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
              final statCards = [
                AdminStatCard(
                  icon: Icons.people_alt_rounded,
                  title: 'Pengguna',
                  value: '${users.length}',
                  subtitle: '$activeUsersCount Akun Aktif',
                  onTap: () => onSelectMenu(1),
                ),
                AdminStatCard(
                  icon: Icons.folder_shared_rounded,
                  title: 'Folder User',
                  value: '${users.length}',
                  subtitle: 'Direktori Penyuluh',
                  onTap: () => onSelectMenu(2),
                ),
                AdminStatCard(
                  icon: Icons.description_rounded,
                  title: 'Laporan',
                  value: '${recentReports.length}',
                  subtitle: '$completedReportsCount Selesai',
                  onTap: () => onSelectMenu(3),
                ),
                AdminStatCard(
                  icon: Icons.calendar_today_rounded,
                  title: 'Jadwal & Materi',
                  value: '$totalJadwalCount',
                  subtitle: '$totalMateriCount Modul Materi',
                  onTap: () => onSelectMenu(4),
                ),
              ];

              if (isWide) {
                return Row(
                  children: [
                    Expanded(child: statCards[0]),
                    const SizedBox(width: 12),
                    Expanded(child: statCards[1]),
                    const SizedBox(width: 12),
                    Expanded(child: statCards[2]),
                    const SizedBox(width: 12),
                    Expanded(child: statCards[3]),
                  ],
                );
              }
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: statCards[0]),
                      const SizedBox(width: 12),
                      Expanded(child: statCards[1]),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: statCards[2]),
                      const SizedBox(width: 12),
                      Expanded(child: statCards[3]),
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
          AdminMainMenuCard(
            icon: Icons.people_alt_rounded,
            title: 'Pengguna',
            subtitle: 'Kelola akun & NIP penyuluh',
            isPrimaryVariant: true,
            onTap: () => onSelectMenu(1),
          ),
          AdminMainMenuCard(
            icon: Icons.folder_shared_rounded,
            title: 'Folder User',
            subtitle: 'Buka seluruh arsip pegawai',
            isPrimaryVariant: false,
            onTap: () => onSelectMenu(2),
          ),
          AdminMainMenuCard(
            icon: Icons.description_rounded,
            title: 'Laporan',
            subtitle: 'Atur template & pantau laporan',
            isPrimaryVariant: true,
            onTap: () => onSelectMenu(3),
          ),
          AdminMainMenuCard(
            icon: Icons.bar_chart_rounded,
            title: 'Monitoring',
            subtitle: 'Pantau aktivitas & statistik pengguna',
            isPrimaryVariant: false,
            onTap: () => onSelectMenu(4),
          ),
          AdminMainMenuCard(
            icon: Icons.menu_book_rounded,
            title: 'Materi',
            subtitle: 'Unggah modul penyuluhan',
            isPrimaryVariant: true,
            onTap: () => onSelectMenu(5),
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
                  const Expanded(child: SizedBox()),
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
            Row(children: [Expanded(child: cards[4])]),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader({
    required AdminTheme t,
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
              Icon(icon, color: t.primaryAccent, size: 22),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18.5,
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
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
                      color: t.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: t.textSecondary,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildReportStatusFilterChips(AdminTheme t) {
    final filters = ['Semua', 'Selesai', 'Diproses', 'Draft'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = reportFilterStatus == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(f),
              selected: isSelected,
              showCheckmark: false,
              selectedColor: AdminTheme.kPrimary,
              backgroundColor: t.cardBg,
              side: BorderSide(
                color: isSelected ? AdminTheme.kPrimary : t.borderColor,
              ),
              labelStyle: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : t.textPrimary,
              ),
              onSelected: (_) => onReportFilterChanged(f),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLaporanTerbaruCard(AdminTheme t, Map<String, String> lap) {
    final status = lap['status'] ?? 'Draft';

    return Material(
      color: t.cardBg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => onSelectMenu(2),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: t.borderColor),
            boxShadow: [
              BoxShadow(
                color: AdminTheme.kPrimary.withValues(
                  alpha: t.isDark ? 0.18 : 0.04,
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
                  color: t.lightGreenBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.description_rounded,
                  color: t.primaryAccent,
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
                              color: t.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        AdminStatusChip(status: status),
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
                              color: t.primaryAccent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              lap['pelapor'] ?? '-',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: t.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Text('|', style: TextStyle(color: t.textSecondary)),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 13,
                              color: t.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              lap['tanggal'] ?? '-',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: t.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        Text('|', style: TextStyle(color: t.textSecondary)),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              size: 14,
                              color: AdminTheme.kSecondary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              lap['lokasi'] ?? 'CDK Wilayah Garut',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: t.textSecondary,
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
                            color: t.textSecondary,
                          ),
                        ),
                        if (status != 'Selesai')
                          InkWell(
                            onTap: () => onVerifyReport(lap),
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
                                    color: t.primaryAccent,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Verifikasi',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: t.primaryAccent,
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
}
