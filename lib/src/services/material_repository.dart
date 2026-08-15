import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/material_item.dart';

class MaterialRepository {
  MaterialRepository(this._client);
  final SupabaseClient _client;

  Future<List<MaterialItem>> list() async {
    try {
      // Lakukan JOIN ke tabel profiles untuk mengambil nama pengunggah ('name')
      // Pastikan foreign key di tabel 'materials' kolom 'uploaded_by' merujuk ke tabel 'profiles'
      final rows = await _client
          .from('materials')
          .select('*, profiles(name)')
          .order('created_at', ascending: false);
          
      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map(MaterialItem.fromMap)
          .toList();
    } catch (e) {
      // JIKA GAGAL (biasanya karena belum ada Foreign Key ke tabel profiles di Supabase),
      // Kita fallback ke query biasa agar list materi TETAP MUNCUL untuk SEMUA USER.
      final fallbackRows = await _client
          .from('materials')
          .select()
          .order('created_at', ascending: false);
          
      return (fallbackRows as List)
          .cast<Map<String, dynamic>>()
          .map(MaterialItem.fromMap)
          .toList();
    }
  }

  /// Signed URL untuk file asli yang sudah diunggah admin ke Storage.
  /// Valid selama 1 jam (3600 detik).
  Future<String> signedUrl(String storagePath) => _client.storage
      .from('materi-edukasi')
      .createSignedUrl(storagePath, 3600);

  /// Mengunggah file materi baru: upload bytes ke Storage bucket
  /// 'materi-edukasi', lalu insert baris baru ke tabel 'materials'.
  Future<void> upload({
    required String title,
    required String category,
    required String fileType,
    required String fileName,
    required Uint8List bytes,
    String? uploadedBy, // Tambahan field uploader
  }) async {
    final namaAman =
        '${DateTime.now().millisecondsSinceEpoch}_${fileName.replaceAll(RegExp(r'[^\w.\-]'), '_')}';

    // 1. Upload ke Storage
    await _client.storage.from('materi-edukasi').uploadBinary(
          namaAman,
          bytes,
          fileOptions: const FileOptions(upsert: false),
        );

    // 2. Simpan ke Database
    await _client.from('materials').insert({
      'title': title,
      'category': category,
      'file_type': fileType,
      'file_name': fileName,
      'file_size_bytes': bytes.length,
      'storage_path': namaAman,
      'uploaded_by': uploadedBy, // <--- PASTIKAN TANDA // DI HAPUS DI SINI
    });
  }

  /// Memperbarui informasi materi di database.
  /// Bila [newFileBytes] dilampirkan, akan mengupload file baru ke Storage 
  /// sekaligus menghapus file yang lama.
  Future<void> update({
    required String id,
    required String title,
    required String category,
    Uint8List? newFileBytes,
    String? newFileName,
    String? newFileType,
  }) async {
    final Map<String, dynamic> updates = {
      'title': title,
      'category': category,
    };

    // Apabila user mengganti file fisiknya
    if (newFileBytes != null && newFileName != null && newFileType != null) {
      // Dapatkan data path lama terlebih dahulu agar bisa dihapus
      final oldData = await _client
          .from('materials')
          .select('storage_path')
          .eq('id', id)
          .maybeSingle();

      // Buat nama file aman baru
      final namaAmanBaru =
          '${DateTime.now().millisecondsSinceEpoch}_${newFileName.replaceAll(RegExp(r'[^\w.\-]'), '_')}';

      // 1. Upload File Baru ke Storage
      await _client.storage.from('materi-edukasi').uploadBinary(
            namaAmanBaru,
            newFileBytes,
            fileOptions: const FileOptions(upsert: false),
          );

      // 2. Hapus file lama secara background (ignore error jika gagal dihapus)
      if (oldData != null && oldData['storage_path'] != null) {
        _client.storage
            .from('materi-edukasi')
            .remove([oldData['storage_path']]).catchError((_) {});
      }

      // 3. Masukkan data file baru ke dalam object update
      updates['file_name'] = newFileName;
      updates['file_type'] = newFileType;
      updates['file_size_bytes'] = newFileBytes.length;
      updates['storage_path'] = namaAmanBaru;
    }

    // Jalankan operasi update pada Supabase DB
    await _client.from('materials').update(updates).eq('id', id);
  }

  /// Menghapus materi berdasarkan Parameter UI.
  /// (Menghapus file di storage + baris di tabel database).
  Future<void> delete({required String id, String? storagePath}) async {
    // Hapus dari bucket storage jika ada file yang berkaitan
    if (storagePath != null && storagePath.isNotEmpty) {
      await _client.storage.from('materi-edukasi').remove([storagePath]);
    }
    
    // Hapus baris data dari database
    await _client.from('materials').delete().eq('id', id);
  }
}