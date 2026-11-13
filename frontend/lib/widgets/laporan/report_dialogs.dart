// ============================================================================
// [DIALOG, FORMULIR & UNDUH LAPORAN - REPORT_DIALOGS.DART]
// Simpan file ini di: lib/widgets/laporan/report_dialogs.dart
//
// Pembaruan Utama:
// 1. Desain Formulir Lebih Rapi, Lega & Responsif (Tidak Menumpuk):
//    - Menggunakan label di atas kolom input (_SpaciousLabeledField), pengelompokan
//      kartu ber-padding lega, serta tata letak 2 kolom adaptif pada layar lebar.
// 2. Editor Template Admin 3-Tab + Konversi Langsung File Contoh Laporan:
//    - Admin dapat mengunggah file contoh laporan (.docx, .doc, .pdf, .txt) via
//      FilePicker untuk langsung diekstrak menjadi kerangka template & daftar
//      bagian form yang harus diisi pegawai.
// 3. Unduh Laporan ke PDF Siap Print (.pdf) & Word (.doc):
//    - Setelah mengisi laporan, pegawai maupun Admin dapat mengunduh laporan
//      resmi ber-Kop Surat CDK Wilayah V dalam format PDF siap cetak atau Word.
// ============================================================================

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/laporan_constants.dart';
import '../../services/connectivity_service.dart';
import '../../services/laporan_service.dart';
import 'report_templates.dart';

// ---------------------------------------------------------------------------
// 1. Bottom Sheet Pemilihan Jenis Laporan
// ---------------------------------------------------------------------------

Future<void> showReportTypeDialog(
  BuildContext context, {
  required void Function(String jenisLaporan, {Map<String, dynamic>? existing})
      onSelectType,
}) async {
  final templates = await ReportTemplateManager.loadTemplates();
  if (!context.mounted) return;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).cardColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Center(
          heightFactor: 1.0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 26),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _DragHandle(),
                    const SizedBox(height: 18),
                    const Text(
                      'Pilih Jenis Laporan',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Pilih template laporan yang telah disiapkan sesuai kegiatan Anda.',
                      style: TextStyle(color: Colors.grey, fontSize: 13.5),
                    ),
                    const SizedBox(height: 18),
                    ...templates.map((tpl) {
                      final title =
                          (tpl['title'] ?? 'Laporan Kegiatan').toString();
                      final desc = (tpl['description'] ?? '').toString();
                      final icon = ReportTemplateManager.iconFromKey(
                        tpl['iconKey']?.toString(),
                      );
                      return _TypeOption(
                        icon: icon,
                        title: title,
                        subtitle: desc,
                        onTap: () {
                          Navigator.pop(ctx);
                          onSelectType(title);
                        },
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

// ---------------------------------------------------------------------------
// 2. Formulir Pengisian Laporan (Rapi, Lega, Berbasis Kartu Seksi & Responsif)
// ---------------------------------------------------------------------------

Future<void> showReportForm(
  BuildContext context, {
  required String jenisLaporan,
  Map<String, dynamic>? existing,
  required Future<void> Function() onReportSaved,
  bool isPreviewOnly = false,
}) async {
  final template = await ReportTemplateManager.findByTitle(jenisLaporan);
  if (!context.mounted) return;

  final List<String> templateFields =
      (template['fields'] as List?)?.map((e) => e.toString()).toList() ?? [];
  final String defaultTitle = (template['defaultTitle'] ?? '').toString();
  final String templateDescription =
      (template['description'] ??
              'Lengkapi bagian-bagian laporan sesuai kegiatan di lapangan.')
          .toString();
  final bool requirePhoto = template['requirePhoto'] != false;

  final now = DateTime.now();
  final initialDateIso =
      (existing?['tanggalApi']?.toString().isNotEmpty ?? false)
          ? existing!['tanggalApi'].toString()
          : '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

  DateTime selectedDate = DateTime.tryParse(initialDateIso) ?? now;

  final judulCtrl = TextEditingController(
    text: existing?['judul']?.toString() ??
        (defaultTitle.isNotEmpty ? defaultTitle : ''),
  );
  final lokasiCtrl = TextEditingController(
    text: existing?['lokasi']?.toString() ?? '',
  );
  final latCtrl = TextEditingController(
    text: existing?['latitude']?.toString() ?? '',
  );
  final lngCtrl = TextEditingController(
    text: existing?['longitude']?.toString() ?? '',
  );

  final Map<String, TextEditingController> fieldControllers = {
    for (final field in templateFields) field: TextEditingController(),
  };

  final existingIsi = existing?['isi']?.toString() ?? '';
  final isiCtrl = TextEditingController(
    text: existingIsi.isNotEmpty
        ? existingIsi
        : ReportTemplateManager.buildFormattedBody(
            template: template,
            fieldValues: const {},
          ),
  );

  void syncTemplateFieldsToIsi() {
    final values = <String, String>{
      for (final entry in fieldControllers.entries)
        entry.key: entry.value.text,
    };
    isiCtrl.text = ReportTemplateManager.buildFormattedBody(
      template: template,
      fieldValues: values,
    );
  }

  XFile? pickedPhotoFile;
  Uint8List? pickedPhotoBytes;
  bool isGettingLocation = false;
  bool showCoordinateInputs =
      latCtrl.text.isNotEmpty || lngCtrl.text.isNotEmpty;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (sheetContext, setModalState) {
          final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
          final sheetBg = isDark
              ? const Color(0xFF141C17)
              : const Color(0xFFF6F8F5);
          final cardBg = isDark ? const Color(0xFF1E2822) : Colors.white;
          final borderCol = isDark
              ? const Color(0xFF2E3D34)
              : const Color(0xFFE2EAE3);
          final primaryGreen = isDark
              ? const Color(0xFF81C784)
              : const Color(0xFF245C3A);
          final textPrimary = isDark ? Colors.white : const Color(0xFF24352A);
          final textSecondary = isDark
              ? Colors.white70
              : const Color(0xFF6E7A72);

          Future<void> pickReportDate() async {
            final picked = await showDatePicker(
              context: sheetContext,
              initialDate: selectedDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2035),
            );
            if (picked != null) {
              setModalState(() => selectedDate = picked);
            }
          }

          Future<void> getCurrentLocation() async {
            setModalState(() {
              isGettingLocation = true;
              showCoordinateInputs = true;
            });

            Future<void> handleFallbackLocation() async {
              try {
                final res = await http
                    .get(Uri.parse('http://ip-api.com/json'))
                    .timeout(const Duration(seconds: 4));
                if (res.statusCode == 200) {
                  final data = jsonDecode(res.body);
                  if (data['status'] == 'success') {
                    final lat = (data['lat'] as num).toDouble();
                    final lon = (data['lon'] as num).toDouble();
                    final city =
                        '${data['city'] ?? ''}, ${data['regionName'] ?? ''}'
                            .trim();
                    latCtrl.text = lat.toStringAsFixed(6);
                    lngCtrl.text = lon.toStringAsFixed(6);
                    if (lokasiCtrl.text.trim().isEmpty && city.isNotEmpty) {
                      lokasiCtrl.text = city;
                    }
                    if (sheetContext.mounted) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        SnackBar(
                          content: Text('Lokasi berhasil didapatkan ($city)'),
                        ),
                      );
                    }
                    return;
                  }
                }
              } catch (_) {}

              latCtrl.text = '-7.227900';
              lngCtrl.text = '107.908700';
              if (lokasiCtrl.text.trim().isEmpty) {
                lokasiCtrl.text = 'Kawasan Hutan Garut';
              }
              if (sheetContext.mounted) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Koordinat default wilayah Garut berhasil disetel.',
                    ),
                  ),
                );
              }
            }

            if (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux) {
              await handleFallbackLocation();
              if (sheetContext.mounted) {
                setModalState(() => isGettingLocation = false);
              }
              return;
            }

            try {
              bool serviceEnabled =
                  await Geolocator.isLocationServiceEnabled();
              if (!serviceEnabled) {
                if (sheetContext.mounted) {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Layanan lokasi (GPS) belum aktif. Silakan aktifkan GPS perangkat Anda.',
                      ),
                    ),
                  );
                }
                return;
              }

              LocationPermission permission =
                  await Geolocator.checkPermission();
              if (permission == LocationPermission.denied) {
                permission = await Geolocator.requestPermission();
                if (permission == LocationPermission.denied) {
                  if (sheetContext.mounted) {
                    ScaffoldMessenger.of(sheetContext).showSnackBar(
                      const SnackBar(
                        content: Text('Izin akses lokasi GPS ditolak.'),
                      ),
                    );
                  }
                  return;
                }
              }

              if (permission == LocationPermission.deniedForever) {
                if (sheetContext.mounted) {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Izin lokasi ditolak permanen. Silakan izinkan di setelan aplikasi.',
                      ),
                    ),
                  );
                }
                return;
              }

              final position = await Geolocator.getCurrentPosition(
                locationSettings: const LocationSettings(
                  accuracy: LocationAccuracy.high,
                  timeLimit: Duration(seconds: 12),
                ),
              );

              latCtrl.text = position.latitude.toStringAsFixed(6);
              lngCtrl.text = position.longitude.toStringAsFixed(6);

              if (lokasiCtrl.text.trim().isEmpty) {
                lokasiCtrl.text =
                    'Titik Koordinat (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';
              }

              if (sheetContext.mounted) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  const SnackBar(
                    content: Text('Koordinat GPS berhasil diperoleh!'),
                  ),
                );
              }
            } on MissingPluginException {
              await handleFallbackLocation();
            } on PlatformException catch (pe) {
              if (pe.code == 'MissingPluginException' ||
                  pe.message?.contains('No implementation') == true) {
                await handleFallbackLocation();
              } else {
                if (sheetContext.mounted) {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Gagal mendapatkan lokasi GPS: ${pe.message ?? pe}',
                      ),
                    ),
                  );
                }
              }
            } catch (e) {
              final msg = e.toString();
              if (msg.contains('MissingPluginException') ||
                  msg.contains('No implementation')) {
                await handleFallbackLocation();
              } else {
                if (sheetContext.mounted) {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    SnackBar(content: Text('Gagal mendapatkan lokasi GPS: $e')),
                  );
                }
              }
            } finally {
              if (sheetContext.mounted) {
                setModalState(() => isGettingLocation = false);
              }
            }
          }

          Future<void> pickPhoto() async {
            final source = await showModalBottomSheet<ImageSource>(
              context: sheetContext,
              backgroundColor: cardBg,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              builder: (pickerCtx) => SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 18,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _DragHandle(),
                      const SizedBox(height: 18),
                      const Text(
                        'Pilih Sumber Foto',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Ambil foto dokumentasi dari kamera atau pilih dari galeri',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 18),
                      ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: LaporanColors.primary.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            color: LaporanColors.primary,
                          ),
                        ),
                        title: const Text(
                          'Ambil dari Kamera',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: const Text(
                          'Buka kamera untuk mengambil foto secara langsung',
                        ),
                        onTap: () =>
                            Navigator.pop(pickerCtx, ImageSource.camera),
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.photo_library_rounded,
                            color: Colors.blue,
                          ),
                        ),
                        title: const Text(
                          'Pilih dari Galeri',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: const Text(
                          'Pilih gambar yang tersimpan di perangkat',
                        ),
                        onTap: () =>
                            Navigator.pop(pickerCtx, ImageSource.gallery),
                      ),
                    ],
                  ),
                ),
              ),
            );

            if (source != null) {
              try {
                final picker = ImagePicker();
                XFile? picked;

                if (!kIsWeb &&
                    defaultTargetPlatform == TargetPlatform.linux &&
                    source == ImageSource.camera) {
                  picked = await picker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 80,
                  );
                } else {
                  try {
                    picked = await picker.pickImage(
                      source: source,
                      imageQuality: 80,
                      maxWidth: 1600,
                    );
                  } on PlatformException {
                    if (source == ImageSource.camera) {
                      picked = await picker.pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 80,
                      );
                    } else {
                      rethrow;
                    }
                  }
                }

                if (picked != null) {
                  final bytes = await picked.readAsBytes();
                  setModalState(() {
                    pickedPhotoFile = picked;
                    pickedPhotoBytes = bytes;
                  });
                }
              } catch (e) {
                if (sheetContext.mounted) {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    SnackBar(content: Text('Gagal mengambil foto: $e')),
                  );
                }
              }
            }
          }

          final formattedDateDisplay =
              '${selectedDate.day} ${LaporanDateUtils.monthName(selectedDate.month)} ${selectedDate.year}';
          final formattedDateApi =
              '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';

          return Center(
            heightFactor: 1.0,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 700,
                maxHeight: MediaQuery.of(sheetContext).size.height * 0.92,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: sheetBg,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── HEADER MODAL TETAP (RAPI & TIDAK IKUT TERGULUNG) ──
                    Container(
                      padding: const EdgeInsets.fromLTRB(22, 14, 16, 16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                        border: Border(bottom: BorderSide(color: borderCol)),
                      ),
                      child: Column(
                        children: [
                          const _DragHandle(),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF26352B)
                                      : LaporanColors.greenBackground,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  ReportTemplateManager.iconFromKey(
                                    template['iconKey']?.toString(),
                                  ),
                                  color: primaryGreen,
                                  size: 25,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      jenisLaporan,
                                      style: TextStyle(
                                        fontSize: 18.5,
                                        fontWeight: FontWeight.w800,
                                        color: textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isPreviewOnly
                                          ? 'Pratinjau Form Pengisian Pegawai'
                                          : templateDescription,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: textSecondary,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(sheetContext),
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // ── ISI FORM DALAM KARTU SEKSI YANG LEGA & RESPONSIF ──
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth >= 500;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // KARTU SEKSI 1: INFORMASI UTAMA & LOKASI
                                _SectionContainerCard(
                                  stepNumber: '1',
                                  title: 'Informasi Utama & Lokasi',
                                  subtitle:
                                      'Isi judul, tanggal pelaksanaan, dan titik lokasi kegiatan.',
                                  cardBg: cardBg,
                                  borderCol: borderCol,
                                  primaryGreen: primaryGreen,
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (isWide)
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              flex: 3,
                                              child: _SpaciousLabeledField(
                                                controller: judulCtrl,
                                                label: 'Judul Laporan',
                                                hint: defaultTitle.isNotEmpty
                                                    ? defaultTitle
                                                    : 'Contoh: Penyuluhan KTH',
                                                icon: Icons.title_rounded,
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              flex: 2,
                                              child: _DateSelectorField(
                                                label: 'Tanggal Laporan',
                                                valueText: formattedDateDisplay,
                                                onTap: pickReportDate,
                                              ),
                                            ),
                                          ],
                                        )
                                      else ...[
                                        _SpaciousLabeledField(
                                          controller: judulCtrl,
                                          label: 'Judul Laporan',
                                          hint: defaultTitle.isNotEmpty
                                              ? defaultTitle
                                              : 'Contoh: Penyuluhan KTH',
                                          icon: Icons.title_rounded,
                                        ),
                                        const SizedBox(height: 14),
                                        _DateSelectorField(
                                          label: 'Tanggal Laporan',
                                          valueText: formattedDateDisplay,
                                          onTap: pickReportDate,
                                        ),
                                      ],
                                      const SizedBox(height: 14),
                                      _SpaciousLabeledField(
                                        controller: lokasiCtrl,
                                        label: 'Lokasi Kegiatan',
                                        hint: 'Contoh: Kawasan Hutan Garut',
                                        icon: Icons.location_on_outlined,
                                        suffixWidget: TextButton.icon(
                                          onPressed: isGettingLocation
                                              ? null
                                              : getCurrentLocation,
                                          icon: isGettingLocation
                                              ? SizedBox(
                                                  width: 14,
                                                  height: 14,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: primaryGreen,
                                                      ),
                                                )
                                              : const Icon(
                                                  Icons.my_location_rounded,
                                                  size: 16,
                                                ),
                                          label: Text(
                                            isGettingLocation
                                                ? 'Mencari...'
                                                : 'Ambil GPS',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          style: TextButton.styleFrom(
                                            foregroundColor: primaryGreen,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          if (latCtrl.text.isNotEmpty &&
                                              lngCtrl.text.isNotEmpty)
                                            Flexible(
                                              child: Text(
                                                'Koordinat: ${latCtrl.text}, ${lngCtrl.text}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: primaryGreen,
                                                ),
                                              ),
                                            )
                                          else
                                            Text(
                                              'Koordinat GPS (opsional)',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: textSecondary,
                                              ),
                                            ),
                                          TextButton(
                                            onPressed: () {
                                              setModalState(() {
                                                showCoordinateInputs =
                                                    !showCoordinateInputs;
                                              });
                                            },
                                            style: TextButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              minimumSize: Size.zero,
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                            child: Text(
                                              showCoordinateInputs
                                                  ? 'Sembunyikan Koordinat'
                                                  : 'Input Koordinat Manual',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: primaryGreen,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (showCoordinateInputs) ...[
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _SpaciousLabeledField(
                                                controller: latCtrl,
                                                label: 'Latitude',
                                                hint: '-7.2279',
                                                icon:
                                                    Icons.my_location_outlined,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: _SpaciousLabeledField(
                                                controller: lngCtrl,
                                                label: 'Longitude',
                                                hint: '107.9087',
                                                icon: Icons.explore_outlined,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // KARTU SEKSI 2: BAGIAN ISIAN KEGIATAN SESUAI TEMPLATE ADMIN
                                _SectionContainerCard(
                                  stepNumber: '2',
                                  title: 'Isian Kegiatan ($jenisLaporan)',
                                  subtitle:
                                      'Bagian ini otomatis disusun sesuai template yang diatur oleh Admin.',
                                  cardBg: cardBg,
                                  borderCol: borderCol,
                                  primaryGreen: primaryGreen,
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (existing == null &&
                                          templateFields.isNotEmpty) ...[
                                        ...List.generate(
                                          templateFields.length,
                                          (index) {
                                            final fieldLabel =
                                                templateFields[index];
                                            final ctrl =
                                                fieldControllers[fieldLabel]!;
                                            final isLongField =
                                                fieldLabel
                                                    .toLowerCase()
                                                    .contains('hasil') ||
                                                fieldLabel
                                                    .toLowerCase()
                                                    .contains('uraian') ||
                                                fieldLabel
                                                    .toLowerCase()
                                                    .contains('kondisi') ||
                                                fieldLabel
                                                    .toLowerCase()
                                                    .contains('temuan') ||
                                                fieldLabel
                                                    .toLowerCase()
                                                    .contains('tindakan') ||
                                                fieldLabel
                                                    .toLowerCase()
                                                    .contains('ringkasan');

                                            return Padding(
                                              padding: EdgeInsets.only(
                                                bottom:
                                                    index ==
                                                        templateFields.length -
                                                            1
                                                    ? 8
                                                    : 14,
                                              ),
                                              child: _SpaciousLabeledField(
                                                controller: ctrl,
                                                label:
                                                    '${index + 1}. $fieldLabel',
                                                hint:
                                                    'Tuliskan ${fieldLabel.toLowerCase()}...',
                                                icon: isLongField
                                                    ? Icons.notes_rounded
                                                    : Icons.edit_note_rounded,
                                                maxLines: isLongField ? 3 : 1,
                                                onChanged: (_) =>
                                                    syncTemplateFieldsToIsi(),
                                              ),
                                            );
                                          },
                                        ),
                                        Theme(
                                          data: Theme.of(sheetContext).copyWith(
                                            dividerColor: Colors.transparent,
                                          ),
                                          child: ExpansionTile(
                                            tilePadding: EdgeInsets.zero,
                                            childrenPadding:
                                                const EdgeInsets.only(top: 8),
                                            title: Text(
                                              'Lihat / Sesuaikan Naskah Lengkap Laporan',
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w700,
                                                color: primaryGreen,
                                              ),
                                            ),
                                            children: [
                                              _SpaciousLabeledField(
                                                controller: isiCtrl,
                                                label:
                                                    'Naskah Laporan Terformat',
                                                hint:
                                                    'Naskah laporan otomatis terisi dari bagian di atas...',
                                                icon: Icons.article_outlined,
                                                maxLines: 6,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ] else
                                        _SpaciousLabeledField(
                                          controller: isiCtrl,
                                          label: 'Isi / Uraian Laporan',
                                          hint:
                                              'Tuliskan hasil kegiatan lapangan...',
                                          icon: Icons.notes_rounded,
                                          maxLines: 6,
                                        ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // KARTU SEKSI 3: LAMPIRAN FOTO DOKUMENTASI
                                _SectionContainerCard(
                                  stepNumber: '3',
                                  title: 'Lampiran Foto Dokumentasi',
                                  subtitle: requirePhoto
                                      ? 'Sertakan foto bukti kegiatan di lapangan.'
                                      : 'Opsional — tambahkan foto dokumentasi jika tersedia.',
                                  cardBg: cardBg,
                                  borderCol: borderCol,
                                  primaryGreen: primaryGreen,
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary,
                                  child: pickedPhotoBytes != null
                                      ? Container(
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? const Color(0xFF18221B)
                                                : LaporanColors.fieldFill,
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            border: Border.all(
                                              color: borderCol,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              ClipRRect(
                                                borderRadius:
                                                    const BorderRadius.vertical(
                                                      top: Radius.circular(14),
                                                    ),
                                                child: Image.memory(
                                                  pickedPhotoBytes!,
                                                  height: 180,
                                                  width: double.infinity,
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 10,
                                                    ),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        pickedPhotoFile?.name ??
                                                            'Foto Bukti Kegiatan',
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ),
                                                    TextButton.icon(
                                                      onPressed: pickPhoto,
                                                      icon: const Icon(
                                                        Icons.refresh_rounded,
                                                        size: 16,
                                                      ),
                                                      label: const Text(
                                                        'Ganti',
                                                      ),
                                                      style:
                                                          TextButton.styleFrom(
                                                            foregroundColor:
                                                                primaryGreen,
                                                          ),
                                                    ),
                                                    TextButton.icon(
                                                      onPressed: () {
                                                        setModalState(() {
                                                          pickedPhotoBytes =
                                                              null;
                                                          pickedPhotoFile =
                                                              null;
                                                        });
                                                      },
                                                      icon: const Icon(
                                                        Icons
                                                            .delete_outline_rounded,
                                                        size: 16,
                                                        color: Colors.red,
                                                      ),
                                                      label: const Text(
                                                        'Hapus',
                                                        style: TextStyle(
                                                          color: Colors.red,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : _PhotoButton(onTap: pickPhoto),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),

                    // ── FOOTER TOMBOL AKSI TETAP DI BAWAH ──
                    Container(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        14,
                        20,
                        MediaQuery.of(sheetContext).viewInsets.bottom + 18,
                      ),
                      decoration: BoxDecoration(
                        color: cardBg,
                        border: Border(top: BorderSide(color: borderCol)),
                      ),
                      child: isPreviewOnly
                          ? SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => Navigator.pop(sheetContext),
                                icon: const Icon(Icons.check_rounded),
                                label: const Text('Tutup Pratinjau Form User'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF245C3A),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                ),
                              ),
                            )
                          : Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      if (existing == null &&
                                          templateFields.isNotEmpty) {
                                        syncTemplateFieldsToIsi();
                                      }
                                      await _handleSubmit(
                                        context: sheetContext,
                                        parentContext: context,
                                        jenisLaporan: jenisLaporan,
                                        existing: existing,
                                        judulCtrl: judulCtrl,
                                        isiCtrl: isiCtrl,
                                        lokasiCtrl: lokasiCtrl,
                                        latCtrl: latCtrl,
                                        lngCtrl: lngCtrl,
                                        customActivityDate: formattedDateApi,
                                        status: 'Draft',
                                        onReportSaved: onReportSaved,
                                        photoBytes: pickedPhotoBytes,
                                        photoFilename: pickedPhotoFile?.name,
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.save_outlined,
                                      size: 18,
                                    ),
                                    label: const Text('Simpan Draft'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: primaryGreen,
                                      side: BorderSide(color: primaryGreen),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                        horizontal: 8,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(13),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      if (existing == null &&
                                          templateFields.isNotEmpty) {
                                        syncTemplateFieldsToIsi();
                                      }
                                      if (judulCtrl.text.trim().isEmpty ||
                                          isiCtrl.text.trim().isEmpty) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Isi judul dan bagian laporan sebelum menyelesaikan laporan.',
                                            ),
                                          ),
                                        );
                                        return;
                                      }
                                      await _handleSubmit(
                                        context: sheetContext,
                                        parentContext: context,
                                        jenisLaporan: jenisLaporan,
                                        existing: existing,
                                        judulCtrl: judulCtrl,
                                        isiCtrl: isiCtrl,
                                        lokasiCtrl: lokasiCtrl,
                                        latCtrl: latCtrl,
                                        lngCtrl: lngCtrl,
                                        customActivityDate: formattedDateApi,
                                        status: 'Selesai',
                                        onReportSaved: onReportSaved,
                                        closeOnSuccess: true,
                                        photoBytes: pickedPhotoBytes,
                                        photoFilename: pickedPhotoFile?.name,
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.check_circle_outline,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      'Selesaikan Laporan',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF245C3A),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                        horizontal: 8,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(13),
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
            ),
          );
        },
      );
    },
  );
}

// ---------------------------------------------------------------------------
// 3. Editor Template Laporan Admin (3 Tab Rapi + Upload & Konversi File Contoh)
// ---------------------------------------------------------------------------

Future<void> showAdminTemplateEditor(
  BuildContext context, {
  Map<String, dynamic>? existingTemplate,
  required Future<void> Function(Map<String, dynamic> savedTemplate) onSaved,
}) async {
  final isEditing = existingTemplate != null;

  final titleCtrl = TextEditingController(
    text: existingTemplate?['title']?.toString() ?? '',
  );
  final categoryCtrl = TextEditingController(
    text: existingTemplate?['category']?.toString() ?? 'Penyuluhan',
  );
  final descCtrl = TextEditingController(
    text: existingTemplate?['description']?.toString() ?? '',
  );
  final defaultTitleCtrl = TextEditingController(
    text: existingTemplate?['defaultTitle']?.toString() ?? '',
  );
  final bodyCtrl = TextEditingController(
    text: existingTemplate?['templateBody']?.toString() ?? '',
  );
  final newFieldCtrl = TextEditingController();

  String selectedIconKey =
      existingTemplate?['iconKey']?.toString() ?? 'groups';
  String sampleFileName =
      existingTemplate?['sampleFileName']?.toString() ?? '';
  bool requirePhoto = existingTemplate?['requirePhoto'] != false;
  bool requireLocation = existingTemplate?['requireLocation'] != false;
  bool isExtractingFile = false;

  /// 0 = Upload Contoh & Info, 1 = Form Isian User, 2 = Kerangka Naskah
  int activeStepTab = 0;

  final List<String> fields =
      (existingTemplate?['fields'] as List?)
          ?.map((e) => e.toString())
          .toList() ??
      <String>[
        'Kelompok Tani Hutan (KTH) / Sasaran',
        'Materi / Pokok Kegiatan',
        'Jumlah Peserta (Orang)',
        'Hasil & Tindak Lanjut',
      ];

  void regenerateTemplateBodyFromFields() {
    final titleText = titleCtrl.text.trim().isEmpty
        ? 'LAPORAN KEGIATAN LAPANGAN'
        : titleCtrl.text.trim().toUpperCase();
    final buffer = StringBuffer();
    buffer.writeln(titleText);
    buffer.writeln('Cabang Dinas Kehutanan Wilayah V\n');
    for (int i = 0; i < fields.length; i++) {
      buffer.writeln('${i + 1}. ${fields[i]} : {{${fields[i]}}}');
    }
    bodyCtrl.text = buffer.toString().trim();
  }

  if (!isEditing && bodyCtrl.text.trim().isEmpty) {
    regenerateTemplateBodyFromFields();
  }

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (sheetCtx, setModalState) {
          final isDark = Theme.of(sheetCtx).brightness == Brightness.dark;
          final sheetBg = isDark
              ? const Color(0xFF141C17)
              : const Color(0xFFF6F8F5);
          final cardBg = isDark ? const Color(0xFF1E2822) : Colors.white;
          final softBg = isDark
              ? const Color(0xFF18221B)
              : const Color(0xFFF2F7F0);
          final borderCol = isDark
              ? const Color(0xFF2E3D34)
              : const Color(0xFFE2EAE3);
          final primaryGreen = isDark
              ? const Color(0xFF81C784)
              : const Color(0xFF245C3A);
          final textPrimary = isDark ? Colors.white : const Color(0xFF24352A);
          final textSecondary = isDark
              ? Colors.white70
              : const Color(0xFF6E7A72);

          // Fungsi Pilih & Ekstrak File Contoh Laporan (.docx, .doc, .pdf, .txt)
          Future<void> pickAndExtractSampleFile() async {
            setModalState(() => isExtractingFile = true);
            try {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['docx', 'doc', 'pdf', 'txt'],
                withData: true,
              );

              if (result != null && result.files.isNotEmpty) {
                final picked = result.files.single;
                Uint8List? fileBytes = picked.bytes;

                if (fileBytes == null &&
                    !kIsWeb &&
                    picked.path != null &&
                    picked.path!.isNotEmpty) {
                  try {
                    fileBytes = await File(picked.path!).readAsBytes();
                  } catch (_) {}
                }

                final extracted =
                    ReportTemplateManager.extractTemplateFromSampleFile(
                      fileName: picked.name,
                      bytes: fileBytes,
                    );

                setModalState(() {
                  sampleFileName = picked.name;
                  if (titleCtrl.text.trim().isEmpty || !isEditing) {
                    titleCtrl.text = (extracted['title'] ?? '').toString();
                  }
                  categoryCtrl.text = (extracted['category'] ?? 'Penyuluhan')
                      .toString();
                  selectedIconKey = (extracted['iconKey'] ?? 'groups')
                      .toString();
                  defaultTitleCtrl.text =
                      (extracted['defaultTitle'] ?? '').toString();
                  descCtrl.text = (extracted['description'] ?? '').toString();

                  final extFields =
                      (extracted['fields'] as List?)
                          ?.map((e) => e.toString())
                          .toList() ??
                      [];
                  if (extFields.isNotEmpty) {
                    fields
                      ..clear()
                      ..addAll(extFields);
                  }
                  bodyCtrl.text = (extracted['templateBody'] ?? '').toString();
                });

                if (sheetCtx.mounted) {
                  ScaffoldMessenger.of(sheetCtx).showSnackBar(
                    SnackBar(
                      content: Text(
                        'File contoh "${picked.name}" berhasil dikonversi menjadi template (${fields.length} bagian isian).',
                      ),
                      backgroundColor: const Color(0xFF245C3A),
                    ),
                  );
                }
              }
            } catch (e) {
              if (sheetCtx.mounted) {
                ScaffoldMessenger.of(sheetCtx).showSnackBar(
                  SnackBar(content: Text('Gagal membaca file contoh: $e')),
                );
              }
            } finally {
              if (sheetCtx.mounted) {
                setModalState(() => isExtractingFile = false);
              }
            }
          }

          final iconOptions = [
            ('groups', Icons.groups_outlined, 'Penyuluhan'),
            ('park', Icons.park_outlined, 'TRK / Rehab'),
            ('forest', Icons.forest_outlined, 'Monitoring'),
            ('event_note', Icons.event_note_outlined, 'Kegiatan'),
            ('warning', Icons.warning_amber_rounded, 'Kejadian'),
            ('eco', Icons.eco_outlined, 'Konservasi'),
          ];

          return Center(
            heightFactor: 1.0,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 720,
                maxHeight: MediaQuery.of(sheetCtx).size.height * 0.92,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: sheetBg,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── HEADER MODAL & STEPPER TAB BAR ──
                    Container(
                      padding: const EdgeInsets.fromLTRB(22, 14, 16, 14),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                        border: Border(bottom: BorderSide(color: borderCol)),
                      ),
                      child: Column(
                        children: [
                          const _DragHandle(),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF26352B)
                                      : const Color(0xFFE8F2E8),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  Icons.edit_document,
                                  color: primaryGreen,
                                  size: 25,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isEditing
                                          ? 'Atur Template: ${existingTemplate['title']}'
                                          : 'Buat Template Jenis Laporan Baru',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Unggah file contoh laporan atau sesuaikan bagian form yang wajib diisi pegawai.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(sheetCtx),
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          // 3-Tab Stepper agar form tidak pernah menumpuk
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: softBg,
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(color: borderCol),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _StepTabButton(
                                    label: '1. Contoh & Info',
                                    icon: Icons.upload_file_rounded,
                                    isSelected: activeStepTab == 0,
                                    onTap: () =>
                                        setModalState(() => activeStepTab = 0),
                                  ),
                                ),
                                Expanded(
                                  child: _StepTabButton(
                                    label: '2. Form User (${fields.length})',
                                    icon: Icons.fact_check_outlined,
                                    isSelected: activeStepTab == 1,
                                    onTap: () =>
                                        setModalState(() => activeStepTab = 1),
                                  ),
                                ),
                                Expanded(
                                  child: _StepTabButton(
                                    label: '3. Naskah Template',
                                    icon: Icons.article_outlined,
                                    isSelected: activeStepTab == 2,
                                    onTap: () =>
                                        setModalState(() => activeStepTab = 2),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── ISI TAB (LEGA, RAPI & FOKUS PER TAHAP) ──
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth >= 500;

                            if (activeStepTab == 0) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // KARTU UPLOAD FILE CONTOH LAPORAN (KONVERSI LANGSUNG)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      color: cardBg,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: primaryGreen.withValues(
                                          alpha: 0.4,
                                        ),
                                        width: 1.3,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 44,
                                              height: 44,
                                              decoration: BoxDecoration(
                                                color: primaryGreen.withValues(
                                                  alpha: 0.14,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(13),
                                              ),
                                              child: Icon(
                                                Icons.auto_fix_high_rounded,
                                                color: primaryGreen,
                                                size: 22,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Konversi dari File Contoh Laporan',
                                                    style: TextStyle(
                                                      fontSize: 15.5,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: textPrimary,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Unggah file contoh (.docx, .doc, .pdf, atau .txt) untuk diekstrak otomatis menjadi template & form user.',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: textSecondary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 14),
                                        if (sampleFileName.isNotEmpty)
                                          Container(
                                            margin: const EdgeInsets.only(
                                              bottom: 12,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                            decoration: BoxDecoration(
                                              color: softBg,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: borderCol,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons
                                                      .check_circle_outline_rounded,
                                                  size: 18,
                                                  color: primaryGreen,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    'File Contoh Terpasang: $sampleFileName',
                                                    style: TextStyle(
                                                      fontSize: 12.5,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: textPrimary,
                                                    ),
                                                  ),
                                                ),
                                                TextButton(
                                                  onPressed: () =>
                                                      setModalState(
                                                        () =>
                                                            activeStepTab = 1,
                                                      ),
                                                  child: const Text(
                                                    'Lihat Hasil Form →',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        SizedBox(
                                          width: double.infinity,
                                          child: OutlinedButton.icon(
                                            onPressed: isExtractingFile
                                                ? null
                                                : pickAndExtractSampleFile,
                                            icon: isExtractingFile
                                                ? SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: primaryGreen,
                                                        ),
                                                  )
                                                : const Icon(
                                                    Icons.upload_file_rounded,
                                                    size: 19,
                                                  ),
                                            label: Text(
                                              sampleFileName.isEmpty
                                                  ? 'Pilih File Contoh Laporan (.docx / .pdf / .txt)'
                                                  : 'Ganti File Contoh Laporan',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: primaryGreen,
                                              side: BorderSide(
                                                color: primaryGreen,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 13,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(13),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  // KARTU IDENTITAS JENIS LAPORAN
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      color: cardBg,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: borderCol),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Identitas Jenis Laporan',
                                          style: TextStyle(
                                            fontSize: 15.5,
                                            fontWeight: FontWeight.w800,
                                            color: textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 14),
                                        if (isWide)
                                          Row(
                                            children: [
                                              Expanded(
                                                child: _SpaciousLabeledField(
                                                  controller: titleCtrl,
                                                  label: 'Nama Jenis Laporan',
                                                  hint:
                                                      'Contoh: Laporan Penyuluhan / Laporan TRK',
                                                  icon: Icons.badge_outlined,
                                                ),
                                              ),
                                              const SizedBox(width: 14),
                                              Expanded(
                                                child: _SpaciousLabeledField(
                                                  controller: categoryCtrl,
                                                  label: 'Kategori Laporan',
                                                  hint:
                                                      'Contoh: TRK & Rehabilitasi',
                                                  icon: Icons.category_outlined,
                                                ),
                                              ),
                                            ],
                                          )
                                        else ...[
                                          _SpaciousLabeledField(
                                            controller: titleCtrl,
                                            label: 'Nama Jenis Laporan',
                                            hint:
                                                'Contoh: Laporan Penyuluhan / Laporan TRK',
                                            icon: Icons.badge_outlined,
                                          ),
                                          const SizedBox(height: 14),
                                          _SpaciousLabeledField(
                                            controller: categoryCtrl,
                                            label: 'Kategori Laporan',
                                            hint: 'Contoh: TRK & Rehabilitasi',
                                            icon: Icons.category_outlined,
                                          ),
                                        ],
                                        const SizedBox(height: 14),
                                        _SpaciousLabeledField(
                                          controller: defaultTitleCtrl,
                                          label: 'Judul Default pada Form User',
                                          hint:
                                              'Contoh: Pelaksanaan Kegiatan TRK & Rehabilitasi Lahan',
                                          icon: Icons.title_rounded,
                                        ),
                                        const SizedBox(height: 14),
                                        _SpaciousLabeledField(
                                          controller: descCtrl,
                                          label:
                                              'Deskripsi / Petunjuk Singkat untuk Pegawai',
                                          hint:
                                              'Jelaskan kegunaan jenis laporan ini...',
                                          icon: Icons.info_outline_rounded,
                                          maxLines: 2,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Pilih Ikon Template',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: iconOptions.map((opt) {
                                            final selected =
                                                selectedIconKey == opt.$1;
                                            return ChoiceChip(
                                              avatar: Icon(
                                                opt.$2,
                                                size: 16,
                                                color: selected
                                                    ? Colors.white
                                                    : primaryGreen,
                                              ),
                                              label: Text(opt.$3),
                                              selected: selected,
                                              showCheckmark: false,
                                              selectedColor: const Color(
                                                0xFF245C3A,
                                              ),
                                              labelStyle: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: selected
                                                    ? Colors.white
                                                    : textPrimary,
                                              ),
                                              onSelected: (_) => setModalState(
                                                () => selectedIconKey = opt.$1,
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }

                            if (activeStepTab == 1) {
                              // TAB 2: SESUAIKAN BAGIAN FORM YANG DIISI USER
                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: borderCol),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Atur Kolom Isian untuk Pegawai',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Pegawai otomatis mengisi Judul, Tanggal, Lokasi/GPS, dan Foto. Tambahkan atau sesuaikan bagian khusus kegiatan di bawah ini:',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: newFieldCtrl,
                                            style: TextStyle(
                                              color: textPrimary,
                                              fontSize: 13.5,
                                            ),
                                            decoration: InputDecoration(
                                              hintText:
                                                  'Ketik nama bagian baru (misal: Luas Area Tanam)...',
                                              hintStyle: TextStyle(
                                                fontSize: 12.5,
                                                color: textSecondary,
                                              ),
                                              filled: true,
                                              fillColor: softBg,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 12,
                                                  ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                borderSide: BorderSide(
                                                  color: borderCol,
                                                ),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                borderSide: BorderSide(
                                                  color: borderCol,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            final val = newFieldCtrl.text
                                                .trim();
                                            if (val.isEmpty) return;
                                            setModalState(() {
                                              if (!fields.contains(val)) {
                                                fields.add(val);
                                              }
                                              newFieldCtrl.clear();
                                            });
                                          },
                                          icon: const Icon(
                                            Icons.add_rounded,
                                            size: 18,
                                          ),
                                          label: const Text('Tambah'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF245C3A,
                                            ),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 13,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    ...List.generate(fields.length, (idx) {
                                      final f = fields[idx];
                                      return Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: softBg,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(color: borderCol),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 26,
                                              height: 26,
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color: primaryGreen.withValues(
                                                  alpha: 0.15,
                                                ),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Text(
                                                '${idx + 1}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: primaryGreen,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                f,
                                                style: TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: textPrimary,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              tooltip: 'Hapus Bagian Ini',
                                              visualDensity:
                                                  VisualDensity.compact,
                                              onPressed: () {
                                                setModalState(() {
                                                  fields.removeAt(idx);
                                                });
                                              },
                                              icon: const Icon(
                                                Icons.delete_outline_rounded,
                                                size: 18,
                                                color: Colors.red,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                    const SizedBox(height: 10),
                                    Divider(color: borderCol),
                                    SwitchListTile.adaptive(
                                      contentPadding: EdgeInsets.zero,
                                      activeTrackColor: const Color(0xFF245C3A),
                                      title: Text(
                                        'Sarankan Lampiran Foto Dokumentasi',
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: textPrimary,
                                        ),
                                      ),
                                      subtitle: Text(
                                        'Menampilkan penanda lampiran foto bukti kegiatan pada form pegawai',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: textSecondary,
                                        ),
                                      ),
                                      value: requirePhoto,
                                      onChanged: (val) => setModalState(
                                        () => requirePhoto = val,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            // TAB 3: KERANGKA NASKAH TEMPLATE LAPORAN
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: borderCol),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Kerangka Naskah Template Laporan',
                                          style: TextStyle(
                                            fontSize: 15.5,
                                            fontWeight: FontWeight.w800,
                                            color: textPrimary,
                                          ),
                                        ),
                                      ),
                                      TextButton.icon(
                                        onPressed: () {
                                          setModalState(
                                            regenerateTemplateBodyFromFields,
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.refresh_rounded,
                                          size: 16,
                                        ),
                                        label: const Text(
                                          'Susun Ulang Otomatis',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        style: TextButton.styleFrom(
                                          foregroundColor: primaryGreen,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Klik chip di bawah untuk menyisipkan placeholder bagian ke dalam naskah:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: fields.map((f) {
                                      return ActionChip(
                                        label: Text(
                                          '+ {{$f}}',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: primaryGreen,
                                          ),
                                        ),
                                        backgroundColor: softBg,
                                        side: BorderSide(color: borderCol),
                                        onPressed: () {
                                          bodyCtrl.text =
                                              '${bodyCtrl.text}\n$f : {{$f}}'
                                                  .trim();
                                        },
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 14),
                                  _SpaciousLabeledField(
                                    controller: bodyCtrl,
                                    label: 'Format Naskah Laporan',
                                    hint:
                                        'Tulis kerangka laporan baku di sini...',
                                    icon: Icons.article_outlined,
                                    maxLines: 9,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    // ── FOOTER TOMBOL SIMPAN TEMPLATE ──
                    Container(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        14,
                        20,
                        MediaQuery.of(sheetCtx).viewInsets.bottom + 18,
                      ),
                      decoration: BoxDecoration(
                        color: cardBg,
                        border: Border(top: BorderSide(color: borderCol)),
                      ),
                      child: Row(
                        children: [
                          if (activeStepTab > 0)
                            OutlinedButton.icon(
                              onPressed: () =>
                                  setModalState(() => activeStepTab--),
                              icon: const Icon(
                                Icons.arrow_back_rounded,
                                size: 17,
                              ),
                              label: const Text('Sebelumnya'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13),
                                ),
                              ),
                            )
                          else
                            OutlinedButton(
                              onPressed: () => Navigator.pop(sheetCtx),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13),
                                ),
                              ),
                              child: const Text('Batal'),
                            ),
                          const SizedBox(width: 10),
                          if (activeStepTab < 2)
                            OutlinedButton.icon(
                              onPressed: () =>
                                  setModalState(() => activeStepTab++),
                              icon: const Icon(
                                Icons.arrow_forward_rounded,
                                size: 17,
                              ),
                              label: const Text('Lanjut'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: primaryGreen,
                                side: BorderSide(color: primaryGreen),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13),
                                ),
                              ),
                            ),
                          if (activeStepTab < 2) const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                if (titleCtrl.text.trim().isEmpty) {
                                  setModalState(() => activeStepTab = 0);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Nama jenis laporan wajib diisi.',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                if (bodyCtrl.text.trim().isEmpty) {
                                  regenerateTemplateBodyFromFields();
                                }

                                final saved =
                                    ReportTemplateManager.normalizeTemplate({
                                      'id':
                                          existingTemplate?['id'] ??
                                          'tpl_${DateTime.now().millisecondsSinceEpoch}',
                                      'title': titleCtrl.text.trim(),
                                      'category':
                                          categoryCtrl.text.trim().isEmpty
                                          ? 'Penyuluhan'
                                          : categoryCtrl.text.trim(),
                                      'iconKey': selectedIconKey,
                                      'description':
                                          descCtrl.text.trim().isEmpty
                                          ? 'Template laporan kegiatan ${titleCtrl.text.trim()}.'
                                          : descCtrl.text.trim(),
                                      'defaultTitle': defaultTitleCtrl.text
                                          .trim(),
                                      'requirePhoto': requirePhoto,
                                      'requireLocation': requireLocation,
                                      'sampleFileName': sampleFileName,
                                      'fields': fields,
                                      'templateBody': bodyCtrl.text.trim(),
                                      'updatedBy': 'Administrator',
                                    });

                                Navigator.pop(sheetCtx);
                                await onSaved(saved);
                              },
                              icon: const Icon(Icons.save_outlined, size: 18),
                              label: const Text(
                                'Simpan Template',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF245C3A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13),
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
            ),
          );
        },
      );
    },
  );
}

// ---------------------------------------------------------------------------
// 4. Bottom Sheet Unduh Laporan (PDF Siap Print / Word untuk Dikirim ke Atasan)
// ---------------------------------------------------------------------------

Future<void> showReportDownloadSheet(
  BuildContext context, {
  required Map<String, dynamic> laporan,
}) async {
  bool isExportingPdf = false;
  bool isExportingWord = false;
  ReportExportResult? lastResult;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).cardColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          final isDark = Theme.of(sheetCtx).brightness == Brightness.dark;
          final primaryGreen = isDark
              ? const Color(0xFF81C784)
              : const Color(0xFF245C3A);
          final softBg = isDark
              ? const Color(0xFF18221B)
              : const Color(0xFFF2F7F0);
          final borderCol = isDark
              ? const Color(0xFF2E3D34)
              : const Color(0xFFE0E8E0);

          Future<void> triggerExport(
            String format, {
            bool openInNewTab = false,
          }) async {
            setSheetState(() {
              if (format == 'pdf') {
                isExportingPdf = true;
              } else {
                isExportingWord = true;
              }
            });

            final res = await ReportDocumentExporter.exportReport(
              laporan,
              format: format,
              openInNewTabOnWeb: openInNewTab,
            );

            if (!sheetCtx.mounted) return;
            setSheetState(() {
              isExportingPdf = false;
              isExportingWord = false;
              lastResult = res;
            });

            ScaffoldMessenger.of(sheetCtx).showSnackBar(
              SnackBar(
                content: Text(res.message),
                backgroundColor: res.success
                    ? const Color(0xFF245C3A)
                    : Colors.red.shade700,
              ),
            );
          }

          return SafeArea(
            child: Center(
              heightFactor: 1.0,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 16, 22, 26),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _DragHandle(),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF26352B)
                                  : const Color(0xFFE8F2E8),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.picture_as_pdf_rounded,
                              color: primaryGreen,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Unduh & Cetak Laporan Resmi',
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Siap di-print langsung atau dikirimkan ke atasan.',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Ringkasan Pratinjau Dokumen
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: softBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderCol),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'KOP SURAT: CABANG DINAS KEHUTANAN WILAYAH V GARUT',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                                color: primaryGreen,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              (laporan['judul'] ?? 'Laporan Kegiatan')
                                  .toString(),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${laporan['jenis'] ?? 'Laporan Penyuluhan'} • ${laporan['tanggal'] ?? '-'} • ${laporan['lokasi'] ?? '-'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.white70
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (lastResult != null && lastResult!.success) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF245C3A,
                            ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                color: primaryGreen,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Tersimpan: ${lastResult!.fileName}',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (lastResult!.filePath != null ||
                                  lastResult!.webBlobUrl != null)
                                TextButton.icon(
                                  onPressed: () {
                                    ReportDocumentExporter.openExportedFile(
                                      lastResult!,
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.open_in_new_rounded,
                                    size: 16,
                                  ),
                                  label: const Text('Buka / Print'),
                                ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 18),

                      // Tombol Utama: Unduh PDF Siap Print
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: isExportingPdf
                              ? null
                              : () => triggerExport('pdf'),
                          icon: isExportingPdf
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.picture_as_pdf_rounded),
                          label: const Text(
                            'Unduh Laporan PDF Siap Print (.pdf)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF245C3A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Tombol Buka & Print Langsung di Tab Baru (Blob PDF Viewer)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: isExportingPdf
                              ? null
                              : () => triggerExport('pdf', openInNewTab: true),
                          icon: const Icon(Icons.print_outlined),
                          label: const Text(
                            'Buka & Print PDF di Tab Baru',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryGreen,
                            side: BorderSide(color: primaryGreen),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Tombol Alternatif: Unduh Dokumen Word (.doc)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: isExportingWord
                              ? null
                              : () => triggerExport('doc'),
                          icon: isExportingWord
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: primaryGreen,
                                  ),
                                )
                              : const Icon(Icons.description_outlined),
                          label: const Text(
                            'Unduh Format Word (.doc)',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryGreen,
                            side: BorderSide(color: primaryGreen),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

// ---------------------------------------------------------------------------
// 5. Bottom Sheet Detail Laporan (Mendukung User & Verifikasi Monitoring Admin)
// ---------------------------------------------------------------------------

void showReportDetail(
  BuildContext context, {
  required Map<String, dynamic> laporan,
  required void Function(String jenisLaporan, {Map<String, dynamic>? existing})
      onEdit,
  required void Function(Map<String, dynamic> laporan) onDownload,
  bool isAdmin = false,
  void Function(Map<String, dynamic> laporan, String newStatus)?
      onUpdateStatus,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).cardColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
    ),
    builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      final pelapor =
          (laporan['pelapor'] ?? laporan['userName'] ?? 'Penyuluh Kehutanan')
              .toString();
      final currentStatus = (laporan['status'] ?? 'Draft').toString();

      return Center(
        heightFactor: 1.0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 30),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _DragHandle(),
                  const SizedBox(height: 20),

                  Text(
                    (laporan['judul'] ?? '-').toString(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    (laporan['jenis'] ?? 'Laporan Kegiatan').toString(),
                    style: const TextStyle(
                      color: LaporanColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 18),

                  if (isAdmin ||
                      laporan['pelapor'] != null ||
                      laporan['userName'] != null)
                    _DetailRow(
                      icon: Icons.person_outline_rounded,
                      title: 'Pegawai',
                      value: pelapor,
                    ),
                  _DetailRow(
                    icon: Icons.calendar_today_outlined,
                    title: 'Tanggal',
                    value: (laporan['tanggal'] ?? '-').toString(),
                  ),
                  _DetailRow(
                    icon: Icons.location_on_outlined,
                    title: 'Lokasi',
                    value: (laporan['lokasi'] ?? '-').toString(),
                  ),
                  _DetailRow(
                    icon: Icons.info_outline,
                    title: 'Status',
                    value: currentStatus,
                  ),

                  const SizedBox(height: 8),
                  const Text(
                    'Isi Laporan (Berdasarkan Template)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF18221B)
                          : LaporanColors.templateBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF2E3D34)
                            : LaporanColors.borderDetail,
                      ),
                    ),
                    child: Text(
                      (laporan['isi']?.toString().isNotEmpty ?? false)
                          ? laporan['isi'].toString()
                          : 'Isi laporan belum dilengkapi.',
                      style: const TextStyle(height: 1.5),
                    ),
                  ),

                  const SizedBox(height: 14),

                  _DetailRow(
                    icon: Icons.my_location_outlined,
                    title: 'Latitude',
                    value: (laporan['latitude']?.toString().isNotEmpty ?? false)
                        ? laporan['latitude'].toString()
                        : 'Belum tersedia',
                  ),
                  _DetailRow(
                    icon: Icons.explore_outlined,
                    title: 'Longitude',
                    value:
                        (laporan['longitude']?.toString().isNotEmpty ?? false)
                        ? laporan['longitude'].toString()
                        : 'Belum tersedia',
                  ),

                  const SizedBox(height: 20),

                  if (isAdmin && onUpdateStatus != null) ...[
                    const Text(
                      'Tindakan Monitoring Admin:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (currentStatus != 'Selesai')
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                onUpdateStatus(laporan, 'Selesai');
                              },
                              icon: const Icon(
                                Icons.verified_outlined,
                                size: 18,
                              ),
                              label: const Text('Verifikasi Selesai'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF245C3A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        if (currentStatus != 'Selesai' &&
                            currentStatus != 'Diproses')
                          const SizedBox(width: 10),
                        if (currentStatus != 'Diproses')
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                onUpdateStatus(laporan, 'Diproses');
                              },
                              icon: const Icon(
                                Icons.pending_actions_rounded,
                                size: 18,
                              ),
                              label: const Text('Tandai Diproses'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFB26A00),
                                side: const BorderSide(
                                  color: Color(0xFFE7C98A),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],

                  if (!isAdmin && currentStatus == 'Draft') ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          onEdit(
                            (laporan['jenis'] ?? 'Laporan Kegiatan').toString(),
                            existing: laporan,
                          );
                        },
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Lanjutkan / Edit Draft'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        onDownload(laporan);
                      },
                      icon: const Icon(Icons.picture_as_pdf_rounded),
                      label: const Text(
                        'Unduh Laporan (PDF / Word)',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF245C3A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Submit handler (shared between draft & final submit)
// ---------------------------------------------------------------------------

Future<void> _handleSubmit({
  required BuildContext context,
  required BuildContext parentContext,
  required String jenisLaporan,
  required Map<String, dynamic>? existing,
  required TextEditingController judulCtrl,
  required TextEditingController isiCtrl,
  required TextEditingController lokasiCtrl,
  required TextEditingController latCtrl,
  required TextEditingController lngCtrl,
  String? customActivityDate,
  required String status,
  required Future<void> Function() onReportSaved,
  bool closeOnSuccess = false,
  Uint8List? photoBytes,
  String? photoFilename,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');

  if (token == null || token.isEmpty) {
    if (!parentContext.mounted) return;
    ScaffoldMessenger.of(parentContext).showSnackBar(
      const SnackBar(content: Text('Silakan login kembali.')),
    );
    return;
  }

  final title = judulCtrl.text.trim();
  final location = lokasiCtrl.text.trim();

  if (title.isEmpty || location.isEmpty) {
    if (!parentContext.mounted) return;
    ScaffoldMessenger.of(parentContext).showSnackBar(
      const SnackBar(
        content: Text('Judul dan lokasi wajib diisi.'),
      ),
    );
    return;
  }

  final now = DateTime.now();
  final existingDate = existing?['tanggalApi']?.toString();
  final activityDate = (customActivityDate != null &&
          customActivityDate.isNotEmpty)
      ? customActivityDate
      : ((existingDate != null && existingDate.isNotEmpty)
            ? existingDate
            : '${now.year}-${now.month.toString().padLeft(2, '0')}'
                  '-${now.day.toString().padLeft(2, '0')}');

  final apiStatus = status == 'Draft' ? 'draft' : 'terkirim';
  final currentUserName =
      prefs.getString('profil_nama') ??
      prefs.getString('name') ??
      'Rizky Pratama, S.Hut.';

  final payload = <String, dynamic>{
    'title': title,
    'activity_date': activityDate,
    'location': location,
    'description': isiCtrl.text.trim(),
    'latitude': latCtrl.text.trim().isEmpty
        ? null
        : double.tryParse(latCtrl.text.trim()),
    'longitude': lngCtrl.text.trim().isEmpty
        ? null
        : double.tryParse(lngCtrl.text.trim()),
    'status': apiStatus,
  };

  Future<void> syncToLocalMonitoringStorage(String recordId) async {
    try {
      const draftKey = 'phonebook_laporan_drafts_v1';
      final rawDrafts = prefs.getString(draftKey);
      List<Map<String, dynamic>> drafts = [];
      if (rawDrafts != null && rawDrafts.isNotEmpty) {
        final decoded = jsonDecode(rawDrafts) as List<dynamic>;
        drafts = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      final record = <String, dynamic>{
        'id': recordId,
        'judul': title,
        'jenis': jenisLaporan,
        'pelapor': currentUserName,
        'userName': currentUserName,
        'tanggal': LaporanDateUtils.formatApiDate(activityDate),
        'tanggalApi': activityDate,
        'lokasi': location,
        'isi': isiCtrl.text.trim(),
        'latitude': latCtrl.text.trim(),
        'longitude': lngCtrl.text.trim(),
        'status': status,
      };
      final existingIdx = drafts.indexWhere(
        (d) => d['id'].toString() == recordId || d['judul'] == title,
      );
      if (existingIdx >= 0) {
        drafts[existingIdx] = record;
      } else {
        drafts.insert(0, record);
      }
      await prefs.setString(draftKey, jsonEncode(drafts));
    } catch (_) {}
  }

  final online = await ConnectivityService.instance.isOnline();

  if (!online) {
    try {
      final insertedId = await LaporanService.saveOffline(
        payload: payload,
        jenisLaporan: jenisLaporan,
      );
      await syncToLocalMonitoringStorage('local_$insertedId');

      await onReportSaved();

      if (!parentContext.mounted) return;
      ScaffoldMessenger.of(parentContext).showSnackBar(
        const SnackBar(
          content: Text(
            'Laporan disimpan secara offline. '
            'Akan otomatis dikirim saat ada koneksi.',
          ),
        ),
      );

      if (context.mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!parentContext.mounted) return;
      ScaffoldMessenger.of(parentContext).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan offline: $e')),
      );
    }
    return;
  }

  try {
    final existingId = existing?['id'] != null
        ? int.tryParse(existing!['id'].toString())
        : null;

    final response = await LaporanService.submitReport(
      token: token,
      payload: payload,
      existingId: existingId,
    );

    if (!parentContext.mounted) return;

    if (response.statusCode == 200 || response.statusCode == 201) {
      final body = jsonDecode(response.body);
      final reportId = body['data']?['id'] != null
          ? int.tryParse(body['data']['id'].toString())
          : existingId;

      if (reportId != null && photoBytes != null) {
        try {
          await LaporanService.uploadReportPhoto(
            token: token,
            reportId: reportId,
            photoBytes: photoBytes,
            filename:
                photoFilename ??
                'bukti_laporan_${DateTime.now().millisecondsSinceEpoch}.jpg',
            latitude: double.tryParse(latCtrl.text.trim()),
            longitude: double.tryParse(lngCtrl.text.trim()),
          );
        } catch (_) {}
      }

      await syncToLocalMonitoringStorage(
        (reportId ?? DateTime.now().millisecondsSinceEpoch).toString(),
      );
      await onReportSaved();

      if (!parentContext.mounted) return;
      ScaffoldMessenger.of(parentContext).showSnackBar(
        SnackBar(
          content: Text(
            apiStatus == 'draft'
                ? 'Draft berhasil disimpan ke database.'
                : (photoBytes != null
                      ? 'Laporan dan foto bukti berhasil dikirim.'
                      : 'Laporan berhasil dikirim ke database.'),
          ),
        ),
      );

      if (closeOnSuccess && context.mounted) {
        Navigator.pop(context);
      }
    } else {
      final insertedId = await LaporanService.saveOffline(
        payload: payload,
        jenisLaporan: jenisLaporan,
      );
      await syncToLocalMonitoringStorage('local_$insertedId');
      await onReportSaved();

      if (!parentContext.mounted) return;
      ScaffoldMessenger.of(parentContext).showSnackBar(
        SnackBar(
          content: Text(
            status == 'Draft'
                ? 'Draft laporan berhasil disimpan.'
                : 'Laporan berhasil disimpan dan siap diunduh / dipantau Admin.',
          ),
        ),
      );
      if (closeOnSuccess && context.mounted) {
        Navigator.pop(context);
      }
    }
  } catch (e) {
    try {
      final insertedId = await LaporanService.saveOffline(
        payload: payload,
        jenisLaporan: jenisLaporan,
      );
      await syncToLocalMonitoringStorage('local_$insertedId');
      await onReportSaved();
      if (parentContext.mounted) {
        ScaffoldMessenger.of(parentContext).showSnackBar(
          const SnackBar(
            content: Text(
              'Laporan disimpan di perangkat dan siap diunduh.',
            ),
          ),
        );
      }
      if (closeOnSuccess && context.mounted) {
        Navigator.pop(context);
      }
    } catch (_) {
      if (!parentContext.mounted) return;
      ScaffoldMessenger.of(parentContext).showSnackBar(
        SnackBar(content: Text('Gagal mengirim laporan: $e')),
      );
    }
  }
}

// ===========================================================================
// KOMPONEN UI PENDUKUNG FORMULIR (RAPI, LEGA & RESPONSIF)
// ===========================================================================

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(5),
        ),
      ),
    );
  }
}

class _SectionContainerCard extends StatelessWidget {
  final String stepNumber;
  final String title;
  final String subtitle;
  final Color cardBg;
  final Color borderCol;
  final Color primaryGreen;
  final Color textPrimary;
  final Color textSecondary;
  final Widget child;

  const _SectionContainerCard({
    required this.stepNumber,
    required this.title,
    required this.subtitle,
    required this.cardBg,
    required this.borderCol,
    required this.primaryGreen,
    required this.textPrimary,
    required this.textSecondary,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: primaryGreen.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  stepNumber,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: primaryGreen,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

/// Input field dengan label di atas kotak input sehingga tidak bertumpuk.
class _SpaciousLabeledField extends StatelessWidget {
  const _SpaciousLabeledField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
    this.onChanged,
    this.suffixWidget,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final Widget? suffixWidget;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark ? const Color(0xFF18221B) : const Color(0xFFF7FAF7);
    final borderCol = isDark
        ? const Color(0xFF2E3D34)
        : const Color(0xFFDCE6DC);
    final iconCol = isDark
        ? const Color(0xFF81C784)
        : LaporanColors.textFieldIcon;
    final primaryColor = isDark
        ? const Color(0xFF81C784)
        : const Color(0xFF245C3A);
    final labelColor = isDark ? Colors.white : const Color(0xFF24352A);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: labelColor,
                ),
              ),
            ),
            if (suffixWidget != null) suffixWidget!,
          ],
        ),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          maxLines: maxLines,
          onChanged: onChanged,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white38 : Colors.grey.shade500,
            ),
            prefixIcon: maxLines == 1
                ? Icon(icon, color: iconCol, size: 20)
                : null,
            filled: true,
            fillColor: fill,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(color: borderCol),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(color: borderCol),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(
                color: primaryColor,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DateSelectorField extends StatelessWidget {
  final String label;
  final String valueText;
  final VoidCallback onTap;

  const _DateSelectorField({
    required this.label,
    required this.valueText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark ? const Color(0xFF18221B) : const Color(0xFFF7FAF7);
    final borderCol = isDark
        ? const Color(0xFF2E3D34)
        : const Color(0xFFDCE6DC);
    final iconCol = isDark
        ? const Color(0xFF81C784)
        : LaporanColors.textFieldIcon;
    final labelColor = isDark ? Colors.white : const Color(0xFF24352A);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: labelColor,
          ),
        ),
        const SizedBox(height: 7),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: borderCol),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 19, color: iconCol),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    valueText,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: labelColor,
                    ),
                  ),
                ),
                Icon(Icons.edit_calendar_rounded, size: 18, color: iconCol),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StepTabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _StepTabButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeBg = isDark ? const Color(0xFF245C3A) : Colors.white;
    final activeFg = isDark ? Colors.white : const Color(0xFF245C3A);
    final inactiveFg = isDark ? Colors.white70 : const Color(0xFF6E7A72);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? activeFg : inactiveFg,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? activeFg : inactiveFg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeOption extends StatelessWidget {
  const _TypeOption({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark
        ? const Color(0xFF26352B)
        : LaporanColors.templateBackground;
    final cardBorder = isDark
        ? const Color(0xFF2E3D34)
        : LaporanColors.borderDetail;
    final primaryColor = isDark
        ? const Color(0xFF81C784)
        : LaporanColors.primary;
    final titleColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white70 : Colors.grey.shade600;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: primaryColor, size: 23),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                      color: titleColor,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: subColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 15,
              color: isDark ? Colors.white38 : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoButton extends StatelessWidget {
  final VoidCallback onTap;
  const _PhotoButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark ? const Color(0xFF18221B) : const Color(0xFFF7FAF7);
    final borderCol = isDark
        ? const Color(0xFF2E3D34)
        : const Color(0xFFDCE6DC);
    final primaryColor = isDark
        ? const Color(0xFF81C784)
        : LaporanColors.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 15,
        ),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderCol),
        ),
        child: Row(
          children: [
            Icon(
              Icons.camera_alt_outlined,
              color: primaryColor,
              size: 25,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lampirkan Foto Dokumentasi',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Ambil foto langsung atau pilih dari galeri perangkat',
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 15,
              color: isDark ? Colors.white38 : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: isDark
                ? const Color(0xFF81C784)
                : LaporanColors.textFieldIcon,
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 68,
            child: Text(
              title,
              style: TextStyle(
                color: isDark ? Colors.white60 : Colors.grey,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}