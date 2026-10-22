// ============================================================================
// [FILE WIDGET 2 - TAB JADWAL TERDEKAT vs RIWAYAT & TOMBOL FILTER]
// Simpan file ini di: widgets/jadwal/jadwal_filter_bar.dart
// ============================================================================

import 'package:flutter/material.dart';
import '../../constants/jadwal_constants.dart';

/// Filter and action bar below the calendar, matching the wireframe layout:
/// left tab/category selector + right quick action buttons, followed by subtitle.
class JadwalFilterBar extends StatelessWidget {
  const JadwalFilterBar({
    super.key,
    required this.selectedTab,
    required this.showOnlySelectedDate,
    required this.subtitleText,
    required this.onTabChanged,
    required this.onToggleDateFilter,
    required this.onAddJadwal,
  });

  /// 0 = Jadwal (Hari Ini & Terdekat), 1 = Riwayat
  final int selectedTab;
  final bool showOnlySelectedDate;
  final String subtitleText;
  final ValueChanged<int> onTabChanged;
  final VoidCallback onToggleDateFilter;
  final VoidCallback onAddJadwal;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row matching wireframe: Left pill switcher + 2 right action buttons
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8EFE8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _TabPill(
                        icon: Icons.event_available_rounded,
                        label: 'Jadwal Terdekat',
                        isSelected: selectedTab == 0,
                        onTap: () => onTabChanged(0),
                      ),
                    ),
                    Expanded(
                      child: _TabPill(
                        icon: Icons.history_rounded,
                        label: 'Riwayat',
                        isSelected: selectedTab == 1,
                        onTap: () => onTabChanged(1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Button 1: Filter tanggal dipilih vs Semua jadwal
            Tooltip(
              message: showOnlySelectedDate
                  ? 'Tampilkan Semua Tanggal'
                  : 'Filter Tanggal Dipilih',
              child: InkWell(
                onTap: onToggleDateFilter,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: showOnlySelectedDate
                        ? JadwalColors.primary
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: showOnlySelectedDate
                          ? JadwalColors.primary
                          : JadwalColors.borderCard,
                    ),
                  ),
                  child: Icon(
                    Icons.filter_list_rounded,
                    size: 20,
                    color: showOnlySelectedDate
                        ? Colors.white
                        : JadwalColors.textDark,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Button 2: Tambah Jadwal Baru
            Tooltip(
              message: 'Tambah Jadwal',
              child: InkWell(
                onTap: onAddJadwal,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: JadwalColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    size: 22,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Section title & subtitle (matches the label bar above the 3 cards in wireframe)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedTab == 0
                        ? (showOnlySelectedDate
                            ? 'Kegiatan pada Tanggal Dipilih'
                            : 'Kegiatan Hari Ini & Jadwal Terdekat')
                        : 'Riwayat Kegiatan Selesai',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: JadwalColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitleText,
                    style: const TextStyle(
                      fontSize: 13,
                      color: JadwalColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (showOnlySelectedDate)
              TextButton(
                onPressed: onToggleDateFilter,
                child: const Text(
                  'Lihat Semua',
                  style: TextStyle(
                    color: JadwalColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? JadwalColors.primary : JadwalColors.textMuted,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color:
                      isSelected ? JadwalColors.primary : JadwalColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}