# SIPENYULUH

Aplikasi Flutter Web/PWA untuk pengelolaan kegiatan penyuluh kehutanan dengan Supabase (Auth, PostgreSQL, Storage, dan Edge Functions).

## Menjalankan

1. Buat project Supabase lalu jalankan `supabase/schema.sql` melalui SQL Editor.
   Setelah itu jalankan `supabase/migrations/202607270001_features.sql`.
   Jika migration fitur sedang terkunci, jalankan dahulu `supabase/migrations/202607270002_profile_hotfix.sql` untuk memulihkan login.
2. Buat akun melalui Supabase Auth, lalu buat profile terkait pada tabel `profiles`.
3. Salin `env.example.json` menjadi `env.json`, lalu isi kredensial Supabase. File `env.json` sudah diabaikan Git.
4. Jalankan:

```powershell
flutter pub get
flutter run -d chrome --dart-define-from-file=env.json
```

Untuk produksi PWA: `flutter build web --dart-define-from-file=env.json`.

## API Supabase

Database REST API tersedia otomatis melalui tabel dengan RLS aktif. Deploy dua Edge Function berikut untuk API yang membutuhkan hak server:

```powershell
supabase functions deploy generate-report
supabase functions deploy admin-users
```

- `generate-report`: membangun artefak laporan dari data kegiatan dan menghasilkan URL unduhan bertanda tangan.
- `admin-users`: membuat atau menghapus akun Supabase Auth oleh admin, tanpa pernah mengekspos service-role key ke Flutter.

## Struktur data

`profiles` → `activities` → (`activity_documents`, `activity_photos`), dengan `categories` dan `report_templates` sebagai data referensi. Kebijakan RLS membatasi penyuluh ke datanya sendiri; admin dapat mengelola seluruh data.

## Catatan laporan

Ekspor PDF/DOCX sebaiknya dikerjakan pada Supabase Edge Function bernama `generate-report`, agar template, foto, dan file keluaran tidak mengandalkan browser klien. Tombol laporan di aplikasi sudah menjadi titik integrasi untuk fungsi tersebut.
