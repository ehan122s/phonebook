import 'package:flutter/material.dart';
import '../../constants/laporan_constants.dart';

/// Card that triggers creating a new report.
class CreateReportCard extends StatelessWidget {
  const CreateReportCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: LaporanColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: LaporanColors.borderLight),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
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
                color: LaporanColors.greenBackgroundLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: LaporanColors.primary,
                size: 34,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Buat Laporan Baru',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: LaporanColors.textTitle,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Isi laporan berdasarkan jenis kegiatan '
                    'yang dilakukan.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 18,
              color: LaporanColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}
