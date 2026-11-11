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
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
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
                color: const Color(0xFFF1F8E9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: const Color(0xFF285C2E)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E2923),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0E7E1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.help_outline_rounded,
                  size: 20,
                  color: Color(0xFF285C2E),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bantuan & Pusat Informasi',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E2923),
                      ),
                    ),
                    Text(
                      'Panduan, kontak bantuan, dan pelaporan kendala',
                      style: TextStyle(fontSize: 11.5, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFEDF2EE)),
          const SizedBox(height: 6),

          _buildItem(
            icon: Icons.menu_book_rounded,
            title: 'Panduan Penggunaan Aplikasi',
            subtitle: 'Tata cara input laporan offline, jadwal & materi',
            onTap: onUserGuide,
          ),
          const Divider(height: 1, indent: 48, color: Color(0xFFF1F5F2)),

          _buildItem(
            icon: Icons.quiz_outlined,
            title: 'Pertanyaan Umum (FAQ)',
            subtitle: 'Solusi cepat untuk kendala yang sering dialami',
            onTap: onFaq,
          ),
          const Divider(height: 1, indent: 48, color: Color(0xFFF1F5F2)),

          _buildItem(
            icon: Icons.support_agent_rounded,
            title: 'Hubungi Administrator CDK V',
            subtitle: 'Bantuan teknis via WhatsApp & Telepon dinas',
            onTap: onContactAdmin,
          ),
          const Divider(height: 1, indent: 48, color: Color(0xFFF1F5F2)),

          _buildItem(
            icon: Icons.bug_report_outlined,
            title: 'Laporkan Kendala / Masalah',
            subtitle: 'Kirim keluhan atau bug sistem kepada tim IT',
            onTap: onReportIssue,
          ),
          const Divider(height: 1, indent: 48, color: Color(0xFFF1F5F2)),

          _buildItem(
            icon: Icons.policy_outlined,
            title: 'Kebijakan Privasi & Data ASN',
            subtitle: 'Perlindungan kerahasiaan data kepegawaian',
            onTap: onPrivacyPolicy,
          ),
          const Divider(height: 1, indent: 48, color: Color(0xFFF1F5F2)),

          _buildItem(
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
