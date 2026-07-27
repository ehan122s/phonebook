import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user.dart';

class UserRepository {
  UserRepository(this._client);
  final SupabaseClient _client;

  Future<AppUser> current() async {
    final currentUser = _client.auth.currentUser!;
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', currentUser.id)
        .maybeSingle();
    if (data != null) return AppUser.fromMap(data);
    final fullName =
        currentUser.userMetadata?['full_name'] as String? ??
        currentUser.email?.split('@').first ??
        'Penyuluh';
    final profile = {
      'id': currentUser.id,
      'full_name': fullName,
      'role': 'penyuluh',
    };
    await _client.from('profiles').upsert(profile);
    return AppUser.fromMap(profile);
  }

  Future<List<AppUser>> list() async {
    final data = await _client.from('profiles').select().order('full_name');
    return (data as List)
        .cast<Map<String, dynamic>>()
        .map(AppUser.fromMap)
        .toList();
  }

  Future<void> update(
    AppUser user, {
    required String fullName,
    String? nip,
    required String role,
  }) => _client
      .from('profiles')
      .update({'full_name': fullName, 'nip': nip, 'role': role})
      .eq('id', user.id);

  Future<void> deleteProfile(String id) =>
      _client.from('profiles').delete().eq('id', id);

  Future<void> createUser({
    required String email,
    required String password,
    required String fullName,
  }) => _client.functions.invoke(
    'admin-users',
    body: {
      'action': 'create',
      'email': email,
      'password': password,
      'full_name': fullName,
    },
  );

  Future<void> deleteUser(String id) => _client.functions.invoke(
    'admin-users',
    body: {'action': 'delete', 'user_id': id},
  );
}
