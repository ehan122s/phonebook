import 'package:flutter/material.dart';

import '../../models/app_user.dart'; 
import '../../services/user_repository.dart'; 
import '../../widgets/glashmorp.dart'; 
import 'form_pengguna.dart'; 

class HalamanAdminPengguna extends StatefulWidget {
  const HalamanAdminPengguna({super.key, required this.repository});
  final UserRepository repository;

  @override
  State<HalamanAdminPengguna> createState() => _HalamanAdminPenggunaState();
}

class _HalamanAdminPenggunaState extends State<HalamanAdminPengguna> {
  late Future<List<AppUser>> _users;

  @override
  void initState() {
    super.initState();
    _muatUlang();
  }

  void _muatUlang() {
    setState(() {
      _users = widget.repository.list();
    });
  }

  // --- DELETE (Hapus Pengguna) ---
  Future<void> _hapusUser(AppUser user) async {
    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Pengguna?'),
        content: Text('Apakah Anda yakin ingin menghapus "${user.fullName}"? Data tidak dapat dikembalikan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (konfirmasi == true) {
      try {
        await widget.repository.deleteUser(user.id);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pengguna berhasil dihapus'),
              backgroundColor: Colors.green,
            ),
          );
          _muatUlang();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menghapus pengguna: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AppUser>>(
      future: _users,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Gagal memuat pengguna: ${snapshot.error}'));
        }

        final users = snapshot.data ?? [];

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          children: [
            // HEADER & TOMBOL TAMBAH
            KartuKaca(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // PERBAIKAN: Menggunakan Wrap agar tidak Overflow di HP
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      const Text('Manajemen Pengguna', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      FilledButton.icon(
                        onPressed: () async {
                          await showDialog<void>(
                            context: context,
                            builder: (_) => FormPengguna(repository: widget.repository),
                          );
                          _muatUlang();
                        },
                        icon: const Icon(Icons.person_add),
                        label: const Text('Tambah'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Kelola hak akses penyuluh dan administrator. Semua perubahan akan langsung aktif.',
                    style: TextStyle(color: Colors.grey.shade800),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // LIST PENGGUNA
            if (users.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text('Belum ada data pengguna.'),
                ),
              )
            else
              Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: users.map((user) => ConstrainedBox(
                  // PERBAIKAN: Menggunakan ConstrainedBox agar kartu bisa mengecil di layar HP
                  constraints: const BoxConstraints(maxWidth: 450),
                  child: KartuKaca(
                    padding: const EdgeInsets.all(8),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: user.role == 'admin'
                              ? Colors.orange.withValues(alpha: 0.3)
                              : const Color(0xFF2E7D32).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          user.role == 'admin' ? Icons.admin_panel_settings : Icons.person,
                          color: user.role == 'admin' ? Colors.orange.shade900 : const Color(0xFF2E7D32),
                        ),
                      ),
                      title: Text(user.fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      subtitle: Text('${user.role == 'admin' ? 'Administrator' : 'Penyuluh'} ${user.nip == null || user.nip!.isEmpty ? '' : '• NIP ${user.nip}'}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            tooltip: 'Ubah Data',
                            onPressed: () async {
                              await showDialog<void>(
                                context: context,
                                builder: (_) => FormPengguna(user: user, repository: widget.repository),
                              );
                              _muatUlang();
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            tooltip: 'Hapus Pengguna',
                            onPressed: () => _hapusUser(user),
                          ),
                        ],
                      ),
                    ),
                  ),
                )).toList(),
              ),
          ],
        );
      },
    );
  }
}