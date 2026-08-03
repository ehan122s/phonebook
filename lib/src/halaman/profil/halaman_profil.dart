import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/app_user.dart';
import '../../widgets/glashmorp.dart';

/// Halaman Profil — menampilkan data akun penyuluh yang sedang login.
///
/// Catatan penting (agar tidak ada fitur "palsu"):
/// Kebijakan RLS pada tabel `profiles` (lihat supabase/schema.sql, policy
/// "profiles admin write") hanya mengizinkan role `admin` melakukan
/// insert/update/delete pada tabel profiles. Artinya seorang penyuluh
/// TIDAK BISA mengubah nama/NIP/role dirinya sendiri langsung dari client,
/// dan permintaan tersebut akan ditolak oleh database (403/RLS violation).
/// Karena itu halaman ini menampilkan data secara read-only dan mengarahkan
/// perubahan data ke admin, alih-alih membuat tombol "Simpan" yang akan
/// selalu gagal diam-diam.
class HalamanProfil extends StatelessWidget {
  const HalamanProfil({super.key, required this.user});
  final AppUser user;

  String get _inisial {
    final parts = user.fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  String get _labelRole {
    switch (user.role) {
      case 'admin':
        return 'Administrator';
      case 'pengelola':
        return 'Pengelola Ekosistem';
      case 'penelaah':
        return 'Penelaah Kebijakan';
      case 'penyuluh':
      default:
        return 'Penyuluh Kehutanan';
    }
  }

  Future<void> _gantiRole(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Ganti Role', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text(
          'Role Anda saat ini adalah "$_labelRole". Perubahan role hanya '
          'dapat dilakukan oleh Administrator sistem demi keamanan data. '
          'Silakan hubungi admin SIMPUL jika Anda perlu berpindah role.',
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  Future<void> _konfirmasiKeluar(BuildContext context) async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Keluar Aplikasi', style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text('Apakah Anda yakin ingin keluar dari akun ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (yakin == true) {
      await Supabase.instance.client.auth.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: LatarBelakangGradien(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            KartuKaca(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: const Color(0xFF2E7D32),
                    child: Text(_inisial, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(height: 16),
                  Text(user.fullName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1B5E20)), textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0xFF2E7D32).withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                    child: Text(_labelRole, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1B5E20))),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            KartuKaca(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  _BarisInfo(icon: Icons.badge_rounded, label: 'NIP', value: (user.nip == null || user.nip!.isEmpty) ? '- Belum diisi -' : user.nip!),
                  const Divider(height: 1, indent: 20, endIndent: 20, color: Colors.black12),
                  _BarisInfo(icon: Icons.email_rounded, label: 'Email', value: Supabase.instance.client.auth.currentUser?.email ?? '-'),
                  const Divider(height: 1, indent: 20, endIndent: 20, color: Colors.black12),
                  _BarisInfo(icon: Icons.verified_user_rounded, label: 'Role', value: _labelRole),
                ],
              ),
            ),
            const SizedBox(height: 20),
            KartuKaca(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF2E7D32)),
                    title: const Text('Ganti Role', style: TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: const Text('Perlu persetujuan admin', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _gantiRole(context),
                  ),
                  const Divider(height: 1, indent: 20, endIndent: 20, color: Colors.black12),
                  ListTile(
                    leading: const Icon(Icons.power_settings_new_rounded, color: Colors.redAccent),
                    title: const Text('Keluar Aplikasi', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.redAccent)),
                    onTap: () => _konfirmasiKeluar(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _BarisInfo extends StatelessWidget {
  const _BarisInfo({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFF2E7D32).withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: const Color(0xFF2E7D32), size: 20),
        ),
        title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w700)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.black87)),
        ),
      );
}
