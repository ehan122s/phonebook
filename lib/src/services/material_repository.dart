import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/material_item.dart';

class MaterialRepository {
  MaterialRepository(this._client);
  final SupabaseClient _client;

  Future<List<MaterialItem>> list() async {
    final rows = await _client
        .from('materials')
        .select()
        .order('created_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(MaterialItem.fromMap)
        .toList();
  }

  /// Signed URL untuk file asli yang sudah diunggah admin ke Storage.
  /// Valid selama 1 jam (3600 detik).
  Future<String> signedUrl(String storagePath) => _client.storage
      .from('materi-edukasi')
      .createSignedUrl(storagePath, 3600);

  /// Mengunggah file materi baru: upload bytes ke Storage bucket
  /// 'materi-edukasi', lalu insert baris baru ke tabel 'materials'.
  ///
  /// [fileType] harus salah satu dari: pdf | word | excel | video | image | other
  /// (dipakai untuk memilih ikon/warna badge di UI).
  Future<void> upload({
    required String title,
    required String category,
    required String fileType,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final namaAman =
        '${DateTime.now().millisecondsSinceEpoch}_${fileName.replaceAll(RegExp(r'[^\w.\-]'), '_')}';

    await _client.storage.from('materi-edukasi').uploadBinary(
          namaAman,
          bytes,
          fileOptions: const FileOptions(upsert: false),
        );

    await _client.from('materials').insert({
      'title': title,
      'category': category,
      'file_type': fileType,
      'file_name': fileName,
      'file_size_bytes': bytes.length,
      'storage_path': namaAman,
    });
  }

  /// Menghapus materi (file di storage + baris di tabel).
  /// Butuh role admin (lihat RLS policy "materials admin write").
  Future<void> delete(MaterialItem item) async {
    if (item.storagePath != null && item.storagePath!.isNotEmpty) {
      await _client.storage.from('materi-edukasi').remove([item.storagePath!]);
    }
    await _client.from('materials').delete().eq('id', item.id);
  }
}
