import 'package:flutter/material.dart';

class ProfileSyncStatus extends StatelessWidget {
  final bool isOnline;
  final bool isSyncing;
  final int pendingCount;
  final String lastSyncTime;
  final VoidCallback onSyncNow;

  const ProfileSyncStatus({
    super.key,
    required this.isOnline,
    required this.isSyncing,
    required this.pendingCount,
    required this.lastSyncTime,
    required this.onSyncNow,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusTitle;
    String statusSubtitle;
    IconData statusIcon;

    if (isSyncing) {
      statusColor = const Color(0xFF1565C0);
      statusTitle = 'Sedang Menyinkronkan...';
      statusSubtitle = 'Mengirim data laporan lokal ke server CDK V';
      statusIcon = Icons.sync_rounded;
    } else if (pendingCount == 0) {
      statusColor = const Color(0xFF2E7D32);
      statusTitle = 'Semua Laporan Tersinkronisasi';
      statusSubtitle = isOnline
          ? 'Data di HP dan server pusat CDK V sudah cocok'
          : 'Semua draft lokal telah terkirim sebelum offline';
      statusIcon = Icons.cloud_done_rounded;
    } else {
      statusColor = isOnline ? const Color(0xFFE65100) : const Color(0xFFC62828);
      statusTitle = '$pendingCount Laporan Belum Disinkronkan';
      statusSubtitle = isOnline
          ? 'Ketuk tombol di bawah untuk kirim ke server'
          : 'Tersimpan aman di HP. Hubungkan internet untuk sinkron';
      statusIcon = isOnline ? Icons.cloud_upload_outlined : Icons.cloud_off_rounded;
    }

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
          // Baris Judul & Indikator Online/Offline
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isOnline
                      ? const Color(0xFFE8F5E9)
                      : const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                  size: 20,
                  color: isOnline
                      ? const Color(0xFF285C2E)
                      : const Color(0xFFE65100),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Status Koneksi & Sinkronisasi',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E2923),
                      ),
                    ),
                    Text(
                      isOnline
                          ? 'Perangkat Terhubung ke Internet'
                          : 'Mode Offline (Penyimpanan Lokal Aktif)',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isOnline
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFE65100),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // Pill Status
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isOnline ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isOnline ? const Color(0xFFC8E6C9) : const Color(0xFFFFCDD2),
                  ),
                ),
                child: Text(
                  isOnline ? 'ONLINE' : 'OFFLINE',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: isOnline ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Card Informasi Sinkronisasi
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: statusColor.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                isSyncing
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: statusColor,
                        ),
                      )
                    : Icon(statusIcon, color: statusColor, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusTitle,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        statusSubtitle,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey.shade700,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Waktu Sinkronisasi Terakhir
          Row(
            children: [
              Icon(Icons.history_rounded, size: 15, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(
                'Sinkronisasi Terakhir: ',
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
              ),
              Expanded(
                child: Text(
                  lastSyncTime.isNotEmpty ? lastSyncTime : 'Belum pernah sinkron',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E2923),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Tombol Sinkronkan Sekarang
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: isSyncing ? null : onSyncNow,
              icon: isSyncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.sync_rounded, size: 20),
              label: Text(
                isSyncing
                    ? 'Menyinkronkan...'
                    : (pendingCount > 0
                        ? 'Sinkronkan $pendingCount Laporan Sekarang'
                        : 'Sinkronkan Sekarang'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF285C2E),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
