// ============================================================================
// Simpan file ini di: lib/pages/jadwal.dart
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';

import '../../constants/jadwal_constants.dart';
import '../../services/jadwal_service.dart';

class JadwalPage extends StatefulWidget {
  final VoidCallback? onBack;
  final Function(int)? onNavigate;

  const JadwalPage({
    super.key,
    this.onBack,
    this.onNavigate,
  });

  @override
  State<JadwalPage> createState() => _JadwalPageState();
}

class _JadwalPageState extends State<JadwalPage> {
  DateTime selectedDate = DateTime.now();
  DateTime displayedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  final searchController = TextEditingController();
  final List<Map<String, dynamic>> schedules = [];
  final Set<String> _triggeredReminders = {};
  Timer? _reminderTimer;

  bool isLoading = false;
  // Default: tampilkan SEMUA riwayat jadwal, bukan cuma 1 hari
  bool showAllHistory = true;

  static const green = Color(0xFF245C3A);
  static const secondaryGreen = Color(0xFF4F8A5B);
  static const lightGreen = Color(0xFFE8F2E8);
  static const softGreen = Color(0xFFF2F7F0);

  static const monthNames = [
    'Januari', 'Februari', 'Maret', 'April',
    'Mei', 'Juni', 'Juli', 'Agustus',
    'September', 'Oktober', 'November', 'Desember',
  ];

  static const dayNames = [
    'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min',
  ];

  static const List<Map<String, dynamic>> categoryOptions = [
    {'label': 'Penyuluhan', 'icon': Icons.campaign_rounded},
    {'label': 'Monitoring Hutan', 'icon': Icons.park_rounded},
    {'label': 'Patroli & Pengamanan', 'icon': Icons.shield_outlined},
    {'label': 'Rehabilitasi Lahan', 'icon': Icons.spa_rounded},
    {'label': 'Rapat Koordinasi', 'icon': Icons.groups_rounded},
    {'label': 'Sosialisasi Masyarakat', 'icon': Icons.record_voice_over_rounded},
  ];

  static const List<Map<String, dynamic>> reminderOptions = [
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
    // Cek pengingat jadwal setiap 30 detik selama aplikasi aktif
    _reminderTimer = Timer.periodic(
      const Duration(seconds: 30),
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
    } else if (widget.onBack != null) {
      widget.onBack!();
    } else if (widget.onNavigate != null) {
      // Kembali ke tab Beranda (biasanya index 2 atau 0)
      widget.onNavigate!(2);
    } else {
      // Jika tidak ada route untuk di-pop dan tidak ada callback,
      // kembalikan fokus ke tanggal hari ini & tampilkan semua jadwal
      setState(() {
        selectedDate = DateTime.now();
        displayedMonth = DateTime(DateTime.now().year, DateTime.now().month);
        showAllHistory = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Menampilkan seluruh jadwal kegiatan'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      final list = await JadwalService.loadSchedules();
      if (mounted) {
        setState(() {
          schedules.clear();
          schedules.addAll(list);
          isLoading = false;
        });
        _checkUpcomingReminders();
      }
    } catch (_) {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  /// Mengecek apakah ada jadwal yang memasuki waktu pengingat (misal H-30 menit)
  void _checkUpcomingReminders() {
    if (!mounted) return;
    final now = DateTime.now();

    for (final item in schedules) {
      if (item['isCompleted'] == true) continue;

      final id = (item['id'] ?? item['judul'] ?? '').toString();
      if (_triggeredReminders.contains(id)) continue;

      final itemDate = _getItemDate(item);
      final timeStr = (item['time'] ?? item['waktu'] ?? '08:00').toString();
      final parts = timeStr.split(':');
      final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 8 : 8;
      final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

      final scheduleDateTime = DateTime(
        itemDate.year,
        itemDate.month,
        itemDate.day,
        hour,
        minute,
      );

      final reminderMinutes =
          int.tryParse((item['reminderMinutes'] ?? 30).toString()) ?? 30;
      final diffMinutes = scheduleDateTime.difference(now).inMinutes;

      if (diffMinutes >= 0 && diffMinutes <= reminderMinutes) {
        _triggeredReminders.add(id);
        final title = (item['title'] ?? item['judul'] ?? 'Kegiatan').toString();
        final location = (item['location'] ?? item['lokasi'] ?? '-').toString();

        ScaffoldMessenger.of(context).showMaterialBanner(
          MaterialBanner(
            backgroundColor: lightGreen,
            leading: const CircleAvatar(
              backgroundColor: green,
              child: Icon(Icons.notifications_active_rounded, color: Colors.white),
            ),
            content: Text(
              'Pengingat Jadwal: "$title" akan dimulai dalam $diffMinutes menit ($timeStr WIB) di $location.',
              style: const TextStyle(
                color: Color(0xFF24352A),
                fontWeight: FontWeight.w600,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
                child: const Text(
                  'Tutup',
                  style: TextStyle(color: green, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      }
    }
  }

  DateTime _getItemDate(Map<String, dynamic> item) {
    final rawDate = item['date'];
    if (rawDate is DateTime) return rawDate;

    final iso = (item['tanggalIso'] ?? item['date'] ?? '').toString();
    if (iso.isNotEmpty) {
      final parsed = DateTime.tryParse(iso);
      if (parsed != null) return parsed;
      return JadwalDateUtils.parseIsoDate(iso);
    }
    return DateTime.now();
  }

  String dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String formatDate(DateTime date) =>
      '${date.day} ${monthNames[date.month - 1]} ${date.year}';

  List<Map<String, dynamic>> get filteredSchedules {
    final query = searchController.text.toLowerCase().trim();

    return schedules.where((item) {
      final itemDate = _getItemDate(item);
      // Jika showAllHistory == true, tampilkan semua tanggal
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
        // Urutkan berdasarkan tanggal terbaru dulu, lalu jam
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
      // Saat user klik tanggal spesifik di kalender, filter ke tanggal itu
      showAllHistory = false;
    });
  }

  // ===========================================================================
  // FORM TAMBAH JADWAL MODERN (BOTTOM SHEET + KATEGORI PILIHAN + NOTIF WA)
  // ===========================================================================
  Future<void> addSchedule() async {
    final titleController = TextEditingController();
    final locationController = TextEditingController();
    final descriptionController = TextEditingController();
    final timeController = TextEditingController(text: '08:00');
    final waPhoneController = TextEditingController(text: '089602976525');

    String selectedCategory = categoryOptions.first['label'] as String;
    int selectedReminderMinutes = 30;
    bool enableWaNotification = true;

    DateTime pickedDate = DateTime(
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
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tambah Jadwal Kegiatan',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Atur rincian agenda & pengingat otomatis',
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
                            icon: const Icon(Icons.close_rounded, color: Colors.white),
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
                                ),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                        ? 'Nama kegiatan wajib diisi'
                                        : null,
                              ),

                              const SizedBox(height: 16),

                              // Pilihan Kategori (Interactive Chips)
                              _buildFormLabel('Pilih Kategori Kegiatan *', textColor),
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
                                      color: isSelected ? Colors.white : green,
                                    ),
                                    label: Text(label),
                                    selected: isSelected,
                                    selectedColor: green,
                                    backgroundColor: fieldBg,
                                    labelStyle: TextStyle(
                                      color: isSelected ? Colors.white : textColor,
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
                                                const Icon(
                                                  Icons.calendar_today_rounded,
                                                  size: 18,
                                                  color: green,
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
                                        _buildFormLabel('Waktu *', textColor),
                                        TextFormField(
                                          controller: timeController,
                                          readOnly: true,
                                          style: TextStyle(
                                            color: textColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          onTap: () async {
                                            final nowTime = TimeOfDay.now();
                                            final chosen = await showTimePicker(
                                              context: sheetContext,
                                              initialTime: nowTime,
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
                                            hint: '08:00',
                                            icon: Icons.access_time_rounded,
                                            fillColor: fieldBg,
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
                                        const Icon(
                                          Icons.notifications_active_outlined,
                                          color: green,
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
                                      decoration: InputDecoration(
                                        labelText: 'Ingatkan Sebelum Jadwal',
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
                                          child: Text(opt['label'] as String),
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
                                    if (enableWaNotification) ...[
                                      const SizedBox(height: 10),
                                      TextFormField(
                                        controller: waPhoneController,
                                        keyboardType: TextInputType.phone,
                                        style: TextStyle(color: textColor),
                                        decoration: InputDecoration(
                                          labelText: 'Nomor WhatsApp Penerima',
                                          hintText: '08xxxxxxxxxx',
                                          prefixIcon: const Icon(
                                            Icons.chat_bubble_outline_rounded,
                                            color: green,
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
                                  hint: 'Tulis rincian perlengkapan atau agenda...',
                                  icon: Icons.notes_rounded,
                                  fillColor: fieldBg,
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
                                        foregroundColor: green,
                                        side: const BorderSide(color: green),
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
                                      label: const Text(
                                        'Simpan Jadwal',
                                        style: TextStyle(
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
      final cleanTime =
          JadwalService.formatTimeString(timeController.text.trim());

      final rawItem = {
        'judul': titleController.text.trim(),
        'kategori': selectedCategory,
        'tanggalIso': isoDate,
        'waktu': cleanTime,
        'lokasi': locationController.text.trim(),
        'catatan': descriptionController.text.trim(),
        'reminderMinutes': selectedReminderMinutes,
        'enableWaNotification': enableWaNotification,
        'waPhone': waPhoneController.text.trim(),
        'isCompleted': false,
      };

      try {
        final savedItem = await JadwalService.addSchedule(rawItem);
        if (mounted) {
          setState(() {
            schedules.removeWhere(
              (e) => e['id'].toString() == savedItem['id'].toString(),
            );
            schedules.insert(0, savedItem);
            selectedDate = pickedDate;
            showAllHistory = true;
          });

          _checkUpcomingReminders();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: green,
              content: Text(
                enableWaNotification
                    ? 'Jadwal disimpan! Pengingat WA & Aplikasi aktif ($selectedReminderMinutes menit sebelum).'
                    : 'Jadwal kegiatan berhasil disimpan!',
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
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: green, size: 20),
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
        borderSide: const BorderSide(color: green, width: 1.6),
      ),
    );
  }

  Future<void> showScheduleDetail(Map<String, dynamic> item) async {
    final itemDate = _getItemDate(item);
    final title = (item['title'] ?? item['judul'] ?? '').toString();
    final time = (item['time'] ?? item['waktu'] ?? '').toString();
    final location = (item['location'] ?? item['lokasi'] ?? '').toString();
    final description =
        (item['description'] ?? item['catatan'] ?? '').toString();
    final category = (item['kategori'] ?? 'Kegiatan Lapangan').toString();
    final reminderMinutes =
        int.tryParse((item['reminderMinutes'] ?? 30).toString()) ?? 30;
    final isCompleted = item['isCompleted'] == true;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) => Padding(
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
                          ? Colors.green.shade50
                          : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isCompleted ? 'Selesai' : 'Aktif',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isCompleted
                            ? Colors.green.shade700
                            : Colors.blue.shade700,
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
                      color: lightGreen,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      category,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: green,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
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
                text: 'Pengingat $reminderMinutes menit sebelum jadwal (Aplikasi & WA)',
              ),
              if (description.isNotEmpty)
                _DetailRow(
                  icon: Icons.notes,
                  text: description,
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(bottomSheetContext);
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Hapus Jadwal'),
                            content: const Text(
                              'Apakah Anda yakin ingin menghapus jadwal ini?',
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
                                content: Text('Jadwal berhasil dihapus'),
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
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
                      label: Text(isCompleted ? 'Belum Selesai' : 'Selesai'),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firstWeekday =
        DateTime(displayedMonth.year, displayedMonth.month, 1).weekday;
    final daysInMonth =
        DateTime(displayedMonth.year, displayedMonth.month + 1, 0).day;
    final today = DateTime.now();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E2822) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF2E3D34) : Colors.transparent;
    final textColor = isDark ? Colors.white : const Color(0xFF24352A);
    final subColor = isDark ? Colors.white70 : const Color(0xFF758278);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF121A15) : const Color(0xFFF7F9F6),
      body: SafeArea(
        child: Column(
          children: [
            // Header bar (Tombol Back Sudah Diperbaiki)
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
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Jadwal Kegiatan',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
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
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 100),
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
                              icon: Icon(Icons.chevron_left, color: textColor),
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
                              icon: Icon(Icons.chevron_right, color: textColor),
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
                                              ? Border.all(color: green)
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
                                                fontWeight: selected || isToday
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

                  // Tombol Tambah Jadwal
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: addSchedule,
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      label: const Text(
                        'Tambah Jadwal Kegiatan',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
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
                                color: showAllHistory ? green : lightGreen,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Semua (${schedules.length})',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      showAllHistory ? Colors.white : green,
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
                                color: !showAllHistory ? green : lightGreen,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                formatDate(selectedDate),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      !showAllHistory ? Colors.white : green,
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
                            color:
                                isDark ? const Color(0xFF81C784) : Colors.grey,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            showAllHistory
                                ? 'Belum ada riwayat jadwal tersimpan'
                                : 'Belum ada jadwal pada tanggal ${formatDate(selectedDate)}',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: subColor),
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
                        final time =
                            (item['time'] ?? item['waktu'] ?? '').toString();
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
                                    color: softGreen,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    category,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: green,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${formatDate(itemDate)} • $time WIB • $location',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: subColor,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF245C3A)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 15, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}