// ============================================================================
// [KHUSUS USER - HALAMAN FOLDER LAPORAN & ARSIP KEGIATAN SAYA]
// Simpan file ini di: lib/pages/kategori.dart
// Hanya untuk User: Melihat folder kategori laporan & arsip kegiatan milik user
// ============================================================================

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class KategoriPage extends StatefulWidget {
  const KategoriPage({super.key});

  @override
  State<KategoriPage> createState() => _KategoriPageState();
}

class _KategoriPageState extends State<KategoriPage> {
  static const String _userArchiveKey = 'phonebook_user_folder_archives_v1';
  static const String _jadwalStorageKey = 'phonebook_jadwal_items_v1';
  static const String _laporanDraftKey = 'phonebook_laporan_drafts_v1';

  String _searchQuery = '';
  String _selectedTypeFilter = 'Semua';

  /// Jika tidak null, berarti sedang membuka salah satu folder kategori
  String? _openedCategoryFolder;

  final List<String> _categories = [
    'Penyuluhan',
    'Monitoring & Patroli',
    'Rehabilitasi Hutan',
    'Ekosistem & Konservasi',
    'Kelembagaan KTH',
  ];

  final List<Map<String, dynamic>> _myItems = [];

  @override
  void initState() {
    super.initState();
    _loadUserFolderData();
  }

  Future<void> _loadUserFolderData() async {
    final prefs = await SharedPreferences.getInstance();

    List<Map<String, dynamic>> items = _buildDefaultUserItems();
    final rawSaved = prefs.getString(_userArchiveKey);
    if (rawSaved != null && rawSaved.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(rawSaved);
        items = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {}
    }

    // Sinkronkan jadwal dari halaman Jadwal user
    final rawJadwal = prefs.getString(_jadwalStorageKey);
    if (rawJadwal != null && rawJadwal.isNotEmpty) {
      try {
        final List<dynamic> jadwalList = jsonDecode(rawJadwal);
        for (final j in jadwalList) {
          final map = Map<String, dynamic>.from(j);
          final id = 'my_jadwal_${map['id']}';
          if (!items.any((e) => e['id'] == id)) {
            items.insert(0, {
              'id': id,
              'judul': map['judul'] ?? 'Kegiatan Terjadwal',
              'tipe': 'Arsip Jadwal',
              'kategori': _normalizeCategory(
                (map['kategori'] ?? 'Penyuluhan').toString(),
              ),
              'lokasi': map['lokasi'] ?? 'Kecamatan Garut',
              'tanggal': map['tanggalIso'] ?? '20 Oktober 2026',
              'waktu': map['waktu'] ?? '08:00',
              'status': (map['isCompleted'] ?? false) ? 'Selesai' : 'Terjadwal',
              'deskripsi': map['catatan'] ??
                  'Arsip pelaksanaan jadwal kegiatan lapangan.',
            });
          }
        }
      } catch (_) {}
    }

    // Sinkronkan draft laporan dari halaman Laporan user
    final rawLaporan = prefs.getString(_laporanDraftKey);
    if (rawLaporan != null && rawLaporan.isNotEmpty) {
      try {
        final List<dynamic> laporanList = jsonDecode(rawLaporan);
        for (final l in laporanList) {
          final map = Map<String, dynamic>.from(l);
          final id = 'my_laporan_${map['id']}';
          if (!items.any((e) => e['id'] == id)) {
            items.insert(0, {
              'id': id,
              'judul': map['judul'] ?? 'Laporan Kegiatan',
              'tipe': 'Laporan',
              'kategori': _normalizeCategory(
                (map['jenis'] ?? 'Penyuluhan').toString(),
              ),
              'lokasi': map['lokasi'] ?? 'Garut',
              'tanggal': map['tanggal'] ?? '20 Oktober 2026',
              'waktu': '09:00',
              'status': map['status'] ?? 'Draft',
              'deskripsi':
                  map['isi'] ?? 'Dokumen laporan hasil kegiatan lapangan.',
            });
          }
        }
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _myItems
        ..clear()
        ..addAll(items);
    });
  }

  Future<void> _persistUserItems() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userArchiveKey, jsonEncode(_myItems));
  }

  String _normalizeCategory(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('monitor') || lower.contains('patroli')) {
      return 'Monitoring & Patroli';
    }
    if (lower.contains('rehab') || lower.contains('tanam')) {
      return 'Rehabilitasi Hutan';
    }
    if (lower.contains('ekosistem') || lower.contains('konservasi')) {
      return 'Ekosistem & Konservasi';
    }
    if (lower.contains('kth') || lower.contains('kelembagaan')) {
      return 'Kelembagaan KTH';
    }
    return 'Penyuluhan';
  }

  void _openAddFolderSheet() {
    String folderName = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        final bottomInset = MediaQuery.of(sheetCtx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(24, 8, 24, bottomInset + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tambah Folder Kategori Baru',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E2923),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                autofocus: true,
                onChanged: (v) => folderName = v,
                decoration: const InputDecoration(
                  labelText: 'Nama Folder',
                  hintText: 'Contoh: Perhutanan Sosial',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetCtx),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF285C2E),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        if (folderName.trim().isEmpty) return;
                        Navigator.pop(sheetCtx);
                        setState(() {
                          if (!_categories.contains(folderName.trim())) {
                            _categories.add(folderName.trim());
                          }
                        });
                      },
                      icon: const Icon(Icons.create_new_folder_outlined),
                      label: const Text('Simpan Folder'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showItemDetailSheet(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        final isLaporan = item['tipe'] == 'Laporan';
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: isLaporan
                          ? const Color(0xFFE8F5E9)
                          : const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      isLaporan
                          ? Icons.description_outlined
                          : Icons.event_available_rounded,
                      color: isLaporan
                          ? const Color(0xFF285C2E)
                          : const Color(0xFF1565C0),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (item['judul'] ?? '-').toString(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E2923),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item['tipe']} • Folder ${item['kategori']}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF5A655E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Text(
                'Lokasi: ${item['lokasi'] ?? '-'}',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tanggal: ${item['tanggal']} • ${item['waktu'] ?? '08:00'} WIB',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF5A655E),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                (item['deskripsi'] ?? '-').toString(),
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: Color(0xFF1E2923),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF285C2E),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(sheetCtx),
                  child: const Text('Tutup'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalLaporan = _myItems.where((e) => e['tipe'] == 'Laporan').length;
    final totalJadwal =
        _myItems.where((e) => e['tipe'] == 'Arsip Jadwal').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: _openedCategoryFolder != null
            ? IconButton(
                onPressed: () => setState(() => _openedCategoryFolder = null),
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: Color(0xFF285C2E),
                ),
              )
            : null,
        title: Text(
          _openedCategoryFolder != null
              ? 'Folder $_openedCategoryFolder'
              : 'Folder Laporan & Arsip Saya',
          style: const TextStyle(
            color: Color(0xFF1E2923),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddFolderSheet,
        backgroundColor: const Color(0xFF7B1FA2),
        foregroundColor: Colors.white,
        tooltip: 'Buat Folder Baru',
        child: const Icon(Icons.create_new_folder_outlined),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 90),
        children: [
          // Header Folder Arsip User
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF3E5F5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.folder_copy_rounded,
                  size: 42,
                  color: Color(0xFF7B1FA2),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Arsip Laporan & Kegiatan Saya',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E2923),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$totalLaporan Laporan Kegiatan • $totalJadwal Arsip Jadwal tersimpan',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF5A655E),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Search Bar
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Cari judul laporan, jadwal, atau nama folder...',
              hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Color(0xFF7B1FA2),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE0E7E1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE0E7E1)),
              ),
            ),
          ),

          const SizedBox(height: 22),

          if (_openedCategoryFolder == null) ...[
            const Text(
              'Daftar Folder Kategori',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E2923),
              ),
            ),
            const SizedBox(height: 12),
            ..._categories.map((cat) {
              final catItems =
                  _myItems.where((e) => e['kategori'] == cat).toList();
              final cLap =
                  catItems.where((e) => e['tipe'] == 'Laporan').length;
              final cJad =
                  catItems.where((e) => e['tipe'] == 'Arsip Jadwal').length;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE6ECE7)),
                ),
                child: ListTile(
                  onTap: () => setState(() => _openedCategoryFolder = cat),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E5F5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.folder_outlined,
                      color: Color(0xFF7B1FA2),
                    ),
                  ),
                  title: Text(
                    'Folder $cat',
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    '$cLap Laporan • $cJad Arsip Jadwal',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
              );
            }),
            const SizedBox(height: 22),
          ],

          Text(
            _openedCategoryFolder != null
                ? 'Isi Berkas di Folder $_openedCategoryFolder'
                : 'Seluruh Laporan & Arsip Kegiatan Saya',
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E2923),
            ),
          ),
          const SizedBox(height: 10),

          Wrap(
            spacing: 8,
            children: ['Semua', 'Laporan', 'Arsip Jadwal'].map((f) {
              final selected = _selectedTypeFilter == f;
              return ChoiceChip(
                label: Text(f),
                selected: selected,
                selectedColor: const Color(0xFF285C2E),
                labelStyle: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF1E2923),
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
                onSelected: (_) => setState(() => _selectedTypeFilter = f),
              );
            }).toList(),
          ),

          const SizedBox(height: 12),

          ..._buildUserArchiveList(),
        ],
      ),
    );
  }

  List<Widget> _buildUserArchiveList() {
    final q = _searchQuery.trim().toLowerCase();

    final list = _myItems.where((item) {
      if (_openedCategoryFolder != null &&
          item['kategori'] != _openedCategoryFolder) {
        return false;
      }
      if (_selectedTypeFilter != 'Semua' &&
          item['tipe'] != _selectedTypeFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return (item['judul'] ?? '').toString().toLowerCase().contains(q) ||
          (item['kategori'] ?? '').toString().toLowerCase().contains(q) ||
          (item['lokasi'] ?? '').toString().toLowerCase().contains(q);
    }).toList();

    if (list.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: const Text(
            'Belum ada berkas laporan atau arsip kegiatan di folder ini.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ];
    }

    return list.map((item) {
      final isLaporan = item['tipe'] == 'Laporan';
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE6ECE7)),
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          onTap: () => _showItemDetailSheet(item),
          leading: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: isLaporan
                  ? const Color(0xFFE8F5E9)
                  : const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isLaporan
                  ? Icons.description_outlined
                  : Icons.event_available_rounded,
              color: isLaporan
                  ? const Color(0xFF285C2E)
                  : const Color(0xFF1565C0),
            ),
          ),
          title: Text(
            (item['judul'] ?? '-').toString(),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E2923),
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Folder ${item['kategori']} • ${item['tanggal']} • ${item['lokasi']}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6E7A72)),
            ),
          ),
          trailing: IconButton(
            onPressed: () {
              setState(() {
                _myItems.removeWhere((e) => e['id'] == item['id']);
              });
              _persistUserItems();
            },
            icon: const Icon(
              Icons.delete_outline,
              color: Color(0xFFD32F2F),
              size: 20,
            ),
          ),
        ),
      );
    }).toList();
  }

  List<Map<String, dynamic>> _buildDefaultUserItems() {
    return [
      {
        'id': 'usr_arc_1',
        'judul': 'Laporan Penyuluhan Perhutanan Sosial KTH Makmur',
        'tipe': 'Laporan',
        'kategori': 'Penyuluhan',
        'lokasi': 'Kecamatan Garut',
        'tanggal': '20 Oktober 2026',
        'waktu': '08:00',
        'status': 'Selesai',
        'deskripsi':
            'Pendampingan penyusunan rencana kerja tahunan dan pembagian bibit produktif pada KTH Makmur.',
      },
      {
        'id': 'usr_arc_2',
        'judul': 'Arsip Kegiatan Monitoring Lapangan Blok Utara',
        'tipe': 'Arsip Jadwal',
        'kategori': 'Monitoring & Patroli',
        'lokasi': 'Kawasan Hutan Garut',
        'tanggal': '18 Oktober 2026',
        'waktu': '13:00',
        'status': 'Selesai',
        'deskripsi':
            'Pengecekan kondisi patok batas kawasan hutan dan pemantauan titik rawan kebakaran.',
      },
      {
        'id': 'usr_arc_3',
        'judul': 'Laporan Penanaman Bibit Pohon Bersama Warga',
        'tipe': 'Laporan',
        'kategori': 'Rehabilitasi Hutan',
        'lokasi': 'Lereng Gunung Guntur',
        'tanggal': '14 Oktober 2026',
        'waktu': '07:30',
        'status': 'Selesai',
        'deskripsi':
            'Kegiatan rehabilitasi lahan kritis bersama masyarakat desa sekitar kawasan hutan.',
      },
    ];
  }
}