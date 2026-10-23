import 'package:flutter/material.dart';

import '../constants/jadwal_constants.dart';
import '../services/jadwal_service.dart';

class JadwalPage extends StatefulWidget {
  const JadwalPage({super.key});

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
  bool isLoading = false;

  static const green = Color(0xFF287D3C);
  static const background = Color(0xFFF6F8F5);

  static const monthNames = [
    'Januari', 'Februari', 'Maret', 'April',
    'Mei', 'Juni', 'Juli', 'Agustus',
    'September', 'Oktober', 'November', 'Desember',
  ];

  static const dayNames = [
    'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
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
      }
    } catch (_) {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  /// Safe date parsing to prevent runtime TypeError exceptions
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
      final matchesDate = dateKey(itemDate) == dateKey(selectedDate);

      final title = (item['title'] ?? item['judul'] ?? '').toString().toLowerCase();
      final location = (item['location'] ?? item['lokasi'] ?? '').toString().toLowerCase();
      final category = (item['kategori'] ?? '').toString().toLowerCase();

      final matchesSearch = query.isEmpty ||
          title.contains(query) ||
          location.contains(query) ||
          category.contains(query);

      return matchesDate && matchesSearch;
    }).toList()
      ..sort((a, b) {
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
    });
  }

  Future<void> addSchedule() async {
    final titleController = TextEditingController();
    final categoryController = TextEditingController(text: 'Penyuluhan');
    final locationController = TextEditingController();
    final descriptionController = TextEditingController();
    final timeController = TextEditingController(text: '08:00');

    DateTime pickedDate = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );

    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.calendar_month_rounded, color: green),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Tambah Jadwal Baru',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Kegiatan *',
                      hintText: 'Contoh: Penyuluhan Kehutanan',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value == null || value.trim().isEmpty
                            ? 'Nama kegiatan wajib diisi'
                            : null,
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final chosen = await showDatePicker(
                        context: dialogContext,
                        initialDate: pickedDate,
                        firstDate: DateTime(2024),
                        lastDate: DateTime(2030),
                      );
                      if (chosen != null) {
                        setDialogState(() => pickedDate = chosen);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Tanggal Kegiatan',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                      child: Text(formatDate(pickedDate)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: timeController,
                          decoration: InputDecoration(
                            labelText: 'Jam (HH:MM) *',
                            hintText: '08:00',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.access_time_rounded),
                              onPressed: () async {
                                final nowTime = TimeOfDay.now();
                                final chosen = await showTimePicker(
                                  context: dialogContext,
                                  initialTime: nowTime,
                                );
                                if (chosen != null) {
                                  final h = chosen.hour.toString().padLeft(2, '0');
                                  final m = chosen.minute.toString().padLeft(2, '0');
                                  timeController.text = '$h:$m';
                                }
                              },
                            ),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Jam wajib diisi'
                                  : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: categoryController,
                          decoration: const InputDecoration(
                            labelText: 'Kategori',
                            hintText: 'Penyuluhan',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: locationController,
                    decoration: const InputDecoration(
                      labelText: 'Lokasi Kegiatan *',
                      hintText: 'Contoh: Kecamatan Garut',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value == null || value.trim().isEmpty
                            ? 'Lokasi wajib diisi'
                            : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Keterangan / Catatan (opsional)',
                      hintText: 'Rincian kegiatan lapangan...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    if (result == true && mounted) {
      final isoDate =
          '${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}';
      final cleanTime = JadwalService.formatTimeString(timeController.text.trim());

      final rawItem = {
        'judul': titleController.text.trim(),
        'kategori': categoryController.text.trim().isEmpty
            ? 'Penyuluhan'
            : categoryController.text.trim(),
        'tanggalIso': isoDate,
        'waktu': cleanTime,
        'lokasi': locationController.text.trim(),
        'catatan': descriptionController.text.trim(),
        'isCompleted': false,
      };

      try {
        final savedItem = await JadwalService.addSchedule(rawItem);
        if (mounted) {
          setState(() {
            schedules.removeWhere((e) => e['id'].toString() == savedItem['id'].toString());
            schedules.insert(0, savedItem);
            selectedDate = pickedDate;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Jadwal kegiatan berhasil disimpan!')),
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
    categoryController.dispose();
    locationController.dispose();
    descriptionController.dispose();
    timeController.dispose();
  }

  Future<void> showScheduleDetail(Map<String, dynamic> item) async {
    final itemDate = _getItemDate(item);
    final title = (item['title'] ?? item['judul'] ?? '').toString();
    final time = (item['time'] ?? item['waktu'] ?? '').toString();
    final location = (item['location'] ?? item['lokasi'] ?? '').toString();
    final description = (item['description'] ?? item['catatan'] ?? '').toString();
    final category = (item['kategori'] ?? 'Kegiatan Lapangan').toString();
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCompleted ? Colors.green.shade50 : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isCompleted ? 'Selesai' : 'Aktif',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isCompleted ? Colors.green.shade700 : Colors.blue.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      category,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800,
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
                            content: const Text('Apakah Anda yakin ingin menghapus jadwal ini?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Batal'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Hapus', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await JadwalService.deleteSchedule(item['id']);
                          await _loadData();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Jadwal berhasil dihapus')),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      label: const Text('Hapus', style: TextStyle(color: Colors.red)),
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
                      icon: Icon(isCompleted ? Icons.undo_rounded : Icons.check_circle_outline),
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
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firstWeekday =
        DateTime(displayedMonth.year, displayedMonth.month, 1).weekday;
    final daysInMonth =
        DateTime(displayedMonth.year, displayedMonth.month + 1, 0).day;
    final today = DateTime.now();

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            // Header bar
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
              child: Row(
                children: [
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(13),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(13),
                      onTap: () {
                        Navigator.maybePop(context);
                      },
                      child: const SizedBox(
                        width: 46,
                        height: 46,
                        child: Icon(Icons.arrow_back_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Jadwal Kegiatan',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _loadData,
                    icon: const Icon(Icons.refresh_rounded, color: green),
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
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Cari kegiatan, kategori, atau lokasi...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 18),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                children: [
                  // Kalender
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => changeMonth(-1),
                              icon: const Icon(Icons.chevron_left),
                              tooltip: 'Bulan sebelumnya',
                            ),
                            Expanded(
                              child: Text(
                                '${monthNames[displayedMonth.month - 1]} ${displayedMonth.year}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => changeMonth(1),
                              icon: const Icon(Icons.chevron_right),
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
                                  style: const TextStyle(
                                    color: Colors.grey,
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
                                  final selected =
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
                                                    : Colors.black87,
                                                fontWeight:
                                                    selected || isToday
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                              ),
                                            ),
                                            if (hasSchedule)
                                              Container(
                                                width: 4,
                                                height: 4,
                                                decoration: BoxDecoration(
                                                  color: selected
                                                      ? Colors.white
                                                      : green,
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

                  // Tambah jadwal
                  SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: addSchedule,
                      icon: const Icon(Icons.add),
                      label: const Text('Tambah Jadwal'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Riwayat Jadwal',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        formatDate(selectedDate),
                        style: const TextStyle(
                          color: green,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
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
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Column(
                        children: [
                          Icon(
                            Icons.event_note_outlined,
                            size: 42,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Belum ada jadwal pada tanggal ini',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  else
                    ...filteredSchedules.map(
                      (item) {
                        final title = (item['title'] ?? item['judul'] ?? '').toString();
                        final time = (item['time'] ?? item['waktu'] ?? '').toString();
                        final location = (item['location'] ?? item['lokasi'] ?? '').toString();
                        final isCompleted = item['isCompleted'] == true;

                        return Card(
                          color: Colors.white,
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ListTile(
                            onTap: () => showScheduleDetail(item),
                            leading: Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: isCompleted
                                    ? Colors.green.shade50
                                    : const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                isCompleted
                                    ? Icons.check_circle_rounded
                                    : Icons.event_note_outlined,
                                color: green,
                              ),
                            ),
                            title: Text(
                              title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                decoration: isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: isCompleted ? Colors.grey : Colors.black87,
                              ),
                            ),
                            subtitle: Text(
                              '$time • $location',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(
                              Icons.chevron_right,
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
          Icon(icon, color: const Color(0xFF287D3C)),
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
