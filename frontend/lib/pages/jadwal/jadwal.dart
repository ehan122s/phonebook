// ============================================================================
// Simpan file ini di: lib/pages/jadwal/jadwal.dart
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';

import '../../constants/jadwal_constants.dart';
import '../../services/jadwal_service.dart';
import '../../services/notification_service.dart';
import '../../services/whatsapp_reminder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../notifikasi/notifikasi_page.dart';
import 'history_reminder_page.dart';

class JadwalPage extends StatefulWidget {
  final VoidCallback? onBack;
  final Function(int)? onNavigate;
  final String? initialScheduleId;
  final String? initialScheduleTitle;

  const JadwalPage({
    super.key,
    this.onBack,
    this.onNavigate,
    this.initialScheduleId,
    this.initialScheduleTitle,
  });

  @override
  State<JadwalPage> createState() => _JadwalPageState();
}

class _JadwalPageState extends State<JadwalPage> {
  DateTime selectedDate = JadwalDateUtils.nowWib();
  DateTime displayedMonth = DateTime(
    JadwalDateUtils.nowWib().year,
    JadwalDateUtils.nowWib().month,
  );

  final searchController = TextEditingController();
  final List<Map<String, dynamic>> schedules = [];
  Timer? _reminderTimer;

  bool isLoading = false;
  bool _didOpenInitialSchedule = false;
  // Default: tampilkan SEMUA riwayat jadwal, bukan cuma 1 hari
  bool showAllHistory = true;

  static const green = Color(0xFF245C3A);
  static const secondaryGreen = Color(0xFF4F8A5B);
  static const lightGreen = Color(0xFFE8F2E8);
  static const softGreen = Color(0xFFF2F7F0);

  static const monthNames = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  static const dayNames = [
    'Sen',
    'Sel',
    'Rab',
    'Kam',
    'Jum',
    'Sab',
    'Min',
  ];

  static const List<Map<String, dynamic>> categoryOptions = [
    {'label': 'Penyuluhan', 'icon': Icons.campaign_rounded},
    {'label': 'Monitoring Hutan', 'icon': Icons.park_rounded},
    {'label': 'Patroli & Pengamanan', 'icon': Icons.shield_outlined},
    {'label': 'Rehabilitasi Lahan', 'icon': Icons.spa_rounded},
    {'label': 'Rapat Koordinasi', 'icon': Icons.groups_rounded},
    {'label': 'Sosialisasi Masyarakat', 'icon': Icons.record_voice_over_rounded},
  ];

  /// Pilihan interval reminder lengkap termasuk 5 menit, 10 menit, dan 30 menit sebelumnya
  static const List<Map<String, dynamic>> reminderOptions = [
    {'label': '5 Menit sebelum', 'minutes': 5},
    {'label': '10 Menit sebelum', 'minutes': 10},
    {'label': '15 Menit sebelum', 'minutes': 15},
    {'label': '30 Menit sebelum', 'minutes': 30},
    {'label': '1 Jam sebelum', 'minutes': 60},
    {'label': '1 Hari sebelum', 'minutes': 1440},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
    // Sinkronkan dengan global NotificationService setiap 15 detik
    _reminderTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _checkUpcomingReminders(),
    );
  }

  @override
  void dispose() {
    _reminderTimer?.cancel();
    searchController.dispose();
    super.dispose();
  }

  void _handleBackButton() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    if (widget.onBack != null) {
      widget.onBack!();
      return;
    }
    if (widget.onNavigate != null) {
      widget.onNavigate!(0);
      return;
    }
    if (!showAllHistory) {
      setState(() {
        showAllHistory = true;
      });
    }
  }

  void _openHistoryReminderPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const HistoryReminderPage(),
      ),
    );
  }

  void _openNotificationPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const NotificationPage(),
      ),
    );
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      final list = await JadwalService.loadSchedules();
      if (mounted) {
        setState(() {
          schedules
            ..clear()
            ..addAll(list);
          isLoading = false;
        });
        _checkAndOpenInitialSchedule();
        await NotificationService.instance.checkDueRemindersNow();
      }
    } catch (_) {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _checkAndOpenInitialSchedule() {
    if (_didOpenInitialSchedule) return;
    final targetId = widget.initialScheduleId?.trim();
    final targetTitle = widget.initialScheduleTitle?.trim().toLowerCase();
    if ((targetId == null || targetId.isEmpty) &&
        (targetTitle == null || targetTitle.isEmpty)) {
      return;
    }

    Map<String, dynamic>? matched;
    if (targetId != null && targetId.isNotEmpty) {
      for (final item in schedules) {
        if ((item['id'] ?? '').toString().trim() == targetId) {
          matched = item;
          break;
        }
      }
    }
    if (matched == null && targetTitle != null && targetTitle.isNotEmpty) {
      for (final item in schedules) {
        final t = (item['judul'] ?? item['title'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        if (t == targetTitle || t.contains(targetTitle)) {
          matched = item;
          break;
        }
      }
    }

    if (matched != null) {
      _didOpenInitialSchedule = true;
      final itemToOpen = matched;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showScheduleDetail(itemToOpen);
        }
      });
    }
  }

  Future<void> _checkUpcomingReminders() async {
    if (!mounted) return;
    await NotificationService.instance.checkDueRemindersNow();
  }

  DateTime _getItemDate(Map<String, dynamic> item) {
    final rawDate = item['date'];
    if (rawDate is DateTime) return rawDate;

    final iso = (item['tanggalIso'] ?? item['date'] ?? '').toString();
    if (iso.isNotEmpty) {
      return JadwalDateUtils.parseIsoDate(iso);
    }
    return JadwalDateUtils.nowWib();
  }

  String dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String formatDate(DateTime date) =>
      '${date.day} ${monthNames[date.month - 1]} ${date.year}';

  List<Map<String, dynamic>> get filteredSchedules {
    final query = searchController.text.toLowerCase().trim();

    return schedules.where((item) {
      final itemDate = _getItemDate(item);
      final matchesDate =
          showAllHistory ? true : dateKey(itemDate) == dateKey(selectedDate);

      final title =
          (item['title'] ?? item['judul'] ?? '').toString().toLowerCase();
      final location =
          (item['location'] ?? item['lokasi'] ?? '').toString().toLowerCase();
      final category = (item['kategori'] ?? '').toString().toLowerCase();

      final matchesSearch = query.isEmpty ||
          title.contains(query) ||
          location.contains(query) ||
          category.contains(query);

      return matchesDate && matchesSearch;
    }).toList()
      ..sort((a, b) {
        final dateCompare = _getItemDate(b).compareTo(_getItemDate(a));
        if (dateCompare != 0) return dateCompare;
        final timeA = (a['time'] ?? a['waktu'] ?? '00:00').toString();
        final timeB = (b['time'] ?? b['waktu'] ?? '00:00').toString();
        return timeA.compareTo(timeB);
      });
  }

  void changeMonth(int offset) {
    setState(() {
      displayedMonth = DateTime(
        displayedMonth.year,
        displayedMonth.month + offset,
      );
    });
  }

  void selectDay(int day) {
    setState(() {
      selectedDate = DateTime(
        displayedMonth.year,
        displayedMonth.month,
        day,
      );
      showAllHistory = false;
    });
  }

  // ===========================================================================
  // FORM TAMBAH / EDIT JADWAL MODERN (BOTTOM SHEET + KATEGORI + REMINDER WIB)
  // ===========================================================================
  Future<void> addSchedule({Map<String, dynamic>? existingItem}) async {
    final isEditing = existingItem != null;
    final nowWib = JadwalDateUtils.nowWib();
    final defaultInitialTime =
        '${nowWib.hour.toString().padLeft(2, '0')}:${nowWib.minute.toString().padLeft(2, '0')}';

    final initialTimeStr = isEditing
        ? JadwalService.formatTimeString(
            (existingItem['waktu'] ?? existingItem['time'] ?? defaultInitialTime)
                .toString(),
            fallback: defaultInitialTime,
          )
        : defaultInitialTime;

    final titleController = TextEditingController(
      text: isEditing
          ? (existingItem['judul'] ?? existingItem['title'] ?? '').toString()
          : '',
    );
    final locationController = TextEditingController(
      text: isEditing
          ? (existingItem['lokasi'] ?? existingItem['location'] ?? '').toString()
          : '',
    );
    final descriptionController = TextEditingController(
      text: isEditing
          ? (existingItem['catatan'] ?? existingItem['description'] ?? '')
              .toString()
          : '',
    );
    final timeController = TextEditingController(text: initialTimeStr);
    final prefs = await SharedPreferences.getInstance();
    final userPhone = prefs.getString('profil_whatsapp') ??
        prefs.getString('whatsapp_number') ??
        prefs.getString('telepon') ??
        prefs.getString('phone') ??
        '';

    final initialWaPhone = isEditing
        ? (existingItem['waPhone'] ??
                existingItem['wa_phone'] ??
                userPhone)
            .toString()
        : userPhone;

    final waPhoneController = TextEditingController(text: initialWaPhone);

    String selectedCategory = isEditing
        ? (existingItem['kategori'] ?? categoryOptions.first['label']).toString()
        : categoryOptions.first['label'] as String;
    if (!categoryOptions.any((c) => c['label'] == selectedCategory)) {
      selectedCategory = categoryOptions.first['label'] as String;
    }

    int selectedReminderMinutes = isEditing
        ? (int.tryParse((existingItem['reminderMinutes'] ?? 5).toString()) ??
            5)
        : 5;
    if (!reminderOptions.any((r) => r['minutes'] == selectedReminderMinutes)) {
      selectedReminderMinutes = 5;
    }

    bool enableWaNotification = isEditing
        ? (existingItem['enableWaNotification'] ?? true) == true
        : true;

    DateTime pickedDate = isEditing
        ? _getItemDate(existingItem)
        : DateTime(
            selectedDate.year,
            selectedDate.month,
            selectedDate.day,
          );

    final formKey = GlobalKey<FormState>();

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        final sheetBg = isDark ? const Color(0xFF1A241E) : Colors.white;
        final fieldBg = isDark ? const Color(0xFF243329) : softGreen;
        final textColor = isDark ? Colors.white : const Color(0xFF24352A);

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final currentPreviewTime = JadwalService.formatTimeString(
              timeController.text,
              fallback: initialTimeStr,
            );
            final previewReminderClock =
                JadwalDateUtils.calculateReminderTimeStr(
              currentPreviewTime,
              selectedReminderMinutes,
            );

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.90,
                ),
                decoration: BoxDecoration(
                  color: sheetBg,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag Handle
                    const SizedBox(height: 12),
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),

                    // Header Form Modern
                    Container(
                      margin: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [green, secondaryGreen],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.edit_calendar_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEditing
                                      ? 'Edit Jadwal Kegiatan'
                                      : 'Tambah Jadwal Kegiatan',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Atur rincian agenda & pengingat otomatis (WIB)',
                                  style: TextStyle(
                                    color: Color(0xFFE8F2E8),
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(sheetContext, false),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Isi Form
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        child: Form(
                          key: formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFormLabel('Nama Kegiatan *', textColor),
                              TextFormField(
                                controller: titleController,
                                style: TextStyle(color: textColor),
                                decoration: _modernInputDecoration(
                                  hint: 'Contoh: Penyuluhan Kelompok Tani Hutan',
                                  icon: Icons.assignment_outlined,
                                  fillColor: fieldBg,
                                  isDark: isDark,
                                ),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                        ? 'Nama kegiatan wajib diisi'
                                        : null,
                              ),

                              const SizedBox(height: 16),

                              // Pilihan Kategori (Interactive Chips)
                              _buildFormLabel(
                                'Pilih Kategori Kegiatan *',
                                textColor,
                              ),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: categoryOptions.map((cat) {
                                  final label = cat['label'] as String;
                                  final icon = cat['icon'] as IconData;
                                  final isSelected = selectedCategory == label;

                                  return ChoiceChip(
                                    avatar: Icon(
                                      icon,
                                      size: 17,
                                      color: isSelected
                                          ? Colors.white
                                          : (isDark
                                              ? const Color(0xFF81C784)
                                              : green),
                                    ),
                                    label: Text(label),
                                    selected: isSelected,
                                    selectedColor: green,
                                    backgroundColor: fieldBg,
                                    labelStyle: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : textColor,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: isSelected
                                            ? green
                                            : green.withValues(alpha: 0.2),
                                      ),
                                    ),
                                    onSelected: (_) {
                                      setSheetState(() {
                                        selectedCategory = label;
                                      });
                                    },
                                  );
                                }).toList(),
                              ),

                              const SizedBox(height: 16),

                              // Row Tanggal & Jam
                              Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildFormLabel('Tanggal *', textColor),
                                        InkWell(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          onTap: () async {
                                            final chosen = await showDatePicker(
                                              context: sheetContext,
                                              initialDate: pickedDate,
                                              firstDate: DateTime(2024),
                                              lastDate: DateTime(2030),
                                            );
                                            if (chosen != null) {
                                              setSheetState(
                                                () => pickedDate = chosen,
                                              );
                                            }
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 14,
                                            ),
                                            decoration: BoxDecoration(
                                              color: fieldBg,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              border: Border.all(
                                                color: green.withValues(
                                                  alpha: 0.2,
                                                ),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.calendar_today_rounded,
                                                  size: 18,
                                                  color: isDark
                                                      ? const Color(0xFF81C784)
                                                      : green,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    formatDate(pickedDate),
                                                    style: TextStyle(
                                                      fontSize: 13.5,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: textColor,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildFormLabel(
                                          'Waktu (WIB) *',
                                          textColor,
                                        ),
                                        TextFormField(
                                          controller: timeController,
                                          readOnly: true,
                                          style: TextStyle(
                                            color: textColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          onTap: () async {
                                            final parts =
                                                timeController.text.split(':');
                                            final initH = parts.isNotEmpty
                                                ? (int.tryParse(parts[0]) ??
                                                    nowWib.hour)
                                                : nowWib.hour;
                                            final initM = parts.length > 1
                                                ? (int.tryParse(parts[1]) ??
                                                    nowWib.minute)
                                                : nowWib.minute;

                                            final chosen = await showTimePicker(
                                              context: sheetContext,
                                              initialTime: TimeOfDay(
                                                hour: initH,
                                                minute: initM,
                                              ),
                                              builder: (context, child) {
                                                return MediaQuery(
                                                  data: MediaQuery.of(context)
                                                      .copyWith(
                                                    alwaysUse24HourFormat: true,
                                                  ),
                                                  child: child ??
                                                      const SizedBox.shrink(),
                                                );
                                              },
                                            );
                                            if (chosen != null) {
                                              final h = chosen.hour
                                                  .toString()
                                                  .padLeft(2, '0');
                                              final m = chosen.minute
                                                  .toString()
                                                  .padLeft(2, '0');
                                              setSheetState(() {
                                                timeController.text = '$h:$m';
                                              });
                                            }
                                          },
                                          decoration: _modernInputDecoration(
                                            hint: '13:00',
                                            icon: Icons.access_time_rounded,
                                            fillColor: fieldBg,
                                            isDark: isDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // Lokasi
                              _buildFormLabel('Lokasi Kegiatan *', textColor),
                              TextFormField(
                                controller: locationController,
                                style: TextStyle(color: textColor),
                                decoration: _modernInputDecoration(
                                  hint: 'Contoh: Kawasan Hutan Garut / Pataruman',
                                  icon: Icons.location_on_outlined,
                                  fillColor: fieldBg,
                                  isDark: isDark,
                                ),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                        ? 'Lokasi kegiatan wajib diisi'
                                        : null,
                              ),

                              const SizedBox(height: 16),

                              // Pengaturan Notifikasi Aplikasi & WhatsApp
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: fieldBg,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: green.withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.notifications_active_outlined,
                                          color: isDark
                                              ? const Color(0xFF81C784)
                                              : green,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Pengingat Aplikasi & WhatsApp',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: textColor,
                                            ),
                                          ),
                                        ),
                                        Switch(
                                          value: enableWaNotification,
                                          activeColor: green,
                                          onChanged: (val) {
                                            setSheetState(() {
                                              enableWaNotification = val;
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<int>(
                                      value: selectedReminderMinutes,
                                      dropdownColor: sheetBg,
                                      style: TextStyle(color: textColor),
                                      decoration: InputDecoration(
                                        labelText: 'Ingatkan Sebelum Jadwal',
                                        labelStyle: TextStyle(
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.grey.shade700,
                                        ),
                                        filled: true,
                                        fillColor: sheetBg,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                      items: reminderOptions.map((opt) {
                                        return DropdownMenuItem<int>(
                                          value: opt['minutes'] as int,
                                          child: Text(
                                            opt['label'] as String,
                                            style: TextStyle(color: textColor),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setSheetState(() {
                                            selectedReminderMinutes = val;
                                          });
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: sheetBg,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.alarm_on_rounded,
                                            size: 16,
                                            color: isDark
                                                ? const Color(0xFF81C784)
                                                : green,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Pengingat WhatsApp otomatis akan terkirim pukul $previewReminderClock WIB ($selectedReminderMinutes menit sebelum $currentPreviewTime WIB).',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: textColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (enableWaNotification) ...[
                                      const SizedBox(height: 10),
                                      TextFormField(
                                        controller: waPhoneController,
                                        keyboardType: TextInputType.phone,
                                        style: TextStyle(color: textColor),
                                        decoration: InputDecoration(
                                          labelText: 'Nomor WhatsApp Penerima',
                                          hintText: '08xxxxxxxxxx',
                                          labelStyle: TextStyle(
                                            color: isDark
                                                ? Colors.white70
                                                : Colors.grey.shade700,
                                          ),
                                          prefixIcon: Icon(
                                            Icons.chat_bubble_outline_rounded,
                                            color: isDark
                                                ? const Color(0xFF81C784)
                                                : green,
                                          ),
                                          filled: true,
                                          fillColor: sheetBg,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Catatan
                              _buildFormLabel(
                                'Keterangan / Catatan (Opsional)',
                                textColor,
                              ),
                              TextFormField(
                                controller: descriptionController,
                                maxLines: 3,
                                style: TextStyle(color: textColor),
                                decoration: _modernInputDecoration(
                                  hint:
                                      'Tulis rincian perlengkapan atau agenda...',
                                  icon: Icons.notes_rounded,
                                  fillColor: fieldBg,
                                  isDark: isDark,
                                ),
                              ),

                              const SizedBox(height: 22),

                              // Tombol Aksi
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () =>
                                          Navigator.pop(sheetContext, false),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: isDark
                                            ? const Color(0xFF81C784)
                                            : green,
                                        side: BorderSide(
                                          color: isDark
                                              ? const Color(0xFF81C784)
                                              : green,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                      ),
                                      child: const Text(
                                        'Batal',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 2,
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        if (formKey.currentState!.validate()) {
                                          Navigator.pop(sheetContext, true);
                                        }
                                      },
                                      icon: const Icon(
                                        Icons.check_circle_outline_rounded,
                                      ),
                                      label: Text(
                                        isEditing
                                            ? 'Simpan Perubahan'
                                            : 'Simpan Jadwal',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: green,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == true && mounted) {
      final isoDate =
          '${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}';
      final cleanTime = JadwalService.formatTimeString(
        timeController.text.trim(),
        fallback: initialTimeStr,
      );
      final reminderClock = JadwalDateUtils.calculateReminderTimeStr(
        cleanTime,
        selectedReminderMinutes,
      );

      final rawItem = {
        'judul': titleController.text.trim(),
        'kategori': selectedCategory,
        'tanggalIso': isoDate,
        'waktu': cleanTime,
        'lokasi': locationController.text.trim(),
        'catatan': descriptionController.text.trim(),
        'reminderMinutes': selectedReminderMinutes,
        'reminderTime': reminderClock,
        'reminderEnabled': true,
        'enableWaNotification': enableWaNotification,
        'waPhone': waPhoneController.text.trim(),
        'isCompleted': isEditing ? (existingItem['isCompleted'] == true) : false,
      };

      try {
        final Map<String, dynamic> savedItem;
        if (isEditing) {
          savedItem = await JadwalService.updateSchedule(
            existingItem['id'],
            rawItem,
          );
        } else {
          savedItem = await JadwalService.addSchedule(rawItem);
        }

        if (mounted) {
          setState(() {
            schedules.removeWhere(
              (e) => e['id'].toString() == savedItem['id'].toString(),
            );
            schedules.insert(0, savedItem);
            selectedDate = pickedDate;
            showAllHistory = true;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: green,
              content: Text(
                isEditing
                    ? 'Jadwal diperbarui! Pengingat dijadwalkan ulang pukul $reminderClock WIB ($selectedReminderMinutes menit sebelum $cleanTime WIB).'
                    : 'Jadwal pukul $cleanTime WIB disimpan! Pengingat otomatis dijadwalkan pukul $reminderClock WIB ($selectedReminderMinutes menit sebelum).',
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menyimpan jadwal: $e')),
          );
        }
      }
    }

    titleController.dispose();
    locationController.dispose();
    descriptionController.dispose();
    timeController.dispose();
    waPhoneController.dispose();
  }

  Widget _buildFormLabel(String text, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }

  InputDecoration _modernInputDecoration({
    required String hint,
    required IconData icon,
    required Color fillColor,
    bool isDark = false,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey),
      prefixIcon: Icon(
        icon,
        color: isDark ? const Color(0xFF81C784) : green,
        size: 20,
      ),
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: green.withValues(alpha: 0.2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: green.withValues(alpha: 0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF81C784) : green,
          width: 1.6,
        ),
      ),
    );
  }

  Future<void> showScheduleDetail(Map<String, dynamic> item) async {
    final itemDate = _getItemDate(item);
    final title = (item['title'] ?? item['judul'] ?? '').toString();
    final time = JadwalService.formatTimeString(
      (item['time'] ?? item['waktu'] ?? '08:00').toString(),
    );
    final location = (item['location'] ?? item['lokasi'] ?? '').toString();
    final description =
        (item['description'] ?? item['catatan'] ?? '').toString();
    final category = (item['kategori'] ?? 'Kegiatan Lapangan').toString();
    final reminderMinutes =
        int.tryParse((item['reminderMinutes'] ?? 30).toString()) ?? 30;
    final reminderClock =
        JadwalDateUtils.calculateReminderTimeStr(time, reminderMinutes);
    final isCompleted = item['isCompleted'] == true;
    bool isSendingWa = false;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) => StatefulBuilder(
        builder: (sheetInnerContext, setModalState) {
          final isDark =
              Theme.of(sheetInnerContext).brightness == Brightness.dark;
          final textColor = isDark ? Colors.white : const Color(0xFF24352A);
          final waStatus = (item['whatsappStatus'] ??
                  item['whatsapp_status'] ??
                  'pending')
              .toString()
              .toLowerCase();
          final waError =
              (item['whatsappError'] ?? item['whatsapp_error'])?.toString();
          final waSentAt =
              (item['whatsappSentAt'] ?? item['whatsapp_sent_at'])?.toString();
          final isWaEnabled = item['enableWaNotification'] == true ||
              item['enable_wa_notification'] == true;

          return Padding(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? (isDark
                                  ? const Color(0xFF1B3824)
                                  : Colors.green.shade50)
                              : (isDark
                                  ? const Color(0xFF1A2A3A)
                                  : Colors.blue.shade50),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isCompleted ? 'Selesai' : 'Aktif',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isCompleted
                                ? (isDark
                                    ? const Color(0xFF81C784)
                                    : Colors.green.shade700)
                                : (isDark
                                    ? const Color(0xFF90CAF9)
                                    : Colors.blue.shade700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF233B28) : lightGreen,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFFA5D6A7) : green,
                          ),
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(bottomSheetContext);
                          addSchedule(existingItem: item);
                        },
                        icon: Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: isDark ? const Color(0xFF81C784) : green,
                        ),
                        label: Text(
                          'Edit',
                          style: TextStyle(
                            color: isDark ? const Color(0xFF81C784) : green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _DetailRow(
                    icon: Icons.calendar_today_outlined,
                    text: formatDate(itemDate),
                  ),
                  _DetailRow(
                    icon: Icons.access_time,
                    text: '$time WIB',
                  ),
                  _DetailRow(
                    icon: Icons.location_on_outlined,
                    text: location,
                  ),
                  _DetailRow(
                    icon: Icons.notifications_active_outlined,
                    text:
                        'Pengingat $reminderMinutes menit sebelum jadwal (Pukul $reminderClock WIB)',
                  ),
                  if (isWaEnabled)
                    _DetailRow(
                      icon: Icons.chat_outlined,
                      text:
                          'WhatsApp: ${(item['waPhone'] ?? item['wa_phone'] ?? '').toString().isNotEmpty ? (item['waPhone'] ?? item['wa_phone']) : 'Nomor Profil Pengguna'}',
                    ),
                  if (description.isNotEmpty)
                    _DetailRow(
                      icon: Icons.notes,
                      text: description,
                    ),
                  const SizedBox(height: 14),
                  _buildWaStatusBadge(
                    isDark: isDark,
                    isWaEnabled: isWaEnabled,
                    waStatus: waStatus,
                    waError: waError,
                    waSentAt: waSentAt,
                    reminderClock: reminderClock,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: isSendingWa
                        ? null
                        : () async {
                            setModalState(() => isSendingWa = true);
                            final res = await WhatsappReminderService.instance
                                .sendOrLaunchReminder(
                              item,
                              context: context,
                            );
                            setModalState(() => isSendingWa = false);
                            if (res['success'] == true) {
                              item['whatsapp_status'] = 'sent';
                              item['whatsappStatus'] = 'sent';
                              item['whatsapp_sent'] = true;
                              item['whatsappSent'] = true;
                              item['whatsapp_sent_at'] =
                                  DateTime.now().toIso8601String();
                              item['whatsappSentAt'] =
                                  DateTime.now().toIso8601String();
                              item['whatsapp_error'] = null;
                              item['whatsappError'] = null;
                            } else if (res['reason'] != null) {
                              item['whatsapp_status'] = 'failed';
                              item['whatsappStatus'] = 'failed';
                              item['whatsapp_error'] = res['reason'].toString();
                              item['whatsappError'] = res['reason'].toString();
                            }
                            await JadwalService.saveLocalSchedules(schedules);
                            if (mounted) setState(() {});
                          },
                    icon: isSendingWa
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(
                      isSendingWa
                          ? 'Mengirim...'
                          : (waStatus == 'sent'
                              ? 'Kirim Ulang Pesan WhatsApp'
                              : (waStatus == 'failed'
                                  ? 'Coba Kirim Ulang Sekarang'
                                  : 'Kirim Pengingat Sekarang (Manual)')),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            Navigator.pop(bottomSheetContext);
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: Theme.of(context).cardColor,
                                title: Text(
                                  'Hapus Jadwal',
                                  style: TextStyle(color: textColor),
                                ),
                                content: Text(
                                  'Apakah Anda yakin ingin menghapus jadwal ini? Pengingat terkait juga akan dibatalkan.',
                                  style: TextStyle(
                                    color:
                                        isDark ? Colors.white70 : Colors.black87,
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Batal'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                    ),
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text(
                                      'Hapus',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await JadwalService.deleteSchedule(item['id']);
                              await _loadData();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Jadwal dan pengingat terkait berhasil dihapus',
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          label: const Text(
                            'Hapus',
                            style: TextStyle(color: Colors.red),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            Navigator.pop(bottomSheetContext);
                            await JadwalService.toggleComplete(item['id']);
                            await _loadData();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isCompleted
                                        ? 'Jadwal ditandai belum selesai'
                                        : 'Jadwal ditandai selesai',
                                  ),
                                ),
                              );
                            }
                          },
                          icon: Icon(
                            isCompleted
                                ? Icons.undo_rounded
                                : Icons.check_circle_outline,
                          ),
                          label:
                              Text(isCompleted ? 'Belum Selesai' : 'Selesai'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWaStatusBadge({
    required bool isDark,
    required bool isWaEnabled,
    required String waStatus,
    String? waError,
    String? waSentAt,
    required String reminderClock,
  }) {
    if (!isWaEnabled || waStatus == 'disabled') {
      return Container(
        margin: const EdgeInsets.only(top: 4, bottom: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF232D26) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF35443A) : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.notifications_off_outlined,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notifikasi WhatsApp Dinonaktifkan',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color:
                          isDark ? Colors.grey.shade200 : Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Pengingat WhatsApp otomatis dinonaktifkan untuk kegiatan ini.',
                    style: TextStyle(
                      fontSize: 11,
                      color:
                          isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (waStatus == 'sent') {
      String sentLabel =
          'Pengingat WhatsApp telah otomatis terkirim via Fonnte';
      if (waSentAt != null && waSentAt.isNotEmpty) {
        try {
          final parsed = DateTime.parse(waSentAt);
          final wib =
              parsed.isUtc ? parsed.add(const Duration(hours: 7)) : parsed;
          sentLabel =
              'Terkirim pada ${wib.hour.toString().padLeft(2, '0')}:${wib.minute.toString().padLeft(2, '0')} WIB';
        } catch (_) {}
      }

      return Container(
        margin: const EdgeInsets.only(top: 4, bottom: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1B3824) : const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF2E7D32) : const Color(0xFFA5D6A7),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pengingat WhatsApp: Terkirim',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDark
                          ? const Color(0xFFA5D6A7)
                          : const Color(0xFF1B5E20),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sentLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? const Color(0xFF81C784)
                          : const Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (waStatus == 'failed') {
      return Container(
        margin: const EdgeInsets.only(top: 4, bottom: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF3B1E1E) : const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFFC62828) : const Color(0xFFEF9A9A),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: isDark ? const Color(0xFFEF9A9A) : const Color(0xFFC62828),
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pengingat WhatsApp: Gagal Kirim',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDark
                          ? const Color(0xFFFFCDD2)
                          : const Color(0xFFB71C1C),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    waError != null && waError.isNotEmpty
                        ? waError
                        : 'Pengiriman pesan ke nomor WhatsApp penerima gagal.',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? const Color(0xFFEF9A9A)
                          : const Color(0xFFC62828),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF382F16) : const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFFF57F17) : const Color(0xFFFFE082),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.schedule_rounded,
            color: isDark ? const Color(0xFFFFD54F) : const Color(0xFFF57F17),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pengingat WhatsApp: Menunggu Pengiriman Otomatis',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isDark
                        ? const Color(0xFFFFE082)
                        : const Color(0xFFE65100),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Sistem otomatis mengirim pengingat ke WhatsApp pada pukul $reminderClock WIB.',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? const Color(0xFFFFD54F)
                        : const Color(0xFFF57F17),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firstWeekday =
        DateTime(displayedMonth.year, displayedMonth.month, 1).weekday;
    final daysInMonth =
        DateTime(displayedMonth.year, displayedMonth.month + 1, 0).day;
    final today = JadwalDateUtils.nowWib();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E2822) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF2E3D34) : Colors.transparent;
    final textColor = isDark ? Colors.white : const Color(0xFF24352A);
    final subColor = isDark ? Colors.white70 : const Color(0xFF758278);

    return PopScope(
      canPop: Navigator.of(context).canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleBackButton();
        }
      },
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF121A15) : const Color(0xFFF7F9F6),
        body: SafeArea(
          child: Column(
            children: [
              // Header bar (Tombol Back, History Reminder & Notifikasi)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Jadwal Kegiatan',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _openHistoryReminderPage,
                      icon: Icon(
                        Icons.history_rounded,
                        color: isDark ? const Color(0xFF81C784) : green,
                      ),
                      tooltip: 'History Reminder',
                    ),
                    ListenableBuilder(
                      listenable: NotificationService.instance,
                      builder: (context, _) {
                        final count = NotificationService.instance.unreadCount;
                        return IconButton(
                          onPressed: _openNotificationPage,
                          tooltip: 'Notifikasi ($count belum dibaca)',
                          icon: Badge(
                            isLabelVisible: count > 0,
                            label: Text('$count'),
                            child: Icon(
                              Icons.notifications_outlined,
                              color: isDark ? const Color(0xFF81C784) : green,
                            ),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      onPressed: _loadData,
                      icon: Icon(
                        Icons.refresh_rounded,
                        color: isDark ? const Color(0xFF81C784) : green,
                      ),
                      tooltip: 'Muat ulang jadwal',
                    ),
                  ],
                ),
              ),

              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: TextField(
                  controller: searchController,
                  style: TextStyle(color: textColor),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Cari kegiatan, kategori, atau lokasi...',
                    hintStyle: TextStyle(color: isDark ? Colors.white38 : null),
                    prefixIcon: Icon(
                      Icons.search,
                      color: isDark ? const Color(0xFF81C784) : Colors.grey,
                    ),
                    filled: true,
                    fillColor: cardBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: cardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: cardBorder),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 120),
                  children: [
                    // Kalender
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: cardBorder),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.2 : 0.04,
                            ),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              IconButton(
                                onPressed: () => changeMonth(-1),
                                icon:
                                    Icon(Icons.chevron_left, color: textColor),
                                tooltip: 'Bulan sebelumnya',
                              ),
                              Expanded(
                                child: Text(
                                  '${monthNames[displayedMonth.month - 1]} ${displayedMonth.year}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => changeMonth(1),
                                icon:
                                    Icon(Icons.chevron_right, color: textColor),
                                tooltip: 'Bulan selanjutnya',
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: dayNames.map((name) {
                              return Expanded(
                                child: Center(
                                  child: Text(
                                    name,
                                    style: TextStyle(
                                      color: subColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 10),
                          ...List.generate(
                            (firstWeekday - 1 + daysInMonth + 6) ~/ 7,
                            (week) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 7),
                                child: Row(
                                  children: List.generate(7, (column) {
                                    final day =
                                        week * 7 + column - (firstWeekday - 2);

                                    if (day < 1 || day > daysInMonth) {
                                      return const Expanded(
                                        child: SizedBox(height: 40),
                                      );
                                    }

                                    final date = DateTime(
                                      displayedMonth.year,
                                      displayedMonth.month,
                                      day,
                                    );
                                    final selected = !showAllHistory &&
                                        dateKey(date) == dateKey(selectedDate);
                                    final isToday =
                                        dateKey(date) == dateKey(today);
                                    final hasSchedule = schedules.any(
                                      (item) =>
                                          dateKey(_getItemDate(item)) ==
                                          dateKey(date),
                                    );

                                    return Expanded(
                                      child: GestureDetector(
                                        onTap: () => selectDay(day),
                                        child: Container(
                                          height: 40,
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: selected
                                                ? green
                                                : Colors.transparent,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: isToday && !selected
                                                ? Border.all(
                                                    color: isDark
                                                        ? const Color(
                                                            0xFF81C784,
                                                          )
                                                        : green,
                                                  )
                                                : null,
                                          ),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                '$day',
                                                style: TextStyle(
                                                  color: selected
                                                      ? Colors.white
                                                      : textColor,
                                                  fontWeight:
                                                      selected || isToday
                                                          ? FontWeight.bold
                                                          : FontWeight.normal,
                                                ),
                                              ),
                                              if (hasSchedule)
                                                Container(
                                                  width: 5,
                                                  height: 5,
                                                  decoration: BoxDecoration(
                                                    color: selected
                                                        ? Colors.white
                                                        : (isDark
                                                            ? const Color(
                                                                0xFF81C784,
                                                              )
                                                            : green),
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Tombol Tambah Jadwal & Tombol History Reminder
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: SizedBox(
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed: () => addSchedule(),
                              icon: const Icon(
                                Icons.add_circle_outline_rounded,
                              ),
                              label: const Text(
                                'Tambah Jadwal',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.5,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: green,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 52,
                            child: OutlinedButton.icon(
                              onPressed: _openHistoryReminderPage,
                              icon: const Icon(Icons.history_rounded, size: 19),
                              label: const Text(
                                'History Reminder',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor:
                                    isDark ? const Color(0xFF81C784) : green,
                                side: BorderSide(
                                  color:
                                      isDark ? const Color(0xFF81C784) : green,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Header Riwayat Jadwal + Toggle "Semua Riwayat" vs "Tanggal Dipilih"
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Riwayat Jadwal',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        Row(
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                setState(() => showAllHistory = true);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: showAllHistory
                                      ? green
                                      : (isDark
                                          ? const Color(0xFF26352B)
                                          : lightGreen),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Semua (${schedules.length})',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: showAllHistory
                                        ? Colors.white
                                        : (isDark
                                            ? const Color(0xFF81C784)
                                            : green),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                setState(() => showAllHistory = false);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: !showAllHistory
                                      ? green
                                      : (isDark
                                          ? const Color(0xFF26352B)
                                          : lightGreen),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  formatDate(selectedDate),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: !showAllHistory
                                        ? Colors.white
                                        : (isDark
                                            ? const Color(0xFF81C784)
                                            : green),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    if (isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: CircularProgressIndicator(color: green),
                        ),
                      )
                    else if (filteredSchedules.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(26),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: cardBorder),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.event_note_outlined,
                              size: 42,
                              color: isDark
                                  ? const Color(0xFF81C784)
                                  : Colors.grey,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              showAllHistory
                                  ? 'Belum ada jadwal kegiatan tersimpan.\nTekan tombol "Tambah Jadwal" di atas untuk membuat jadwal baru.'
                                  : 'Belum ada jadwal pada tanggal ${formatDate(selectedDate)}',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: subColor, height: 1.45),
                            ),
                          ],
                        ),
                      )
                    else
                      ...filteredSchedules.map(
                        (item) {
                          final itemDate = _getItemDate(item);
                          final title =
                              (item['title'] ?? item['judul'] ?? '').toString();
                          final time = JadwalService.formatTimeString(
                            (item['time'] ?? item['waktu'] ?? '08:00')
                                .toString(),
                          );
                          final reminderMinutes = int.tryParse(
                                (item['reminderMinutes'] ?? 30).toString(),
                              ) ??
                              30;
                          final reminderClock =
                              JadwalDateUtils.calculateReminderTimeStr(
                            time,
                            reminderMinutes,
                          );
                          final location =
                              (item['location'] ?? item['lokasi'] ?? '')
                                  .toString();
                          final category =
                              (item['kategori'] ?? 'Penyuluhan').toString();
                          final isCompleted = item['isCompleted'] == true;

                          return Card(
                            color: cardBg,
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: cardBorder),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              onTap: () => showScheduleDetail(item),
                              leading: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: isCompleted
                                      ? (isDark
                                          ? const Color(0xFF1B3B22)
                                          : Colors.green.shade50)
                                      : (isDark
                                          ? const Color(0xFF26352B)
                                          : lightGreen),
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                child: Icon(
                                  isCompleted
                                      ? Icons.check_circle_rounded
                                      : Icons.event_note_rounded,
                                  color: isDark
                                      ? const Color(0xFF81C784)
                                      : green,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        decoration: isCompleted
                                            ? TextDecoration.lineThrough
                                            : null,
                                        color: isCompleted
                                            ? Colors.grey
                                            : textColor,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF26352B)
                                          : softGreen,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      category,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? const Color(0xFF81C784)
                                            : green,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${formatDate(itemDate)} • $time WIB • $location',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: subColor,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.notifications_active_outlined,
                                          size: 13,
                                          color: isDark
                                              ? const Color(0xFF81C784)
                                              : green,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            'Reminder: $reminderMinutes menit sebelum ($reminderClock WIB)',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: isDark
                                                  ? const Color(0xFFA5D6A7)
                                                  : green,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.send_rounded,
                                      color: Color(0xFF25D366),
                                      size: 19,
                                    ),
                                    tooltip: 'Kirim Pengingat WhatsApp',
                                    onPressed: () {
                                      WhatsappReminderService.instance
                                          .sendOrLaunchReminder(
                                        item,
                                        context: context,
                                      );
                                    },
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    color: subColor,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _DetailRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: isDark ? const Color(0xFF81C784) : const Color(0xFF245C3A),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white : const Color(0xFF24352A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}