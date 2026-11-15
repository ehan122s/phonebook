import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class StorageSaveResult {
  final bool success;
  final String? filePath;
  final String? displayPath;
  final String fileName;
  final int fileSizeBytes;
  final String message;
  final String? error;

  const StorageSaveResult({
    required this.success,
    this.filePath,
    this.displayPath,
    required this.fileName,
    this.fileSizeBytes = 0,
    required this.message,
    this.error,
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

class DeviceFileStorageService {
  DeviceFileStorageService._();
  static final DeviceFileStorageService instance = DeviceFileStorageService._();

  static const MethodChannel _storageChannel =
      MethodChannel('com.cdkv.phonebook/storage');

  /// Menyimpan bytes berkas langsung ke folder Download perangkat publik.
  /// Mendukung Scoped Storage Android (Android 10 - 15+) melalui MediaStore API,
  /// serta Desktop (Linux/Windows/macOS) dan Web.
  Future<StorageSaveResult> saveToDownloads({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
    String? subfolder = 'Phonebook',
  }) async {
    final cleanName = sanitizeFileName(fileName);
    final resolvedMime = mimeType ?? guessMimeType(cleanName);

    // 1. Android: Prioritaskan MediaStore API via MethodChannel
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final res = await _storageChannel.invokeMapMethod<String, dynamic>(
          'saveFileToDownloads',
          {
            'bytes': bytes,
            'fileName': cleanName,
            'mimeType': resolvedMime,
            'subfolder': subfolder ?? '',
          },
        );

        if (res != null && res['success'] == true) {
          final filePath = res['filePath']?.toString();
          final displayPath =
              res['displayPath']?.toString() ?? 'Download/$cleanName';
          return StorageSaveResult(
            success: true,
            filePath: filePath,
            displayPath: displayPath,
            fileName: cleanName,
            fileSizeBytes: bytes.length,
            message: 'Berkas berhasil disimpan ke folder $displayPath',
          );
        }
      } catch (e) {
        debugPrint('MediaStore MethodChannel fallback: $e');
      }

      // Fallback 1: Coba direct write ke /storage/emulated/0/Download
      try {
        final baseDir = Directory('/storage/emulated/0/Download');
        if (baseDir.existsSync()) {
          final targetDir = (subfolder != null && subfolder.isNotEmpty)
              ? Directory('${baseDir.path}/$subfolder')
              : baseDir;
          if (!targetDir.existsSync()) {
            targetDir.createSync(recursive: true);
          }
          final uniqueFile = getUniqueFile(targetDir, cleanName);
          await uniqueFile.writeAsBytes(bytes, flush: true);
          final rel = uniqueFile.path.replaceFirst('/storage/emulated/0/', '');
          return StorageSaveResult(
            success: true,
            filePath: uniqueFile.path,
            displayPath: rel,
            fileName: uniqueFile.uri.pathSegments.last,
            fileSizeBytes: bytes.length,
            message: 'Berkas berhasil disimpan di $rel',
          );
        }
      } catch (e) {
        debugPrint('Direct write to /storage/emulated/0/Download failed: $e');
      }

      // Fallback 2: getExternalStorageDirectories atau getDownloadsDirectory
      try {
        final extDirs =
            await getExternalStorageDirectories(type: StorageDirectory.downloads);
        if (extDirs != null && extDirs.isNotEmpty) {
          final uniqueFile = getUniqueFile(extDirs.first, cleanName);
          await uniqueFile.writeAsBytes(bytes, flush: true);
          return StorageSaveResult(
            success: true,
            filePath: uniqueFile.path,
            displayPath: 'Download/${uniqueFile.uri.pathSegments.last}',
            fileName: uniqueFile.uri.pathSegments.last,
            fileSizeBytes: bytes.length,
            message: 'Berkas berhasil disimpan di folder Download',
          );
        }
      } catch (e) {
        debugPrint('getExternalStorageDirectories failed: $e');
      }
    }

    // 2. Desktop (Linux, Windows, macOS)
    if (!kIsWeb &&
        (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
      try {
        final dir = await getDownloadsDirectory() ??
            await getApplicationDocumentsDirectory();
        final targetDir = (subfolder != null && subfolder.isNotEmpty)
            ? Directory('${dir.path}/$subfolder')
            : dir;
        if (!targetDir.existsSync()) {
          targetDir.createSync(recursive: true);
        }
        final uniqueFile = getUniqueFile(targetDir, cleanName);
        await uniqueFile.writeAsBytes(bytes, flush: true);
        return StorageSaveResult(
          success: true,
          filePath: uniqueFile.path,
          displayPath: uniqueFile.path,
          fileName: uniqueFile.uri.pathSegments.last,
          fileSizeBytes: bytes.length,
          message: 'Berkas berhasil disimpan di ${uniqueFile.path}',
        );
      } catch (e) {
        debugPrint('Desktop save error: $e');
      }
    }

    // 3. Fallback umum: getApplicationDocumentsDirectory
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final uniqueFile = getUniqueFile(docDir, cleanName);
      await uniqueFile.writeAsBytes(bytes, flush: true);
      return StorageSaveResult(
        success: true,
        filePath: uniqueFile.path,
        displayPath: uniqueFile.path,
        fileName: uniqueFile.uri.pathSegments.last,
        fileSizeBytes: bytes.length,
        message: 'Berkas berhasil disimpan di ${uniqueFile.path}',
      );
    } catch (e) {
      return StorageSaveResult(
        success: false,
        fileName: cleanName,
        message: 'Gagal menyimpan berkas ke penyimpanan: $e',
        error: e.toString(),
      );
    }
  }

  /// Membuka berkas yang telah diunduh menggunakan aplikasi pembaca bawaan sistem (PDF viewer, Docs, dsb.)
  Future<OpenResult> openFile(String filePath, {String? mimeType}) async {
    final resolvedMime = mimeType ?? guessMimeType(filePath);

    // 1. Coba OpenFilex
    try {
      final result = await OpenFilex.open(filePath, type: resolvedMime);
      if (result.type == ResultType.done) {
        return result;
      }
    } catch (_) {}

    // 2. Jika di Android dan gagal, coba intent native
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final res = await _storageChannel.invokeMethod<bool>('openFile', {
          'filePath': filePath,
          'mimeType': resolvedMime,
        });
        if (res == true) {
          return OpenResult(
            type: ResultType.done,
            message: 'Berhasil dibuka dengan aplikasi sistem',
          );
        }
      } catch (_) {}
    }

    return OpenResult(
      type: ResultType.error,
      message: 'Tidak dapat membuka berkas secara otomatis. Anda dapat membukanya melalui File Manager -> Download.',
    );
  }

  /// Menghasilkan nama file yang bersih dan aman dari karakter terlarang sistem berkas
  static String sanitizeFileName(String name) {
    var clean = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    clean = clean.replaceAll(RegExp(r'\s+'), '_');
    if (clean.isEmpty) clean = 'Dokumen_Phonebook';
    return clean;
  }

  /// Menghasilkan file unik jika nama file sudah ada di folder tujuan
  static File getUniqueFile(Directory dir, String baseFileName) {
    File candidate = File('${dir.path}/$baseFileName');
    if (!candidate.existsSync()) return candidate;

    final dotIndex = baseFileName.lastIndexOf('.');
    final nameWithoutExt =
        dotIndex != -1 ? baseFileName.substring(0, dotIndex) : baseFileName;
    final ext = dotIndex != -1 ? baseFileName.substring(dotIndex) : '';

    int counter = 1;
    while (candidate.existsSync()) {
      candidate = File('${dir.path}/$nameWithoutExt ($counter)$ext');
      counter++;
    }
    return candidate;
  }

  /// Mendeteksi tipe MIME berdasarkan ekstensi file
  static String guessMimeType(String fileNameOrPath) {
    final ext = fileNameOrPath.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'txt':
        return 'text/plain';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'zip':
        return 'application/zip';
      default:
        return 'application/octet-stream';
    }
  }
}
