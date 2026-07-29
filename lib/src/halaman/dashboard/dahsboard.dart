import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/app_user.dart';
import '../../services/activity_repository.dart';
import '../../services/user_repository.dart';
import '../../widgets/glashmorp.dart';

import 'ringkasan.dart';
import '../kegiatan/halaman_kegiatan.dart';
import '../kegiatan/widgets/form_kegiatan.dart';

// PENTING: Buka komentar (uncomment) dan sesuaikan path import ini 
// agar mengarah ke file tempat class HalamanAdminPengguna dan Katalog berada.
import '../admin/halaman_admin_pengguna.dart'; 
import '../admin/halaman_admin.dart' hide HalamanAdminPengguna; 

class HalamanDashboard extends StatefulWidget {
  const HalamanDashboard({super.key});
  @override
  State<HalamanDashboard> createState() => _HalamanDashboardState();
}

class _HalamanDashboardState extends State<HalamanDashboard> {
  late final ActivityRepository _repository;
  late final UserRepository _userRepository;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _repository = ActivityRepository(Supabase.instance.client);
    _userRepository = UserRepository(Supabase.instance.client);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AppUser>(
        future: _userRepository.current(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Scaffold(
              body: LatarBelakangGradien(
                child: const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32))),
              ),
            );
          }
          if (snapshot.hasError) return _buildErrorState();
          return _buildContent(context, snapshot.data!);
        },
      );

  Widget _buildErrorState() {
    return Scaffold(
      body: LatarBelakangGradien(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: KartuKaca(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, size: 54, color: Colors.orange),
                  const SizedBox(height: 16),
                  const Text('Profil Belum Siap', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => Supabase.instance.client.auth.signOut(),
                    icon: const Icon(Icons.logout),
                    label: const Text('Keluar & Masuk Lagi'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, AppUser user) {
    final isAdmin = user.role == 'admin';
    
    // DI SINI PERBAIKANNYA: Mengganti teks dummy dengan Class Halaman asli
    final pages = [
      HalamanRingkasan(repository: _repository),
      HalamanKegiatan(repository: _repository),
      const Center(child: KartuKaca(padding: EdgeInsets.all(24), child: Text('Halaman Arsip', style: TextStyle(fontSize: 20)))),
      if (isAdmin) HalamanAdminPengguna(repository: _userRepository), // Memanggil class asli
      if (isAdmin) const HalamanAdminKatalog(), // Memanggil class asli
    ];
    
    final titles = ['Beranda', 'Kegiatan', 'Arsip', if (isAdmin) 'Pengguna', if (isAdmin) 'Referensi'];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 860;

        return Scaffold(
          extendBody: true, // Penting agar gradien tembus ke bawah BottomNav
          body: LatarBelakangGradien(
            child: Row(
              children: [
                if (isDesktop) ...[
                  // Sidebar Glassmorphism
                  ClipRRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        width: 250,
                        color: Colors.white.withValues(alpha: 0.3),
                        child: Column(
                          children: [
                            const SizedBox(height: 48),
                            const Icon(Icons.forest, color: Color(0xFF2E7D32), size: 48),
                            const SizedBox(height: 12),
                            const Text('SIPENYULUH', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 48),
                            for (int i = 0; i < titles.length; i++)
                              ListTile(
                                leading: Icon(_getIcon(i), color: _index == i ? const Color(0xFF2E7D32) : Colors.black54),
                                title: Text(titles[i], style: TextStyle(fontWeight: _index == i ? FontWeight.bold : FontWeight.normal, color: _index == i ? const Color(0xFF2E7D32) : Colors.black87)),
                                selected: _index == i,
                                selectedTileColor: Colors.white.withValues(alpha: 0.5),
                                onTap: () => setState(() => _index = i),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                              ),
                            const Spacer(),
                            ListTile(
                              leading: const Icon(Icons.logout, color: Colors.red),
                              title: const Text('Keluar'),
                              onTap: () => Supabase.instance.client.auth.signOut(),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(width: 1, color: Colors.white.withValues(alpha: 0.4)),
                ],
                
                // Konten Utama
                Expanded(
                  child: Column(
                    children: [
                      if (!isDesktop)
                        AppBar(
                          title: Text(titles[_index]),
                          actions: [
                            IconButton(
                              onPressed: () => Supabase.instance.client.auth.signOut(),
                              icon: const Icon(Icons.logout),
                            ),
                          ],
                        ),
                      if (isDesktop)
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(titles[_index], style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      // Merender halaman sesuai indeks yang dipilih
                      Expanded(child: pages[_index]),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Bottom Navigation Glassmorphism untuk Mobile
          bottomNavigationBar: isDesktop ? null : ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.4),
                  border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.5), width: 1)),
                ),
                child: BottomNavigationBar(
                  currentIndex: _index,
                  onTap: (value) => setState(() => _index = value),
                  backgroundColor: Colors.transparent, // Penting
                  elevation: 0,
                  type: BottomNavigationBarType.fixed,
                  selectedItemColor: const Color(0xFF2E7D32),
                  unselectedItemColor: Colors.black54,
                  items: [
                    for (int i = 0; i < titles.length; i++)
                      BottomNavigationBarItem(icon: Icon(_getIcon(i)), label: titles[i]),
                  ],
                ),
              ),
            ),
          ),
          
          floatingActionButton: _index == 1
              ? FloatingActionButton.extended(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => ActivityForm(repository: _repository),
                  ),
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add),
                  label: const Text('Buat Kegiatan'),
                )
              : null,
        );
      },
    );
  }

  IconData _getIcon(int index) {
    const icons = [Icons.dashboard_outlined, Icons.event_note_outlined, Icons.inventory_2_outlined, Icons.people_outline, Icons.tune_outlined];
    return icons[index];
  }
}