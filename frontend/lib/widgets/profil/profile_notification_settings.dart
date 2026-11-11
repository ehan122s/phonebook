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
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
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
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: const Color(0xFF285C2E),
            activeTrackColor: const Color(0xFFC8E6C9),
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
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.alarm_rounded, color: Color(0xFF285C2E)),
              SizedBox(width: 10),
              Text(
                'Waktu Pengingat',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
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
                activeColor: const Color(0xFF285C2E),
                title: Text(
                  t,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? const Color(0xFF285C2E) : Colors.black87,
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
                  Icons.notifications_active_outlined,
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
                      'Pengaturan Notifikasi',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E2923),
                      ),
                    ),
                    Text(
                      'Kelola pengingat jadwal dan status sinkronisasi',
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

          _buildSwitchTile(
            icon: Icons.calendar_today_outlined,
            title: 'Notifikasi Jadwal Kegiatan',
            subtitle: 'Pengingat agenda rapat dan penyuluhan dinas',
            value: notifJadwal,
            onChanged: onToggleJadwal,
          ),
          const Divider(height: 1, indent: 48, color: Color(0xFFF1F5F2)),

          _buildSwitchTile(
            icon: Icons.nature_people_outlined,
            title: 'Pengingat Kunjungan Lapangan',
            subtitle: 'Pemberitahuan sebelum berangkat ke wilayah binaan',
            value: notifKunjungan,
            onChanged: onToggleKunjungan,
          ),
          const Divider(height: 1, indent: 48, color: Color(0xFFF1F5F2)),

          _buildSwitchTile(
            icon: Icons.sync_problem_rounded,
            title: 'Notifikasi Sinkronisasi Laporan',
            subtitle: 'Pemberitahuan saat laporan offline berhasil diunggah',
            value: notifSinkron,
            onChanged: onToggleSinkron,
          ),
          const Divider(height: 1, indent: 48, color: Color(0xFFF1F5F2)),

          _buildSwitchTile(
            icon: Icons.campaign_outlined,
            title: 'Informasi & Pengumuman CDK V',
            subtitle: 'Surat edaran, materi baru, dan pengumuman dinas',
            value: notifPengumuman,
            onChanged: onTogglePengumuman,
          ),
          const Divider(height: 1, indent: 48, color: Color(0xFFF1F5F2)),
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
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.timer_outlined, size: 18, color: Color(0xFF285C2E)),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Waktu Alarm Pengingat',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E2923),
                          ),
                        ),
                        SizedBox(height: 1),
                        Text(
                          'Kapan pengingat jadwal dibunyikan',
                          style: TextStyle(fontSize: 11.5, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F8E9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFC8E6C9)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          reminderTime,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF285C2E),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down, size: 18, color: Color(0xFF285C2E)),
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
