// ============================================================================
// [KHUSUS USER - DASHBOARD USER]
// Simpan file ini di: lib/pages/dashboard.dart
// ============================================================================

import 'package:flutter/material.dart';
import 'kategori.dart';

class DashboardPage extends StatelessWidget {
  final Function(int)? onNavigate;

  const DashboardPage({
    super.key,
    this.onNavigate,
  });

  // Palet Warna Modern Soft Green Forest
  static const Color kPrimary = Color(0xFF245C3A);
  static const Color kSecondary = Color(0xFF4F8A5B);
  static const Color kLightGreen = Color(0xFFE8F2E8);
  static const Color kSoftGreen = Color(0xFFF2F7F0);
  static const Color kBackground = Color(0xFFF7F9F6);
  static const Color kWhite = Color(0xFFFFFFFF);
  static const Color kTextPrimary = Color(0xFF24352A);
  static const Color kTextSecondary = Color(0xFF758278);

  void _openUserFolders(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const KategoriPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121A15) : kBackground;
    final textColor = isDark ? kWhite : kTextPrimary;

    return Container(
      color: bgColor,
      child: SafeArea(
        top: false, // Biarkan header menyatu dengan bagian atas layar
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==========================================
              // 3. WELCOME HEADER (DENGAN ILUSTRASI HUTAN)
              // ==========================================
              _buildWelcomeHeader(context),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 22),

                    // ==========================================
                    // 4. RINGKASAN (DALAM CONTAINER PUTIH)
                    // ==========================================
                    _buildRingkasanSection(isDark, textColor),

                    const SizedBox(height: 26),

                    // ==========================================
                    // 5. MENU UTAMA (2 KARTU BERDAMPINGAN)
                    // ==========================================
                    _buildSectionHeader(
                      icon: Icons.eco_rounded,
                      title: 'Menu Utama',
                      textColor: textColor,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _MainMenuCard(
                            icon: Icons.description_rounded,
                            title: 'Laporan',
                            subtitle: 'Buat laporan kegiatan',
                            primaryColor: kPrimary,
                            bgColor: kLightGreen,
                            accentColor: kSecondary.withValues(alpha: 0.15),
                            isPrimaryVariant: true,
                            onTap: () => onNavigate?.call(1),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _MainMenuCard(
                            icon: Icons.calendar_month_rounded,
                            title: 'Jadwal',
                            subtitle: 'Lihat jadwal kegiatan',
                            primaryColor: kPrimary,
                            bgColor: kSoftGreen,
                            accentColor: kPrimary.withValues(alpha: 0.10),
                            isPrimaryVariant: false,
                            onTap: () => onNavigate?.call(2),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 26),

                    // ==========================================
                    // 6. LAPORAN TERBARU
                    // ==========================================
                    _buildSectionHeader(
                      icon: Icons.assignment_rounded,
                      title: 'Laporan Terbaru',
                      actionText: 'Lihat Semua',
                      onActionTap: () => onNavigate?.call(1),
                      textColor: textColor,
                    ),
                    const SizedBox(height: 14),
                    _buildLaporanTerbaruCard(isDark),

                    const SizedBox(height: 26),

                    // ==========================================
                    // 7. JURNAL KEGIATAN (TIMELINE CARD)
                    // ==========================================
                    _buildSectionHeader(
                      icon: Icons.history_rounded,
                      title: 'Jurnal Kegiatan',
                      actionText: 'Lihat Semua',
                      onActionTap: () {},
                      textColor: textColor,
                    ),
                    const SizedBox(height: 14),
                    _buildJurnalKegiatanCard(isDark),

                    const SizedBox(height: 26),

                    // ==========================================
                    // 8. MENU ARSIP & HASIL LAPORAN (PENTING)
                    // ==========================================
                    _buildSectionHeader(
                      icon: Icons.inventory_2_rounded,
                      title: 'Arsip & Hasil Laporan',
                      textColor: textColor,
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
    );
  }

  // ---------------------------------------------------------------------------
  // WIDGET BUILDERS
  // ---------------------------------------------------------------------------

  Widget _buildWelcomeHeader(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 220),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1B462B),
            kPrimary,
            kSecondary,
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
            // Ilustrasi Pegunungan & Pepohonan Hutan (Sisi Kanan & Bawah)
            Positioned.fill(
              child: CustomPaint(
                painter: _ForestHeaderPainter(),
              ),
            ),

            // Konten Teks & Tombol Notifikasi
            Padding(
              padding: EdgeInsets.fromLTRB(24, topPadding + 24, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Selamat Datang 👋',
                              style: TextStyle(
                                color: kWhite,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Kelola kegiatan dan laporan\nlapangan dengan mudah.',
                              style: TextStyle(
                                color: Color(0xFFE8F2E8),
                                fontSize: 15,
                                height: 1.45,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Ikon Lonceng Notifikasi seperti pada referensi
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: kWhite.withValues(alpha: 0.9),
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
                              Icons.notifications_rounded,
                              color: kPrimary,
                              size: 24,
                            ),
                          ),
                          Positioned(
                            right: 2,
                            top: 2,
                            child: Container(
                              width: 11,
                              height: 11,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE53935),
                                shape: BoxShape.circle,
                                border: Border.all(color: kWhite, width: 2),
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

  Widget _buildRingkasanSection(bool isDark, Color textColor) {
    final containerBg = isDark ? const Color(0xFF1A241E) : kWhite;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: kPrimary.withValues(alpha: isDark ? 0.2 : 0.05),
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
                  const Icon(
                    Icons.bar_chart_rounded,
                    color: kPrimary,
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
                onTap: () => onNavigate?.call(1),
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        'Lihat Detail',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: kTextSecondary,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: kTextSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.description_rounded,
                  title: 'Laporan',
                  value: '4',
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.calendar_today_rounded,
                  title: 'Jadwal',
                  value: '3',
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
    String? actionText,
    VoidCallback? onActionTap,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: kPrimary, size: 22),
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
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: kTextSecondary,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: kTextSecondary,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLaporanTerbaruCard(bool isDark) {
    final cardBg = isDark ? const Color(0xFF1A241E) : kWhite;
    final titleColor = isDark ? kWhite : kTextPrimary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: kPrimary.withValues(alpha: isDark ? 0.2 : 0.05),
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
              color: kLightGreen,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.description_rounded,
              color: kPrimary,
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
                        'Kegiatan Penyuluhan Kehutanan',
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
                        color: kLightGreen,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Selesai',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: kPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Wrap(
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
                          color: kTextSecondary,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '20 Oktober 2026',
                          style: TextStyle(
                            fontSize: 13,
                            color: kTextSecondary,
                          ),
                        ),
                      ],
                    ),
                    Text('|', style: TextStyle(color: kTextSecondary)),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 14,
                          color: kSecondary,
                        ),
                        SizedBox(width: 3),
                        Text(
                          'Kawasan Hutan Garut',
                          style: TextStyle(
                            fontSize: 13,
                            color: kTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Kategori: Penyuluhan',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: kTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJurnalKegiatanCard(bool isDark) {
    final cardBg = isDark ? const Color(0xFF1A241E) : kWhite;
    final titleColor = isDark ? kWhite : kTextPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: kPrimary.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Indikator Timeline Vertikal
            Column(
              children: [
                const SizedBox(height: 6),
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: kPrimary,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: kLightGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            // Ikon Aktivitas Kehutanan
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: kLightGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.park_rounded,
                  color: kPrimary,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Detail Jurnal
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          'Monitoring Hutan',
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
                          color: const Color(0xFFE1F0F7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Tercatat',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E6B7B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Wrap(
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
                            color: kTextSecondary,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '21 Oktober 2026',
                            style: TextStyle(
                              fontSize: 13,
                              color: kTextSecondary,
                            ),
                          ),
                        ],
                      ),
                      Text('|', style: TextStyle(color: kTextSecondary)),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            size: 14,
                            color: kSecondary,
                          ),
                          SizedBox(width: 3),
                          Text(
                            'Kawasan Hutan Garut',
                            style: TextStyle(
                              fontSize: 13,
                              color: kTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Melakukan monitoring kondisi hutan.',
                    style: TextStyle(
                      fontSize: 14,
                      color: kTextSecondary,
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
// KOMPONEN KARTU RINGKASAN (_StatCard)
// ============================================================================
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF223026) : DashboardPage.kSoftGreen;
    final valueColor = isDark ? DashboardPage.kWhite : DashboardPage.kTextPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: DashboardPage.kLightGreen,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: DashboardPage.kLightGreen,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: DashboardPage.kPrimary,
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
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: DashboardPage.kTextSecondary,
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
                // Aksen Dekoratif Berbeda Secara Halus di Sudut Kanan
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
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: DashboardPage.kTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.2,
                                color: DashboardPage.kTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: DashboardPage.kPrimary,
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
    final titleColor = isDark ? DashboardPage.kWhite : DashboardPage.kTextPrimary;

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
            color: DashboardPage.kPrimary.withValues(alpha: isDark ? 0.2 : 0.05),
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
              color: isPrimary
                  ? DashboardPage.kLightGreen
                  : DashboardPage.kSoftGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isPrimary
                  ? DashboardPage.kPrimary
                  : DashboardPage.kSecondary,
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
            style: const TextStyle(
              fontSize: 13,
              height: 1.35,
              color: DashboardPage.kTextSecondary,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: isPrimary
                    ? DashboardPage.kPrimary
                    : DashboardPage.kLightGreen,
                foregroundColor: isPrimary
                    ? DashboardPage.kWhite
                    : DashboardPage.kPrimary,
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
    // 1. Bukit Belakang (Hijau Muda Lembut Transparan)
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

    // 2. Gunung / Bukit Tengah
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

    // 3. Bukit Depan Kanan Bawah
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

    // 4. Siluet Pepohonan Cemara/Hutan di Sisi Kanan Bawah
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