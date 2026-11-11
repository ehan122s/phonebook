import 'package:flutter/material.dart';

class ProfileHelpSection extends StatelessWidget {
  final VoidCallback onUserGuide;
  final VoidCallback onFaq;
  final VoidCallback onContactAdmin;
  final VoidCallback onReportIssue;
  final VoidCallback onPrivacyPolicy;
  final VoidCallback onAboutApp;

  const ProfileHelpSection({
    super.key,
    required this.onUserGuide,
    required this.onFaq,
    required this.onContactAdmin,
    required this.onReportIssue,
    required this.onPrivacyPolicy,
    required this.onAboutApp,
  });

  Widget _buildItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconBg = isDark ? const Color(0xFF26352B) : const Color(0xFFF1F8E9);
    final iconColor = isDark ? const Color(0xFF81C784) : const Color(0xFF285C2E);
    final titleColor = isDark ? Colors.white : const Color(0xFF1E2923);
    final subColor = isDark ? Colors.white60 : Colors.grey.shade600;
    final chevronColor = isDark ? Colors.white38 : Colors.grey;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11.5, color: subColor),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: chevronColor,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E2822) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF2E3D34) : const Color(0xFFE0E7E1);
    final headerBg = isDark ? const Color(0xFF26352B) : const Color(0xFFE8F5E9);
    final primaryGreen = isDark ? const Color(0xFF81C784) : const Color(0xFF285C2E);
    final titleColor = isDark ? Colors.white : const Color(0xFF1E2923);
    final subColor = isDark ? Colors.white60 : Colors.grey;
    final dividerColor = isDark ? const Color(0xFF2E3D34) : const Color(0xFFEDF2EE);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: headerBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.help_outline_rounded,
                  size: 20,
                  color: primaryGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bantuan & Pusat Informasi',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: titleColor,
                      ),
                    ),
                    Text(
                      'Panduan, kontak bantuan, dan pelaporan kendala',
                      style: TextStyle(fontSize: 11.5, color: subColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: dividerColor),
          const SizedBox(height: 6),

          _buildItem(
            context: context,
            icon: Icons.menu_book_rounded,
            title: 'Panduan Penggunaan Aplikasi',
            subtitle: 'Tata cara input laporan offline, jadwal & materi',
            onTap: onUserGuide,
          ),
          Divider(height: 1, indent: 48, color: dividerColor),

          _buildItem(
            context: context,
            icon: Icons.quiz_outlined,
            title: 'Pertanyaan Umum (FAQ)',
            subtitle: 'Solusi cepat untuk kendala yang sering dialami',
            onTap: onFaq,
          ),
          Divider(height: 1, indent: 48, color: dividerColor),

          _buildItem(
            context: context,
            icon: Icons.support_agent_rounded,
            title: 'Hubungi Administrator CDK V',
            subtitle: 'Bantuan teknis via WhatsApp & Telepon dinas',
            onTap: onContactAdmin,
          ),
          Divider(height: 1, indent: 48, color: dividerColor),

          _buildItem(
            context: context,
            icon: Icons.bug_report_outlined,
            title: 'Laporkan Kendala / Masalah',
            subtitle: 'Kirim keluhan atau bug sistem kepada tim IT',
            onTap: onReportIssue,
          ),
          Divider(height: 1, indent: 48, color: dividerColor),

          _buildItem(
            context: context,
            icon: Icons.policy_outlined,
            title: 'Kebijakan Privasi & Data ASN',
            subtitle: 'Perlindungan kerahasiaan data kepegawaian',
            onTap: onPrivacyPolicy,
          ),
          Divider(height: 1, indent: 48, color: dividerColor),

          _buildItem(
            context: context,
            icon: Icons.info_outline_rounded,
            title: 'Tentang Aplikasi Phonebook',
            subtitle: 'Informasi versi, lisensi, dan pengembang CDK V',
            onTap: onAboutApp,
          ),
        ],
      ),
    );
  }
}
