// lib/src/services/report_downloader_stub.dart

/// Stub untuk platform non-web (mis. saat dijalankan sebagai aplikasi
/// desktop/mobile native). Mengembalikan false supaya UI bisa menampilkan
/// dialog fallback (menampilkan isi teks) alih-alih diam-diam gagal.
bool downloadTextFile({required String fileName, required String content}) {
  return false;
}

bool openExternalUrl(String url) => false;

/// Stub untuk fungsi downloadReport agar tidak error saat di-export
Future<void> downloadReport({
  required String url,
  required String fileName,
  required void Function(String message) onStatus,
}) async {
  throw UnsupportedError('Platform ini tidak didukung atau stub belum diimplementasikan.');
}