import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_update_service.dart';

/// Dialog pop-up pembaruan aplikasi modern, elegan, dan adaptif tema (Light/Dark).
class AppUpdateDialog extends StatefulWidget {
  final AppUpdateInfo updateInfo;
  final String currentVersion;

  const AppUpdateDialog({
    super.key,
    required this.updateInfo,
    required this.currentVersion,
  });

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  bool _isLaunching = false;

  Future<void> _handleUpdate() async {
    final apkUrl = widget.updateInfo.apkUrl.trim();
    if (apkUrl.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tautan unduhan APK tidak valid.')),
        );
      }
      return;
    }

    setState(() => _isLaunching = true);

    try {
      final uri = Uri.parse(apkUrl);
      final canLaunch = await canLaunchUrl(uri);

      if (canLaunch) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback coba buka browser platform default
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text('Gagal membuka link download: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLaunching = false);
      }
    }
  }

  void _handleDismiss() {
    AppUpdateService.instance.dismissUpdate(widget.updateInfo.version);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMandatory = widget.updateInfo.isMandatory;

    // Warna tema khas Phonebook
    final primaryColor = const Color(0xFF245C3A);
    final accentGreen = const Color(0xFF2E7D32);
    final bgColor = isDark ? const Color(0xFF1E2822) : Colors.white;
    final cardBg = isDark ? const Color(0xFF27362C) : const Color(0xFFF3F7F4);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1F2E23);
    final textSecondary = isDark ? const Color(0xFFBAC7BD) : const Color(0xFF5D6B60);

    final content = Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 16,
      backgroundColor: bgColor,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Icon & Status Chip
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: isMandatory
                            ? [const Color(0xFFE53935), const Color(0xFFC62828)]
                            : [accentGreen, primaryColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isMandatory ? const Color(0xFFE53935) : primaryColor).withValues(alpha: 0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      isMandatory ? Icons.warning_rounded : Icons.rocket_launch_rounded,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Badge Tipe Update
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: isMandatory
                      ? const Color(0xFFFFEBEE)
                      : (isDark ? const Color(0xFF2A4232) : const Color(0xFFE8F5E9)),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isMandatory
                        ? const Color(0xFFEF5350).withValues(alpha: 0.5)
                        : primaryColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isMandatory ? Icons.error_outline_rounded : Icons.new_releases_outlined,
                      size: 14,
                      color: isMandatory ? const Color(0xFFC62828) : primaryColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isMandatory ? 'Pembaruan Wajib' : 'Pembaruan Tersedia',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isMandatory ? const Color(0xFFC62828) : primaryColor,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Judul Pembaruan
            Text(
              widget.updateInfo.title.isNotEmpty
                  ? widget.updateInfo.title
                  : 'Pembaruan Aplikasi Phonebook',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: textPrimary,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 8),

            // Indikator Versi (v1.0.0 -> v1.2.0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Versi saat ini: v${widget.currentVersion}',
                    style: TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 14, color: textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    'Terbaru: v${widget.updateInfo.version}',
                    style: TextStyle(fontSize: 12, color: primaryColor, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Catatan Perubahan (Changelog)
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.format_list_bulleted_rounded, size: 16, color: primaryColor),
                        const SizedBox(width: 6),
                        Text(
                          'Catatan Pembaruan:',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 160),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Text(
                          widget.updateInfo.description.isNotEmpty
                              ? widget.updateInfo.description
                              : 'Peningkatan performa, perbaikan bug sistem, dan kestabilan aplikasi.',
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.45,
                            color: textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (isMandatory) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, size: 15, color: Color(0xFFC62828)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Pembaruan ini wajib dilakukan untuk melanjutkan penggunaan aplikasi Phonebook.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? const Color(0xFFEF9A9A) : const Color(0xFFC62828),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 20),

            // Tombol Aksi
            Row(
              children: [
                if (!isMandatory) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _handleDismiss,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: BorderSide(
                          color: isDark ? Colors.white24 : Colors.grey.shade400,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Nanti Saja',
                        style: TextStyle(
                          color: textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: isMandatory ? 2 : 1,
                  child: ElevatedButton(
                    onPressed: _isLaunching ? null : _handleUpdate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLaunching
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.download_rounded, size: 18),
                              SizedBox(width: 6),
                              Text(
                                'Update Sekarang',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    // Kunci tombol Back Android jika update wajib (mandatory)
    if (isMandatory) {
      return PopScope(
        canPop: false,
        child: content,
      );
    }

    return content;
  }
}
