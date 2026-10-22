// ============================================================================
// [FILE WIDGET 1 - KALENDER BESAR & BANNER JADWAL TERDEKAT]
// Simpan file ini di: widgets/jadwal/jadwal_calendar_card.dart
// ============================================================================

import 'package:flutter/material.dart';
import '../../constants/jadwal_constants.dart';

/// Main interactive calendar widget and nearest/today schedule highlight banner.
class JadwalCalendarCard extends StatelessWidget {
  const JadwalCalendarCard({
    super.key,
    required this.focusedMonth,
    required this.selectedDate,
    required this.today,
    required this.allSchedules,
    required this.nearestSchedule,
    required this.onSelectDate,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onResetToday,
    required this.onTapNearest,
  });

  final DateTime focusedMonth;
  final DateTime selectedDate;
  final DateTime today;
  final List<Map<String, dynamic>> allSchedules;
  final Map<String, dynamic>? nearestSchedule;
  final ValueChanged<DateTime> onSelectDate;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onResetToday;
  final VoidCallback? onTapNearest;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top selected-date pill (matches top bar in wireframe & green banner)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: JadwalColors.primaryLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: JadwalColors.outlineGreen),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: JadwalColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tanggal yang dipilih',
                      style: TextStyle(
                        fontSize: 12,
                        color: JadwalColors.textSubtle,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      JadwalDateUtils.formatHariTanggal(selectedDate),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: JadwalColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),
              if (!JadwalDateUtils.isSameDay(selectedDate, today))
                TextButton.icon(
                  onPressed: onResetToday,
                  icon: const Icon(Icons.today_rounded, size: 16),
                  label: const Text('Hari Ini'),
                  style: TextButton.styleFrom(
                    foregroundColor: JadwalColors.primary,
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Large main calendar card (the biggest element in the wireframe)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: JadwalColors.cardBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: JadwalColors.borderCard),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Month navigation header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.event_note_rounded,
                        color: JadwalColors.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        JadwalDateUtils.formatBulanTahun(focusedMonth),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: JadwalColors.textDark,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      _MonthNavButton(
                        icon: Icons.chevron_left_rounded,
                        onTap: onPrevMonth,
                      ),
                      const SizedBox(width: 6),
                      _MonthNavButton(
                        icon: Icons.chevron_right_rounded,
                        onTap: onNextMonth,
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Weekday headers (Sen - Min)
              Row(
                children: JadwalDateUtils.hariSingkat.map((hari) {
                  final isWeekend = hari == 'Sab' || hari == 'Min';
                  return Expanded(
                    child: Center(
                      child: Text(
                        hari,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isWeekend
                              ? Colors.red.shade400
                              : JadwalColors.textMuted,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 10),

              // Calendar days grid
              _buildCalendarGrid(),

              const SizedBox(height: 14),
              const Divider(height: 1, color: JadwalColors.divider),
              const SizedBox(height: 12),

              // Legend & Nearest / Today Schedule Highlight inside Calendar Card
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: const [
                  _LegendDot(
                    color: JadwalColors.timeBoxText,
                    label: 'Jadwal Aktif / Terdekat',
                  ),
                  _LegendDot(
                    color: JadwalColors.completedText,
                    label: 'Selesai (Riwayat)',
                  ),
                ],
              ),

              if (nearestSchedule != null) ...[
                const SizedBox(height: 14),
                _NearestScheduleBanner(
                  jadwal: nearestSchedule!,
                  today: today,
                  onTap: onTapNearest,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarGrid() {
    final firstDayOfMonth = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final daysInMonth =
        DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;

    // Monday = 1 ... Sunday = 7 -> leading empty cells = weekday - 1
    final int leadingEmpty = firstDayOfMonth.weekday - 1;
    final int totalCells = leadingEmpty + daysInMonth;
    final int rowCount = (totalCells / 7).ceil();

    return Column(
      children: List.generate(rowCount, (rowIndex) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: List.generate(7, (colIndex) {
              final cellIndex = rowIndex * 7 + colIndex;
              final dayNumber = cellIndex - leadingEmpty + 1;

              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const Expanded(child: SizedBox(height: 44));
              }

              final cellDate = DateTime(
                focusedMonth.year,
                focusedMonth.month,
                dayNumber,
              );
              final iso = JadwalDateUtils.toIsoDate(cellDate);
              final isSelected =
                  JadwalDateUtils.isSameDay(cellDate, selectedDate);
              final isToday = JadwalDateUtils.isSameDay(cellDate, today);

              // Find schedules on this day
              final daySchedules = allSchedules
                  .where((item) => item['tanggalIso'] == iso)
                  .toList();
              final hasActive = daySchedules
                  .any((item) => (item['isCompleted'] ?? false) == false);
              final hasCompleted = daySchedules
                  .any((item) => (item['isCompleted'] ?? false) == true);

              return Expanded(
                child: GestureDetector(
                  onTap: () => onSelectDate(cellDate),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    height: 44,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? JadwalColors.primary
                          : isToday
                              ? JadwalColors.primaryLight
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(11),
                      border: isToday && !isSelected
                          ? Border.all(
                              color: JadwalColors.primary,
                              width: 1.4,
                            )
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$dayNumber',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected || isToday
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : isToday
                                    ? JadwalColors.primary
                                    : JadwalColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 3),
                        if (daySchedules.isNotEmpty)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (hasActive)
                                Container(
                                  width: 5,
                                  height: 5,
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 1),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white
                                        : JadwalColors.timeBoxText,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              if (hasCompleted)
                                Container(
                                  width: 5,
                                  height: 5,
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 1),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white70
                                        : JadwalColors.completedText,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          )
                        else
                          const SizedBox(height: 5),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }
}

class _MonthNavButton extends StatelessWidget {
  const _MonthNavButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: JadwalColors.pageBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: JadwalColors.borderCard),
        ),
        child: Icon(icon, size: 20, color: JadwalColors.textDark),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: JadwalColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _NearestScheduleBanner extends StatelessWidget {
  const _NearestScheduleBanner({
    required this.jadwal,
    required this.today,
    this.onTap,
  });

  final Map<String, dynamic> jadwal;
  final DateTime today;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheduleDate =
        JadwalDateUtils.parseIsoDate(jadwal['tanggalIso'] ?? '');
    final isToday = JadwalDateUtils.isSameDay(scheduleDate, today);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isToday ? JadwalColors.timeBoxBg : JadwalColors.upcomingBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.notifications_active_outlined,
                    size: 18,
                    color: isToday
                        ? JadwalColors.timeBoxText
                        : JadwalColors.upcomingText,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    jadwal['waktu'] ?? '08:00',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isToday
                          ? JadwalColors.timeBoxText
                          : JadwalColors.upcomingText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isToday
                        ? 'JADWAL HARI INI TERDEKAT'
                        : 'JADWAL TERDEKAT BERIKUTNYA',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: isToday
                          ? JadwalColors.timeBoxText
                          : JadwalColors.upcomingText,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    jadwal['judul'] ?? '-',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: JadwalColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${JadwalDateUtils.formatTanggal(scheduleDate)} • ${jadwal['lokasi'] ?? '-'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: JadwalColors.textSubtle,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: JadwalColors.textSubtle,
            ),
          ],
        ),
      ),
    );
  }
}