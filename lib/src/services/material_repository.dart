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
  Future<String> signedUrl(String storagePath) => _client.storage
      .from('materi-edukasi')
      .createSignedUrl(storagePath, 3600);
}
