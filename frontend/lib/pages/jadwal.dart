
import 'package:flutter/material.dart';

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

  String dateKey(DateTime date) =>
      '${date.year}-${date.month}-${date.day}';

  String formatDate(DateTime date) =>
      '${date.day} ${monthNames[date.month - 1]} ${date.year}';

  List<Map<String, dynamic>> get filteredSchedules {
    final query = searchController.text.toLowerCase().trim();

    return schedules.where((item) {
      final matchesDate = dateKey(item['date'] as DateTime) ==
          dateKey(selectedDate);

      final matchesSearch = query.isEmpty ||
          (item['title'] as String).toLowerCase().contains(query) ||
          (item['location'] as String).toLowerCase().contains(query);

      return matchesDate && matchesSearch;
    }).toList()
      ..sort((a, b) =>
          (a['time'] as String).compareTo(b['time'] as String));
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
    final locationController = TextEditingController();
    final descriptionController = TextEditingController();
    final timeController = TextEditingController(text: '08:00');

    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tambah Jadwal'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Nama kegiatan',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Nama kegiatan wajib diisi'
                          : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: timeController,
                  decoration: const InputDecoration(
                    labelText: 'Jam (contoh 08:00)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Jam wajib diisi'
                          : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: locationController,
                  decoration: const InputDecoration(
                    labelText: 'Lokasi',
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
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Keterangan (opsional)',
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
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      setState(() {
        schedules.add({
          'title': titleController.text.trim(),
          'time': timeController.text.trim(),
          'location': locationController.text.trim(),
          'description': descriptionController.text.trim(),
          'date': DateTime(
            selectedDate.year,
            selectedDate.month,
            selectedDate.day,
          ),
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jadwal berhasil ditambahkan')),
      );
    }

    titleController.dispose();
    locationController.dispose();
    descriptionController.dispose();
    timeController.dispose();
  }

  Future<void> showScheduleDetail(Map<String, dynamic> item) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item['title'] as String,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 18),
            _DetailRow(
              icon: Icons.calendar_today_outlined,
              text: formatDate(item['date'] as DateTime),
            ),
            _DetailRow(
              icon: Icons.access_time,
              text: item['time'] as String,
            ),
            _DetailRow(
              icon: Icons.location_on_outlined,
              text: item['location'] as String,
            ),
            if ((item['description'] as String).isNotEmpty)
              _DetailRow(
                icon: Icons.notes,
                text: item['description'] as String,
              ),
          ],
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
            // Tombol kembali
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
                  const Text(
                    'Jadwal Kegiatan',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
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
                  hintText: 'Cari kegiatan atau lokasi...',
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
                                        dateKey(item['date'] as DateTime) ==
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

                  if (filteredSchedules.isEmpty)
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
                      (item) => Card(
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
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.event_note_outlined,
                              color: green,
                            ),
                          ),
                          title: Text(
                            item['title'] as String,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            '${item['time']} • ${item['location']}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                          ),
                        ),
                      ),
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