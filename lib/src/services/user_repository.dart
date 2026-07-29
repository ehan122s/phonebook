import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_user.dart'; // Pastikan path ini sesuai

class UserRepository {
  UserRepository(this._client);
  final SupabaseClient _client;

  // READ: Mengambil profil pengguna saat ini
  Future<AppUser> current() async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw StateError('Sesi pengguna tidak aktif. Silakan masuk kembali.');
    }

    final data = await _client
        .from('profiles')
        .select()
        .eq('id', currentUser.id)
        .maybeSingle();
    if (data != null) return AppUser.fromMap(data);

    final role = currentUser.userMetadata?['role'] as String? ?? 'penyuluh';
    final fullName =
        currentUser.userMetadata?['full_name'] as String? ??
        currentUser.email?.split('@').first ??
        'Penyuluh';
    final profile = {
      'id': currentUser.id,
      'full_name': fullName,
      'role': role,
    };
    await _client.from('profiles').upsert(profile, onConflict: 'id');
    return AppUser.fromMap(profile);
  }

  // READ: Menampilkan seluruh daftar pengguna
  Future<List<AppUser>> list() async {
    final data = await _client.from('profiles').select().order('full_name');
    return (data as List)
        .cast<Map<String, dynamic>>()
        .map(AppUser.fromMap)
        .toList();
  }

  // UPDATE: Memperbarui profil (tabel public)
  Future<void> update(
    AppUser user, {
    required String fullName,
    String? nip,
    required String role,
  }) => _client
      .from('profiles')
      .update({'full_name': fullName, 'nip': nip, 'role': role})
      .eq('id', user.id);

  // DELETE: Menghapus profil dari tabel public saja
  Future<void> deleteProfile(String id) =>
      _client.from('profiles').delete().eq('id', id);

  // CREATE (EDGE FUNCTION): Membuat Auth User & Profile sekaligus via Serverless Function
  Future<void> createUser({
    required String email,
    required String password,
    required String fullName,
    String? nip, // Ditambahkan agar support form
    required String role, // Ditambahkan agar support form
  }) => _client.functions.invoke(
    'admin-users',
    body: {
      'action': 'create',
      'email': email,
      'password': password,
      'full_name': fullName,
      'nip': nip, // Dikirim ke body (sesuaikan di script Edge Function kamu)
      'role': role, // Dikirim ke body (sesuaikan di script Edge Function kamu)
    },
  );

  // DELETE (EDGE FUNCTION): Menghapus Auth User secara permanen (Cascade)
  Future<void> deleteUser(String id) => _client.functions.invoke(
    'admin-users',
    body: {'action': 'delete', 'user_id': id},
  );
}