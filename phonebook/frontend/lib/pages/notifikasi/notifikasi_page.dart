// ============================================================================
// [HALAMAN NOTIFIKASI - PENGELOLAAN NOTIFIKASI PENGGUNA]
// Simpan file ini di: lib/pages/notifikasi/notifikasi_page.dart
// Fitur:
// - Menampilkan daftar notifikasi (Laporan baru, Jadwal baru, Pengingat/Reminder, Sinkronisasi)
// - Hapus Semua Notifikasi dengan Dialog Konfirmasi ("Apakah Anda yakin ingin menghapus semua notifikasi?")
//   beserta tombol Batal dan Hapus.
// - Hapus Notifikasi Satu per Satu (Ikon Tempat Sampah & Swipe-to-Dismiss).
// - Empty state otomatis ketika tidak ada notifikasi tersisa.
// - Badge indikator jumlah notifikasi diperbarui secara real-time.
// - Penghapusan persisten (tidak muncul kembali setelah aplikasi ditutup & dibuka kembali)
//   serta tidak menghapus data Laporan maupun Jadwal aslinya.
// ============================================================================

import 'package:flutter/material.dart';

import '../../constants/jadwal_constants.dart';
import '../../services/notification_service.dart';

class NotificationPage extends StatefulWidget {
  final VoidCallback? onBack;

  const NotificationPage({
    super.key,
    this.onBack,
  });

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  static const Color kPrimary = Color(0xFF245C3A);
  static const Color kSecondary = Color(0xFF4F8A5B);
  static const Color kLightGreen = Color(0xFFE8F2E8);
  static const Color kSoftGreen = Color(0xFFF2F7F0);
  static const Color kBackground = Color(0xFFF7F9F6);
  static const Color kTextPrimary = Color(0xFF24352A);
  static const Color kTextSecondary = Color(0xFF758278);

  String _selectedFilter = 'Semua';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _refreshNotifications();
  }

  Future<void> _refreshNotifications() async {
    setState(() => _isLoading = true);
    await NotificationService.instance.loadNotifications();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _handleBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else if (widget.onBack != null) {
      widget.onBack!();
    }
  }

  /// Dialog Konfirmasi Hapus Semua Notifikasi
  Future<void> _confirmDeleteAll() async {
    if (NotificationService.instance.totalCount == 0) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1E2822) : Colors.white;
    final titleColor = isDark ? Colors.white : kTextPrimary;
    final bodyColor = isDark ? Colors.white70 : kTextSecondary;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.delete_sweep_rounded,
                color: Colors.red,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Hapus Semua Notifikasi',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus semua notifikasi?\n\n'
          'Tindakan ini hanya menghapus daftar notifikasi dan tidak akan menghapus data laporan maupun jadwal asli Anda.',
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: bodyColor,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            style: OutlinedButton.styleFrom(
              foregroundColor: titleColor,
              side: BorderSide(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            ),
            child: const Text(
              'Batal',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
            ),
            child: const Text(
              'Hapus',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await NotificationService.instance.deleteAllNotifications();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: kPrimary,
          content: Text('Seluruh notifikasi berhasil dihapus.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Hapus satu notifikasi secara individual
  Future<void> _deleteSingleNotification(Map<String, dynamic> item) async {
    final id = (item['id'] ?? '').toString();
    final title = (item['title'] ?? 'Notifikasi').toString();
    await NotificationService.instance.deleteNotification(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: kPrimary,
        content: Text('Notifikasi "$title" berhasil dihapus.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type.toLowerCase()) {
      case 'laporan':
        return Icons.description_rounded;
      case 'jadwal':
        return Icons.calendar_month_rounded;
      case 'reminder':
        return Icons.notifications_active_rounded;
      case 'sinkronisasi':
        return Icons.cloud_done_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _accentColorForType(String type, bool isDark) {
    switch (type.toLowerCase()) {
      case 'laporan':
        return isDark ? const Color(0xFF81C784) : kPrimary;
      case 'jadwal':
        return isDark ? const Color(0xFF64B5F6) : const Color(0xFF1565C0);
      case 'reminder':
        return isDark ? const Color(0xFFFFB74D) : const Color(0xFFE65100);
      default:
        return isDark ? const Color(0xFFA5D6A7) : kSecondary;
    }
  }

  String _labelForType(String type) {
    switch (type.toLowerCase()) {
      case 'laporan':
        return 'Laporan';
      case 'jadwal':
        return 'Jadwal';
      case 'reminder':
        return 'Pengingat';
      case 'sinkronisasi':
        return 'Sinkronisasi';
      default:
        return 'Info';
    }
  }

  String _formatTimestamp(String rawIso) {
    final parsed = DateTime.tryParse(rawIso);
    if (parsed == null) return rawIso;
    final dt = parsed.isUtc ? parsed.add(JadwalDateUtils.wibOffset) : parsed;
    final tanggal = JadwalDateUtils.formatTanggal(dt);
    final jam =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} WIB';
    return '$tanggal • $jam';
  }

  List<Map<String, dynamic>> _filteredItems(List<Map<String, dynamic>> all) {
    if (_selectedFilter == 'Semua') return all;
    return all.where((item) {
      final type = (item['type'] ?? 'umum').toString().toLowerCase();
      if (_selectedFilter == 'Laporan') return type == 'laporan';
      if (_selectedFilter == 'Jadwal') return type == 'jadwal';
      if (_selectedFilter == 'Pengingat') return type == 'reminder';
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121A15) : kBackground;
    final cardBg = isDark ? const Color(0xFF1E2822) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF2E3D34) : const Color(0xFFE3ECE4);
    final textColor = isDark ? Colors.white : kTextPrimary;
    final subColor = isDark ? Colors.white70 : kTextSecondary;
    final primaryGreen = isDark ? const Color(0xFF81C784) : kPrimary;

    return PopScope(
      canPop: Navigator.of(context).canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && widget.onBack != null) {
          widget.onBack!();
        }
      },
      child: ListenableBuilder(
        listenable: NotificationService.instance,
        builder: (context, _) {
          final allNotifications = NotificationService.instance.notifications;
          final filtered = _filteredItems(allNotifications);
          final totalCount = allNotifications.length;

          return Scaffold(
            backgroundColor: bgColor,
            body: SafeArea(
              child: Column(
                children: [
                  // Header Bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
                    child: Row(
                      children: [
                        Material(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(13),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(13),
                            onTap: _handleBack,
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: Icon(
                                Icons.arrow_back_rounded,
                                color: textColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'Notifikasi',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: totalCount > 0
                                      ? primaryGreen
                                      : (isDark
                                          ? const Color(0xFF26352B)
                                          : kLightGreen),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '$totalCount',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: totalCount > 0
                                        ? (isDark
                                            ? const Color(0xFF121814)
                                            : Colors.white)
                                        : primaryGreen,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (totalCount > 0)
                          TextButton.icon(
                            onPressed: _confirmDeleteAll,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red.shade600,
                              backgroundColor:
                                  Colors.red.withValues(alpha: 0.10),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(
                              Icons.delete_sweep_rounded,
                              size: 18,
                            ),
                            label: const Text(
                              'Hapus Semua',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Filter Chips
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      children:
                          ['Semua', 'Laporan', 'Jadwal', 'Pengingat'].map((f) {
                        final selected = _selectedFilter == f;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(f),
                            selected: selected,
                            selectedColor: kPrimary,
                            backgroundColor: cardBg,
                            labelStyle: TextStyle(
                              color: selected ? Colors.white : textColor,
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              fontSize: 13,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: selected ? kPrimary : cardBorder,
                              ),
                            ),
                            onSelected: (_) {
                              setState(() => _selectedFilter = f);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Content List or Empty State
                  Expanded(
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(color: kPrimary),
                          )
                        : filtered.isEmpty
                            ? _buildEmptyState(isDark, textColor, subColor)
                            : RefreshIndicator(
                                color: kPrimary,
                                onRefresh: _refreshNotifications,
                                child: ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                    18,
                                    4,
                                    18,
                                    32,
                                  ),
                                  itemCount: filtered.length,
                                  itemBuilder: (context, index) {
                                    final item = filtered[index];
                                    return _buildNotificationCard(
                                      item: item,
                                      isDark: isDark,
                                      cardBg: cardBg,
                                      cardBorder: cardBorder,
                                      textColor: textColor,
                                      subColor: subColor,
                                    );
                                  },
                                ),
                              ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, Color textColor, Color subColor) {
    final cardBg = isDark ? const Color(0xFF1E2822) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF2E3D34) : const Color(0xFFE3ECE4);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: cardBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF26352B) : kLightGreen,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.notifications_off_outlined,
                  size: 34,
                  color: isDark ? const Color(0xFF81C784) : kPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Tidak Ada Notifikasi',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _selectedFilter == 'Semua'
                    ? 'Seluruh notifikasi Anda sudah bersih.\nNotifikasi baru akan muncul saat Anda membuat laporan, membuat jadwal, atau ketika waktu pengingat tiba.'
                    : 'Belum ada notifikasi pada kategori $_selectedFilter.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: subColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard({
    required Map<String, dynamic> item,
    required bool isDark,
    required Color cardBg,
    required Color cardBorder,
    required Color textColor,
    required Color subColor,
  }) {
    final id = (item['id'] ?? '').toString();
    final type = (item['type'] ?? 'umum').toString();
    final title = (item['title'] ?? 'Notifikasi').toString();
    final message = (item['message'] ?? '').toString();
    final createdAt = (item['createdAt'] ?? '').toString();
    final isRead = item['isRead'] == true;
    final accentColor = _accentColorForType(type, isDark);

    return Dismissible(
      key: ValueKey('notif_item_$id'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: Colors.red.shade600,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.white),
            SizedBox(width: 6),
            Text(
              'Hapus',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      onDismissed: (_) => _deleteSingleNotification(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isRead
                ? cardBorder
                : accentColor.withValues(alpha: 0.40),
            width: isRead ? 1.0 : 1.3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              if (!isRead) {
                NotificationService.instance.markAsRead(id);
              }
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _iconForType(type),
                      color: accentColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _labelForType(type),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: accentColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (!isRead)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: accentColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          message,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: subColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 13,
                              color: subColor,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _formatTimestamp(createdAt),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: subColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Hapus notifikasi ini',
                    onPressed: () => _deleteSingleNotification(item),
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red.shade400,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
