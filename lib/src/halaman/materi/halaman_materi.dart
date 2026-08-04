import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // Tambahan penting untuk deteksi Web
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
 
class HalamanMateriEdukasi extends StatefulWidget {
  const HalamanMateriEdukasi({super.key});
 
  @override
  State<HalamanMateriEdukasi> createState() => _HalamanMateriEdukasiState();
}
 
class _HalamanMateriEdukasiState extends State<HalamanMateriEdukasi> {
  String _kategoriAktif = 'Semua';
 
  final TextEditingController _judulController = TextEditingController();
  final TextEditingController _kategoriController = TextEditingController();
 
  // File yang baru saja dipilih lewat file_picker, sebelum ditekan "Upload"
  PlatformFile? _filePicked;
  bool _sedangMenyalinFile = false;
 
  final List<String> _daftarKategori = [
    'Semua',
    'KTH',
    'RHL',
    'Panduan',
    'Modul',
    'Jurnal'
  ];
 
  
  List<Map<String, dynamic>> _semuaMateri = [
    {
      'judul': 'Panduan Budidaya Kopi Di Bawah Tegakan',
      'penulis': 'Dinas Kehutanan',
      'kategori': 'Panduan',
      'tipe': 'PDF',
      'ukuran': '13 KB',
      'warna': const Color(0xFFE53935),
      'deskripsi':
          'Panduan komprehensif tentang cara membudidayakan tanaman kopi di bawah naungan pohon hutan tanpa merusak ekosistem tegakan utama. Sangat cocok untuk petani hutan (KTH).',
      'url': 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
      'localPath': null,
    },
    {
      'judul': 'Modul Pencegahan Kebakaran Hutan 2026',
      'penulis': 'KLHK Pusat',
      'kategori': 'Modul',
      'tipe': 'PDF',
      'ukuran': '13 KB',
      'warna': const Color(0xFF1E88E5),
      'deskripsi':
          'Modul pelatihan standar untuk tim pemadam dan masyarakat sekitar hutan mengenai langkah-langkah mitigasi dan pencegahan karhutla secara dini.',
      'url': 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
      'localPath': null,
    },
    {
      'judul': 'Teknik Pemetaan Partisipatif KTH',
      'penulis': 'Budi Santoso',
      'kategori': 'KTH',
      'tipe': 'PDF',
      'ukuran': '13 KB',
      'warna': const Color(0xFFE53935),
      'deskripsi':
          'Buku saku teknik pemetaan wilayah kelola hutan oleh masyarakat. Berisi panduan menggunakan GPS handheld dan aplikasi pemetaan di smartphone.',
      'url': 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
      'localPath': null,
    },
    {
      'judul': 'Pedoman Pelaksanaan RHL Terpadu',
      'penulis': 'Dirjen PDASRH',
      'kategori': 'RHL',
      'tipe': 'PDF',
      'ukuran': '13 KB',
      'warna': const Color(0xFFE53935),
      'deskripsi':
          'Buku pedoman resmi mengenai Rehabilitasi Hutan dan Lahan (RHL) terpadu, mencakup aspek perencanaan, penanaman, hingga evaluasi keberhasilan tumbuh.',
      'url': 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
      'localPath': null,
    },
    {
      'judul': 'Jurnal Pengelolaan Hutan Produksi',
      'penulis': 'Universitas Rimbawan',
      'kategori': 'Jurnal',
      'tipe': 'PDF',
      'ukuran': '13 KB',
      'warna': const Color(0xFF1E88E5),
      'deskripsi':
          'Kumpulan hasil penelitian terbaru tentang teknik silvikultur intensif pada Hutan Tanaman Industri (HTI) untuk meningkatkan riap kayu.',
      'url': 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
      'localPath': null,
    },
  ];
 
  @override
  void dispose() {
    _judulController.dispose();
    _kategoriController.dispose();
    super.dispose();
  }
 
  String _formatUkuranFile(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = (bytes == 0) ? 0 : (bytes.bitLength - 1) ~/ 10;
    if (i >= suffixes.length) i = suffixes.length - 1;
    final size = bytes / (1 << (i * 10));
    return '${size.toStringAsFixed(size < 10 && i > 0 ? 1 : 0)} ${suffixes[i]}';
  }
 
  // Membuka file picker sungguhan untuk memilih PDF / DOC / DOCX
  Future<void> _pilihFile(StateSetter setDialogState) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
      withData: kIsWeb, // Wajib true jika di web agar bisa membaca ukuran/byte
    );
 
    if (result != null && result.files.isNotEmpty) {
      setDialogState(() {
        _filePicked = result.files.first;
      });
      // Auto-isi judul dari nama file jika masih kosong
      if (_judulController.text.trim().isEmpty) {
        final namaTanpaEkstensi =
            _filePicked!.name.replaceAll(RegExp(r'\.(pdf|docx|doc)$', caseSensitive: false), '');
        _judulController.text = namaTanpaEkstensi;
      }
    }
  }
 
  // Menyalin file yang dipilih (Aman untuk Web dan Mobile)
  Future<void> _simpanMateriBaru() async {
    final String judul = _judulController.text.trim();
    final String kategoriInput = _kategoriController.text.trim();
    final String kategori = kategoriInput.isEmpty ? 'Umum' : kategoriInput;
 
    if (judul.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Judul materi tidak boleh kosong!'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
 
    // Jika di mobile pastikan path ada, jika di web path memang selalu null jadi gunakan bytes
    if (_filePicked == null || (!kIsWeb && _filePicked!.path == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih file PDF/Word terlebih dahulu!'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
 
    setState(() => _sedangMenyalinFile = true);
 
    try {
      String? savedPath;
      int ukuranBytes = 15000; // Mock default
      final ekstensi = _filePicked!.extension?.toLowerCase() ?? 'pdf';

      if (kIsWeb) {
        // --- LOGIKA WEB ---
        // Browser tidak mengizinkan simpan file langsung ke lokal disk (path_provider tidak bekerja).
        // Kita simulasikan jeda upload.
        await Future.delayed(const Duration(seconds: 1));
        if (_filePicked!.bytes != null) {
          ukuranBytes = _filePicked!.bytes!.length;
        }
        savedPath = null; // Tidak ada path fisik di web
      } else {
        // --- LOGIKA MOBILE (Android/iOS) ---
        final sourceFile = File(_filePicked!.path!);
        final appDir = await getApplicationDocumentsDirectory();
        final materiDir = Directory('${appDir.path}/materi_upload');
        if (!await materiDir.exists()) {
          await materiDir.create(recursive: true);
        }
  
        final namaFileAman = '${DateTime.now().millisecondsSinceEpoch}_${_filePicked!.name}';
        final targetPath = '${materiDir.path}/$namaFileAman';
  
        final savedFile = await sourceFile.copy(targetPath);
        ukuranBytes = await savedFile.length();
        savedPath = savedFile.path;
      }
 
      setState(() {
        if (!_daftarKategori.contains(kategori)) {
          _daftarKategori.add(kategori);
        }
 
        _semuaMateri.insert(0, {
          'judul': judul,
          'penulis': 'Anda (Pengguna)',
          'kategori': kategori,
          'tipe': ekstensi == 'pdf' ? 'PDF' : 'DOCX',
          'ukuran': _formatUkuranFile(ukuranBytes),
          'warna': ekstensi == 'pdf'
              ? const Color(0xFFE53935)
              : const Color(0xFF1E88E5),
          'deskripsi': 'Materi ini diunggah oleh pengguna komunitas.',
          'url': null,
          'localPath': savedPath,
        });
      });
 
      _judulController.clear();
      _kategoriController.clear();
      _filePicked = null;
      _sedangMenyalinFile = false;
 
      if (mounted) Navigator.pop(context); // Tutup dialog
 
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Materi berhasil diupload!'),
            backgroundColor: Color(0xFF1B5E20),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() => _sedangMenyalinFile = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan file: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
 
  void _showFormUpload(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text(
              'Upload Materi Baru',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bagikan modul atau panduan untuk membantu pengguna lain.',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _judulController,
                    decoration: InputDecoration(
                      labelText: 'Judul Materi',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF1B5E20), width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _kategoriController,
                    decoration: InputDecoration(
                      labelText: 'Kategori (cth: KTH, Panduan, Jurnal)',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF1B5E20), width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: () => _pilihFile(setDialogState),
                    icon: const Icon(Icons.upload_file_rounded),
                    label: Text(_filePicked == null ? 'Pilih File PDF/Word' : 'Ganti File'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1B5E20),
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(color: Color(0xFF1B5E20)),
                    ),
                  ),
                  if (_filePicked != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Color(0xFF1B5E20), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _filePicked!.name,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.only(right: 20, bottom: 20),
            actions: [
              TextButton(
                onPressed: _sedangMenyalinFile
                    ? null
                    : () {
                        _judulController.clear();
                        _kategoriController.clear();
                        _filePicked = null;
                        Navigator.pop(context);
                      },
                style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700),
                child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              FilledButton(
                onPressed: _sedangMenyalinFile
                    ? null
                    : () async {
                        await _simpanMateriBaru();
                        setDialogState(() {});
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: _sedangMenyalinFile
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Upload', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }
 
  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> materiDitampilkan = _semuaMateri.where((materi) {
      if (_kategoriAktif == 'Semua') return true;
      return materi['kategori'] == _kategoriAktif;
    }).toList();
 
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          physics: const BouncingScrollPhysics(),
          children: [
            const Text(
              'Materi Edukasi',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade50, Colors.orange.shade100],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orange.shade200, width: 0.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.shade200.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade200.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.tips_and_updates_rounded, color: Colors.orange.shade800, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Temukan panduan, modul, dan jurnal kehutanan di sini. Anda juga dapat membagikan materi untuk pengguna lain.',
                      style: TextStyle(color: Colors.orange.shade900, fontSize: 14, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Kategori',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: _daftarKategori.map((kategori) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: GestureDetector(
                      onTap: () => setState(() => _kategoriAktif = kategori),
                      child: _KategoriChip(label: kategori, isActive: _kategoriAktif == kategori),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _kategoriAktif == 'Semua' ? 'Materi Terbaru' : 'Materi $_kategoriAktif',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
                ),
                Text(
                  '${materiDitampilkan.length} File',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (materiDitampilkan.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(Icons.folder_off_outlined, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        'Belum ada materi untuk kategori ini.',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...materiDitampilkan.map((materi) => _MateriCard(
                    judul: materi['judul'],
                    penulis: materi['penulis'],
                    kategori: materi['kategori'],
                    tipe: materi['tipe'],
                    ukuran: materi['ukuran'],
                    warna: materi['warna'],
                    deskripsi: materi['deskripsi'],
                    url: materi['url'],
                    localPath: materi['localPath'],
                  )),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFormUpload(context),
        backgroundColor: const Color(0xFF1B5E20),
        elevation: 4,
        highlightElevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.cloud_upload_rounded, color: Colors.white),
        label: const Text('Upload Materi',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
      ),
    );
  }
}
 
class _KategoriChip extends StatelessWidget {
  final String label;
  final bool isActive;
 
  const _KategoriChip({required this.label, this.isActive = false});
 
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF1B5E20) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isActive ? const Color(0xFF1B5E20) : Colors.grey.shade300),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: const Color(0xFF1B5E20).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ]
            : [],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isActive ? Colors.white : Colors.grey.shade700,
          fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }
}
 
// =============================================================================
// FUNGSI BERSAMA: Mengunduh file (Aman untuk Web & Mobile)
// =============================================================================
Future<String?> unduhFileDariUrl({
  required String url,
  required String judul,
  required String tipe,
  void Function(double progress)? onProgress,
}) async {
  if (kIsWeb) {
    // LOGIKA WEB: Animasi download simulasi, return URL
    for (int i = 1; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 150));
      if (onProgress != null) onProgress(i / 10);
    }
    return url;
  } else {
    // LOGIKA MOBILE: Download beneran pakai Dio ke Path Provider
    final dir = await getApplicationDocumentsDirectory();
    final downloadDir = Directory('${dir.path}/unduhan_materi');
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }
  
    final namaFileAman = judul.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(RegExp(r'\s+'), '_');
    final ekstensi = tipe.toLowerCase();
    final savePath = '${downloadDir.path}/$namaFileAman.$ekstensi';
  
    final dio = Dio();
    await dio.download(
      url,
      savePath,
      onReceiveProgress: (received, total) {
        if (total > 0 && onProgress != null) {
          onProgress(received / total);
        }
      },
    );
  
    return savePath;
  }
}
 
class _MateriCard extends StatefulWidget {
  final String judul;
  final String penulis;
  final String kategori;
  final String tipe;
  final String ukuran;
  final Color warna;
  final String deskripsi;
  final String? url;
  final String? localPath;
 
  const _MateriCard({
    required this.judul,
    required this.penulis,
    required this.kategori,
    required this.tipe,
    required this.ukuran,
    required this.warna,
    required this.deskripsi,
    required this.url,
    required this.localPath,
  });
 
  @override
  State<_MateriCard> createState() => _MateriCardState();
}
 
class _MateriCardState extends State<_MateriCard> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String? _savedLocalPath;
 
  @override
  void initState() {
    super.initState();
    _savedLocalPath = widget.localPath;
  }
 
  void _bukaPreview() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LayarPreviewMateri(
          judul: widget.judul,
          penulis: widget.penulis,
          tipe: widget.tipe,
          ukuran: widget.ukuran,
          warna: widget.warna,
          deskripsi: widget.deskripsi,
          url: widget.url,
          localPath: _savedLocalPath,
        ),
      ),
    );
  }
 
  Future<void> _unduhAtauBukaFile() async {
    // File sudah diunduh atau ini file hasil upload
    if (_savedLocalPath != null) {
      if (kIsWeb) {
        // Di Web, open_filex tidak disupport. Jadi buka preview saja.
        _bukaPreview();
      } else {
        final result = await OpenFilex.open(_savedLocalPath!);
        if (mounted && result.type != ResultType.done) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Tidak bisa membuka file: ${result.message}')),
          );
        }
      }
      return;
    }
 
    if (widget.url == null) return;
 
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });
 
    try {
      final savedPath = await unduhFileDariUrl(
        url: widget.url!,
        judul: widget.judul,
        tipe: widget.tipe,
        onProgress: (p) {
          if (mounted) setState(() => _downloadProgress = p);
        },
      );
 
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _savedLocalPath = savedPath; // Di Web ini akan berisi URL, di Mobile berisi path lokal
        });
 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('${widget.judul} berhasil diunduh!')),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            action: kIsWeb 
                ? SnackBarAction(
                    label: 'Pratinjau',
                    textColor: Colors.white,
                    onPressed: _bukaPreview, // Web fallback
                  )
                : SnackBarAction(
                    label: 'Buka',
                    textColor: Colors.white,
                    onPressed: () => OpenFilex.open(savedPath!),
                  ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDownloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengunduh file: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
 
  @override
  Widget build(BuildContext context) {
    final sudahTersimpan = _savedLocalPath != null;
 
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _bukaPreview,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: widget.warna.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          widget.tipe == 'PDF' ? Icons.picture_as_pdf_rounded : Icons.description_rounded,
                          color: widget.warna,
                          size: 24,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.tipe,
                          style: TextStyle(color: widget.warna, fontWeight: FontWeight.w900, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Text(
                          widget.kategori,
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade700, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        widget.judul,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF212121), height: 1.3),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.person_outline, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              widget.penulis,
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_red_eye_outlined),
                          color: Colors.grey.shade600,
                          iconSize: 22,
                          splashRadius: 24,
                          tooltip: 'Lihat Pratinjau',
                          onPressed: _bukaPreview,
                        ),
                        Container(
                          decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                          child: IconButton(
                            icon: _isDownloading
                                ? Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          value: _downloadProgress,
                                          strokeWidth: 2,
                                          color: const Color(0xFF1B5E20),
                                          backgroundColor: Colors.green.shade200,
                                        ),
                                      ),
                                    ],
                                  )
                                : Icon(sudahTersimpan ? Icons.check_circle_outline : Icons.download_rounded),
                            color: const Color(0xFF1B5E20),
                            iconSize: 22,
                            splashRadius: 24,
                            tooltip: sudahTersimpan ? (kIsWeb ? 'Lihat File' : 'Buka File') : 'Unduh File',
                            onPressed: _isDownloading ? null : _unduhAtauBukaFile,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.ukuran,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
 
// =============================================================================
// Layar Preview Materi — Mendukung perenderan PDF dengan syncfusion_flutter_pdfviewer
// =============================================================================
class LayarPreviewMateri extends StatefulWidget {
  final String judul;
  final String penulis;
  final String tipe;
  final String ukuran;
  final Color warna;
  final String deskripsi;
  final String? url;
  final String? localPath;
 
  const LayarPreviewMateri({
    super.key,
    required this.judul,
    required this.penulis,
    required this.tipe,
    required this.ukuran,
    required this.warna,
    required this.deskripsi,
    required this.url,
    required this.localPath,
  });
 
  @override
  State<LayarPreviewMateri> createState() => _LayarPreviewMateriState();
}
 
class _LayarPreviewMateriState extends State<LayarPreviewMateri> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String? _savedLocalPath;
 
  @override
  void initState() {
    super.initState();
    _savedLocalPath = widget.localPath;
  }
 
  Future<void> _unduhAtauBukaFile() async {
    if (_savedLocalPath != null) {
      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File sudah dimuat di pratinjau atas.')),
        );
      } else {
        await OpenFilex.open(_savedLocalPath!);
      }
      return;
    }
    if (widget.url == null) return;
 
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });
 
    try {
      final savedPath = await unduhFileDariUrl(
        url: widget.url!,
        judul: widget.judul,
        tipe: widget.tipe,
        onProgress: (p) {
          if (mounted) setState(() => _downloadProgress = p);
        },
      );
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _savedLocalPath = savedPath;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('File berhasil diunduh!'),
            backgroundColor: const Color(0xFF1B5E20),
            action: kIsWeb ? null : SnackBarAction(
              label: 'Buka',
              textColor: Colors.white,
              onPressed: () => OpenFilex.open(savedPath!),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDownloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengunduh: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
 
  Widget _buildAreaPreview() {
    final bool isPdf = widget.tipe.toUpperCase() == 'PDF';
 
    // Di Mobile, jika PDF sudah tersimpan secara lokal
    if (isPdf && !kIsWeb && _savedLocalPath != null) {
      return SfPdfViewer.file(File(_savedLocalPath!));
    }
    // Di Web, atau jika PDF belum didownload tapi ada link URL
    if (isPdf && widget.url != null) {
      return SfPdfViewer.network(widget.url!);
    }
 
    // DOCX atau format tidak diketahui
    return Container(
      width: double.infinity,
      color: Colors.grey.shade100,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description_outlined, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Pratinjau langsung tidak tersedia untuk file ${widget.tipe}',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              kIsWeb 
                ? 'File DOCX tidak dapat dipratinjau di versi Web.'
                : 'Unduh atau buka file untuk melihat isinya menggunakan aplikasi Word / pembaca dokumen di perangkat Anda.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
 
  @override
  Widget build(BuildContext context) {
    final sudahTersimpan = _savedLocalPath != null;
 
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Pratinjau Materi', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: widget.warna.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    widget.tipe == 'PDF' ? Icons.picture_as_pdf_rounded : Icons.description_rounded,
                    color: widget.warna,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.judul,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A), height: 1.3),
                      ),
                      const SizedBox(height: 6),
                      Text('Oleh: ${widget.penulis}',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration:
                                BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                            child: Text(widget.tipe,
                                style:
                                    TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                          ),
                          const SizedBox(width: 8),
                          Text(widget.ukuran, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(thickness: 1, height: 1),
          Expanded(child: _buildAreaPreview()),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), offset: const Offset(0, -4), blurRadius: 10)],
        ),
        child: FilledButton.icon(
          onPressed: _isDownloading ? null : _unduhAtauBukaFile,
          icon: _isDownloading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: _downloadProgress,
                    color: Colors.white,
                  ),
                )
              : Icon(sudahTersimpan ? (kIsWeb ? Icons.check_circle_outline : Icons.folder_open_rounded) : Icons.download_rounded),
          label: Text(
            _isDownloading
                ? 'Mengunduh ${(_downloadProgress * 100).toStringAsFixed(0)}%'
                : (sudahTersimpan ? (kIsWeb ? 'Selesai' : 'Buka Materi') : 'Unduh Materi Sekarang'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF1B5E20),
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );
  }
}