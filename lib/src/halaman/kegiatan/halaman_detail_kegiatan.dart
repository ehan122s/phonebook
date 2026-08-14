import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/activity.dart';
import '../../models/stored_file.dart';
import '../../services/activity_repository.dart';
import '../../services/report_downloader.dart'; // BARU — pakai downloader native yang sudah ada
import '../../widgets/glashmorp.dart';
import '../../widgets/leaflet_map.dart'; // Sesuaikan lokasi file leaflet_map

class HalamanDetailKegiatan extends StatefulWidget {
  const HalamanDetailKegiatan({
    super.key,
    required this.activity,
    required this.repository,
  });
  final Activity activity;
  final ActivityRepository repository;

  @override
  State<HalamanDetailKegiatan> createState() => _HalamanDetailKegiatanState();
}

class _HalamanDetailKegiatanState extends State<HalamanDetailKegiatan> {
  late Future<List<StoredFile>> _documents;
  late Future<List<StoredFile>> _photos;

  // Supaya tombol "Buat Laporan PDF/Docx" tidak bisa ditekan dobel selagi
  // proses generate + download masih berjalan.
  bool _sedangBuatLaporan = false;

  @override
  void initState() {
    super.initState();
    _muatUlang();
  }

  void _muatUlang() {
    _documents = widget.repository.media(widget.activity.id, photos: false);
    _photos = widget.repository.media(widget.activity.id, photos: true);
  }

  Future<void> _upload({bool photosOnly = false}) async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: true,
      type: photosOnly ? FileType.image : FileType.any,
    );
    for (final file in result?.files ?? <PlatformFile>[]) {
      if (file.bytes == null) continue;
      final extension = file.extension?.toLowerCase();
      final isPhoto = photosOnly || ['jpg', 'jpeg', 'png'].contains(extension);
      await widget.repository.uploadFile(
        activityId: widget.activity.id,
        name: file.name,
        bytes: file.bytes!,
        contentType: isPhoto ? 'image/$extension' : 'application/octet-stream',
        isPhoto: isPhoto,
      );
    }
    if (mounted) {
      setState(_muatUlang);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload berhasil')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        extendBodyBehindAppBar: true, // Biar background tembus ke bawah AppBar
        appBar: AppBar(
          title: const Text('Detail Kegiatan'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _upload,
          icon: const Icon(Icons.upload_file),
          label: const Text('Upload File'),
          backgroundColor: const Color(0xFF2E7D32),
          foregroundColor: Colors.white,
        ),
        body: LatarBelakangGradien(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900), // Max width agar rapi di Desktop
              child: ListView(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + AppBar().preferredSize.height + 24,
                  left: 24,
                  right: 24,
                  bottom: 80,
                ),
                children: [
                  Text(
                    widget.activity.title,
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 32),

                  // Gunakan Grid/Wrap untuk responsivitas kolom Detail & Catatan
                  Wrap(
                    spacing: 24,
                    runSpacing: 24,
                    children: [
                      SizedBox(
                        width: 400,
                        child: _bangunBagianKaca('Identitas Kegiatan', Icons.info_outline, {
                          'Jenis': widget.activity.categoryName,
                          'Tanggal': DateFormat('dd MMMM yyyy', 'id_ID').format(widget.activity.activityDate),
                          'Lokasi': widget.activity.location ?? '-',
                          'Wilayah': '${widget.activity.village}, ${widget.activity.district}, ${widget.activity.regency}',
                          'Kelompok Tani': widget.activity.farmerGroup ?? '-',
                          'Peserta': '${widget.activity.participantCount} orang',
                        }),
                      ),
                      SizedBox(
                        width: 400,
                        child: _bangunBagianKaca('Catatan Pelaksanaan', Icons.assignment_outlined, {
                          'Materi': widget.activity.material ?? '-',
                          'Tujuan': widget.activity.objective ?? '-',
                          'Hasil': widget.activity.result ?? '-',
                          'Kendala': widget.activity.obstacle ?? '-',
                          'Tindak Lanjut': widget.activity.followUp ?? '-',
                          'Catatan Khusus': widget.activity.notes ?? '-',
                        }),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),
                  const Text('Peta Lokasi', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  KartuKaca(
                    padding: EdgeInsets.zero,
                    child: SizedBox(
                      height: 300,
                      child: LeafletMap(
                        latitude: widget.activity.latitude,
                        longitude: widget.activity.longitude,
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _sedangBuatLaporan ? null : () => _buatLaporan('pdf'),
                          icon: _sedangBuatLaporan
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.picture_as_pdf),
                          label: const Text('Buat Laporan PDF'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: KartuKaca(
                          padding: EdgeInsets.zero,
                          child: OutlinedButton.icon(
                            onPressed: _sedangBuatLaporan ? null : () => _buatLaporan('docx'),
                            icon: const Icon(Icons.description),
                            label: const Text('Buat Word (Docx)'),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide.none, // Hide default border since we use glass card
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 48),
                  const Text('Dokumen Pendukung', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _daftarMedia(_documents, false),

                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Dokumentasi Foto', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      TextButton.icon(
                        onPressed: () => _upload(photosOnly: true),
                        icon: const Icon(Icons.add_a_photo, size: 20),
                        label: const Text('Tambah Foto', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _daftarMedia(_photos, true),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _bangunBagianKaca(String judul, IconData ikon, Map<String, String> nilai) {
    return KartuKaca(
      padding: EdgeInsets.zero, // Padding diatur manual di dalam
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Icon(ikon, color: const Color(0xFF2E7D32), size: 28),
                const SizedBox(width: 16),
                Text(judul, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.5)),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: nilai.entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 130,
                      child: Text(
                        entry.key,
                        style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: const TextStyle(color: Colors.black87, height: 1.5),
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // DAFTAR MEDIA (dokumen & foto)
  // ---------------------------------------------------------------------

  Widget _daftarMedia(Future<List<StoredFile>> future, bool isPhoto) =>
      FutureBuilder<List<StoredFile>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return KartuKaca(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Gagal memuat ${isPhoto ? 'foto' : 'dokumen'}: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return KartuKaca(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'Belum ada ${isPhoto ? 'foto' : 'dokumen'} yang diunggah.',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
                ),
              ),
            );
          }
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: items.map((file) => _kartuMedia(file, isPhoto)).toList(),
          );
        },
      );

  /// Kartu untuk satu file (dokumen atau foto).
  /// Untuk foto, thumbnail asli diambil lewat signed URL dari Supabase Storage.
  Widget _kartuMedia(StoredFile file, bool isPhoto) {
    return FutureBuilder<String>(
      future: widget.repository.signedUrl(file, photo: isPhoto),
      builder: (context, urlSnapshot) {
        final url = urlSnapshot.data;

        Widget leading;
        if (isPhoto && url != null) {
          leading = ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              url,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : const SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
              errorBuilder: (context, error, stack) => Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.broken_image, color: Colors.redAccent),
              ),
            ),
          );
        } else if (isPhoto) {
          // Signed URL belum siap / masih loading
          leading = Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        } else {
          leading = Container(
            width: 48,
            height: 48,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.description, color: Colors.blue.shade700),
          );
        }

        return SizedBox(
          width: 350, // Agar sejajar di mode desktop
          child: KartuKaca(
            padding: const EdgeInsets.all(8),
            child: ListTile(
              leading: leading,
              title: Text(
                file.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: file.caption != null && file.caption!.isNotEmpty
                  ? Text(file.caption!, maxLines: 1, overflow: TextOverflow.ellipsis)
                  : null,
              onTap: url == null ? null : () => _bukaFile(url),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () async {
                  await widget.repository.deleteMedia(file, photo: isPhoto);
                  if (mounted) setState(_muatUlang);
                },
              ),
            ),
          ),
        );
      },
    );
  }

  /// Dipakai untuk MEMBUKA (preview) dokumen/foto yang sudah diupload,
  /// bukan untuk mengunduh laporan — itu sudah pindah ke [_buatLaporan]
  /// yang memakai `report_downloader.dart`.
  Future<void> _bukaFile(String url) async {
    final uri = Uri.parse(url);
    final berhasil = await canLaunchUrl(uri);
    if (berhasil) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak bisa membuka file ini')),
      );
    }
  }

  // ---------------------------------------------------------------------
  // LAPORAN PDF / DOCX
  // ---------------------------------------------------------------------

  Future<void> _buatLaporan(String format) async {
    setState(() => _sedangBuatLaporan = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Membuat laporan $format...'), duration: const Duration(seconds: 3)),
    );

    try {
      // 1) Panggil Edge Function generate-report (lewat ActivityRepository,
      //    yang sudah menangani error dengan pesan yang jelas).
      final data = await widget.repository.createReport(widget.activity.id, format);

      final url = data?['download_url'] as String?;
      final fileName = (data?['file_name'] as String?) ??
          'Laporan_${widget.activity.title}.$format';

      if (!mounted) return;

      if (url == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Laporan berhasil dibuat, tapi URL unduhan tidak ditemukan')),
        );
        return;
      }

      // 2) Simpan file ke perangkat lewat downloader native:
      //    - Web    -> anchor-click download (report_downloader_web.dart)
      //    - Mobile -> unduh lalu buka share-sheet "Simpan ke..." (report_downloader_io.dart)
      //    - Desktop-> langsung ditulis ke folder Downloads
      await downloadReport(
        url: url,
        fileName: fileName,
        onStatus: (message) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: const Color(0xFF2E7D32)),
          );
        },
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuat laporan: $error'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _sedangBuatLaporan = false);
    }
  }
}