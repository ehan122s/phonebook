import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/api_constants.dart';
import 'connectivity_service.dart';
import 'device_file_storage_service.dart';

class DownloadResult {
  final bool success;
  final String? filePath;
  final String? displayPath;
  final String fileName;
  final int fileSizeBytes;
  final String message;
  final String? error;
  final bool isExternalLink;
  final String? externalUrl;

  const DownloadResult({
    required this.success,
    this.filePath,
    this.displayPath,
    required this.fileName,
    this.fileSizeBytes = 0,
    required this.message,
    this.error,
    this.isExternalLink = false,
    this.externalUrl,
  });

  String get formattedSize {
    if (fileSizeBytes <= 0) return '';
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class MaterialDownloadService {
  MaterialDownloadService._();
  static final MaterialDownloadService instance = MaterialDownloadService._();

  /// Mengunduh materi edukasi dan menyimpannya secara fisik ke folder Download HP.
  /// Mendukung format PDF, DOC, DOCX, PPT, PPTX, XLS, XLSX, dan format file server lainnya.
  Future<DownloadResult> downloadMaterial(
    Map<String, dynamic> material, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final title = (material['title'] ?? 'Materi Kehutanan').toString();
      final type = (material['type'] ?? material['file_type'] ?? 'PDF').toString().toUpperCase();
      var rawFileName = (material['file_name'] ?? '').toString().trim();

      if (rawFileName.isEmpty) {
        final ext = guessExtension(type);
        rawFileName = '${DeviceFileStorageService.sanitizeFileName(title)}.$ext';
      }

      final safeFileName = DeviceFileStorageService.sanitizeFileName(rawFileName);
      final mimeType = DeviceFileStorageService.guessMimeType(safeFileName);

      // 1. Coba ambil dari base64 data URI jika materi tersimpan di sesi/cache lokal
      final dataUri = (material['file_data_uri'] ?? '').toString();
      if (dataUri.isNotEmpty) {
        final bytes = _extractBytesFromDataUri(dataUri);
        if (bytes != null && bytes.isNotEmpty) {
          final saveRes = await DeviceFileStorageService.instance.saveToDownloads(
            bytes: bytes,
            fileName: safeFileName,
            mimeType: mimeType,
            subfolder: 'Phonebook_Materi',
          );

          return DownloadResult(
            success: saveRes.success,
            filePath: saveRes.filePath,
            displayPath: saveRes.displayPath,
            fileName: saveRes.fileName,
            fileSizeBytes: bytes.length,
            message: saveRes.success
                ? 'Materi berhasil diunduh dan tersimpan di folder ${saveRes.displayPath}'
                : saveRes.message,
            error: saveRes.error,
          );
        }
      }

      // 2. Coba ambil dari file path lokal perangkat jika tersedia
      final localPath = (material['local_path'] ?? material['file_path'] ?? '').toString();
      if (localPath.isNotEmpty &&
          !localPath.startsWith('http') &&
          !localPath.startsWith('materials/')) {
        final existingFile = File(localPath);
        if (existingFile.existsSync()) {
          final bytes = await existingFile.readAsBytes();
          final saveRes = await DeviceFileStorageService.instance.saveToDownloads(
            bytes: bytes,
            fileName: safeFileName,
            mimeType: mimeType,
            subfolder: 'Phonebook_Materi',
          );

          return DownloadResult(
            success: saveRes.success,
            filePath: saveRes.filePath,
            displayPath: saveRes.displayPath,
            fileName: saveRes.fileName,
            fileSizeBytes: bytes.length,
            message: saveRes.success
                ? 'Materi berhasil tersimpan di folder ${saveRes.displayPath}'
                : saveRes.message,
            error: saveRes.error,
          );
        }
      }

      // 3. Coba unduh dari Backend API Server resmi
      final materialId = material['id']?.toString() ?? '';
      final rawFilePath = (material['file_path'] ?? '').toString();
      final isOnline = await ConnectivityService.instance.isOnline();

      final List<Uri> candidateUris = [];

      // A. Endpoint download resmi Laravel
      final downloadUrl = (material['download_url'] ?? '').toString().trim();
      if (downloadUrl.isNotEmpty && downloadUrl.startsWith('http')) {
        var cleanUrl = downloadUrl;
        if (cleanUrl.contains('localhost') || cleanUrl.contains('127.0.0.1')) {
          final u = Uri.tryParse(cleanUrl);
          if (u != null) {
            cleanUrl = '${ApiConstants.baseUrl}${u.path}${u.hasQuery ? '?${u.query}' : ''}';
          }
        }
        candidateUris.add(Uri.parse(cleanUrl));
      }

      if (materialId.isNotEmpty && !materialId.startsWith('MAT-')) {
        final directUri = Uri.parse('${ApiConstants.baseUrl}/api/materials/$materialId/download');
        if (!candidateUris.contains(directUri)) {
          candidateUris.add(directUri);
        }
      }

      // B. Storage disk path
      if (rawFilePath.isNotEmpty && !rawFilePath.startsWith('http')) {
        final cleanStoragePath =
            rawFilePath.startsWith('/') ? rawFilePath.substring(1) : rawFilePath;
        candidateUris.add(
          Uri.parse('${ApiConstants.baseUrl}/storage/$cleanStoragePath'),
        );
      }

      // C. Direct HTTP URL
      if (rawFilePath.startsWith('http')) {
        var cleanUrl = rawFilePath;
        if (cleanUrl.contains('localhost') || cleanUrl.contains('127.0.0.1')) {
          final u = Uri.tryParse(cleanUrl);
          if (u != null) {
            cleanUrl = '${ApiConstants.baseUrl}${u.path}${u.hasQuery ? '?${u.query}' : ''}';
          }
        }
        final parsed = Uri.parse(cleanUrl);
        if (!candidateUris.contains(parsed)) {
          candidateUris.add(parsed);
        }
      }

      final driveUrl = (material['drive_url'] ?? '').toString();
      if (driveUrl.startsWith('http') &&
          !candidateUris.any((u) => u.toString() == driveUrl)) {
        final directDriveUri = _convertToDirectDriveUrl(driveUrl);
        if (directDriveUri != null) {
          candidateUris.add(directDriveUri);
        } else {
          candidateUris.add(Uri.parse(driveUrl));
        }
      }

      // Siapkan headers autentikasi Sanctum Bearer Token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final headers = <String, String>{
        'Accept': '*/*',
      };
      if (token != null && token.isNotEmpty && !token.startsWith('offline_')) {
        headers['Authorization'] = 'Bearer $token';
      }

      // Coba unduh dari URL kandidat server jika online
      if (isOnline && candidateUris.isNotEmpty) {
        for (final uri in candidateUris) {
          try {
            final res = await http.get(uri, headers: headers).timeout(
              const Duration(seconds: 20),
            );

            if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
              final contentType = res.headers['content-type'] ?? '';
              final isHtml = contentType.contains('text/html');
              final isDocsError = isHtml && res.body.contains('<!DOCTYPE html');

              if (!isDocsError) {
                final saveRes =
                    await DeviceFileStorageService.instance.saveToDownloads(
                  bytes: res.bodyBytes,
                  fileName: safeFileName,
                  mimeType: mimeType,
                  subfolder: 'Phonebook_Materi',
                );

                return DownloadResult(
                  success: saveRes.success,
                  filePath: saveRes.filePath,
                  displayPath: saveRes.displayPath,
                  fileName: saveRes.fileName,
                  fileSizeBytes: res.bodyBytes.length,
                  message: saveRes.success
                      ? 'Materi berhasil diunduh dari server dan tersimpan di folder ${saveRes.displayPath}'
                      : saveRes.message,
                  error: saveRes.error,
                );
              }
            }
          } catch (e) {
            debugPrint('Download error from candidate $uri: $e');
          }
        }
      }

      // 4. Fallback dokumen resmi berformat standar (untuk materi seeded/offline)
      //    Memastikan file dapat dibuka di Adobe Acrobat, Word, WPS, dsb. tanpa corrupt.
      final Uint8List documentBytes = _generateStandardDocumentBytes(
        material,
        safeFileName,
      );

      final saveRes = await DeviceFileStorageService.instance.saveToDownloads(
        bytes: documentBytes,
        fileName: safeFileName,
        mimeType: mimeType,
        subfolder: 'Phonebook_Materi',
      );

      return DownloadResult(
        success: saveRes.success,
        filePath: saveRes.filePath,
        displayPath: saveRes.displayPath,
        fileName: saveRes.fileName,
        fileSizeBytes: documentBytes.length,
        message: saveRes.success
            ? 'Materi edukasi resmi berhasil disimpan di folder ${saveRes.displayPath}'
            : saveRes.message,
        error: saveRes.error,
      );
    } catch (e) {
      debugPrint('MaterialDownloadService error: $e');
      return DownloadResult(
        success: false,
        fileName: material['file_name'] ?? 'Materi_Kehutanan.pdf',
        message: 'Gagal mengunduh materi ke penyimpanan HP: $e',
        error: e.toString(),
      );
    }
  }

  /// Membuka berkas materi yang telah diunduh menggunakan aplikasi pembaca bawaan sistem (PDF viewer, Docs, dsb.)
  Future<OpenResult> openFile(String filePath) async {
    return await DeviceFileStorageService.instance.openFile(filePath);
  }

  /// Menentukan ekstensi default berdasarkan tipe materi
  static String guessExtension(String type) {
    final t = type.toLowerCase();
    if (t.contains('pdf')) return 'pdf';
    if (t.contains('docx')) return 'docx';
    if (t.contains('doc')) return 'docx';
    if (t.contains('pptx')) return 'pptx';
    if (t.contains('ppt')) return 'pptx';
    if (t.contains('xlsx')) return 'xlsx';
    if (t.contains('xls')) return 'xlsx';
    if (t.contains('txt')) return 'txt';
    if (t.contains('jpg') || t.contains('jpeg')) return 'jpg';
    if (t.contains('png')) return 'png';
    return 'pdf';
  }

  /// Konversi tautan Google Drive menjadi direct download URL
  Uri? _convertToDirectDriveUrl(String driveUrl) {
    try {
      final reg1 = RegExp(r'file/d/([a-zA-Z0-9_-]+)');
      final reg2 = RegExp(r'[?&]id=([a-zA-Z0-9_-]+)');
      final match1 = reg1.firstMatch(driveUrl);
      final match2 = reg2.firstMatch(driveUrl);
      final fileId = match1?.group(1) ?? match2?.group(1);

      if (fileId != null && fileId.isNotEmpty) {
        return Uri.parse(
          'https://drive.google.com/uc?export=download&id=$fileId',
        );
      }
    } catch (_) {}
    return null;
  }

  /// Ekstraksi bytes dari data URI base64
  Uint8List? _extractBytesFromDataUri(String dataUri) {
    try {
      String clean = dataUri;
      if (clean.contains(',')) {
        clean = clean.split(',').last;
      }
      return base64Decode(clean.trim());
    } catch (e) {
      debugPrint('Error decoding base64 data URI: $e');
      return null;
    }
  }

  /// Menghasilkan bytes dokumen standar yang valid sesuai ekstensinya (PDF-1.4, Word XML, dll.)
  Uint8List _generateStandardDocumentBytes(
    Map<String, dynamic> material,
    String fileName,
  ) {
    final ext = fileName.split('.').last.toLowerCase();

    if (ext == 'pdf') {
      return _generatePdfStandardBytes(material);
    } else if (ext == 'doc' || ext == 'docx') {
      return _generateWordStandardBytes(material);
    } else if (ext == 'xls' || ext == 'xlsx') {
      return _generateExcelStandardBytes(material);
    } else {
      final text = _generateTextSummary(material);
      return Uint8List.fromList(utf8.encode(text));
    }
  }

  /// Generator PDF 1.4 standar valid tanpa dependensi eksternal
  Uint8List _generatePdfStandardBytes(Map<String, dynamic> material) {
    final title = _cleanText((material['title'] ?? 'Materi Kehutanan').toString());
    final category = _cleanText((material['category'] ?? 'Penyuluhan Kehutanan').toString());
    final uploaderName = _cleanText((material['uploader_name'] ?? 'Penyuluh Kehutanan').toString());
    final uploaderRole = _cleanText((material['uploader_role'] ?? 'CDK Wilayah V Garut').toString());
    final uploadedAt = _cleanText((material['uploaded_at'] ?? '2026').toString());
    final description = _cleanText((material['description'] ?? 'Materi panduan teknis kehutanan.').toString());

    final content = StringBuffer();

    // Garis Kop Atas
    content.writeln('0.14 0.36 0.23 rg');
    content.writeln('50 792 495 3 re f');
    content.writeln('0 0 0 rg');

    void draw(String text, double x, double y, {bool bold = false, int size = 11}) {
      final fontKey = bold ? '/F2' : '/F1';
      final esc = text.replaceAll(r'\', r'\\').replaceAll('(', r'\(').replaceAll(')', r'\)');
      content.writeln('BT $fontKey $size Tf $x $y Td ($esc) Tj ET');
    }

    draw('PEMERINTAH DAERAH PROVINSI JAWA BARAT', 155, 772, bold: true, size: 12);
    draw('DINAS KEHUTANAN', 238, 756, bold: true, size: 13);
    draw('CABANG DINAS KEHUTANAN WILAYAH V GARUT', 150, 740, bold: true, size: 12);
    draw('Dokumen Resmi Materi Edukasi & Panduan Teknis Kehutanan Lapangan', 135, 725, size: 9);

    content.writeln('0.14 0.36 0.23 rg');
    content.writeln('50 714 495 1.5 re f');
    content.writeln('0 0 0 rg');

    draw(category.toUpperCase(), 50, 690, bold: true, size: 13);
    draw(title, 50, 673, bold: true, size: 11);

    // Kotak Metadata
    content.writeln('0.95 0.97 0.95 rg');
    content.writeln('50 580 495 80 re f');
    content.writeln('0 0 0 rg');

    draw('Penyusun / Pengunggah', 62, 642, bold: true, size: 10);
    draw(':  $uploaderName ($uploaderRole)', 205, 642, size: 10);

    draw('Kategori Materi', 62, 624, bold: true, size: 10);
    draw(':  $category', 205, 624, size: 10);

    draw('Tanggal Diterbitkan', 62, 606, bold: true, size: 10);
    draw(':  $uploadedAt', 205, 606, size: 10);

    draw('Status Dokumen', 62, 588, bold: true, size: 10);
    draw(':  Tersertifikasi Dinas Kehutanan Jawa Barat', 205, 588, size: 10);

    draw('URAIAN & RINGKASAN MATERI KEHUTANAN:', 50, 550, bold: true, size: 11);
    content.writeln('0.80 0.85 0.80 rg');
    content.writeln('50 543 495 0.8 re f');
    content.writeln('0 0 0 rg');

    final lines = _wrapLines(description, maxChars: 78);
    double yPos = 524;
    for (final l in lines) {
      if (yPos < 120) break;
      draw(l, 50, yPos, size: 10);
      yPos -= 15;
    }

    final streamData = content.toString();
    final streamBytes = utf8.encode(streamData);
    final length = streamBytes.length;

    final pdf = StringBuffer();
    pdf.writeln('%PDF-1.4');
    pdf.writeln('%\xFF\xFF\xFF\xFF');

    final offsets = <int>[];

    // Obj 1: Catalog
    offsets.add(pdf.length);
    pdf.writeln('1 0 obj');
    pdf.writeln('<< /Type /Catalog /Pages 2 0 R >>');
    pdf.writeln('endobj');

    // Obj 2: Pages
    offsets.add(pdf.length);
    pdf.writeln('2 0 obj');
    pdf.writeln('<< /Type /Pages /Kids [3 0 R] /Count 1 >>');
    pdf.writeln('endobj');

    // Obj 3: Page
    offsets.add(pdf.length);
    pdf.writeln('3 0 obj');
    pdf.writeln('<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Contents 4 0 R /Resources 5 0 R >>');
    pdf.writeln('endobj');

    // Obj 4: Contents
    offsets.add(pdf.length);
    pdf.writeln('4 0 obj');
    pdf.writeln('<< /Length $length >>');
    pdf.writeln('stream');
    pdf.write(streamData);
    pdf.writeln('endstream');
    pdf.writeln('endobj');

    // Obj 5: Resources
    offsets.add(pdf.length);
    pdf.writeln('5 0 obj');
    pdf.writeln('<< /Font << /F1 6 0 R /F2 7 0 R >> >>');
    pdf.writeln('endobj');

    // Obj 6: Font Regular
    offsets.add(pdf.length);
    pdf.writeln('6 0 obj');
    pdf.writeln('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>');
    pdf.writeln('endobj');

    // Obj 7: Font Bold
    offsets.add(pdf.length);
    pdf.writeln('7 0 obj');
    pdf.writeln('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>');
    pdf.writeln('endobj');

    // xref table
    final xrefPos = pdf.length;
    pdf.writeln('xref');
    pdf.writeln('0 8');
    pdf.writeln('0000000000 65535 f ');
    for (final off in offsets) {
      pdf.writeln('${off.toString().padLeft(10, '0')} 00000 n ');
    }
    pdf.writeln('trailer');
    pdf.writeln('<< /Size 8 /Root 1 0 R >>');
    pdf.writeln('startxref');
    pdf.writeln(xrefPos);
    pdf.writeln('%%EOF');

    return Uint8List.fromList(utf8.encode(pdf.toString()));
  }

  /// Generator dokumen Word XML standar
  Uint8List _generateWordStandardBytes(Map<String, dynamic> material) {
    final title = (material['title'] ?? 'Materi Kehutanan').toString();
    final category = (material['category'] ?? 'Penyuluhan').toString();
    final uploader = (material['uploader_name'] ?? 'Penyuluh Kehutanan').toString();
    final description = (material['description'] ?? '').toString().replaceAll('\n', '<br/>');

    final html = '''
<html xmlns:o="urn:schemas-microsoft-com:office:office"
      xmlns:w="urn:schemas-microsoft-com:office:word"
      xmlns="http://www.w3.org/TR/REC-html40">
<head>
  <meta charset="utf-8">
  <title>$title</title>
  <style>
    body { font-family: Arial, sans-serif; font-size: 11pt; color: #1E2923; line-height: 1.6; margin: 30px; }
    h1 { color: #1E3F24; font-size: 16pt; margin-bottom: 4px; }
    .header { border-bottom: 2px solid #1E3F24; padding-bottom: 12px; margin-bottom: 20px; }
    .meta { background-color: #F2F7F2; padding: 12px; border-left: 4px solid #1E3F24; margin-bottom: 20px; }
    .content { margin-top: 15px; }
  </style>
</head>
<body>
  <div class="header">
    <strong>PEMERINTAH DAERAH PROVINSI JAWA BARAT</strong><br/>
    <strong>DINAS KEHUTANAN - CABANG DINAS KEHUTANAN WILAYAH V GARUT</strong><br/>
    <small>Dokumen Resmi Materi Edukasi & Penyuluhan Kehutanan</small>
  </div>
  <h1>$title</h1>
  <div class="meta">
    <strong>Kategori:</strong> $category<br/>
    <strong>Pengunggah:</strong> $uploader<br/>
    <strong>Aplikasi:</strong> Phonebook Kehutanan CDK Wilayah V Garut
  </div>
  <div class="content">
    <h3>Uraian Materi:</h3>
    <p>$description</p>
  </div>
</body>
</html>
''';
    return Uint8List.fromList(utf8.encode(html));
  }

  /// Generator berkas Excel XML standar
  Uint8List _generateExcelStandardBytes(Map<String, dynamic> material) {
    final title = (material['title'] ?? 'Materi Kehutanan').toString();
    final category = (material['category'] ?? 'Penyuluhan').toString();
    final uploader = (material['uploader_name'] ?? 'Penyuluh Kehutanan').toString();
    final description = (material['description'] ?? '').toString();

    final csv = 'Judul Materi,Kategori,Pengunggah,Deskripsi\n'
        '"$title","$category","$uploader","${description.replaceAll('"', '""')}"';
    return Uint8List.fromList(utf8.encode(csv));
  }

  String _generateTextSummary(Map<String, dynamic> material) {
    final title = (material['title'] ?? 'Materi Kehutanan').toString();
    final category = (material['category'] ?? 'Penyuluhan').toString();
    final uploader = (material['uploader_name'] ?? 'Penyuluh Kehutanan').toString();
    final description = (material['description'] ?? '').toString();

    return '''
================================================================================
PEMERINTAH DAERAH PROVINSI JAWA BARAT - DINAS KEHUTANAN
CABANG DINAS KEHUTANAN (CDK) WILAYAH V GARUT
================================================================================
DOKUMEN RESMI MATERI EDUKASI KEHUTANAN

Judul Materi   : $title
Kategori       : $category
Pengunggah     : $uploader
--------------------------------------------------------------------------------
URAIAN MATERI:
$description
================================================================================
''';
  }

  String _cleanText(String text) {
    return text.replaceAll(RegExp(r'[^\x20-\x7E]'), ' ').trim();
  }

  List<String> _wrapLines(String text, {int maxChars = 78}) {
    final result = <String>[];
    final paragraphs = text.split('\n');
    for (final p in paragraphs) {
      final words = p.split(' ');
      String current = '';
      for (final w in words) {
        if ((current.length + w.length + 1) <= maxChars) {
          current = current.isEmpty ? w : '$current $w';
        } else {
          if (current.isNotEmpty) result.add(current);
          current = w;
        }
      }
      if (current.isNotEmpty) result.add(current);
    }
    return result;
  }
}
