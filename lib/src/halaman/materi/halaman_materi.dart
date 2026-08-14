import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/material_item.dart';
import '../../services/material_repository.dart';
import '../../services/report_downloader.dart'; // download file fisik -> benar2 masuk ke HP
import '../../widgets/file_downloader.dart' hide downloadReport;

class HalamanMateriEdukasi extends StatefulWidget {
  const HalamanMateriEdukasi({super.key});

  @override
  State<HalamanMateriEdukasi> createState() => _HalamanMateriEdukasiState();
}

class _HalamanMateriEdukasiState extends State<HalamanMateriEdukasi> {
  late final MaterialRepository _repository;
  late Future<List<MaterialItem>> _future;

  String _query = '';
  String _kategori = 'Semua Kategori';
  bool _isAdmin = false;

  // -- state form upload --
  final TextEditingController _judulController = TextEditingController();
  final TextEditingController _kategoriController = TextEditingController();
  PlatformFile? _filePicked;
  bool _sedangUpload = false;

  static const _badge = {
    'pdf': (label: 'PDF', color: Color(0xFFDC2626)),
    'word': (label: 'Word', color: Color(0xFF2563EB)),
    'excel': (label: 'Excel', color: Color(0xFF16A34A)),
    'video': (label: 'Video', color: Color(0xFF7C3AED)),
    'image': (label: 'Gambar', color: Color(0xFF0891B2)),
    'other': (label: 'File', color: Color(0xFF6B7280)),
  };

  @override
  void initState() {
    super.initState();
    _repository = MaterialRepository(Supabase.instance.client);
    _future = _repository.list();
    _cekPeranAdmin();
  }

  @override
  void dispose() {
    _judulController.dispose();
    _kategoriController.dispose();
    super.dispose();
  }

  Future<void> _cekPeranAdmin() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final profil = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .single();
      if (mounted) setState(() => _isAdmin = profil['role'] == 'admin');
    } catch (_) {
      // Default aman: tetap dianggap bukan admin kalau gagal cek
    }
  }

  Future<void> _refresh() async => setState(() => _future = _repository.list());

  // ---------------------------------------------------------------------
  // DOWNLOAD
  // ---------------------------------------------------------------------

  Future<void> _unduh(BuildContext context, MaterialItem item) async {
    try {
      if (item.hasRealFile) {
        final url = await _repository.signedUrl(item.storagePath!);
        final ekstensi = item.fileType == 'word' ? 'docx' : item.fileType;
        final namaFile =
            '${item.title.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(RegExp(r'\s+'), '_')}.$ekstensi';

        // Pakai downloader yang sama dengan Laporan Kegiatan supaya file
        // benar-benar tersimpan ke perangkat (share-sheet native di mobile,
        // folder Downloads di desktop, anchor-click di web) — bukan cuma
        // dibuka via browser seperti openExternalUrl.
        await downloadReport(
          url: url,
          fileName: namaFile,
          onStatus: (message) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(message), backgroundColor: const Color(0xFF1B5E20)),
              );
            }
          },
        );
      } else {
        downloadTextFile(
          fileName: item.fileName,
          content: item.contentText ?? 'Konten tidak tersedia.',
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal mengunduh: $error')));
      }
    }
  }

  // ---------------------------------------------------------------------
  // UPLOAD (ADMIN ONLY — mengikuti RLS tabel materials & bucket materi-edukasi)
  // ---------------------------------------------------------------------

  Future<void> _pilihFile(StateSetter setDialogState) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx',
        'jpg', 'jpeg', 'png', 'mp4',
      ],
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      setDialogState(() => _filePicked = result.files.first);
      if (_judulController.text.trim().isEmpty) {
        final namaTanpaEkstensi = _filePicked!.name.replaceAll(
          RegExp(r'\.[^.]+$'),
          '',
        );
        _judulController.text = namaTanpaEkstensi;
      }
    }
  }

  String _mapEkstensiKeFileType(String ekstensi) {
    switch (ekstensi.toLowerCase()) {
      case 'pdf':
        return 'pdf';
      case 'doc':
      case 'docx':
        return 'word';
      case 'xls':
      case 'xlsx':
      case 'csv':
        return 'excel';
      case 'jpg':
      case 'jpeg':
      case 'png':
        return 'image';
      case 'mp4':
      case 'mov':
        return 'video';
      default:
        return 'other';
    }
  }

  Future<void> _simpanMateriBaru() async {
    final String judul = _judulController.text.trim();
    final String kategoriInput = _kategoriController.text.trim();
    final String kategori = kategoriInput.isEmpty ? 'Umum' : kategoriInput;

    if (judul.isEmpty) {
      _tampilkanSnackbar('Judul materi tidak boleh kosong!', Colors.red);
      return;
    }
    if (_filePicked == null || _filePicked!.bytes == null) {
      _tampilkanSnackbar('Silakan pilih file terlebih dahulu!', Colors.red);
      return;
    }

    setState(() => _sedangUpload = true);

    try {
      final ekstensi = _filePicked!.extension?.toLowerCase() ?? 'pdf';

      await _repository.upload(
        title: judul,
        category: kategori,
        fileType: _mapEkstensiKeFileType(ekstensi),
        fileName: _filePicked!.name,
        bytes: _filePicked!.bytes!,
      );

      _judulController.clear();
      _kategoriController.clear();
      _filePicked = null;
      setState(() => _sedangUpload = false);

      if (mounted) Navigator.pop(context);
      await _refresh();

      if (mounted) {
        _tampilkanSnackbar('Materi berhasil diupload!', const Color(0xFF1B5E20));
      }
    } on StorageException catch (e) {
      setState(() => _sedangUpload = false);
      _tampilkanSnackbar(
        e.statusCode == '403'
            ? 'Hanya admin yang dapat mengunggah materi.'
            : 'Gagal upload file: ${e.message}',
        Colors.red,
      );
    } on PostgrestException catch (e) {
      setState(() => _sedangUpload = false);
      _tampilkanSnackbar(
        e.code == '42501'
            ? 'Hanya admin yang dapat mengunggah materi.'
            : 'Gagal menyimpan data materi: ${e.message}',
        Colors.red,
      );
    } catch (e) {
      setState(() => _sedangUpload = false);
      _tampilkanSnackbar('Gagal menyimpan file: $e', Colors.red);
    }
  }

  void _tampilkanSnackbar(String pesan, Color warna) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(pesan), backgroundColor: warna, behavior: SnackBarBehavior.floating),
    );
  }

  void _showFormUpload(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Upload Materi Baru',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bagikan modul, buku, atau panduan untuk penyuluh lain.',
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
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
                    label: Text(_filePicked == null ? 'Pilih File' : 'Ganti File'),
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
                onPressed: _sedangUpload
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
                onPressed: _sedangUpload
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
                child: _sedangUpload
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

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showFormUpload(context),
              backgroundColor: const Color(0xFF1B5E20),
              icon: const Icon(Icons.cloud_upload_rounded, color: Colors.white),
              label: const Text('Upload Materi',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
      body: RefreshIndicator(
        color: const Color(0xFF1B5E20),
        onRefresh: _refresh,
        child: FutureBuilder<List<MaterialItem>>(
          future: _future,
          builder: (context, snapshot) {
            final isLoading = snapshot.connectionState == ConnectionState.waiting;
            final semua = snapshot.data ?? const <MaterialItem>[];
            final kategoriTersedia = <String>{
              'Semua Kategori',
              ...semua.map((m) => m.category),
            }.toList();
            final hasil = semua.where((m) {
              final cocokQuery =
                  _query.isEmpty || m.title.toLowerCase().contains(_query.toLowerCase());
              final cocokKategori = _kategori == 'Semua Kategori' || m.category == _kategori;
              return cocokQuery && cocokKategori;
            }).toList();

            return ListView(
              padding: EdgeInsets.fromLTRB(24, 24, 24, _isAdmin ? 96 : 24),
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobileFilter = constraints.maxWidth < 560;
                      final search = TextField(
                        onChanged: (v) => setState(() => _query = v),
                        decoration: const InputDecoration(
                          icon: Icon(Icons.search, color: Colors.black45),
                          hintText: 'Cari nama modul / buku...',
                          border: InputBorder.none,
                        ),
                      );
                      final filter = DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _kategori,
                          borderRadius: BorderRadius.circular(16),
                          items: kategoriTersedia
                              .map((k) => DropdownMenuItem(
                                    value: k,
                                    child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => _kategori = v ?? 'Semua Kategori'),
                        ),
                      );
                      if (isMobileFilter) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              search,
                              const Divider(height: 1),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                child: filter,
                              ),
                            ],
                          ),
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: search),
                          Container(
                            width: 1,
                            height: 28,
                            color: Colors.black12,
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          Padding(padding: const EdgeInsets.only(right: 12), child: filter),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(child: CircularProgressIndicator(color: Color(0xFF1B5E20))),
                  )
                else if (hasil.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(
                      child: Text('Materi tidak ditemukan.',
                          style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
                    ),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final kolom =
                          constraints.maxWidth >= 1100 ? 3 : (constraints.maxWidth >= 700 ? 2 : 1);
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: hasil.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: kolom,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: kolom == 1 ? 2.6 : 1.3,
                        ),
                        itemBuilder: (context, i) {
                          final item = hasil[i];
                          final b = _badge[item.fileType] ?? _badge['other']!;
                          return Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 15,
                                  offset: const Offset(0, 4),
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
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: b.color,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        b.label,
                                        style: const TextStyle(
                                            color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.category.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.grey.shade500,
                                              letterSpacing: 0.4,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            item.title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF1F2937),
                                              height: 1.25,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                const SizedBox(height: 8),
                                Text(
                                  'Ukuran: ${item.sizeLabel}',
                                  style: TextStyle(
                                      fontSize: 12.5, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: TextButton.icon(
                                    onPressed: () => _unduh(context, item),
                                    style: TextButton.styleFrom(
                                      backgroundColor: const Color(0xFF1B5E20).withOpacity(0.1),
                                      foregroundColor: const Color(0xFF1B5E20),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    icon: const Icon(Icons.download_rounded, size: 18),
                                    label: const Text('Unduh File', style: TextStyle(fontWeight: FontWeight.w800)),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                const SizedBox(height: 40),
              ],
            );
          },
        ),
      ),
    );
  }
}