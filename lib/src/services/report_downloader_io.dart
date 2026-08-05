import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Implementasi untuk platform native: Android, iOS, Windows, macOS, Linux.
///
/// - Desktop (Windows/macOS/Linux): file langsung ditulis ke folder
///   Downloads perangkat.
/// - Android/iOS: menulis langsung ke folder Downloads publik butuh
///   permission khusus (scoped storage). Supaya tetap simpel dan tidak
///   perlu minta permission storage, file disimpan sementara lalu
///   ditampilkan lewat share-sheet bawaan OS ("Simpan ke File" / Download),
///   yang tetap membuat file berakhir di penyimpanan HP.
Future<void> downloadReport({
  required String url,
  required String fileName,
  required void Function(String message) onStatus,
}) async {
  onStatus('Mengunduh $fileName...');

  final response = await http.get(Uri.parse(url));
  if (response.statusCode != 200) {
    throw Exception('Gagal mengunduh file (status ${response.statusCode})');
  }

  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    Directory? dir;
    try {
      dir = await getDownloadsDirectory();
    } catch (_) {
      dir = null;
    }
    dir ??= await getApplicationDocumentsDirectory();

    final path = '${dir.path}${Platform.pathSeparator}$fileName';
    final file = File(path);
    await file.writeAsBytes(response.bodyBytes);
    onStatus('Tersimpan di $path');
    return;
  }

  // Android / iOS
  final tempDir = await getTemporaryDirectory();
  final tempPath = '${tempDir.path}${Platform.pathSeparator}$fileName';
  final tempFile = File(tempPath);
  await tempFile.writeAsBytes(response.bodyBytes);

  await Share.shareXFiles([XFile(tempPath)], text: fileName);
  onStatus('Pilih "Simpan ke File" / folder Download pada menu berbagi untuk menyimpan laporan');
}