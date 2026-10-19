import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

const String baseUrl = 'http://127.0.0.1:8001';

class LaporanPage extends StatefulWidget {
  const LaporanPage({super.key});

  @override
  State<LaporanPage> createState() => _LaporanPageState();
}

class _LaporanPageState extends State<LaporanPage> {
  int selectedTab = 0;
  static const String _storageKey = 'phonebook_laporan_drafts_v1';

  @override
  void initState() {
    super.initState();
    _loadSavedReports();
  }

  
Future<void> _loadSavedReports() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null || token.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sesi login tidak ditemukan. Silakan login kembali.'),
        ),
      );
      return;
    }

    final response = await http.get(
      Uri.parse('$baseUrl/api/reports'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (!mounted) return;

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final List<dynamic> data = body['data'] ?? [];

      setState(() {
        laporanList
          ..clear()
          ..addAll(data.map((item) {
            final report = Map<String, dynamic>.from(item as Map);
            final rawStatus = report['status']?.toString() ?? 'draft';
            final activityDate =
                report['activity_date']?.toString() ?? '';

            return <String, dynamic>{
              'id': report['id'],
              'judul': report['title'] ?? 'Laporan tanpa judul',
              'jenis': report['category']?['name'] ?? 'Laporan Kegiatan',
              'tanggal': _formatApiDate(activityDate),
              'tanggalApi': activityDate,
              'lokasi': report['location'] ?? 'Belum diisi',
              'isi': report['description'] ?? '',
              'latitude': report['latitude']?.toString() ?? '',
              'longitude': report['longitude']?.toString() ?? '',
              'foto': '',
              'photos': report['photos'] ?? [],
              'status': _displayStatus(rawStatus),
              'statusApi': rawStatus,
            };
          }));
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal mengambil laporan (${response.statusCode}): ${response.body}',
          ),
        ),
      );
    }
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Gagal terhubung ke Laravel: $e')),
    );
  }
}

String _displayStatus(String status) {
  switch (status) {
    case 'draft':
      return 'Draft';
    case 'terkirim':
      return 'Selesai';
    case 'diperiksa':
      return 'Diproses';
    case 'disetujui':
      return 'Disetujui';
    case 'ditolak':
      return 'Ditolak';
    default:
      return status;
  }
}

String _formatApiDate(String date) {
  final parsed = DateTime.tryParse(date);
  if (parsed == null) return date;

  return '${parsed.day} ${_monthName(parsed.month)} ${parsed.year}';
}

  Future<void> _persistReports() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(laporanList));
  }

  Future<void> _saveReport(Map<String, dynamic> report) async {
    final id = report['id'];
    final index = laporanList.indexWhere((item) => item['id'] == id);
    setState(() {
      if (index >= 0) {
        laporanList[index] = report;
      } else {
        laporanList.insert(0, report);
      }
    });
    await _persistReports();
  }


  final List<Map<String, dynamic>> laporanList = [];  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Laporan',
          style: TextStyle(
            color: Color(0xFF1F2D21),
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(
          color: Color(0xFF285C2E),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),

              const SizedBox(height: 24),

              _buildCreateReportCard(),

              const SizedBox(height: 28),

              _buildSectionTitle(),

              const SizedBox(height: 14),

              _buildTabs(),

              const SizedBox(height: 18),

              if (selectedTab == 0)
                _buildReportHistory()
              else
                _buildReportTemplates(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF2E7D32),
            Color(0xFF4C944F),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.15),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.description_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),

          const SizedBox(width: 16),

          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kelola Laporan',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Buat, lihat, dan simpan laporan kegiatan lapangan Anda.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateReportCard() {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        _showReportTypeDialog();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFDCE6DC),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Color(0xFF2E7D32),
                size: 34,
              ),
            ),

            const SizedBox(width: 16),

            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Buat Laporan Baru',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF253127),
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Isi laporan berdasarkan jenis kegiatan yang dilakukan.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 18,
              color: Color(0xFF2E7D32),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Arsip Laporan',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2D21),
          ),
        ),
        SizedBox(height: 5),
        Text(
          'Draft yang masih bisa diedit dan arsip laporan yang sudah selesai.',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EDE8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _tabButton(
              title: 'Riwayat Laporan',
              icon: Icons.history_rounded,
              index: 0,
            ),
          ),
          Expanded(
            child: _tabButton(
              title: 'Jenis Laporan',
              icon: Icons.category_outlined,
              index: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton({
    required String title,
    required IconData icon,
    required int index,
  }) {
    final bool active = selectedTab == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedTab = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          vertical: 13,
          horizontal: 8,
        ),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 19,
              color: active
                  ? const Color(0xFF2E7D32)
                  : Colors.grey.shade600,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      active ? FontWeight.bold : FontWeight.w500,
                  color: active
                      ? const Color(0xFF2E7D32)
                      : Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportHistory() {
    if (laporanList.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: laporanList.map((laporan) {
        return _buildReportCard(laporan);
      }).toList(),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> laporan) {
    final String status = laporan['status'];

    Color statusColor;
    Color statusBackground;

    if (status == 'Selesai') {
      statusColor = const Color(0xFF2E7D32);
      statusBackground = const Color(0xFFE8F5E9);
    } else if (status == 'Diproses') {
      statusColor = const Color(0xFFB26A00);
      statusBackground = const Color(0xFFFFF4DC);
    } else {
      statusColor = Colors.grey.shade700;
      statusBackground = Colors.grey.shade200;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE1E7E1),
        ),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF4EA),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: Color(0xFF2E7D32),
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
                        color: Color(0xFF263329),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      laporan['jenis'],
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6E776F),
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusBackground,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          const Divider(
            height: 1,
            color: Color(0xFFE9EDE9),
          ),

          const SizedBox(height: 13),

          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 16,
                color: Color(0xFF718071),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  laporan['tanggal'],
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF596259),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 17,
                color: Color(0xFF718071),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  laporan['lokasi'],
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF596259),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _showReportDetail(laporan),
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('Lihat'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2E7D32),
                  side: const BorderSide(color: Color(0xFFB9CCBA)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                ),
              ),
              if (status == 'Draft')
                OutlinedButton.icon(
                  onPressed: () => _showReportForm(laporan['jenis'], existing: laporan),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Lanjutkan / Edit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB26A00),
                    side: const BorderSide(color: Color(0xFFE7C98A)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                  ),
                ),
              if (status == 'Selesai')
                ElevatedButton.icon(
                  onPressed: () => _downloadReport(laporan),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Unduh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReportTemplates() {
    final templates = [
      {
        'icon': Icons.groups_outlined,
        'title': 'Laporan Penyuluhan',
        'description':
            'Digunakan untuk melaporkan kegiatan penyuluhan kehutanan.',
      },
      {
        'icon': Icons.forest_outlined,
        'title': 'Laporan Monitoring',
        'description':
            'Digunakan untuk melaporkan hasil monitoring kawasan hutan.',
      },
      {
        'icon': Icons.event_note_outlined,
        'title': 'Laporan Kegiatan',
        'description':
            'Digunakan untuk berbagai kegiatan lapangan lainnya.',
      },
      {
        'icon': Icons.warning_amber_rounded,
        'title': 'Laporan Kejadian',
        'description':
            'Digunakan untuk melaporkan kejadian atau kondisi khusus di lapangan.',
      },
    ];

    return Column(
      children: templates.map((template) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: const Color(0xFFE0E7E0),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF4EA),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  template['icon'] as IconData,
                  color: const Color(0xFF2E7D32),
                  size: 25,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template['title'] as String,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      template['description'] as String,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              IconButton(
                onPressed: () {
                  _showReportForm(
                    template['title'] as String,
                  );
                },
                icon: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 18,
                ),
                color: const Color(0xFF2E7D32),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 25,
        vertical: 45,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.folder_open_outlined,
            size: 55,
            color: Color(0xFF9EAA9E),
          ),
          SizedBox(height: 15),
          Text(
            'Belum ada laporan',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 7),
          Text(
            'Laporan yang Anda buat akan muncul di sini.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  void _showReportTypeDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(25),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                'Pilih Jenis Laporan',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 5),

              const Text(
                'Pilih template yang sesuai dengan kegiatan Anda.',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 18),

              _typeOption(
                icon: Icons.groups_outlined,
                title: 'Laporan Penyuluhan',
              ),

              _typeOption(
                icon: Icons.forest_outlined,
                title: 'Laporan Monitoring',
              ),

              _typeOption(
                icon: Icons.event_note_outlined,
                title: 'Laporan Kegiatan',
              ),

              _typeOption(
                icon: Icons.warning_amber_rounded,
                title: 'Laporan Kejadian',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _typeOption({
    required IconData icon,
    required String title,
  }) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        _showReportForm(title);
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F9F6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFE0E8E0),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: const Color(0xFF2E7D32),
              size: 25,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 15,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  void _showReportForm(String jenisLaporan, {Map<String, dynamic>? existing}) {
    final judulController = TextEditingController(text: existing?['judul']?.toString() ?? '');
    final isiController = TextEditingController(text: existing?['isi']?.toString() ?? '');
    final lokasiController = TextEditingController(text: existing?['lokasi']?.toString() ?? '');
    final latitudeController = TextEditingController(text: existing?['latitude']?.toString() ?? '');
    final longitudeController = TextEditingController(text: existing?['longitude']?.toString() ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(25),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            18,
            20,
            MediaQuery.of(context).viewInsets.bottom + 25,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  jenisLaporan,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                const Text(
                  'Lengkapi data laporan sesuai kegiatan di lapangan.',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height: 20),

                _formField(
                  controller: judulController,
                  label: 'Judul Laporan',
                  hint: 'Contoh: Penyuluhan Kehutanan',
                  icon: Icons.title_rounded,
                ),

                const SizedBox(height: 13),

                _formField(
                  controller: isiController,
                  label: 'Isi / Keterangan Laporan',
                  hint: 'Tuliskan hasil kegiatan...',
                  icon: Icons.notes_rounded,
                  maxLines: 5,
                ),

                const SizedBox(height: 13),

                _formField(
                  controller: lokasiController,
                  label: 'Lokasi Kegiatan',
                  hint: 'Contoh: Kawasan Hutan Garut',
                  icon: Icons.location_on_outlined,
                ),

                const SizedBox(height: 13),

                Row(
                  children: [
                    Expanded(
                      child: _formField(
                        controller: latitudeController,
                        label: 'Latitude',
                        hint: '-7.2279',
                        icon: Icons.my_location_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _formField(
                        controller: longitudeController,
                        label: 'Longitude',
                        hint: '107.9087',
                        icon: Icons.explore_outlined,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 15),

                _buildPhotoButton(),

                const SizedBox(height: 22),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
  await _submitReport(
    jenisLaporan: jenisLaporan,
    existing: existing,
    judulController: judulController,
    isiController: isiController,
    lokasiController: lokasiController,
    latitudeController: latitudeController,
    longitudeController: longitudeController,
    status: 'Draft',
  );

  if (!mounted) return;

  // Tutup form hanya jika laporan berhasil tersimpan.
  // Untuk membedakan sukses/gagal dengan benar, sebaiknya
  // _submitReport diubah mengembalikan bool pada langkah berikutnya.
},
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Simpan Sementara'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2E7D32),
                          side: const BorderSide(color: Color(0xFF2E7D32)),
                          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          if (judulController.text.trim().isEmpty || isiController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(content: Text('Isi judul dan isi laporan sebelum menyelesaikan laporan.')),
                            );
                            return;
                          }
                          await _submitReport(
                            jenisLaporan: jenisLaporan,
                            existing: existing,
                            judulController: judulController,
                            isiController: isiController,
                            lokasiController: lokasiController,
                            latitudeController: latitudeController,
                            longitudeController: longitudeController,
                            status: 'Selesai',
                          );
                          if (context.mounted) Navigator.pop(context);
                        },
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Selesaikan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
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
    );
  }

  
Future<void> _submitReport({
  required String jenisLaporan,
  required Map<String, dynamic>? existing,
  required TextEditingController judulController,
  required TextEditingController isiController,
  required TextEditingController lokasiController,
  required TextEditingController latitudeController,
  required TextEditingController longitudeController,
  required String status,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');

  if (token == null || token.isEmpty) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Silakan login kembali.')),
    );
    return;
  }

  final now = DateTime.now();
  final existingDate = existing?['tanggalApi']?.toString();

  final activityDate = existingDate != null &&
          existingDate.isNotEmpty
      ? existingDate
      : '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

  final title = judulController.text.trim();
  final location = lokasiController.text.trim();

  // API Laravel mewajibkan judul, tanggal, dan lokasi.
  if (title.isEmpty || location.isEmpty) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Judul dan lokasi wajib diisi.'),
      ),
    );
    return;
  }

  final apiStatus = status == 'Draft' ? 'draft' : 'terkirim';

  final payload = <String, dynamic>{
    'title': title,
    'activity_date': activityDate,
    'location': location,
    'description': isiController.text.trim(),
    'latitude': latitudeController.text.trim().isEmpty
        ? null
        : double.tryParse(latitudeController.text.trim()),
    'longitude': longitudeController.text.trim().isEmpty
        ? null
        : double.tryParse(longitudeController.text.trim()),
    'status': apiStatus,
  };

  try {
    final isEditing = existing?['id'] != null &&
        int.tryParse(existing!['id'].toString()) != null;

    final uri = isEditing
        ? Uri.parse('$baseUrl/api/reports/${existing!['id']}')
        : Uri.parse('$baseUrl/api/reports');

    final response = isEditing
        ? await http.put(
            uri,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(payload),
          )
        : await http.post(
            uri,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(payload),
          );

    if (!mounted) return;

    if (response.statusCode == 200 || response.statusCode == 201) {
      await _loadSavedReports();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            apiStatus == 'draft'
                ? 'Draft berhasil disimpan ke database.'
                : 'Laporan berhasil dikirim ke database.',
          ),
        ),
      );
    } else {
      String message = 'Gagal menyimpan laporan (${response.statusCode}).';

      try {
        final body = jsonDecode(response.body);
        message = body['message']?.toString() ?? message;

        if (body['errors'] is Map) {
          final errors = body['errors'] as Map;
          message += '\n${errors.values.expand((e) => e is List ? e : [e]).join('\n')}';
        }
      } catch (_) {}

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Gagal mengirim laporan: $e')),
    );
  }
}

  String _monthName(int month) {
    const months = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
    return months[month - 1];
  }

  Widget _formField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Padding(
          padding: EdgeInsets.only(
            bottom: maxLines > 1 ? 70 : 0,
          ),
          child: Icon(
            icon,
            color: const Color(0xFF527054),
          ),
        ),
        filled: true,
        fillColor: const Color(0xFFF7F9F7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(
            color: Color(0xFFDDE5DD),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(
            color: Color(0xFFDDE5DD),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(
            color: Color(0xFF2E7D32),
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoButton() {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Fitur pengambilan foto akan dihubungkan ke kamera.',
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          vertical: 18,
          horizontal: 15,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9F7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFDDE5DD),
          ),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.camera_alt_outlined,
              color: Color(0xFF2E7D32),
              size: 25,
            ),
            SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Foto Lokasi / Kegiatan',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Ambil atau pilih foto sebagai bukti kegiatan.',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.add_a_photo_outlined,
              color: Color(0xFF2E7D32),
            ),
          ],
        ),
      ),
    );
  }   

  void _showReportDetail(Map<String, dynamic> laporan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(25),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            20,
            20,
            20,
            30,
          ),
          child: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Text(
                laporan['judul'],
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                laporan['jenis'],
                style: const TextStyle(
                  color: Color(0xFF2E7D32),
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 20),

              _detailRow(
                Icons.calendar_today_outlined,
                'Tanggal',
                laporan['tanggal'],
              ),

              _detailRow(
                Icons.location_on_outlined,
                'Lokasi',
                laporan['lokasi'],
              ),

              _detailRow(
                Icons.info_outline,
                'Status',
                laporan['status']?.toString() ?? 'Draft',
              ),

              const SizedBox(height: 8),
              const Text('Isi Laporan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFFF6F9F6), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE0E8E0))),
                child: Text((laporan['isi']?.toString().isNotEmpty ?? false) ? laporan['isi'].toString() : 'Isi laporan belum dilengkapi.', style: const TextStyle(height: 1.5)),
              ),
              const SizedBox(height: 14),
              _detailRow(Icons.my_location_outlined, 'Latitude', (laporan['latitude']?.toString().isNotEmpty ?? false) ? laporan['latitude'].toString() : 'Belum tersedia'),
              _detailRow(Icons.explore_outlined, 'Longitude', (laporan['longitude']?.toString().isNotEmpty ?? false) ? laporan['longitude'].toString() : 'Belum tersedia'),
              const SizedBox(height: 20),

              if (laporan['status'] == 'Draft')
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showReportForm(laporan['jenis'], existing: laporan);
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Lanjutkan / Edit Draft'),
                  ),
                ),
              if (laporan['status'] == 'Selesai')
                SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _downloadReport(laporan);
                  },
                  icon: const Icon(
                    Icons.download_rounded,
                  ),
                  label: const Text('Unduh Laporan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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
  }

  Widget _detailRow(
    IconData icon,
    String title,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: const Color(0xFF527054),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 65,
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _downloadReport(Map<String, dynamic> laporan) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Menyiapkan file "${laporan['judul']}"...',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}