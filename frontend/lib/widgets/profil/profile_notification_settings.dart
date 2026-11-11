import 'package:flutter/material.dart';

class ProfileNotificationSettings extends StatelessWidget {
  final bool notifJadwal;
  final bool notifKunjungan;
  final bool notifSinkron;
  final bool notifPengumuman;
  final String reminderTime;
  final ValueChanged<bool> onToggleJadwal;
  final ValueChanged<bool> onToggleKunjungan;
  final ValueChanged<bool> onToggleSinkron;
  final ValueChanged<bool> onTogglePengumuman;
  final ValueChanged<String> onChangeReminderTime;

  const ProfileNotificationSettings({
    super.key,
    required this.notifJadwal,
    required this.notifKunjungan,
    required this.notifSinkron,
    required this.notifPengumuman,
    required this.reminderTime,
    required this.onToggleJadwal,
    required this.onToggleKunjungan,
    required this.onToggleSinkron,
    required this.onTogglePengumuman,
    required this.onChangeReminderTime,
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
            activeColor: isDark ? const Color(0xFF81C784) : const Color(0xFF285C2E),
            activeTrackColor: isDark ? const Color(0xFF2E4D34) : const Color(0xFFC8E6C9),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  void _showReminderTimeDialog(BuildContext context) {
    final times = [
      '15 Menit Sebelumnya',
      '30 Menit Sebelumnya',
      '1 Jam Sebelumnya',
      '1 Hari Sebelumnya',
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        final dialogDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: dialogDark ? const Color(0xFF1E2822) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Icon(
                Icons.alarm_rounded,
                color: dialogDark ? const Color(0xFF81C784) : const Color(0xFF285C2E),
              ),
              const SizedBox(width: 10),
              Text(
                'Waktu Pengingat',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: dialogDark ? Colors.white : const Color(0xFF1E2923),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: times.map((t) {
              final isSelected = t == reminderTime;
              return RadioListTile<String>(
                value: t,
                groupValue: reminderTime,
                activeColor: dialogDark ? const Color(0xFF81C784) : const Color(0xFF285C2E),
                title: Text(
                  t,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected
                        ? (dialogDark ? const Color(0xFFA5D6A7) : const Color(0xFF285C2E))
                        : (dialogDark ? Colors.white : Colors.black87),
                  ),
                ),
                onChanged: (val) {
                  if (val != null) {
                    Navigator.pop(ctx);
                    onChangeReminderTime(val);
                  }
                },
              );
            }).toList(),
          ),
        );
      },
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
    final badgeBg = isDark ? const Color(0xFF26352B) : const Color(0xFFF1F8E9);
    final badgeBorder = isDark ? const Color(0xFF2E3D34) : const Color(0xFFC8E6C9);

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
                  Icons.notifications_active_outlined,
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
                      'Pengaturan Notifikasi',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: titleColor,
                      ),
                    ),
                    Text(
                      'Kelola pengingat jadwal dan status sinkronisasi',
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
            icon: Icons.calendar_today_outlined,
            title: 'Notifikasi Jadwal Kegiatan',
            subtitle: 'Pengingat agenda rapat dan penyuluhan dinas',
            value: notifJadwal,
            onChanged: onToggleJadwal,
          ),
          Divider(height: 1, indent: 48, color: dividerColor),

          _buildSwitchTile(
            context: context,
            icon: Icons.nature_people_outlined,
            title: 'Pengingat Kunjungan Lapangan',
            subtitle: 'Pemberitahuan sebelum berangkat ke wilayah binaan',
            value: notifKunjungan,
            onChanged: onToggleKunjungan,
          ),
          Divider(height: 1, indent: 48, color: dividerColor),

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
          Divider(height: 1, indent: 48, color: dividerColor),
          const SizedBox(height: 4),

          // Pengaturan Waktu Pengingat
          InkWell(
            onTap: () => _showReminderTimeDialog(context),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: headerBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.timer_outlined, size: 18, color: primaryGreen),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Waktu Alarm Pengingat',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: titleColor,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Kapan pengingat jadwal dibunyikan',
                          style: TextStyle(fontSize: 11.5, color: subColor),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: badgeBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          reminderTime,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: primaryGreen,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_drop_down, size: 18, color: primaryGreen),
                      ],
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
}
