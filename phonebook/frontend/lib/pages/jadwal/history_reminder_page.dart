// ============================================================================
// [HALAMAN HISTORY REMINDER - RIWAYAT JADWAL & PENGINGAT OTOMATIS]
// Simpan file ini di: lib/pages/jadwal/history_reminder_page.dart
// Perbaikan:
// - Menampilkan jam jadwal yang sebenarnya sesuai input pengguna (bukan 08:00).
// - Menampilkan interval reminder yang sebenarnya sesuai pilihan pengguna
//   (misal 5, 10, 15, 30, 60, atau 1440 menit sebelumnya, bukan tertimpa 30 menit).
// - Menampilkan jam pengingat akurat dalam zona waktu Asia/Jakarta (WIB).
// - Tombol Kembali di AppBar dan tombol Back bawaan Android berfungsi normal
//   mengarahkan kembali ke halaman Jadwal / halaman sebelumnya tanpa layar kosong.
// ============================================================================

import 'package:flutter/material.dart';

import '../../constants/jadwal_constants.dart';
import '../../services/jadwal_service.dart';
import '../../services/notification_service.dart';

class HistoryReminderPage extends StatefulWidget {
  final VoidCallback? onBack;

  const HistoryReminderPage({
    super.key,
    this.onBack,
  });

  @override
  State<HistoryReminderPage> createState() => _HistoryReminderPageState();
}

class _HistoryReminderPageState extends State<HistoryReminderPage> {
  static const Color green = Color(0xFF245C3A);
  static const Color secondaryGreen = Color(0xFF4F8A5B);
  static const Color lightGreen = Color(0xFFE8F2E8);
  static const Color softGreen = Color(0xFFF2F7F0);

  final List<Map<String, dynamic>> _schedules = [];
  String _selectedFilter = 'Semua';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final list = await JadwalService.loadSchedules();
      if (mounted) {
        setState(() {
          _schedules
            ..clear()
            ..addAll(list);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleBackButton() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else if (widget.onBack != null) {
      widget.onBack!();
    }
  }

  DateTime _getItemDate(Map<String, dynamic> item) {
    final rawDate = item['date'];
    if (rawDate is DateTime) return rawDate;
    final iso = (item['tanggalIso'] ?? item['date'] ?? '').toString();
    return JadwalDateUtils.parseIsoDate(iso);
  }

  List<Map<String, dynamic>> get _filteredHistory {
    final sorted = List<Map<String, dynamic>>.from(_schedules)
      ..sort((a, b) {
        final dateCompare = _getItemDate(b).compareTo(_getItemDate(a));
        if (dateCompare != 0) return dateCompare;
        final timeA = (a['waktu'] ?? a['time'] ?? '00:00').toString();
        final timeB = (b['waktu'] ?? b['time'] ?? '00:00').toString();
        return timeA.compareTo(timeB);
      });

    if (_selectedFilter == 'Semua') return sorted;

    return sorted.where((item) {
      final isCompleted = item['isCompleted'] == true;
      final isTriggered = NotificationService.instance.isReminderTriggered(item);
      if (_selectedFilter == 'Menunggu') {
        return !isCompleted && !isTriggered;
      }
      if (_selectedFilter == 'Sudah Diingatkan') {
        return isTriggered;
      }
      if (_selectedFilter == 'Selesai') {
        return isCompleted;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? const Color(0xFF121A15) : const Color(0xFFF7F9F6);
    final cardBg = isDark ? const Color(0xFF1E2822) : Colors.white;
    final cardBorder =
        isDark ? const Color(0xFF2E3D34) : const Color(0xFFE3ECE4);
    final textColor = isDark ? Colors.white : const Color(0xFF24352A);
    final subColor = isDark ? Colors.white70 : const Color(0xFF758278);

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
          final items = _filteredHistory;

          return Scaffold(
            backgroundColor: bgColor,
            body: SafeArea(
              child: Column(
                children: [
                  // Header dengan Tombol Kembali yang berfungsi normal
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
                    child: Row(
                      children: [
                        Material(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(13),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(13),
                            onTap: _handleBackButton,
                            child: SizedBox(
                              width: 46,
                              height: 46,
                              child: Icon(
                                Icons.arrow_back_rounded,
                                color: textColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'History Reminder',
                                style: TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              Text(
                                'Zona waktu: Asia/Jakarta (WIB)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: subColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _loadHistory,
                          tooltip: 'Muat ulang history reminder',
                          icon: Icon(
                            Icons.refresh_rounded,
                            color: isDark ? const Color(0xFF81C784) : green,
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
                      children: [
                        'Semua',
                        'Menunggu',
                        'Sudah Diingatkan',
                        'Selesai',
                      ].map((filter) {
                        final selected = _selectedFilter == filter;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(filter),
                            selected: selected,
                            selectedColor: green,
                            backgroundColor: cardBg,
                            labelStyle: TextStyle(
                              color: selected ? Colors.white : textColor,
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              fontSize: 12.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: selected ? green : cardBorder,
                              ),
                            ),
                            onSelected: (_) {
                              setState(() => _selectedFilter = filter);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Expanded(
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(color: green),
                          )
                        : items.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(28),
                                    decoration: BoxDecoration(
                                      color: cardBg,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: cardBorder),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.history_toggle_off_rounded,
                                          size: 46,
                                          color: isDark
                                              ? const Color(0xFF81C784)
                                              : green,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Belum Ada History Reminder',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: textColor,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Riwayat jadwal dan waktu pengingat yang Anda atur akan tampil di sini.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: subColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            : RefreshIndicator(
                                color: green,
                                onRefresh: _loadHistory,
                                child: ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                    18,
                                    4,
                                    18,
                                    32,
                                  ),
                                  itemCount: items.length,
                                  itemBuilder: (context, index) {
                                    final item = items[index];
                                    return _buildHistoryCard(
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

  Widget _buildHistoryCard({
    required Map<String, dynamic> item,
    required bool isDark,
    required Color cardBg,
    required Color cardBorder,
    required Color textColor,
    required Color subColor,
  }) {
    final itemDate = _getItemDate(item);
    final title = (item['judul'] ?? item['title'] ?? 'Kegiatan').toString();
    final category = (item['kategori'] ?? 'Penyuluhan').toString();
    final location = (item['lokasi'] ?? item['location'] ?? '-').toString();
    final scheduleTime =
        JadwalService.formatTimeString((item['waktu'] ?? item['time'] ?? '08:00').toString());
    final reminderMinutes =
        int.tryParse((item['reminderMinutes'] ?? 30).toString()) ?? 30;
    final reminderClock =
        JadwalDateUtils.calculateReminderTimeStr(scheduleTime, reminderMinutes);
    final reminderLabel =
        JadwalDateUtils.formatReminderIntervalLabel(reminderMinutes);
    final isCompleted = item['isCompleted'] == true;
    final isTriggered = NotificationService.instance.isReminderTriggered(item);

    final String statusText;
    final Color statusColor;
    if (isCompleted) {
      statusText = 'Selesai';
      statusColor = green;
    } else if (isTriggered) {
      statusText = 'Sudah Diingatkan';
      statusColor = const Color(0xFF1565C0);
    } else {
      statusText = 'Terjadwal ($reminderClock WIB)';
      statusColor = const Color(0xFFE65100);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
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
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF26352B) : softGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  category,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFF81C784) : green,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF162019) : softGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 16,
                      color: green,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tanggal: ${JadwalDateUtils.formatTanggal(itemDate)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time_filled_rounded,
                      size: 16,
                      color: green,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Jam Jadwal: $scheduleTime WIB',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.notifications_active_rounded,
                      size: 16,
                      color: secondaryGreen,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Reminder: $reminderLabel (Pukul $reminderClock WIB)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? const Color(0xFFA5D6A7)
                              : green,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: subColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Lokasi: $location',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: subColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
