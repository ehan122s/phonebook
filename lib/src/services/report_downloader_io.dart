import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_file_downloader/flutter_file_downloader.dart';
import 'package:path_provider/path_provider.dart';

/// Implementasi untuk platform native: Android, iOS, Windows, macOS, Linux.
///
/// PENTING — perubahan dari versi sebelumnya:
/// Sebelumnya file diunduh dulu ke folder sementara lalu ditawarkan lewat
/// share-sheet ("Bagikan ke...") supaya user pilih sendiri mau disimpan ke
/// mana. Ternyata itu bukan yang diinginkan — maunya file LANGSUNG masuk ke
/// folder Download tanpa dialog tambahan.
///
/// Untuk Android/iOS sekarang dipakai `flutter_file_downloader`, yang di
/// balik layar memakai:
/// - Android: `DownloadManager` bawaan OS (servis sistem yang sama dipakai
///   browser untuk mengunduh file) — otomatis muncul di folder Download
///   publik DAN di notification tray, tanpa perlu izin storage tambahan di
///   Android 10+, dan jauh lebih tahan terhadap koneksi putus-nyambung
///   dibanding http/Dio karena ditangani di level native OS.
/// - iOS: tersimpan ke folder yang terlihat di app Files.
///
/// Desktop (Windows/macOS/Linux) tetap pakai Dio, karena di sana memang
/// bisa langsung tulis ke folder Downloads tanpa kendala scoped storage.
Future<void> downloadReport({
  required String url,
  required String fileName,
  required void Function(String message) onStatus,
}) async {
  onStatus('Mengunduh $fileName...');

  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await _downloadDesktop(url: url, fileName: fileName, onStatus: onStatus);
    return;
  }

  // Android / iOS — download langsung ke folder publik, tanpa share-sheet.
  final completer = Completer<void>();

  await FileDownloader.downloadFile(
    url: url,
    name: fileName,
    onDownloadCompleted: (path) {
      onStatus('Laporan tersimpan di folder Download!');
      if (!completer.isCompleted) completer.complete();
    },
    onDownloadError: (errorMessage) {
      if (!completer.isCompleted) {
        completer.completeError(Exception(errorMessage));
      }
    },
    // Notifikasi progres bawaan Android muncul otomatis di status bar,
    // jadi tidak wajib pantau onProgress di sini — tapi tetap diteruskan
    // ke onStatus untuk ditampilkan di dalam app juga.
    onProgress: (fName, progress) {
      onStatus('Mengunduh $fileName... ${progress.toStringAsFixed(0)}%');
    },
  );

  return completer.future;
}

Future<void> _downloadDesktop({
  required String url,
  required String fileName,
  required void Function(String message) onStatus,
}) async {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 2),
    ),
  );

  Directory? downloadsDir;
  try {
    downloadsDir = await getDownloadsDirectory();
  } catch (_) {
    downloadsDir = null;
  }
  downloadsDir ??= await getApplicationDocumentsDirectory();

  final path = '${downloadsDir.path}${Platform.pathSeparator}$fileName';

  Object? lastError;
  for (var percobaan = 1; percobaan <= 3; percobaan++) {
    try {
      await dio.download(
        url,
        path,
        options: Options(followRedirects: true, receiveDataWhenStatusError: true),
      );
      lastError = null;
      break;
    } catch (e) {
      lastError = e;
      final gagalFile = File(path);
      if (await gagalFile.exists()) await gagalFile.delete();
      if (percobaan < 3) {
        onStatus('Koneksi terputus, mencoba lagi... ($percobaan/3)');
        await Future.delayed(Duration(seconds: percobaan));
      }
    }
  }

  if (lastError != null) {
    throw Exception('Gagal mengunduh file setelah beberapa percobaan: $lastError');
  }

  onStatus('Tersimpan di $path');
}