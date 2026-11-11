// ============================================================================
// [KHUSUS USER - HALAMAN FOLDER LAPORAN & ARSIP KEGIATAN SAYA]
// Simpan file ini di: lib/pages/kategori.dart
// Hanya untuk User: Melihat folder kategori laporan & arsip kegiatan milik user
//
// REDESIGN UI: "Soft Green Forest - Modern Professional"
// - Palet Forest Green (#245C3A) yang konsisten, tanpa ungu/biru.
// - Header ringkasan gradasi soft green + ilustrasi daun minimalis.
// - Card putih rounded, shadow sangat tipis, white space lega.
// - Ikon berbeda tiap kategori folder, satu gaya visual.
// - Item arsip menampilkan status (Draft / Terjadwal / Selesai).
//
// CATATAN: Seluruh logika & fungsi lama dipertahankan 100%
// (sinkronisasi jadwal/draft, pencarian, filter, navigasi folder,
// tambah folder, detail item, hapus item, penyimpanan SharedPreferences).
// ============================================================================

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ----------------------------------------------------------------------------
// PALET WARNA - Soft Green Forest
// ----------------------------------------------------------------------------
const Color kPrimary = Color(0xFF245C3A); // Forest Green (utama)
const Color kSecondary = Color(0xFF4F8A5B); // Hijau sekunder
const Color kLightGreen = Color(0xFFE8F2E8); // Light green
const Color kSoftGreen = Color(0xFFF2F7F0); // Soft green
const Color kBackground = Color(0xFFF7F9F6); // Background
const Color kCard = Color(0xFFFFFFFF); // Card
const Color kTextPrimary = Color(0xFF24352A); // Teks utama
const Color kTextSecondary = Color(0xFF758278); // Teks sekunder
const Color kBorder = Color(0xFFE1EAE0); // Border

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

  // --------------------------------------------------------------------------
  // IKON & WARNA KATEGORI (satu gaya visual: outline, forest green)
  // --------------------------------------------------------------------------
  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Penyuluhan':
        return Icons.campaign_outlined;
      case 'Monitoring & Patroli':
        return Icons.travel_explore_outlined;
      case 'Rehabilitasi Hutan':
        return Icons.park_outlined;
      case 'Ekosistem & Konservasi':
        return Icons.eco_outlined;
      case 'Kelembagaan KTH':
        return Icons.groups_outlined;
      default:
        return Icons.folder_outlined;
    }
  }

  /// Warna badge status arsip
  Color _statusColor(String status) {
    switch (status) {
      case 'Selesai':
        return kPrimary;
      case 'Terjadwal':
        return kSecondary;
      default: // Draft
        return const Color(0xFF9A6A12); // aksen cokelat keemasan (bukan ungu/biru)
    }
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
                  color: kTextPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Folder baru akan muncul pada daftar folder kategori Anda.',
                style: TextStyle(fontSize: 13.5, color: kTextSecondary),
              ),
              const SizedBox(height: 16),
              TextFormField(
                autofocus: true,
                onChanged: (v) => folderName = v,
                decoration: InputDecoration(
                  labelText: 'Nama Folder',
                  hintText: 'Contoh: Perhutanan Sosial',
                  labelStyle: const TextStyle(color: kTextSecondary),
                  floatingLabelStyle: const TextStyle(
                    color: kPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  prefixIcon: const Icon(
                    Icons.create_new_folder_outlined,
                    color: kSecondary,
                  ),
                  filled: true,
                  fillColor: kSoftGreen,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 15,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: kBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: kBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: kPrimary, width: 1.6),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kTextPrimary,
                          side: const BorderSide(color: kBorder),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => Navigator.pop(sheetCtx),
                        child: const Text(
                          'Batal',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 1,
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
                        label: const Text(
                          'Simpan Folder',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
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
    final isLaporan = item['tipe'] == 'Laporan';
    final status = (item['status'] ?? 'Draft').toString();

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: isLaporan ? kLightGreen : kSoftGreen,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      isLaporan
                          ? Icons.description_outlined
                          : Icons.event_available_rounded,
                      color: isLaporan ? kPrimary : kSecondary,
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
                            fontSize: 17.5,
                            fontWeight: FontWeight.bold,
                            color: kTextPrimary,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item['tipe']} • Folder ${item['kategori']}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: kTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _StatusBadge(status: status, fg: _statusColor(status)),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: kSoftGreen,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    _detailRow(
                      Icons.place_outlined,
                      'Lokasi',
                      (item['lokasi'] ?? '-').toString(),
                    ),
                    const SizedBox(height: 8),
                    _detailRow(
                      Icons.event_outlined,
                      'Tanggal',
                      '${item['tanggal']} • ${item['waktu'] ?? '08:00'} WIB',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                (item['deskripsi'] ?? '-').toString(),
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: kTextPrimary,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 1,
                  ),
                  onPressed: () => Navigator.pop(sheetCtx),
                  child: const Text(
                    'Tutup',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: kSecondary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: kTextPrimary,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13.5, color: kTextSecondary),
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // ============================ BUILD UI ====================================
  // --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final totalLaporan = _myItems.where((e) => e['tipe'] == 'Laporan').length;
    final totalJadwal =
        _myItems.where((e) => e['tipe'] == 'Arsip Jadwal').length;

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        toolbarHeight: 64,
        centerTitle: false,
        leading: _openedCategoryFolder != null
            ? IconButton(
                onPressed: () => setState(() => _openedCategoryFolder = null),
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: kPrimary,
                ),
              )
            : null,
        title: Text(
          _openedCategoryFolder != null
              ? 'Folder $_openedCategoryFolder'
              : 'Folder Laporan & Arsip Saya',
          style: const TextStyle(
            color: kTextPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      // E. Floating Action Button - forest green, ikon folder putih
floatingActionButton: DecoratedBox(
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(18),
    boxShadow: [
      BoxShadow(
        color: kPrimary.withOpacity(0.35),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  ),
  child: FloatingActionButton(
    onPressed: _openAddFolderSheet,
    backgroundColor: kPrimary,
    foregroundColor: Colors.white,
    tooltip: 'Buat Folder Baru',
    elevation: 0,
    highlightElevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
    ),
    child: const Icon(Icons.create_new_folder_outlined),
  ),
),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
        children: [
          // B. Header Ringkasan - gradasi soft green + ilustrasi daun
          _buildSummaryHeader(totalLaporan, totalJadwal),
          const SizedBox(height: 16),

          // C. Search Bar
          _buildSearchBar(),
          const SizedBox(height: 24),

          // D. Daftar Folder Kategori
          if (_openedCategoryFolder == null) ...[
            const Text(
              'Daftar Folder Kategori',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: kTextPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ..._categories.map(_buildCategoryCard),
            const SizedBox(height: 24),
          ],

          // F. Daftar Arsip
          Text(
            _openedCategoryFolder != null
                ? 'Isi Berkas di Folder $_openedCategoryFolder'
                : 'Seluruh Laporan & Arsip Kegiatan Saya',
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: kTextPrimary,
            ),
          ),
          const SizedBox(height: 12),

          _buildFilterChips(),
          const SizedBox(height: 14),

          ..._buildUserArchiveList(),
        ],
      ),
    );
  }

  /// B. Kartu ringkasan arsip dengan gradasi halus + ilustrasi daun kanan
  Widget _buildSummaryHeader(int totalLaporan, int totalJadwal) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
      decoration: BoxDecoration(
        // Gradasi soft green yang sangat halus
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF5F9F2), kSoftGreen, kLightGreen],
          stops: [0.0, 0.55, 1.0],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: kPrimary,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.folder_copy_rounded,
                        size: 26,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Flexible(
                      child: Text(
                        'Arsip Laporan & Kegiatan Saya',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                          color: kTextPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _summaryChip(
                      icon: Icons.description_outlined,
                      label: '$totalLaporan Laporan Kegiatan',
                    ),
                    _summaryChip(
                      icon: Icons.event_available_rounded,
                      label: '$totalJadwal Arsip Jadwal',
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Ilustrasi daun minimalis di sisi kanan
          const SizedBox(
            width: 60,
            height: 100,
            child: _LeafIllustration(),
          ),
        ],
      ),
    );
  }

  Widget _summaryChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: kPrimary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: kTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// C. Search bar rounded besar & nyaman (54px)
  Widget _buildSearchBar() {
    return SizedBox(
      height: 54,
      child: TextField(
        onChanged: (val) => setState(() => _searchQuery = val),
        style: const TextStyle(fontSize: 15, color: kTextPrimary),
        decoration: InputDecoration(
          hintText: 'Cari folder, judul laporan, atau nama...',
          hintStyle: const TextStyle(fontSize: 14, color: kTextSecondary),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: kPrimary,
            size: 24,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  tooltip: 'Bersihkan pencarian',
                  icon: const Icon(
                    Icons.close_rounded,
                    color: kTextSecondary,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _searchQuery = ''),
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: kBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: kBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: kPrimary, width: 1.6),
          ),
        ),
      ),
    );
  }

  /// D. Card kategori folder vertikal modern (rounded 18, shadow tipis)
  Widget _buildCategoryCard(String cat) {
    final catItems = _myItems.where((e) => e['kategori'] == cat).toList();
    final cLap = catItems.where((e) => e['tipe'] == 'Laporan').length;
    final cJad = catItems.where((e) => e['tipe'] == 'Arsip Jadwal').length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kBorder),
        boxShadow: [
          // Shadow sangat tipis
          BoxShadow(
            color: kPrimary.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => setState(() => _openedCategoryFolder = cat),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                // Ikon kategori dalam wadah soft green (aksen)
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: kLightGreen,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _categoryIcon(cat),
                    color: kPrimary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cat,
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w600,
                          color: kTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$cLap Laporan • $cJad Arsip Jadwal',
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: kTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: kSoftGreen,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${cLap + cJad} berkas',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: kSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: kSecondary,
                  size: 26,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// F. Filter Semua / Laporan / Arsip Jadwal (tinggi 46px, sentuh nyaman)
  Widget _buildFilterChips() {
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: ['Semua', 'Laporan', 'Arsip Jadwal'].map((f) {
          final selected = _selectedTypeFilter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () => setState(() => _selectedTypeFilter = f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? kPrimary : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected ? kPrimary : kBorder,
                    width: 1.2,
                  ),
                ),
                child: Text(
                  f,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : kTextPrimary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: kBorder),
          ),
          child: Column(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: const BoxDecoration(
                  color: kLightGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.folder_open_rounded,
                  size: 30,
                  color: kSecondary,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Belum ada berkas di sini',
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.bold,
                  color: kTextPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Laporan dan arsip jadwal kegiatan yang\ntersimpan akan tampil pada folder ini.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: kTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ];
    }

    return list.map((item) {
      final isLaporan = item['tipe'] == 'Laporan';
      final status = (item['status'] ?? 'Draft').toString();
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kBorder),
          boxShadow: [
            BoxShadow(
              color: kPrimary.withOpacity(0.04),
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
            onTap: () => _showItemDetailSheet(item),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isLaporan ? kLightGreen : kSoftGreen,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      isLaporan
                          ? Icons.description_outlined
                          : Icons.event_available_rounded,
                      color: isLaporan ? kPrimary : kSecondary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (item['judul'] ?? '-').toString(),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: kTextPrimary,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 4,
                          runSpacing: 5,
                          children: [
                            _archiveMeta(
                              Icons.folder_outlined,
                              '${item['kategori']}',
                            ),
                            _archiveMeta(
                              Icons.event_outlined,
                              '${item['tanggal']}',
                            ),
                            _archiveMeta(
                              Icons.place_outlined,
                              '${item['lokasi']}',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _StatusBadge(status: status, fg: _statusColor(status)),
                      ],
                    ),
                  ),
                  // Tombol hapus (area sentuh 44x44)
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        setState(() {
                          _myItems.removeWhere((e) => e['id'] == item['id']);
                        });
                        _persistUserItems();
                      },
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Color(0xFFB2472D),
                        size: 21,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  /// Metadata item arsip (kategori / tanggal / lokasi)
  Widget _archiveMeta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: kTextSecondary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, color: kTextSecondary),
          ),
        ),
        const SizedBox(width: 6),
      ],
    );
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

// ============================================================================
// BADGE STATUS ARSIP (Draft / Terjadwal / Selesai)
// ============================================================================
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.fg});

  final String status;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    IconData icon;
    switch (status) {
      case 'Selesai':
        icon = Icons.check_circle_rounded;
        break;
      case 'Terjadwal':
        icon = Icons.schedule_rounded;
        break;
      default: // Draft
        icon = Icons.edit_note_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: fg.withOpacity(0.12),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 5),
          Text(
            status,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: fg,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ILUSTRASI DAUN MINIMALIS (kanan kartu ringkasan)
// Tiga helai daun sederhana bergaya flat, warna hijau transparan lembut.
// ============================================================================
class _LeafIllustration extends StatelessWidget {
  const _LeafIllustration();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(60, 100),
      painter: _LeafPainter(),
    );
  }
}

class _LeafPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Helai daun besar
    final leafBig = Paint()
      ..color = kSecondary.withOpacity(0.30)
      ..style = PaintingStyle.fill;

    // Helai daun sedang
    final leafMid = Paint()
      ..color = kPrimary.withOpacity(0.20)
      ..style = PaintingStyle.fill;

    // Helai daun kecil (paling atas)
    final leafSmall = Paint()
      ..color = kSecondary.withOpacity(0.16)
      ..style = PaintingStyle.fill;

    // Tangkai
    final stem = Paint()
      ..color = kPrimary.withOpacity(0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    // Tangkai melengkung dari bawah ke atas
    final stemPath = Path();
    stemPath.moveTo(size.width * 0.40, size.height * 0.98);
    stemPath.quadraticBezierTo(
      size.width * 0.44,
      size.height * 0.55,
      size.width * 0.62,
      size.height * 0.22,
    );
    canvas.drawPath(stemPath, stem);

    // Daun besar (kiri bawah tangkai)
    canvas.drawPath(
      _leafPath(
        tipX: size.width * 0.02,
        tipY: size.height * 0.36,
        baseX: size.width * 0.46,
        baseY: size.height * 0.70,
      ),
      leafBig,
    );

    // Daun sedang (kanan tengah tangkai)
    canvas.drawPath(
      _leafPath(
        tipX: size.width * 0.98,
        tipY: size.height * 0.42,
        baseX: size.width * 0.52,
        baseY: size.height * 0.62,
      ),
      leafMid,
    );

    // Daun kecil (paling atas)
    canvas.drawPath(
      _leafPath(
        tipX: size.width * 0.68,
        tipY: size.height * 0.02,
        baseX: size.width * 0.58,
        baseY: size.height * 0.30,
      ),
      leafSmall,
    );
  }

  /// Membentuk satu helai daun (dua kurva bezier bertemu di ujung)
  Path _leafPath({
    required double tipX,
    required double tipY,
    required double baseX,
    required double baseY,
  }) {
    final ctrlDx = (tipX - baseX).abs() * 0.9 + 6;
    final ctrlDy = (tipY - baseY).abs() * 0.6 + 6;

    final path = Path();
    path.moveTo(baseX, baseY);
    path.quadraticBezierTo(
      baseX - ctrlDx * 0.4,
      baseY - ctrlDy,
      tipX,
      tipY,
    );
    path.quadraticBezierTo(
      baseX + ctrlDx * 0.6,
      baseY - ctrlDy * 0.8,
      baseX,
      baseY,
    );
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
