import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../../models/app_user.dart';
import '../../services/activity_repository.dart';
import '../../services/user_repository.dart';

// Import widget kaca kita
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
                child: Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32), strokeWidth: 4)),
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
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, size: 72, color: Colors.orange),
                  const SizedBox(height: 24),
                  const Text('Profil Belum Siap', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF3E2723))),
                  const SizedBox(height: 16),
                  const Text('Terjadi kesalahan saat memuat data. Silakan coba masuk kembali.', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: Colors.black87)),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: () => Supabase.instance.client.auth.signOut(),
                    icon: const Icon(Icons.logout, size: 28),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                      child: Text('Keluar & Masuk Lagi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                    ),
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
    List<Widget> pages;
    List<String> titles;
    List<IconData> icons;
    Color warnaTema;

    // LOGIKA ROLE DENGAN WARNA TEGAS & BAPAK-BAPAK FRIENDLY
    switch (user.role) {
      case 'admin':
        warnaTema = const Color(0xFF1B5E20); // Hijau Sangat Tua (Mewah)
        titles = ['Pusat Admin', 'Semua Kegiatan', 'Pengguna', 'Sistem'];
        icons = [Icons.dashboard_rounded, Icons.map_rounded, Icons.groups_rounded, Icons.settings_suggest_rounded];
        pages = [
          HalamanRingkasanAdmin(repository: _repository, user: user),
          HalamanKegiatan(repository: _repository),
          HalamanAdminPengguna(repository: _userRepository),
          const HalamanAdminKatalog(),
        ];
        break;

      case 'pengelola':
        warnaTema = const Color(0xFF00695C); // Emerald Gelap
        titles = ['Ekosistem', 'Peta Hutan', 'Laporan'];
        icons = [Icons.eco_rounded, Icons.map_rounded, Icons.analytics_rounded];
        pages = [
          Center(child: KartuKaca(padding: const EdgeInsets.all(24), child: const Text('Dashboard Pengelola', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)))),
          Center(child: KartuKaca(padding: const EdgeInsets.all(24), child: const Text('Peta Ekosistem', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)))),
          Center(child: KartuKaca(padding: const EdgeInsets.all(24), child: const Text('Laporan Kerusakan', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)))),
        ];
        break;

      case 'penelaah':
        warnaTema = const Color(0xFF4E342E); // Coklat Kayu Tua
        titles = ['Kebijakan', 'Arsip Laporan', 'Statistik'];
        icons = [Icons.gavel_rounded, Icons.folder_special_rounded, Icons.query_stats_rounded];
        pages = [
          Center(child: KartuKaca(padding: const EdgeInsets.all(24), child: const Text('Dashboard Penelaah', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)))),
          Center(child: KartuKaca(padding: const EdgeInsets.all(24), child: const Text('Arsip Laporan', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)))),
          Center(child: KartuKaca(padding: const EdgeInsets.all(24), child: const Text('Statistik Kebijakan', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)))),
        ];
        break;

      case 'penyuluh':
      default:
        warnaTema = const Color(0xFF2E7D32); // Hijau Daun Terang
        titles = ['Beranda Saya', 'Kegiatanku', 'Arsip'];
        icons = [Icons.home_rounded, Icons.event_note_rounded, Icons.inventory_2_rounded];
        pages = [
          HalamanRingkasanPenyuluh(repository: _repository, user: user),
          HalamanKegiatan(repository: _repository),
          Center(child: KartuKaca(padding: const EdgeInsets.all(24), child: const Text('Arsip Pribadi', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)))),
        ];
        break;
    }

    if (_index >= pages.length) _index = 0; 

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 860;

        return Scaffold(
          extendBody: true, 
          // MENGGUNAKAN LATAR BELAKANG GRADIEN KACA LAGI
          body: LatarBelakangGradien(
            child: Row(
              children: [
                // SIDEBAR DESKTOP DENGAN EFEK KACA MEWAH
                if (isDesktop) ...[
                  ClipRRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        width: 280,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.4),
                          border: Border(right: BorderSide(color: Colors.white.withOpacity(0.6), width: 1)),
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 56),
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: warnaTema.withOpacity(0.15), 
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                              ),
                              child: Icon(Icons.park_rounded, color: warnaTema, size: 56),
                            ),
                            const SizedBox(height: 16),
                            Text('SIMPUL', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 2.0, color: warnaTema)),
                            Text('Sistem Informasi Penyuluh', style: TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 48),
                            Expanded(
                              child: ListView.builder(
                                itemCount: titles.length,
                                itemBuilder: (context, i) {
                                  final isSelected = _index == i;
                                  return Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isSelected ? Colors.white.withOpacity(0.7) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(16),
                                      border: isSelected ? Border.all(color: Colors.white, width: 1.5) : null,
                                      boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)] : null,
                                    ),
                                    child: ListTile(
                                      leading: Icon(icons[i], color: isSelected ? warnaTema : Colors.black87, size: 28),
                                      title: Text(titles[i], style: TextStyle(fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700, fontSize: 16, color: isSelected ? warnaTema : Colors.black87)),
                                      selected: isSelected,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      onTap: () => setState(() => _index = i),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                    ),
                                  );
                                }
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.all(24),
                              decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.red.withOpacity(0.3))),
                              child: ListTile(
                                leading: const Icon(Icons.power_settings_new_rounded, color: Colors.redAccent, size: 28),
                                title: const Text('Keluar Aplikasi', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.redAccent, fontSize: 16)),
                                onTap: () => Supabase.instance.client.auth.signOut(),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                
                // MAIN CONTENT
                Expanded(
                  child: Column(
                    children: [
                      // CUSTOM HEADER MOBILE DENGAN EFEK KACA
                      if (!isDesktop)
                        ClipRRect(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                            child: Container(
                              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 16, left: 24, right: 16, bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.5),
                                border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.5))),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(titles[_index], style: TextStyle(color: warnaTema, fontWeight: FontWeight.w900, fontSize: 26)),
                                      const SizedBox(height: 4),
                                      Text(DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(DateTime.now()), style: const TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w800)),
                                    ],
                                  ),
                                  IconButton(
                                    onPressed: () => Supabase.instance.client.auth.signOut(),
                                    icon: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), shape: BoxShape.circle),
                                      child: const Icon(Icons.logout_rounded, color: Colors.red, size: 26),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      
                      // HEADER DESKTOP
                      if (isDesktop)
                        Container(
                          padding: const EdgeInsets.only(left: 40, top: 40, right: 40, bottom: 20),
                          child: Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(titles[_index], style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: warnaTema)),
                                  const SizedBox(height: 8),
                                  Text(DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(DateTime.now()), style: const TextStyle(fontSize: 18, color: Colors.black87, fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                      // PAGE RENDERER
                      Expanded(
                        child: ClipRRect(
                          child: pages[_index],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // BOTTOM NAV MOBILE (EFEK KACA MEWAH)
          bottomNavigationBar: isDesktop ? null : ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.6),
                  border: Border(top: BorderSide(color: Colors.white.withOpacity(0.8), width: 1.5)),
                ),
                child: BottomNavigationBar(
                  currentIndex: _index,
                  onTap: (value) => setState(() => _index = value),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  type: BottomNavigationBarType.fixed,
                  selectedItemColor: warnaTema,
                  unselectedItemColor: Colors.black54,
                  selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, height: 1.5),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, height: 1.5),
                  items: [
                    for (int i = 0; i < titles.length; i++)
                      BottomNavigationBarItem(
                        icon: Padding(
                          padding: const EdgeInsets.only(bottom: 6, top: 8), 
                          child: Icon(icons[i], size: _index == i ? 30 : 26)
                        ), 
                        label: titles[i]
                      ),
                  ],
                ),
              ),
            ),
          ),
          
          // FAB
          floatingActionButton: (_index == 1 && (user.role == 'penyuluh' || user.role == 'admin'))
              ? FloatingActionButton.extended(
                  onPressed: () => showDialog(context: context, builder: (_) => ActivityForm(repository: _repository)),
                  backgroundColor: warnaTema,
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withOpacity(0.5), width: 1.5)),
                  icon: const Icon(Icons.add_location_alt_rounded, color: Colors.white, size: 28),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text('Buat Kegiatan Baru', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 16)),
                  ),
                )
              : null,
        );
      },
    );
  }
}