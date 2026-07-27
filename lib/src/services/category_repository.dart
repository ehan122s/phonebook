import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/category.dart';

class CategoryRepository {
  CategoryRepository(this._client);
  final SupabaseClient _client;
  Future<List<Category>> list() async {
    final data = await _client.from('categories').select().order('name');
    return (data as List)
        .cast<Map<String, dynamic>>()
        .map(Category.fromMap)
        .toList();
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
