import 'package:flutter/material.dart';
import '../../constants/laporan_constants.dart';

/// A card displaying a single report's summary in the history list.
class ReportCard extends StatelessWidget {
  const ReportCard({
    super.key,
    required this.laporan,
    required this.onView,
    required this.onEdit,
    required this.onDownload,
    this.onDelete,
  });

  final Map<String, dynamic> laporan;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDownload;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final String status = laporan['status'];
    final bool isOffline = laporan['isOffline'] == true;
    final String? syncStatus = laporan['syncStatus']?.toString();

    final (Color statusColor, Color statusBg) = switch (status) {
      'Selesai' => (
        LaporanColors.statusComplete,
        LaporanColors.statusCompleteBg,
      ),
      'Diproses' => (
        LaporanColors.statusProcess,
        LaporanColors.statusProcessBg,
      ),
      _ => (
        LaporanColors.statusDraft,
        LaporanColors.statusDraftBg,
      ),
    };

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: LaporanColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: LaporanColors.borderCard),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: LaporanColors.greenBackground,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: LaporanColors.primary,
                  size: 25,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      laporan['judul'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: LaporanColors.textCard,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      laporan['jenis'],
                      style: const TextStyle(
                        fontSize: 12,
                        color: LaporanColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isOffline)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: syncStatus == 'failed'
                            ? Colors.red.shade50
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            syncStatus == 'failed'
                                ? Icons.error_outline
                                : Icons.cloud_off_rounded,
                            size: 13,
                            color: syncStatus == 'failed'
                                ? Colors.red.shade600
                                : Colors.orange.shade700,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            syncStatus == 'failed'
                                ? 'Gagal'
                                : 'Offline',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: syncStatus == 'failed'
                                  ? Colors.red.shade600
                                  : Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  _StatusBadge(
                    status: status,
                    color: statusColor,
                    background: statusBg,
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(height: 1, color: LaporanColors.divider),
          const SizedBox(height: 13),

          // Date row
          _InfoRow(
            icon: Icons.calendar_today_outlined,
            text: laporan['tanggal'],
          ),
          const SizedBox(height: 8),

          // Location row
          _InfoRow(
            icon: Icons.location_on_outlined,
            text: laporan['lokasi'],
            iconSize: 17,
          ),

          const SizedBox(height: 16),

          // Action buttons
          _ActionButtons(
            status: status,
            onView: onView,
            onEdit: onEdit,
            onDownload: onDownload,
            onDelete: onDelete,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private helper widgets
// ---------------------------------------------------------------------------

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.status,
    required this.color,
    required this.background,
  });

  final String status;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.text,
    this.iconSize = 16,
  });

  final IconData icon;
  final String text;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: iconSize, color: LaporanColors.textIcon),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: LaporanColors.textSubtle,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.status,
    required this.onView,
    required this.onEdit,
    required this.onDownload,
    this.onDelete,
  });

  final String status;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDownload;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: onView,
          icon: const Icon(Icons.visibility_outlined, size: 18),
          label: const Text('Lihat'),
          style: OutlinedButton.styleFrom(
            foregroundColor: LaporanColors.primary,
            side: const BorderSide(color: LaporanColors.outlineGreen),
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(11),
            ),
          ),
        ),
        if (status == 'Draft')
          OutlinedButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Lanjutkan / Edit'),
            style: OutlinedButton.styleFrom(
              foregroundColor: LaporanColors.statusProcess,
              side: const BorderSide(
                color: LaporanColors.statusProcessBorder,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
          ),
        if (status == 'Selesai')
          ElevatedButton.icon(
            onPressed: onDownload,
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Unduh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: LaporanColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
          ),
        if (onDelete != null)
          OutlinedButton.icon(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Hapus'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade700,
              side: BorderSide(color: Colors.red.shade200),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
          ),
      ],
    );
  }
}