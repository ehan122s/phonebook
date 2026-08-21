import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/category.dart';
import 'reference_cache_service.dart';

class CategoryRepository {
  CategoryRepository(this._client);
  final SupabaseClient _client;

  static const _cacheKey = 'categories';

  Future<List<Category>> list() async {
    try {
      final data = await _client
          .from('categories')
          .select()
          .order('name')
          // BARU — batasi tunggu 8 detik. Sebelumnya query ini bisa hang
          // tanpa batas kalau koneksi lambat/putus, bikin dropdown "Jenis
          // Kegiatan" macet di "Memuat..." selamanya.
          .timeout(const Duration(seconds: 8));

      final categories = (data as List)
          .cast<Map<String, dynamic>>()
          .map(Category.fromMap)
          .toList();

      // BARU — simpan ke cache lokal supaya bisa dipakai lagi kalau nanti
      // offline. Tidak perlu ditunggu (unawaited), tidak boleh sampai
      // menunda tampilnya dropdown ke user.
      unawaited(ReferenceCacheService.setMapList(
        _cacheKey,
        categories.map((c) => {'id': c.id, 'name': c.name, 'description': c.description}).toList(),
      ));

      return categories;
    } catch (_) {
      // BARU — offline / timeout / error lain: coba pakai cache hasil
      // fetch terakhir yang berhasil, supaya dropdown tetap bisa dipakai.
      final cached = ReferenceCacheService.getMapList(_cacheKey);
      if (cached != null && cached.isNotEmpty) {
        return cached.map(Category.fromMap).toList();
      }
      rethrow; // Belum pernah ada cache sama sekali -> tetap lempar error asli.
    }
  }

  Future<void> save({
    String? id,
    required String name,
    String? description,
  }) async {
    final data = {'name': name, 'description': description};
    if (id == null) {
      await _client.from('categories').insert(data);
    } else {
      await _client.from('categories').update(data).eq('id', id);
    }
  }

  Future<void> delete(String id) =>
      _client.from('categories').delete().eq('id', id);
}