/// Stub untuk platform non-web (mis. saat dijalankan sebagai aplikasi
/// desktop/mobile native). Mengembalikan false supaya UI bisa menampilkan
/// dialog fallback (menampilkan isi teks) alih-alih diam-diam gagal.
bool downloadTextFile({required String fileName, required String content}) {
  return false;
}

bool openExternalUrl(String url) => false;
