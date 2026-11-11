import 'package:flutter/material.dart';
import '../../constants/laporan_constants.dart';

/// Custom segmented tab bar for switching between History and Templates.
class LaporanTabBar extends StatelessWidget {
  const LaporanTabBar({
    super.key,
    required this.selectedTab,
    required this.onTabChanged,
  });

  final int selectedTab;
  final ValueChanged<int> onTabChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final containerBg = isDark ? const Color(0xFF1E2822) : LaporanColors.tabBackground;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(14),
        border: isDark ? Border.all(color: const Color(0xFF2E3D34)) : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              title: 'Riwayat Laporan',
              icon: Icons.history_rounded,
              isActive: selectedTab == 0,
              onTap: () => onTabChanged(0),
            ),
          ),
          Expanded(
            child: _TabButton(
              title: 'Jenis Laporan',
              icon: Icons.category_outlined,
              isActive: selectedTab == 1,
              onTap: () => onTabChanged(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.title,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeBg = isDark ? const Color(0xFF26352B) : Colors.white;
    final activeColor = isDark ? const Color(0xFF81C784) : LaporanColors.primary;
    final inactiveColor = isDark ? Colors.white60 : Colors.grey.shade600;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
        decoration: BoxDecoration(
          color: isActive ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                    blurRadius: 6,
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
              size: 19,
              color: isActive ? activeColor : inactiveColor,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      isActive ? FontWeight.bold : FontWeight.w500,
                  color: isActive ? activeColor : inactiveColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
