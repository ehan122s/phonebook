// ============================================================================
// [FILE WIDGET 3 - KARTU ITEM JADWAL & RIWAYAT]
// Simpan file ini di: widgets/jadwal/jadwal_card.dart
// ============================================================================

import 'package:flutter/material.dart';
import '../../constants/jadwal_constants.dart';

/// Card representing a single schedule item in Either "Jadwal Terdekat" or "Riwayat".
class JadwalCard extends StatelessWidget {
  const JadwalCard({
    super.key,
    required this.jadwal,
    required this.today,
    required this.onTap,
    required this.onToggleComplete,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> jadwal;
  final DateTime today;
  final VoidCallback onTap;
  final VoidCallback onToggleComplete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final bool isCompleted = jadwal['isCompleted'] ?? false;
    final DateTime scheduleDate =
        JadwalDateUtils.parseIsoDate(jadwal['tanggalIso'] ?? '');
    final bool isToday = JadwalDateUtils.isSameDay(scheduleDate, today);

    final (String badgeLabel, Color badgeColor, Color badgeBg) = isCompleted
        ? ('Selesai', JadwalColors.completedText, JadwalColors.completedBg)
        : isToday
            ? ('Hari Ini', JadwalColors.timeBoxText, JadwalColors.timeBoxBg)
            : ('Terdekat', JadwalColors.upcomingText, JadwalColors.upcomingBg);

    final Color timeBg =
        isCompleted ? JadwalColors.completedBg : JadwalColors.timeBoxBg;
    final Color timeColor =
        isCompleted ? JadwalColors.completedText : JadwalColors.timeBoxText;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: JadwalColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: JadwalColors.borderCard),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left time badge (matches 08:00 / 13:00 blue card from screenshot)
                  Container(
                    width: 58,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: timeBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isCompleted
                              ? Icons.check_circle_outline_rounded
                              : Icons.access_time_rounded,
                          color: timeColor,
                          size: 20,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          jadwal['waktu'] ?? '08:00',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: timeColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Title, date, and location
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                jadwal['judul'] ?? '-',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: JadwalColors.textCard,
                                  decoration: isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: badgeBg,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                badgeLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: badgeColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 14,
                              color: JadwalColors.textIcon,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              JadwalDateUtils.formatTanggal(scheduleDate),
                              style: const TextStyle(
                                fontSize: 12,
                                color: JadwalColors.textSubtle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(
                              Icons.location_on_outlined,
                              size: 15,
                              color: JadwalColors.textIcon,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                jadwal['lokasi'] ?? '-',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: JadwalColors.textSubtle,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if ((jadwal['catatan'] ?? '').toString().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            jadwal['catatan'],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: JadwalColors.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(width: 6),
                  const Padding(
                    padding: EdgeInsets.only(top: 14),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: JadwalColors.textIcon,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1, color: JadwalColors.divider),
              const SizedBox(height: 10),

              // Quick action buttons
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: onToggleComplete,
                    icon: Icon(
                      isCompleted
                          ? Icons.replay_rounded
                          : Icons.check_rounded,
                      size: 16,
                    ),
                    label: Text(
                      isCompleted ? 'Kembalikan ke Aktif' : 'Tandai Selesai',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: JadwalColors.primary,
                      side: const BorderSide(color: JadwalColors.outlineGreen),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: JadwalColors.upcomingText,
                      side: BorderSide(color: Colors.orange.shade200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: const Text('Hapus'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}