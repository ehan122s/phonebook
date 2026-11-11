import 'package:flutter/material.dart';
import '../../constants/laporan_constants.dart';

/// Card that triggers creating a new report.
class CreateReportCard extends StatelessWidget {
  const CreateReportCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E2822) : LaporanColors.cardBackground;
    final cardBorder = isDark ? const Color(0xFF2E3D34) : LaporanColors.borderLight;
    final iconBg = isDark ? const Color(0xFF26352B) : LaporanColors.greenBackgroundLight;
    final primaryColor = isDark ? const Color(0xFF81C784) : LaporanColors.primary;
    final titleColor = isDark ? Colors.white : LaporanColors.textTitle;
    final subColor = isDark ? Colors.white70 : Colors.grey;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.add_rounded,
                color: primaryColor,
                size: 34,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Buat Laporan Baru',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Isi laporan berdasarkan jenis kegiatan '
                    'yang dilakukan.',
                    style: TextStyle(
                      fontSize: 13,
                      color: subColor,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 18,
              color: primaryColor,
            ),
          ],
        ),
      ),
    );
  }
}
