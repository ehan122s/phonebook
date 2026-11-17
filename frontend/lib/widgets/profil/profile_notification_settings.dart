import 'package:flutter/material.dart';

/// Komponen pengaturan notifikasi umum pada halaman Profil (tanpa menu Pengingat
/// karena fitur Pengingat dikelola langsung per jadwal pada halaman Jadwal).
class ProfileNotificationSettings extends StatelessWidget {
  final bool notifSinkron;
  final bool notifPengumuman;
  final ValueChanged<bool> onToggleSinkron;
  final ValueChanged<bool> onTogglePengumuman;

  const ProfileNotificationSettings({
    super.key,
    required this.notifSinkron,
    required this.notifPengumuman,
    required this.onToggleSinkron,
    required this.onTogglePengumuman,
  });

  Widget _buildSwitchTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconBg = isDark ? const Color(0xFF26352B) : const Color(0xFFF1F8E9);
    final iconColor = isDark ? const Color(0xFF81C784) : const Color(0xFF285C2E);
    final titleColor = isDark ? Colors.white : const Color(0xFF1E2923);
    final subColor = isDark ? Colors.white60 : Colors.grey.shade600;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
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
                  style: TextStyle(
                    fontSize: 11.5,
                    color: subColor,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor:
                isDark ? const Color(0xFF81C784) : const Color(0xFF285C2E),
            activeTrackColor:
                isDark ? const Color(0xFF2E4D34) : const Color(0xFFC8E6C9),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E2822) : Colors.white;
    final cardBorder =
        isDark ? const Color(0xFF2E3D34) : const Color(0xFFE0E7E1);
    final headerBg = isDark ? const Color(0xFF26352B) : const Color(0xFFE8F5E9);
    final primaryGreen =
        isDark ? const Color(0xFF81C784) : const Color(0xFF285C2E);
    final titleColor = isDark ? Colors.white : const Color(0xFF1E2923);
    final subColor = isDark ? Colors.white60 : Colors.grey;
    final dividerColor =
        isDark ? const Color(0xFF2E3D34) : const Color(0xFFEDF2EE);

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
                  Icons.notifications_none_rounded,
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
                      'Preferensi Pemberitahuan Sistem',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: titleColor,
                      ),
                    ),
                    Text(
                      'Pemberitahuan status sinkronisasi dan pengumuman dinas',
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
          _buildSwitchTile(
            context: context,
            icon: Icons.sync_problem_rounded,
            title: 'Notifikasi Sinkronisasi Laporan',
            subtitle: 'Pemberitahuan saat laporan offline berhasil diunggah',
            value: notifSinkron,
            onChanged: onToggleSinkron,
          ),
          Divider(height: 1, indent: 48, color: dividerColor),
          _buildSwitchTile(
            context: context,
            icon: Icons.campaign_outlined,
            title: 'Informasi & Pengumuman CDK V',
            subtitle: 'Surat edaran, materi baru, dan pengumuman dinas',
            value: notifPengumuman,
            onChanged: onTogglePengumuman,
          ),
        ],
      ),
    );
  }
}