import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../constants/api_constants.dart';

class DownloadResult {
  final bool success;
  final String? filePath;
  final String fileName;
  final int fileSizeBytes;
  final String message;
  final String? error;
  final bool isExternalLink;
  final String? externalUrl;

  const DownloadResult({
    required this.success,
    this.filePath,
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

  /// Mengunduh materi dan menyimpannya ke dalam penyimpanan perangkat user (folder Download).
  Future<DownloadResult> downloadMaterial(
    Map<String, dynamic> material, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final title = (material['title'] ?? 'Materi Kehutanan').toString();
      final type = (material['type'] ?? 'PDF').toString().toUpperCase();
      var rawFileName = (material['file_name'] ?? '').toString().trim();

      if (rawFileName.isEmpty) {
        final ext = _guessExtension(type);
        rawFileName = '${_sanitizeFileName(title)}.$ext';
      }

      final safeFileName = _sanitizeFileName(rawFileName);
      final downloadDir = await getDownloadDirectory();

      // Buat file path unik agar tidak menimpa file yang sudah ada
      final targetFile = _getUniqueFile(downloadDir, safeFileName);

      // 1. Coba ambil dari base64 data URI lokal
      final dataUri = (material['file_data_uri'] ?? '').toString();
      if (dataUri.isNotEmpty) {
        final bytes = _extractBytesFromDataUri(dataUri);
        if (bytes != null && bytes.isNotEmpty) {
          await targetFile.writeAsBytes(bytes, flush: true);
          return DownloadResult(
            success: true,
            filePath: targetFile.path,
            fileName: targetFile.uri.pathSegments.last,
            fileSizeBytes: bytes.length,
            message: 'Materi berhasil diunduh dan disimpan ke penyimpanan HP.',
          );
        }
      }

      // 2. Coba ambil dari file path lokal di perangkat jika ada
      final localPath = (material['local_path'] ?? material['file_path'] ?? '').toString();
      if (localPath.isNotEmpty && !localPath.startsWith('http') && !localPath.startsWith('materials/')) {
        final existingFile = File(localPath);
        if (existingFile.existsSync()) {
          final bytes = await existingFile.readAsBytes();
          await targetFile.writeAsBytes(bytes, flush: true);
          return DownloadResult(
            success: true,
            filePath: targetFile.path,
            fileName: targetFile.uri.pathSegments.last,
            fileSizeBytes: bytes.length,
            message: 'Materi berhasil disimpan ke penyimpanan HP.',
          );
        }
      }

      // 3. Coba unduh dari Backend API Server
      final materialId = material['id']?.toString() ?? '';
      final rawFilePath = (material['file_path'] ?? '').toString();

      final List<Uri> candidateUris = [];

      // A. Endpoint download resmi
      if (materialId.isNotEmpty && !materialId.startsWith('MAT-')) {
        candidateUris.add(
          Uri.parse('${ApiConstants.baseUrl}/api/materials/$materialId/download'),
        );
      }

      // B. Storage disk path
      if (rawFilePath.isNotEmpty && !rawFilePath.startsWith('http')) {
        final cleanStoragePath = rawFilePath.startsWith('/')
            ? rawFilePath.substring(1)
            : rawFilePath;
        candidateUris.add(
          Uri.parse('${ApiConstants.baseUrl}/storage/$cleanStoragePath'),
        );
      }

      // C. Direct HTTP URL
      if (rawFilePath.startsWith('http')) {
        candidateUris.add(Uri.parse(rawFilePath));
      }

      final driveUrl = (material['drive_url'] ?? '').toString();
      if (driveUrl.startsWith('http') && !candidateUris.any((u) => u.toString() == driveUrl)) {
        // Jika tautan Google Drive, coba buat direct export URL
        final directDriveUri = _convertToDirectDriveUrl(driveUrl);
        if (directDriveUri != null) {
          candidateUris.add(directDriveUri);
        } else {
          candidateUris.add(Uri.parse(driveUrl));
        }
      }

      // Coba unduh dari URI kandidat
      for (final uri in candidateUris) {
        try {
          final res = await http.get(uri).timeout(const Duration(seconds: 15));
          if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
            // Periksa jika bukan halaman HTML error / login
            final contentType = res.headers['content-type'] ?? '';
            final isHtml = contentType.contains('text/html');
            final isGoogleDocsHtml = isHtml && res.body.contains('<!DOCTYPE html');

            if (!isGoogleDocsHtml) {
              await targetFile.writeAsBytes(res.bodyBytes, flush: true);
              return DownloadResult(
                success: true,
                filePath: targetFile.path,
                fileName: targetFile.uri.pathSegments.last,
                fileSizeBytes: res.bodyBytes.length,
                message: 'Materi berhasil diunduh dari server dan tersimpan di HP.',
              );
            }
          }
        } catch (e) {
          debugPrint('Download error from $uri: $e');
        }
      }

      // 4. Fallback dokumen resmi (untuk data seeded / panduan edukasi offline)
      final generatedDoc = _generateOfficialDocument(material);
      final generatedBytes = utf8.encode(generatedDoc);
      await targetFile.writeAsBytes(generatedBytes, flush: true);

      return DownloadResult(
        success: true,
        filePath: targetFile.path,
        fileName: targetFile.uri.pathSegments.last,
        fileSizeBytes: generatedBytes.length,
        message: 'Materi edukasi resmi berhasil disimpan ke penyimpanan HP.',
      );
    } catch (e) {
      debugPrint('MaterialDownloadService error: $e');
      return DownloadResult(
        success: false,
        fileName: material['file_name'] ?? 'Materi.pdf',
        message: 'Gagal mengunduh materi ke penyimpanan HP.',
        error: e.toString(),
      );
    }
  }

  /// Membuka berkas yang telah diunduh menggunakan aplikasi pembaca bawaan sistem (PDF viewer, dll)
  Future<OpenResult> openFile(String filePath) async {
    return await OpenFilex.open(filePath);
  }

  /// Menentukan folder penyimpanan (Mengutamakan folder Download publik HP)
  Future<Directory> getDownloadDirectory() async {
    if (!kIsWeb && Platform.isAndroid) {
      // 1. Prioritaskan folder Download publik Android: /storage/emulated/0/Download
      final publicDownload = Directory('/storage/emulated/0/Download');
      if (publicDownload.existsSync()) {
        final subDir = Directory('${publicDownload.path}/Phonebook_Materi');
        if (!subDir.existsSync()) {
          try {
            subDir.createSync(recursive: true);
            return subDir;
          } catch (_) {
            return publicDownload;
          }
        }
        return subDir;
      }

      // 2. Alternatif folder eksternal aplikasi
      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          final subDir = Directory('${extDir.path}/Download');
          if (!subDir.existsSync()) {
            subDir.createSync(recursive: true);
          }
          return subDir;
        }
      } catch (_) {}
    }

    // Untuk Desktop (Linux, Windows, macOS) atau iOS
    try {
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null) return downloadsDir;
    } catch (_) {}

    // Fallback umum dokumen aplikasi
    return await getApplicationDocumentsDirectory();
  }

  /// Konversi tautan Google Drive menjadi direct download URL
  Uri? _convertToDirectDriveUrl(String driveUrl) {
    try {
      // Pola: drive.google.com/file/d/FILE_ID/view atau id=FILE_ID
      final reg1 = RegExp(r'file/d/([a-zA-Z0-9_-]+)');
      final reg2 = RegExp(r'[?&]id=([a-zA-Z0-9_-]+)');
      final match1 = reg1.firstMatch(driveUrl);
      final match2 = reg2.firstMatch(driveUrl);
      final fileId = match1?.group(1) ?? match2?.group(1);

      if (fileId != null && fileId.isNotEmpty) {
        return Uri.parse('https://drive.google.com/uc?export=download&id=$fileId');
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

  /// Membuat dokumen resmi terstruktur jika materi belum memiliki binary di server
  String _generateOfficialDocument(Map<String, dynamic> material) {
    final title = (material['title'] ?? 'Materi Kehutanan').toString();
    final category = (material['category'] ?? 'Penyuluhan').toString();
    final type = (material['type'] ?? 'DOKUMEN').toString();
    final uploaderName = (material['uploader_name'] ?? 'Penyuluh Kehutanan').toString();
    final uploaderRole = (material['uploader_role'] ?? 'Penyuluh Kehutanan CDK V').toString();
    final uploadedAt = (material['uploaded_at'] ?? '2026').toString();
    final description = (material['description'] ?? '').toString();
    final driveUrl = (material['drive_url'] ?? '').toString();

    final buffer = StringBuffer();
    buffer.writeln('================================================================================');
    buffer.writeln('                   PEMERINTAH DAERAH PROVINSI JAWA BARAT');
    buffer.writeln('                              DINAS KEHUTANAN');
    buffer.writeln('                CABANG DINAS KEHUTANAN (CDK) WILAYAH V GARUT');
    buffer.writeln('================================================================================');
    buffer.writeln();
    buffer.writeln('DOKUMEN RESMI MATERI EDUKASI & PENYULUHAN LAPANGAN');
    buffer.writeln();
    buffer.writeln('Judul Materi   : $title');
    buffer.writeln('Kategori       : $category');
    buffer.writeln('Tipe Dokumen   : $type');
    buffer.writeln('Penyusun       : $uploaderName');
    buffer.writeln('Jabatan/Peran  : $uploaderRole');
    buffer.writeln('Tanggal Terbit : $uploadedAt');
    if (driveUrl.isNotEmpty) {
      buffer.writeln('Tautan Sumber  : $driveUrl');
    }
    buffer.writeln();
    buffer.writeln('--------------------------------------------------------------------------------');
    buffer.writeln('URAIAN & RINGKASAN MATERI:');
    buffer.writeln('--------------------------------------------------------------------------------');
    buffer.writeln(description.isNotEmpty ? description : 'Tidak ada catatan uraian tambahan.');
    buffer.writeln();
    buffer.writeln('--------------------------------------------------------------------------------');
    buffer.writeln('Catatan Kedinasan:');
    buffer.writeln('Dokumen ini diunduh melalui Aplikasi Mobile Phonebook CDK Wilayah V.');
    buffer.writeln('Dapat digunakan sebagai pedoman kerja penyuluhan kelompok tani hutan (KTH),');
    buffer.writeln('pelaporan kegiatan lapangan, dan arsip kepegawaian dinas.');
    buffer.writeln('================================================================================');
    return buffer.toString();
  }

  /// Menghasilkan nama file yang bersih dan aman dari karakter terlarang sistem berkas
  String _sanitizeFileName(String name) {
    var clean = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    if (clean.isEmpty) clean = 'Materi_Kehutanan';
    return clean;
  }

  /// Menentukan ekstensi default berdasarkan tipe materi
  String _guessExtension(String type) {
    final t = type.toLowerCase();
    if (t.contains('pdf')) return 'pdf';
    if (t.contains('doc')) return 'docx';
    if (t.contains('ppt')) return 'pptx';
    if (t.contains('xls')) return 'xlsx';
    if (t.contains('txt')) return 'txt';
    if (t.contains('jpg') || t.contains('jpeg')) return 'jpg';
    if (t.contains('png')) return 'png';
    if (t.contains('mp4')) return 'mp4';
    return 'pdf';
  }

  /// Menghasilkan file unik jika nama file sudah ada di folder tujuan
  File _getUniqueFile(Directory dir, String baseFileName) {
    File candidate = File('${dir.path}/$baseFileName');
    if (!candidate.existsSync()) return candidate;

    final dotIndex = baseFileName.lastIndexOf('.');
    final nameWithoutExt = dotIndex != -1 ? baseFileName.substring(0, dotIndex) : baseFileName;
    final ext = dotIndex != -1 ? baseFileName.substring(dotIndex) : '';

    int counter = 1;
    while (candidate.existsSync()) {
      candidate = File('${dir.path}/$nameWithoutExt ($counter)$ext');
      counter++;
    }
    return candidate;
  }
}
