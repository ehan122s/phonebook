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
import '../admin/halaman_admin.dart'; 

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
            return const Scaffold(
              body: LatarBelakangGradien(
                child: Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32))),
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
          child: Padding(
            padding: const EdgeInsets.all(24),
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
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
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
    // VARIABEL UNTUK MENYIMPAN MENU BERDASARKAN ROLE
    List<Widget> pages;
    List<String> titles;
    List<IconData> icons;
    Color warnaTema;

    // LOGIKA PEMBAGIAN ROLE (HAK AKSES)
    switch (user.role) {
      case 'admin':
        warnaTema = const Color(0xFF5D4037); // Coklat Kayu
        titles = ['Pusat Admin', 'Semua Kegiatan', 'Pengguna', 'Sistem'];
        icons = [Icons.admin_panel_settings, Icons.map_outlined, Icons.groups, Icons.account_tree_outlined];
        pages = [
          HalamanRingkasanAdmin(repository: _repository),
          HalamanKegiatan(repository: _repository),
          HalamanAdminPengguna(repository: _userRepository),
          const HalamanAdminKatalog(),
        ];
        break;

      case 'pengelola': // Pengelola Ekosistem Hutan
        warnaTema = const Color(0xFF00695C); // Hijau Teal (Nuansa Hutan Tropis)
        titles = ['Ekosistem', 'Peta Hutan', 'Laporan'];
        icons = [Icons.eco, Icons.map, Icons.analytics];
        pages = [
          HalamanRingkasanPengelola(repository: _repository),
          Center(child: KartuKaca(padding: const EdgeInsets.all(24), child: const Text('Peta Ekosistem (Segera Hadir)', style: TextStyle(fontSize: 18)))),
          Center(child: KartuKaca(padding: const EdgeInsets.all(24), child: const Text('Laporan Kerusakan', style: TextStyle(fontSize: 18)))),
        ];
        break;

      case 'penelaah': // Penelaah Teknis Kebijakan
        warnaTema = const Color(0xFF4527A0); // Ungu Kebijakan/Otoritas
        titles = ['Kebijakan', 'Arsip Laporan', 'Statistik'];
        icons = [Icons.gavel, Icons.folder_special, Icons.query_stats];
        pages = [
          HalamanRingkasanPenelaah(repository: _repository),
          Center(child: KartuKaca(padding: const EdgeInsets.all(24), child: const Text('Arsip Laporan Penyuluh', style: TextStyle(fontSize: 18)))),
          Center(child: KartuKaca(padding: const EdgeInsets.all(24), child: const Text('Statistik Kebijakan', style: TextStyle(fontSize: 18)))),
        ];
        break;

      case 'penyuluh': // Penyuluh Lapangan
      default:
        warnaTema = const Color(0xFF2E7D32); // Hijau Daun
        titles = ['Beranda Saya', 'Kegiatanku', 'Arsip'];
        icons = [Icons.home_filled, Icons.event_note_outlined, Icons.inventory_2_outlined];
        pages = [
          HalamanRingkasanPenyuluh(repository: _repository),
          HalamanKegiatan(repository: _repository),
          Center(child: KartuKaca(padding: const EdgeInsets.all(24), child: const Text('Arsip Pribadi', style: TextStyle(fontSize: 18)))),
        ];
        break;
    }

    // Cegah error index out of bounds jika ganti akun
    if (_index >= pages.length) _index = 0; 

    // Fokus UI Mobile
    return Scaffold(
      extendBody: true, 
      body: LatarBelakangGradien(
        child: Column(
          children: [
            // AppBar Custom Mobile
            Container(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 16, left: 24, right: 16, bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Halo, ${user.fullName.split(' ')[0]}!', style: TextStyle(fontSize: 16, color: Colors.grey.shade800, fontWeight: FontWeight.bold)),
                      Text(titles[_index], style: TextStyle(color: warnaTema, fontWeight: FontWeight.w900, fontSize: 24)),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Supabase.instance.client.auth.signOut(),
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.logout, color: Colors.red, size: 24),
                    ),
                  ),
                ],
              ),
            ),
            
            // Konten Halaman
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                child: Container(
                  color: Colors.white.withValues(alpha: 0.2), // Sedikit kontras
                  child: pages[_index],
                ),
              ),
            ),
          ],
        ),
      ),
      
      // Bottom Navigation Khusus Mobile (Sangat Nyaman untuk Jempol)
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.7), width: 1.5)),
            ),
            child: BottomNavigationBar(
              currentIndex: _index,
              onTap: (value) => setState(() => _index = value),
              backgroundColor: Colors.transparent,
              elevation: 0,
              type: BottomNavigationBarType.fixed, // Pastikan ikon tidak bergeser aneh
              selectedItemColor: warnaTema,
              unselectedItemColor: Colors.black45,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              items: [
                for (int i = 0; i < titles.length; i++)
                  BottomNavigationBarItem(
                    icon: Padding(padding: const EdgeInsets.only(bottom: 4), child: Icon(icons[i], size: 26)), 
                    label: titles[i]
                  ),
              ],
            ),
          ),
        ),
      ),
      
      // Tombol Tambah Kegiatan Khusus Penyuluh & Admin di Tab Kegiatan
      floatingActionButton: (_index == 1 && (user.role == 'penyuluh' || user.role == 'admin'))
          ? FloatingActionButton.extended(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => ActivityForm(repository: _repository),
              ),
              backgroundColor: warnaTema,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_location_alt),
              label: const Text('Buat Kegiatan', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }
}