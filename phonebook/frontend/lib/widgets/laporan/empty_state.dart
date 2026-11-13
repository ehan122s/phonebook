import 'package:flutter/material.dart';

/// Displayed when there are no reports in the history.
class LaporanEmptyState extends StatelessWidget {
  const LaporanEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E2822) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF2E3D34) : const Color(0xFFE0E7E1);
    final titleColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white60 : Colors.grey;
    final iconColor = isDark ? const Color(0xFF81C784) : const Color(0xFF9EAA9E);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 25,
        vertical: 45,
      ),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        children: [
          Icon(
            Icons.folder_open_outlined,
            size: 55,
            color: iconColor,
          ),
          const SizedBox(height: 15),
          Text(
            'Belum ada laporan',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Laporan yang Anda buat akan muncul di sini.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: subtitleColor,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
