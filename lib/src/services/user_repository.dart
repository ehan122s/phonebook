import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart'; // <-- Tambahan untuk mode offline
import '../models/app_user.dart';

class UserRepository {
  UserRepository(this._client);
  final SupabaseClient _client;

  // READ: Mengambil profil pengguna saat ini (Mendukung Mode Offline)
  Future<AppUser> current() async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw StateError('Sesi pengguna tidak aktif. Silakan masuk kembali.');
    }

    // Buka kotak penyimpanan profil di memori HP
    final box = await Hive.openBox<Map>('user_profile_cache');

    try {
      // 1. Coba ambil data terbaru dari server (Supabase)
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', currentUser.id)
          .maybeSingle();

      if (data != null) {
        // Kalau berhasil dapet dari internet, simpan/update ke HP (Cache)
        await box.put(currentUser.id, data);
        return AppUser.fromMap(data);
      }

      // 2. Jika profil di database kosong, buat dari metadata
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
      
      // Simpan juga ke HP
      await box.put(currentUser.id, profile);
      return AppUser.fromMap(profile);

    } catch (e) {
      // ==========================================================
      // 3. JIKA ERROR (MISAL: TIDAK ADA INTERNET / OFFLINE)
      // ==========================================================
      // Jangan langsung bikin aplikasi error, cek dulu di kotak lokal HP!
      final cachedData = box.get(currentUser.id);
      
      if (cachedData != null) {
        // Data ketemu di HP! Ubah tipe datanya biar sesuai dan kembalikan
        final mappedData = Map<String, dynamic>.from(cachedData);
        return AppUser.fromMap(mappedData);
      }

      // Kalau di server gagal dan di HP juga belum pernah tersimpan:
      throw StateError('Tidak bisa memuat profil saat offline. Pastikan Anda pernah login dengan koneksi internet sebelumnya.');
    }
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
  }) => _invokeAdminUsers({
        'action': 'update',
        'user_id': user.id,
        'full_name': fullName,
        'nip': nip,
        'role': role,
      });

  // DELETE: Menghapus profil dari tabel public saja
  Future<void> deleteProfile(String id) =>
      _client.from('profiles').delete().eq('id', id);

  // CREATE (EDGE FUNCTION): Membuat Auth User & Profile sekaligus via Serverless Function
  Future<void> createUser({
    required String email,
    required String password,
    required String fullName,
    String? nip, 
    required String role, 
  }) => _invokeAdminUsers({
        'action': 'create',
        'email': email,
        'password': password,
        'full_name': fullName,
        'nip': nip,
        'role': role,
      });

  // DELETE (EDGE FUNCTION): Menghapus Auth User secara permanen (Cascade)
  Future<void> deleteUser(String id) =>
      _invokeAdminUsers({'action': 'delete', 'user_id': id});

  Future<void> _invokeAdminUsers(Map<String, dynamic> body) async {
    final response = await _client.functions.invoke('admin-users', body: body);
    final data = response.data;
    if (data is Map && data['error'] != null) {
      throw StateError(data['error'].toString());
    }
  }
}