import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/laporan_constants.dart';
import '../../services/laporan_service.dart';

// ---------------------------------------------------------------------------
// Report‑type selection bottom sheet
// ---------------------------------------------------------------------------

/// Shows a bottom sheet that lets the user pick a report type, then opens
/// the report form for the selected type.
void showReportTypeDialog(
  BuildContext context, {
  required void Function(String jenisLaporan, {Map<String, dynamic>? existing})
      onSelectType,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
    ),
    builder: (ctx) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _DragHandle(),
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
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 18),
            _TypeOption(
              icon: Icons.groups_outlined,
              title: 'Laporan Penyuluhan',
              onTap: () {
                Navigator.pop(ctx);
                onSelectType('Laporan Penyuluhan');
              },
            ),
            _TypeOption(
              icon: Icons.forest_outlined,
              title: 'Laporan Monitoring',
              onTap: () {
                Navigator.pop(ctx);
                onSelectType('Laporan Monitoring');
              },
            ),
            _TypeOption(
              icon: Icons.event_note_outlined,
              title: 'Laporan Kegiatan',
              onTap: () {
                Navigator.pop(ctx);
                onSelectType('Laporan Kegiatan');
              },
            ),
            _TypeOption(
              icon: Icons.warning_amber_rounded,
              title: 'Laporan Kejadian',
              onTap: () {
                Navigator.pop(ctx);
                onSelectType('Laporan Kejadian');
              },
            ),
          ],
        ),
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Report form bottom sheet
// ---------------------------------------------------------------------------

/// Shows the report creation/editing form as a scrollable bottom sheet.
void showReportForm(
  BuildContext context, {
  required String jenisLaporan,
  Map<String, dynamic>? existing,
  required Future<void> Function() onReportSaved,
}) {
  final judulCtrl = TextEditingController(
    text: existing?['judul']?.toString() ?? '',
  );
  final isiCtrl = TextEditingController(
    text: existing?['isi']?.toString() ?? '',
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

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          18,
          20,
          MediaQuery.of(ctx).viewInsets.bottom + 25,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _DragHandle(),
              const SizedBox(height: 20),

              // Title
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
                style: TextStyle(color: Colors.grey),
              ),

              const SizedBox(height: 20),

              // Fields
              _FormField(
                controller: judulCtrl,
                label: 'Judul Laporan',
                hint: 'Contoh: Penyuluhan Kehutanan',
                icon: Icons.title_rounded,
              ),
              const SizedBox(height: 13),
              _FormField(
                controller: isiCtrl,
                label: 'Isi / Keterangan Laporan',
                hint: 'Tuliskan hasil kegiatan...',
                icon: Icons.notes_rounded,
                maxLines: 5,
              ),
              const SizedBox(height: 13),
              _FormField(
                controller: lokasiCtrl,
                label: 'Lokasi Kegiatan',
                hint: 'Contoh: Kawasan Hutan Garut',
                icon: Icons.location_on_outlined,
              ),
              const SizedBox(height: 13),

              // Lat / Lng
              Row(
                children: [
                  Expanded(
                    child: _FormField(
                      controller: latCtrl,
                      label: 'Latitude',
                      hint: '-7.2279',
                      icon: Icons.my_location_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _FormField(
                      controller: lngCtrl,
                      label: 'Longitude',
                      hint: '107.9087',
                      icon: Icons.explore_outlined,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 15),
              const _PhotoButton(),
              const SizedBox(height: 22),

              // Action buttons
              Row(
                children: [
                  // Save draft
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await _handleSubmit(
                          context: ctx,
                          parentContext: context,
                          jenisLaporan: jenisLaporan,
                          existing: existing,
                          judulCtrl: judulCtrl,
                          isiCtrl: isiCtrl,
                          lokasiCtrl: lokasiCtrl,
                          latCtrl: latCtrl,
                          lngCtrl: lngCtrl,
                          status: 'Draft',
                          onReportSaved: onReportSaved,
                        );
                      },
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Simpan Sementara'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: LaporanColors.primary,
                        side: const BorderSide(
                          color: LaporanColors.primary,
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 15,
                          horizontal: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Submit
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        if (judulCtrl.text.trim().isEmpty ||
                            isiCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Isi judul dan isi laporan sebelum '
                                'menyelesaikan laporan.',
                              ),
                            ),
                          );
                          return;
                        }
                        await _handleSubmit(
                          context: ctx,
                          parentContext: context,
                          jenisLaporan: jenisLaporan,
                          existing: existing,
                          judulCtrl: judulCtrl,
                          isiCtrl: isiCtrl,
                          lokasiCtrl: lokasiCtrl,
                          latCtrl: latCtrl,
                          lngCtrl: lngCtrl,
                          status: 'Selesai',
                          onReportSaved: onReportSaved,
                          closeOnSuccess: true,
                        );
                      },
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Selesaikan'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: LaporanColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 15,
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
            ],
          ),
        ),
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Report detail bottom sheet
// ---------------------------------------------------------------------------

/// Shows the full detail of a report in a scrollable bottom sheet.
void showReportDetail(
  BuildContext context, {
  required Map<String, dynamic> laporan,
  required void Function(String jenisLaporan, {Map<String, dynamic>? existing})
      onEdit,
  required void Function(Map<String, dynamic> laporan) onDownload,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
    ),
    builder: (ctx) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _DragHandle(),
              const SizedBox(height: 20),

              // Title
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
                  color: LaporanColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 20),

              // Meta rows
              _DetailRow(
                icon: Icons.calendar_today_outlined,
                title: 'Tanggal',
                value: laporan['tanggal'],
              ),
              _DetailRow(
                icon: Icons.location_on_outlined,
                title: 'Lokasi',
                value: laporan['lokasi'],
              ),
              _DetailRow(
                icon: Icons.info_outline,
                title: 'Status',
                value: laporan['status']?.toString() ?? 'Draft',
              ),

              // Content
              const SizedBox(height: 8),
              const Text(
                'Isi Laporan',
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
                  color: LaporanColors.templateBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: LaporanColors.borderDetail),
                ),
                child: Text(
                  (laporan['isi']?.toString().isNotEmpty ?? false)
                      ? laporan['isi'].toString()
                      : 'Isi laporan belum dilengkapi.',
                  style: const TextStyle(height: 1.5),
                ),
              ),

              const SizedBox(height: 14),

              // Coordinates
              _DetailRow(
                icon: Icons.my_location_outlined,
                title: 'Latitude',
                value:
                    (laporan['latitude']?.toString().isNotEmpty ?? false)
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

              // Action buttons
              if (laporan['status'] == 'Draft')
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      onEdit(
                        laporan['jenis'],
                        existing: laporan,
                      );
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
                      Navigator.pop(ctx);
                      onDownload(laporan);
                    },
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Unduh Laporan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LaporanColors.primary,
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
  required String status,
  required Future<void> Function() onReportSaved,
  bool closeOnSuccess = false,
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
  final activityDate =
      (existingDate != null && existingDate.isNotEmpty)
          ? existingDate
          : '${now.year}-${now.month.toString().padLeft(2, '0')}'
              '-${now.day.toString().padLeft(2, '0')}';

  final apiStatus = status == 'Draft' ? 'draft' : 'terkirim';

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
      await onReportSaved();

      if (!parentContext.mounted) return;
      ScaffoldMessenger.of(parentContext).showSnackBar(
        SnackBar(
          content: Text(
            apiStatus == 'draft'
                ? 'Draft berhasil disimpan ke database.'
                : 'Laporan berhasil dikirim ke database.',
          ),
        ),
      );

      if (closeOnSuccess && context.mounted) {
        Navigator.pop(context);
      }
    } else {
      String message =
          'Gagal menyimpan laporan (${response.statusCode}).';

      try {
        final body = jsonDecode(response.body);
        message = body['message']?.toString() ?? message;

        if (body['errors'] is Map) {
          final errors = body['errors'] as Map;
          message +=
              '\n${errors.values.expand((e) => e is List ? e : [e]).join('\n')}';
        }
      } catch (_) {}

      ScaffoldMessenger.of(parentContext).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  } catch (e) {
    if (!parentContext.mounted) return;
    ScaffoldMessenger.of(parentContext).showSnackBar(
      SnackBar(content: Text('Gagal mengirim laporan: $e')),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared private widgets used only within dialogs
// ---------------------------------------------------------------------------

/// Drag indicator shown at the top of bottom sheets.
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

/// Option tile inside the report‑type selection sheet.
class _TypeOption extends StatelessWidget {
  const _TypeOption({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: LaporanColors.templateBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: LaporanColors.borderDetail),
        ),
        child: Row(
          children: [
            Icon(icon, color: LaporanColors.primary, size: 25),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600),
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
}

/// Reusable text field used in the report form.
class _FormField extends StatelessWidget {
  const _FormField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
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
          child: Icon(icon, color: LaporanColors.textFieldIcon),
        ),
        filled: true,
        fillColor: LaporanColors.fieldFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: LaporanColors.borderField),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: LaporanColors.borderField),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(
            color: LaporanColors.primary,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

/// Photo capture / pick button shown in the report form.
class _PhotoButton extends StatelessWidget {
  const _PhotoButton();

  @override
  Widget build(BuildContext context) {
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
          color: LaporanColors.fieldFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: LaporanColors.borderField),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.camera_alt_outlined,
              color: LaporanColors.primary,
              size: 25,
            ),
            SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Foto Lokasi / Kegiatan',
                    style: TextStyle(fontWeight: FontWeight.bold),
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
              color: LaporanColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}

/// A key–value row used in the detail bottom sheet.
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: LaporanColors.textFieldIcon),
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
}
