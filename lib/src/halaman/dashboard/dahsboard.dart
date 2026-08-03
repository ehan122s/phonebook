import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';

import '../../models/app_user.dart';
import '../../services/activity_repository.dart';
import '../../services/user_repository.dart';

// Import halaman lain sesuaikan dengan struktur folder
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

  void _pindahTab(int indexBaru) {
    setState(() {
      _index = indexBaru;
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AppUser>(
        future: _userRepository.current(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              backgroundColor: Color(0xFFF4F7F6),
              body: Center(child: CircularProgressIndicator(color: Color(0xFF1B5E20))),
            );
          }
          if (snapshot.hasError) return _buildErrorState();
          return _buildContent(context, snapshot.data!);
        },
      );

  Widget _buildErrorState() {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.white, 
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 4))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 72, color: Colors.orange),
              const SizedBox(height: 24),
              const Text('Profil Belum Siap', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text('Terjadi kesalahan saat memuat data.', textAlign: TextAlign.center),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () => Supabase.instance.client.auth.signOut(),
                icon: const Icon(Icons.logout),
                label: const Text('Keluar & Masuk Lagi'),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1B5E20)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, AppUser user) {
    List<Widget> pages;
    List<String> titles;
    List<IconData> icons;
    Color warnaTema = const Color(0xFF1B5E20); 

    // LOGIKA ROLE
    switch (user.role) {
      case 'admin':
        titles = ['Beranda Admin', 'Semua Laporan', 'Pengguna', 'Pengaturan'];
        icons = [Icons.dashboard_outlined, Icons.map_outlined, Icons.people_outline, Icons.settings_outlined];
        pages = [
          const Center(key: ValueKey('admin_0'), child: Text('Dashboard Admin', style: TextStyle(fontSize: 24))),
          HalamanKegiatan(key: const ValueKey('admin_1'), repository: _repository),
          HalamanAdminPengguna(key: const ValueKey('admin_2'), repository: _userRepository),
          const HalamanAdminKatalog(key: ValueKey('admin_3')),
        ];
        break;
      case 'penyuluh':
      default:
        // MENU DIGABUNG JADI 3: Beranda, Laporan Kegiatan, Materi Edukasi
        titles = ['Beranda', 'Laporan Kegiatan', 'Materi Edukasi'];
        icons = [Icons.dashboard_rounded, Icons.description_rounded, Icons.menu_book_rounded];
        pages = [
          DashboardPenyuluhContent(
            key: const ValueKey('penyuluh_0'), 
            user: user, 
            repository: _repository,
            onNavigate: _pindahTab, 
          ),
          HalamanKegiatan(key: const ValueKey('penyuluh_1'), repository: _repository),
          const HalamanMateriEdukasi(key: ValueKey('penyuluh_2')), 
        ];
        break;
    }

    if (_index >= pages.length) _index = 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC), 
          body: Row(
            children: [
              // SIDEBAR DESKTOP
              if (isDesktop)
                Container(
                  width: 260,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(2, 0))],
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [warnaTema, Colors.green.shade400]), 
                                borderRadius: BorderRadius.circular(12)
                              ),
                              child: const Icon(Icons.home_work_rounded, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Text('SIMPUL', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: warnaTema, letterSpacing: 1.0)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: titles.length,
                          itemBuilder: (context, i) {
                            final isSelected = _index == i;
                            return Padding(
                              padding: const EdgeInsets.only(right: 16, bottom: 8),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => setState(() => _index = i),
                                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFFE8F5E9) : Colors.transparent,
                                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
                                      border: isSelected ? Border(right: BorderSide(color: warnaTema, width: 4)) : null,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(icons[i], color: isSelected ? warnaTema : Colors.grey.shade600, size: 22),
                                        const SizedBox(width: 16),
                                        Text(
                                          titles[i],
                                          style: TextStyle(
                                            color: isSelected ? warnaTema : Colors.grey.shade700,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(24),
                        child: OutlinedButton.icon(
                          onPressed: () => Supabase.instance.client.auth.signOut(),
                          icon: const Icon(Icons.logout_rounded, size: 20, color: Colors.redAccent),
                          label: const Text('Keluar Akun', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.red.shade100),
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            backgroundColor: Colors.red.shade50.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // KONTEN UTAMA
              Expanded(
                child: Column(
                  children: [
                    // HEADER MODERN
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(titles[_index], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                                  const SizedBox(height: 4),
                                  const Text('Kelola dan pantau kegiatan Anda hari ini.', style: TextStyle(fontSize: 13, color: Colors.grey)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50, 
                                borderRadius: BorderRadius.circular(30), 
                                border: Border.all(color: Colors.grey.shade200)
                              ),
                              child: Row(
                                children: [
                                  if (MediaQuery.of(context).size.width > 400) ...[
                                    const SizedBox(width: 12),
                                    Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF374151), fontSize: 14)),
                                    const SizedBox(width: 12),
                                  ],
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: warnaTema,
                                    child: Text(
                                      _getInitials(user.fullName),
                                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                  )
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                    
                    // ANIMASI GANTI TAB
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: pages[_index],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // NAVBAR MOBILE
          bottomNavigationBar: isDesktop ? null : Container(
            decoration: BoxDecoration(
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, -5))],
            ),
            child: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              backgroundColor: Colors.white,
              elevation: 0,
              indicatorColor: const Color(0xFFE8F5E9),
              animationDuration: const Duration(milliseconds: 400),
              destinations: [
                for (int i = 0; i < titles.length; i++)
                  NavigationDestination(
                    icon: Icon(icons[i], color: Colors.grey.shade400), 
                    selectedIcon: Icon(icons[i], color: warnaTema), 
                    label: titles[i]
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getInitials(String name) {
    List<String> names = name.split(" ");
    String initials = "";
    int numWords = names.length > 2 ? 2 : names.length;
    for (int i = 0; i < numWords; i++) {
      if (names[i].isNotEmpty) initials += names[i][0];
    }
    return initials.toUpperCase();
  }
}

// ============================================================================
// WIDGET KONTEN DASHBOARD PENYULUH (INDEX 0)
// ============================================================================

class DashboardPenyuluhContent extends StatelessWidget {
  final AppUser user;
  final ActivityRepository repository;
  final Function(int) onNavigate;

  const DashboardPenyuluhContent({super.key, required this.user, required this.repository, required this.onNavigate});

  void _tampilFormKegiatan(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => ActivityForm(repository: repository),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 650;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.all(isMobile ? 16 : 32), 
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // BANNER
              TweenAnimationBuilder(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) => Transform.scale(
                  scale: 0.95 + (0.05 * value),
                  child: Opacity(opacity: value, child: child),
                ),
                child: Container(
                  padding: EdgeInsets.all(isMobile ? 24 : 32),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: const Color(0xFF1B5E20).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
                  ),
                  child: isMobile ? _buildBannerMobile() : _buildBannerDesktop(),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // QUICK ACTION MENUS 
              if (isMobile)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MobileIconMenu(title: 'Isi\nLaporan', icon: Icons.add, iconColor: Colors.green.shade700, iconBg: Colors.green.shade50, onTap: () => _tampilFormKegiatan(context)),
                    _MobileIconMenu(title: 'Laporan\nSaya', icon: Icons.description_rounded, iconColor: Colors.blue.shade700, iconBg: Colors.blue.shade50, onTap: () => onNavigate(1)), // Index navigasi diupdate jadi 1
                    _MobileIconMenu(title: 'Materi\nEdukasi', icon: Icons.menu_book_rounded, iconColor: Colors.orange.shade700, iconBg: Colors.orange.shade50, onTap: () => onNavigate(2)), // Index navigasi diupdate jadi 2
                    _MobileIconMenu(title: 'Profil\nAkun', icon: Icons.person_rounded, iconColor: Colors.purple.shade700, iconBg: Colors.purple.shade50, onTap: () {}),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(child: _QuickActionCard(title: 'Isi Laporan', subtitle: 'Catat Laporan Baru', icon: Icons.add, iconColor: Colors.green.shade700, iconBg: const Color(0xFFE8F5E9), onTap: () => _tampilFormKegiatan(context))),
                    const SizedBox(width: 16),
                    Expanded(child: _QuickActionCard(title: 'Laporan Saya', subtitle: 'Riwayat Anda', icon: Icons.description_rounded, iconColor: Colors.blue.shade700, iconBg: const Color(0xFFE3F2FD), onTap: () => onNavigate(1))), // Index navigasi diupdate
                    const SizedBox(width: 16),
                    Expanded(child: _QuickActionCard(title: 'Materi', subtitle: 'Buku & Modul', icon: Icons.menu_book_rounded, iconColor: Colors.orange.shade700, iconBg: const Color(0xFFFFF3E0), onTap: () => onNavigate(2))), // Index navigasi diupdate
                    const SizedBox(width: 16),
                    Expanded(child: _QuickActionCard(title: 'Profil', subtitle: 'Pengaturan', icon: Icons.person_rounded, iconColor: Colors.purple.shade700, iconBg: const Color(0xFFF3E5F5), onTap: () {})),
                  ],
                ),

              const SizedBox(height: 32),

              _buildGrafikStatistik(isMobile),

              const SizedBox(height: 32),

              // TABEL KEGIATAN TERAKHIR
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 4))],
                ),
                child: LayoutBuilder( 
                  builder: (context, tableConstraints) {
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Laporan Terakhir', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                              TextButton(
                                onPressed: () => onNavigate(1), // Navigasi ke index 1 (Laporan Kegiatan)
                                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30)),
                                child: const Text('Semua →', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
                              )
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: SizedBox(
                            width: max(650.0, tableConstraints.maxWidth), 
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                  child: Row(
                                    children: [
                                      Expanded(flex: 2, child: Text('Tanggal', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 13))),
                                      Expanded(flex: 3, child: Text('Judul Kegiatan', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 13))),
                                      Expanded(flex: 2, child: Text('Kategori', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 13))),
                                      Expanded(flex: 2, child: Text('Status', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 13))),
                                      Expanded(flex: 1, child: Text('Unduh', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 13))),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1),
                                const _TableRow(tanggal: '23 Jul 2026', judul: 'Pendampingan KTH Mekar Sari', kategori: 'KTH', status: 'Selesai'),
                                const Divider(height: 1),
                                const _TableRow(tanggal: '20 Jul 2026', judul: 'Sosialisasi Pencegahan Karhutla', kategori: 'Perlindungan Hutan', status: 'Selesai'),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                ),
              )
            ],
          ),
        );
      }
    );
  }

  Widget _buildGrafikStatistik(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 20 : 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tren Laporan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
                child: const Text('Bulan Ini', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              )
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 200, 
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _ChartBar(label: 'Mg 1', height: 40, color: Colors.green.shade200),
                _ChartBar(label: 'Mg 2', height: 90, color: Colors.green.shade400),
                _ChartBar(label: 'Mg 3', height: 60, color: Colors.green.shade300),
                _ChartBar(label: 'Mg 4', height: 130, color: const Color(0xFF1B5E20)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildBannerDesktop() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Halo, ${user.fullName} 👋', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 12),
              Text(
                'Selamat bertugas hari ini! Kelola laporan lapangan, cek\nmateri penyuluhan terbaru, dan pantau riwayat kegiatan.',
                style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 16, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: const Column(
            children: [
              Text('Total Laporan Selesai', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              Text('3', style: TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBannerMobile() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Halo, ${user.fullName} 👋', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 12),
        Text(
          'Selamat bertugas hari ini! Kelola laporan dan pantau riwayat kegiatan Anda.',
          style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Laporan Selesai', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              Text('3', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// HALAMAN MATERI EDUKASI (INDEX 3 -> SEKARANG INDEX 2)
// ============================================================================
class HalamanMateriEdukasi extends StatelessWidget {
  const HalamanMateriEdukasi({super.key});

  void _showFormUpload(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upload Materi Baru', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TextField(decoration: InputDecoration(labelText: 'Judul Materi', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            const TextField(decoration: InputDecoration(labelText: 'Kategori (cth: Panduan, Jurnal)', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {}, 
              icon: const Icon(Icons.upload_file),
              label: const Text('Pilih File PDF/Word'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context), style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1B5E20)), child: const Text('Upload')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.orange.shade200)),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange.shade800),
                const SizedBox(width: 16),
                Expanded(child: Text('Temukan panduan, modul, dan jurnal kehutanan di sini. Anda juga dapat membagikan materi untuk pengguna lain.', style: TextStyle(color: Colors.orange.shade900))),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _MateriCard(judul: 'Panduan Budidaya Kopi Di Bawah Tegakan', penulis: 'Dinas Kehutanan', tipe: 'PDF', warna: Colors.red),
          const _MateriCard(judul: 'Modul Pencegahan Kebakaran Hutan 2026', penulis: 'KLHK Pusat', tipe: 'DOCX', warna: Colors.blue),
          const _MateriCard(judul: 'Teknik Pemetaan Partisipatif KTH', penulis: 'Budi Santoso', tipe: 'PDF', warna: Colors.red),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFormUpload(context),
        backgroundColor: const Color(0xFF1B5E20),
        icon: const Icon(Icons.cloud_upload, color: Colors.white),
        label: const Text('Upload Materi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _MateriCard extends StatelessWidget {
  final String judul;
  final String penulis;
  final String tipe;
  final Color warna;

  const _MateriCard({required this.judul, required this.penulis, required this.tipe, required this.warna});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: warna.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Text(tipe, style: TextStyle(color: warna, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
        title: Text(judul, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text('Oleh: $penulis', style: const TextStyle(fontSize: 13)),
        trailing: IconButton(
          icon: const Icon(Icons.download_rounded, color: Colors.grey),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Mengunduh $judul...')));
          },
        ),
      ),
    );
  }
}

// ============================================================================
// ANIMATED WIDGETS
// ============================================================================

class _ChartBar extends StatelessWidget {
  final String label;
  final double height;
  final Color color;

  const _ChartBar({required this.label, required this.height, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TweenAnimationBuilder(
          tween: Tween<double>(begin: 0, end: height),
          duration: const Duration(milliseconds: 1200),
          curve: Curves.easeOutQuart,
          builder: (context, value, child) {
            return Container(
              width: 36,
              height: value,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// CART MENU DESKTOP YANG DIBIKIN HALUS
class _QuickActionCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final VoidCallback onTap;

  const _QuickActionCard({required this.title, required this.subtitle, required this.icon, required this.iconColor, required this.iconBg, required this.onTap});

  @override
  State<_QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<_QuickActionCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap(); 
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1.0, 
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: _isPressed
                ? [BoxShadow(color: widget.iconColor.withOpacity(0.1), blurRadius: 5, offset: const Offset(0, 2))]
                : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 6))],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: widget.iconBg, shape: BoxShape.circle),
                child: Icon(widget.icon, color: widget.iconColor, size: 28),
              ),
              const SizedBox(height: 16),
              Text(widget.title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1F2937))),
              const SizedBox(height: 4),
              Text(widget.subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileIconMenu extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final VoidCallback onTap;

  const _MobileIconMenu({required this.title, required this.icon, required this.iconColor, required this.iconBg, required this.onTap});

  @override
  State<_MobileIconMenu> createState() => _MobileIconMenuState();
}

class _MobileIconMenuState extends State<_MobileIconMenu> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap(); 
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.85 : 1.0, 
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutBack, 
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: widget.iconBg, 
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: widget.iconBg.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Icon(widget.icon, color: widget.iconColor, size: 28),
              ),
              const SizedBox(height: 10),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF374151), height: 1.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  final String tanggal;
  final String judul;
  final String kategori;
  final String status;

  const _TableRow({required this.tanggal, required this.judul, required this.kategori, required this.status});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {}, 
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Expanded(flex: 2, child: Text(tanggal, style: const TextStyle(color: Colors.black87, fontSize: 14))),
              Expanded(flex: 3, child: Text(judul, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87, fontSize: 14))),
              Expanded(flex: 2, child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                  child: Text(kategori, style: TextStyle(color: Colors.grey.shade800, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              )),
              Expanded(flex: 2, child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
                  child: Text(status, style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              )),
              Expanded(flex: 1, child: Align(
                alignment: Alignment.center,
                child: IconButton(
                  icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 22),
                  tooltip: 'Unduh Laporan PDF',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sedang menyiapkan PDF: $judul...')));
                  },
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }
}