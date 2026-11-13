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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String status = laporan['status'];
    final bool isOffline = laporan['isOffline'] == true;
    final String? syncStatus = laporan['syncStatus']?.toString();

    final (Color statusColor, Color statusBg) = switch (status) {
      'Selesai' => (
        isDark ? const Color(0xFF81C784) : LaporanColors.statusComplete,
        isDark ? const Color(0xFF1B3B22) : LaporanColors.statusCompleteBg,
      ),
      'Diproses' => (
        isDark ? const Color(0xFFFFB74D) : LaporanColors.statusProcess,
        isDark ? const Color(0xFF3B2B11) : LaporanColors.statusProcessBg,
      ),
      _ => (
        isDark ? Colors.white70 : LaporanColors.statusDraft,
        isDark ? const Color(0xFF2D3530) : LaporanColors.statusDraftBg,
      ),
    };

    final cardBg = isDark ? const Color(0xFF1E2822) : LaporanColors.cardBackground;
    final cardBorder = isDark ? const Color(0xFF2E3D34) : LaporanColors.borderCard;
    final iconBg = isDark ? const Color(0xFF26352B) : LaporanColors.greenBackground;
    final primaryGreen = isDark ? const Color(0xFF81C784) : LaporanColors.primary;
    final titleColor = isDark ? Colors.white : LaporanColors.textCard;
    final mutedColor = isDark ? Colors.white70 : LaporanColors.textMuted;
    final dividerColor = isDark ? const Color(0xFF2E3D34) : LaporanColors.divider;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.035),
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
                  color: iconBg,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.description_outlined,
                  color: primaryGreen,
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
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      laporan['jenis'],
                      style: TextStyle(
                        fontSize: 12,
                        color: mutedColor,
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
                            ? (isDark ? const Color(0xFF3B1515) : Colors.red.shade50)
                            : (isDark ? const Color(0xFF332005) : Colors.orange.shade50),
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
                                ? (isDark ? const Color(0xFFEF9A9A) : Colors.red.shade600)
                                : (isDark ? const Color(0xFFFFB74D) : Colors.orange.shade700),
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
                                  ? (isDark ? const Color(0xFFEF9A9A) : Colors.red.shade600)
                                  : (isDark ? const Color(0xFFFFB74D) : Colors.orange.shade700),
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
          Divider(height: 1, color: dividerColor),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(
          icon,
          size: iconSize,
          color: isDark ? const Color(0xFF81C784) : LaporanColors.textIcon,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : LaporanColors.textSubtle,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: onView,
          icon: const Icon(Icons.visibility_outlined, size: 18),
          label: const Text('Lihat'),
          style: OutlinedButton.styleFrom(
            foregroundColor: isDark ? const Color(0xFF81C784) : LaporanColors.primary,
            side: BorderSide(color: isDark ? const Color(0xFF388E3C) : LaporanColors.outlineGreen),
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
              foregroundColor: isDark ? const Color(0xFFFFB74D) : LaporanColors.statusProcess,
              side: BorderSide(
                color: isDark ? const Color(0xFF8D6E63) : LaporanColors.statusProcessBorder,
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
              backgroundColor: isDark ? const Color(0xFF285C2E) : LaporanColors.primary,
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
              foregroundColor: isDark ? const Color(0xFFEF9A9A) : Colors.red.shade700,
              side: BorderSide(color: isDark ? const Color(0xFF5C2D32) : Colors.red.shade200),
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