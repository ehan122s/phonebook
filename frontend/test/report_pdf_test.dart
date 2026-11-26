import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:frontend/widgets/laporan/report_templates.dart';

void main() {
  group('ReportDocumentExporter PDF Generation Tests', () {
    test('generatePdfBytes succeeds with attached photo and non-ASCII characters (no latin1 crash)', () {
      final image = img.Image(width: 200, height: 150);
      img.fill(image, color: img.ColorRgba8(36, 92, 58, 255));
      final jpgBytes = Uint8List.fromList(img.encodeJpg(image));

      final photo = ReportProcessedPhoto(
        jpegBytes: jpgBytes,
        width: 200,
        height: 150,
      );

      final pdfBytes = ReportDocumentExporter.generatePdfBytes(
        {
          'judul': 'Laporan Penyuluhan • “Garut” — KTH Mekar 🌱',
          'jenis': 'Laporan Penyuluhan',
          'pelapor': 'r4yy73',
          'tanggal': '26 November 2026',
          'lokasi': 'Pakuwon, Garut, Jawa Barat',
          'status': 'Selesai',
          'latitude': '-7.214475',
          'longitude': '107.901318',
          'isi': 'Kegiatan • Rincian:\n1. Kelompok Sasaran : KTH\n2. Hasil — Lancar ✅',
        },
        photo: photo,
        waktuUnduh: '26 November 2026, Pukul 14:56:26 WIB',
      );

      expect(pdfBytes.isNotEmpty, isTrue);
      // PDF header %PDF-1.4
      expect(String.fromCharCodes(pdfBytes.sublist(0, 8)), '%PDF-1.4');
    });
  });
}
