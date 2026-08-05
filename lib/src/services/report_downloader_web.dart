import 'dart:html' as html;

/// Implementasi untuk platform Web.
///
/// PENTING: kita TIDAK pakai url_launcher (window.open) di sini. Karena
/// `downloadReport` dipanggil setelah proses `await` (menunggu Edge Function
/// selesai generate PDF/Docx), Chrome tidak lagi menganggapnya berasal dari
/// klik user secara langsung, sehingga window.open() diam-diam diblokir
/// oleh popup blocker tanpa error apa pun.
///
/// Trik yang reliable: buat elemen <a> dengan atribut `download`, lalu
/// panggil `.click()` lewat DOM. Cara ini tidak dianggap "popup" oleh
/// browser manapun, jadi tidak diblokir meskipun dipanggil setelah await.
///
/// `url` yang dikirim dari Edge Function `generate-report` juga sudah
/// dibuat dengan opsi `download: <nama file>` saat createSignedUrl (server
/// sudah menyertakan header Content-Disposition: attachment), jadi browser
/// otomatis mengunduhnya alih-alih membuka preview.
Future<void> downloadReport({
  required String url,
  required String fileName,
  required void Function(String message) onStatus,
}) async {
  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..target = '_self';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  onStatus('Laporan berhasil diunduh');
}