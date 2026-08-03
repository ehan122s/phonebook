import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Membuat file teks di memori (Blob) lalu memicu unduhan asli lewat browser.
/// Dipakai untuk materi contoh yang kontennya disimpan sebagai teks di
/// database (belum ada file biner asli yang diunggah admin).
bool downloadTextFile({required String fileName, required String content}) {
  final bytes = Uint8List.fromList(content.codeUnits);
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'text/plain;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = fileName
    ..style.display = 'none';
  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
  return true;
}

/// Membuka signed URL Supabase Storage (file asli) di tab baru agar
/// browser mengunduh/menampilkan filenya.
bool openExternalUrl(String url) {
  web.window.open(url, '_blank');
  return true;
}
