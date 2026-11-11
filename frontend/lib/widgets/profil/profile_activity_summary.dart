import 'package:flutter/material.dart';

class ProfileActivitySummary extends StatelessWidget {
  final int totalLaporan;
  final int totalJadwal;
  final int totalMateri;
  final int totalPendingSync;
  final VoidCallback? onSyncTap;

  const ProfileActivitySummary({
    super.key,
    required this.totalLaporan,
    required this.totalJadwal,
    required this.totalMateri,
    required this.totalPendingSync,
    this.onSyncTap,
  });

  Widget _buildMetricCard({
    required BuildContext context,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color borderColor,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: iconColor.withValues(alpha: 0.15),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(icon, size: 18, color: iconColor),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E2923),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
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
                  Icons.insights_rounded,
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
                      'Ringkasan Aktivitas Saya',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E2923),
                      ),
                    ),
                    Text(
                      'Data riil kinerja di CDK Wilayah V',
                      style: TextStyle(fontSize: 11.5, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Grid 2x2
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  context: context,
                  title: 'Laporan Kegiatan',
                  value: '$totalLaporan',
                  subtitle: 'Tersimpan lokal & awan',
                  icon: Icons.assignment_outlined,
                  iconColor: const Color(0xFF2E7D32),
                  bgColor: const Color(0xFFF1F8E9),
                  borderColor: const Color(0xFFC8E6C9),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  context: context,
                  title: 'Jadwal Kegiatan',
                  value: '$totalJadwal',
                  subtitle: 'Agenda penyuluhan',
                  icon: Icons.calendar_month_outlined,
                  iconColor: const Color(0xFF1565C0),
                  bgColor: const Color(0xFFE3F2FD),
                  borderColor: const Color(0xFFBBDEFB),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  context: context,
                  title: 'Materi Edukasi',
                  value: '$totalMateri',
                  subtitle: 'PDF, PPT & modul',
                  icon: Icons.auto_stories_outlined,
                  iconColor: const Color(0xFFE65100),
                  bgColor: const Color(0xFFFFF3E0),
                  borderColor: const Color(0xFFFFCC80),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  context: context,
                  title: 'Antrean Sinkron',
                  value: '$totalPendingSync',
                  subtitle: totalPendingSync == 0
                      ? 'Semua tersinkron'
                      : 'Perlu sinkronisasi',
                  icon: totalPendingSync == 0
                      ? Icons.cloud_done_rounded
                      : Icons.cloud_upload_outlined,
                  iconColor: totalPendingSync == 0
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFFC2185B),
                  bgColor: totalPendingSync == 0
                      ? const Color(0xFFE8F5E9)
                      : const Color(0xFFFCE4EC),
                  borderColor: totalPendingSync == 0
                      ? const Color(0xFFC8E6C9)
                      : const Color(0xFFF8BBD0),
                  onTap: onSyncTap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
