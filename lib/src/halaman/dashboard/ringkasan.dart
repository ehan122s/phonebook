import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/activity.dart';
import '../../models/app_user.dart';
import '../../services/offline_activity_repository.dart';
import '../../services/user_repository.dart';
import '../../services/category_repository.dart';
import '../../services/template_repository.dart';
import '../../widgets/glashmorp.dart';
import '../kegiatan/halaman_kegiatan.dart';
import '../kegiatan/widgets/form_kegiatan.dart';
import '../profil/halaman_profil.dart';
import '../materi/halaman_materi.dart';
import '../admin/halaman_admin.dart' show HalamanAdminKatalog;
import '../admin/halaman_admin_pengguna.dart';
import '../admin/halaman_admin_template_laporan.dart'; // BARU

// ========================================================
// 1. DASHBOARD KHUSUS ADMIN (SISTEM)
// Tema: Mewah, Glassmorphism, 100% Mobile Responsive
// ========================================================
class HalamanRingkasanAdmin extends StatefulWidget {
  const HalamanRingkasanAdmin({super.key, required this.repository, required this.user, required this.userRepository});
  final OfflineActivityRepository repository;
  final AppUser user;
  final UserRepository userRepository;

  @override
  State<HalamanRingkasanAdmin> createState() => _HalamanRingkasanAdminState();
}

class _HalamanRingkasanAdminState extends State<HalamanRingkasanAdmin> {
  late final CategoryRepository _categoryRepo;
  late final TemplateRepository _templateRepo;
  late Future<_AdminData> _future;

  @override
  void initState() {
    super.initState();
    _categoryRepo = CategoryRepository(Supabase.instance.client);
    _templateRepo = TemplateRepository(Supabase.instance.client);
    _future = _load();
  }

  Future<_AdminData> _load() async {
    final results = await Future.wait([
      widget.repository.list(),
      widget.userRepository.list(),
      _categoryRepo.list(),
      _templateRepo.list(),
    ]);
    return _AdminData(
      activities: results[0] as List<Activity>,
      users: results[1] as List<AppUser>,
      categoryCount: (results[2] as List).length,
      templateCount: (results[3] as List).length,
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;

    return RefreshIndicator(
      color: const Color(0xFF1B5E20),
      onRefresh: _refresh,
      child: FutureBuilder<_AdminData>(
        future: _future,
        builder: (_, snapshot) {
          final isLoading = snapshot.connectionState == ConnectionState.waiting;
          final data = snapshot.data;
          final items = data?.activities ?? const <Activity>[];
          final users = data?.users ?? const <AppUser>[];
          final today = DateTime.now();
          final giatHariIni = items.where((a) =>
              a.activityDate.year == today.year &&
              a.activityDate.month == today.month &&
              a.activityDate.day == today.day).length;
          final penyuluhAktif = users.where((u) => u.role == 'penyuluh').length;
          final terbaru = items.take(5).toList();

          return ListView(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32, vertical: 24),
            children: [
              // 1. HEADER WELCOME CARD KACA
              KartuKaca(
                padding: EdgeInsets.all(isMobile ? 24 : 32),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(isMobile ? 12 : 16),
                      decoration: BoxDecoration(color: const Color(0xFF1B5E20).withOpacity(0.15), shape: BoxShape.circle),
                      child: Icon(Icons.shield_rounded, color: const Color(0xFF1B5E20), size: isMobile ? 40 : 48),
                    ),
                    SizedBox(width: isMobile ? 16 : 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Halo, ${widget.user.fullName.split(' ')[0]} 👋', style: TextStyle(fontSize: isMobile ? 24 : 28, fontWeight: FontWeight.w900, color: const Color(0xFF1B5E20))),
                          const SizedBox(height: 8),
                          Text('Pusat Administrasi SIMPUL', style: TextStyle(fontSize: isMobile ? 14 : 18, color: Colors.black87, fontWeight: FontWeight.w600, height: 1.4)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: isMobile ? 24 : 40),

              // 2. JALAN PINTAS (navigasi nyata ke halaman admin lain)
              const SectionTitle('Jalan Pintas Administrasi'),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    QuickActionBtn(
                      icon: Icons.person_add_alt_1_rounded,
                      label: 'Tambah\nPengguna',
                      color: const Color(0xFF047857),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('Pengguna'), backgroundColor: const Color(0xFF1B5E20), foregroundColor: Colors.white),
                        body: LatarBelakangGradien(child: HalamanAdminPengguna(repository: widget.userRepository)),
                      ))).then((_) => _refresh()),
                    ),
                    QuickActionBtn(
                      icon: Icons.category_rounded,
                      label: 'Kelola\nKategori',
                      color: const Color(0xFF1D4ED8),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('Referensi Sistem'), backgroundColor: const Color(0xFF1B5E20), foregroundColor: Colors.white),
                        body: LatarBelakangGradien(child: const HalamanAdminKatalog()),
                      ))).then((_) => _refresh()),
                    ),
                    QuickActionBtn(
                      icon: Icons.menu_book_rounded,
                      label: 'Materi\nEdukasi',
                      color: const Color(0xFFD97706),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HalamanMateriEdukasi())),
                    ),
                    QuickActionBtn(
                      icon: Icons.map_rounded,
                      label: 'Semua\nKegiatan',
                      color: const Color(0xFF5D4037),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('Semua Kegiatan'), backgroundColor: const Color(0xFF1B5E20), foregroundColor: Colors.white),
                        body: LatarBelakangGradien(child: HalamanKegiatan(repository: widget.repository)),
                      ))).then((_) => _refresh()),
                    ),
                    // BARU — jalan pintas ke halaman kelola Template Laporan
                    QuickActionBtn(
                      icon: Icons.description_rounded,
                      label: 'Template\nLaporan',
                      color: const Color(0xFF7B1FA2),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const HalamanAdminTemplateLaporan()),
                      ).then((_) => _refresh()),
                    ),
                  ],
                ),
              ),
              SizedBox(height: isMobile ? 24 : 40),

              // 3. STATISTIK UTAMA (data asli dari Supabase)
              const SectionTitle('Rekapitulasi Data Sistem'),
              GridView.count(
                crossAxisCount: isMobile ? 2 : 4,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: isMobile ? 1.0 : 1.4,
                children: [
                  StatCard(label: 'Total Pengguna', value: isLoading ? '-' : '${users.length}', icon: Icons.groups_rounded, color: const Color(0xFF2E7D32)),
                  StatCard(label: 'Penyuluh Aktif', value: isLoading ? '-' : '$penyuluhAktif', icon: Icons.nature_people_rounded, color: const Color(0xFF047857)),
                  StatCard(label: 'Total Laporan', value: isLoading ? '-' : '${items.length}', icon: Icons.description_rounded, color: const Color(0xFFD97706)),
                  StatCard(label: 'Giat Hari Ini', value: isLoading ? '-' : '$giatHariIni', icon: Icons.today_rounded, color: const Color(0xFF2563EB)),
                ],
              ),
              SizedBox(height: isMobile ? 24 : 40),

              // 4. CHART & AKTIVITAS TERBARU (data asli)
              Wrap(
                spacing: 24,
                runSpacing: 24,
                children: [
                  SizedBox(
                    width: isMobile ? double.infinity : 500,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionTitle('Grafik Kegiatan per Bulan (Tahun Berjalan)'),
                        KartuKaca(
                          padding: EdgeInsets.all(isMobile ? 16 : 24),
                          child: SizedBox(
                            height: isMobile ? 220 : 280,
                            child: isLoading
                                ? const Center(child: CircularProgressIndicator(color: Color(0xFF1B5E20)))
                                : GrafikKegiatan(items: items, warnaBar: const Color(0xFF1B5E20)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: isMobile ? double.infinity : 400,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionTitle('Kegiatan Lapangan Terbaru'),
                        KartuKaca(
                          padding: const EdgeInsets.all(20),
                          child: isLoading
                              ? const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: Color(0xFF1B5E20))))
                              : terbaru.isEmpty
                                  ? const Padding(padding: EdgeInsets.all(12), child: Text('Belum ada kegiatan tercatat.', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700)))
                                  : Column(
                                      children: [
                                        for (var i = 0; i < terbaru.length; i++)
                                          TimelineItem(
                                            title: '${terbaru[i].creatorName ?? 'Penyuluh'} • ${terbaru[i].title}',
                                            time: DateFormat('dd MMM yyyy', 'id_ID').format(terbaru[i].activityDate),
                                            icon: Icons.event_available_rounded,
                                            color: const Color(0xFF2E7D32),
                                            isLast: i == terbaru.length - 1,
                                          ),
                                      ],
                                    ),
                        ),
                        const SizedBox(height: 24),
                        const SectionTitle('Status Sistem'),
                        KartuKaca(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              const SystemInfoRow(label: 'Koneksi Server', value: 'Online', isStatus: true),
                              const Divider(height: 24, color: Colors.black12),
                              SystemInfoRow(label: 'Kategori Kegiatan Aktif', value: isLoading ? '-' : '${data?.categoryCount ?? 0}'),
                              const Divider(height: 24, color: Colors.black12),
                              SystemInfoRow(label: 'Template Laporan Tersimpan', value: isLoading ? '-' : '${data?.templateCount ?? 0}'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }
}

class _AdminData {
  const _AdminData({required this.activities, required this.users, required this.categoryCount, required this.templateCount});
  final List<Activity> activities;
  final List<AppUser> users;
  final int categoryCount;
  final int templateCount;
}

// ========================================================
// 2. DASHBOARD PENYULUH (Tema Hijau Hutan & Personal)
// ========================================================
class HalamanRingkasanPenyuluh extends StatefulWidget {
  const HalamanRingkasanPenyuluh({super.key, required this.repository, required this.user});
  final OfflineActivityRepository repository;
  final AppUser user;

  @override
  State<HalamanRingkasanPenyuluh> createState() => _HalamanRingkasanPenyuluhState();
}

class _HalamanRingkasanPenyuluhState extends State<HalamanRingkasanPenyuluh> {
  late Future<List<Activity>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.list();
  }

  Future<void> _refresh() async {
    setState(() => _future = widget.repository.list());
  }

  Future<void> _openIsiLaporan(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (_) => ActivityForm(repository: widget.repository),
    );
    _refresh();
  }

  void _openLaporanSaya(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: const Text('Laporan Saya', style: TextStyle(fontWeight: FontWeight.w900)),
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
          ),
          body: LatarBelakangGradien(
            child: HalamanKegiatan(repository: widget.repository),
          ),
        ),
      ),
    ).then((_) => _refresh());
  }

  void _openMateri(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const HalamanMateriEdukasi()));
  }

  void _openProfil(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => HalamanProfil(user: widget.user)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;

    return RefreshIndicator(
      color: const Color(0xFF2E7D32),
      onRefresh: _refresh,
      child: FutureBuilder<List<Activity>>(
        future: _future,
        builder: (context, snapshot) {
          final isLoading = snapshot.connectionState == ConnectionState.waiting;
          final hasError = snapshot.hasError;
          final items = snapshot.data ?? const <Activity>[];
          final totalLaporan = items.length;
          final terbaru = items.take(5).toList();

          return ListView(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 16),
            children: [
              // 1. BANNER SAMBUTAN + TOTAL LAPORAN (sesuai referensi desain)
              KartuKaca(
                padding: EdgeInsets.all(isMobile ? 20 : 32),
                child: Flex(
                  direction: isMobile ? Axis.vertical : Axis.horizontal,
                  crossAxisAlignment: isMobile ? CrossAxisAlignment.stretch : CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: isMobile ? 0 : 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Halo, ${widget.user.fullName} 👋',
                              style: TextStyle(fontSize: isMobile ? 22 : 28, fontWeight: FontWeight.w900, color: const Color(0xFF1B5E20))),
                          const SizedBox(height: 8),
                          Text(
                            'Selamat bertugas hari ini! Kelola laporan lapangan, cek materi penyuluhan terbaru, dan pantau riwayat kegiatan dengan mudah.',
                            style: TextStyle(fontSize: isMobile ? 14 : 16, color: Colors.black87, fontWeight: FontWeight.w600, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: isMobile ? 20 : 0, width: isMobile ? 0 : 24),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Total Laporan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.black87)),
                          const SizedBox(height: 4),
                          isLoading
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 6),
                                  child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF2E7D32))),
                                )
                              : Text('$totalLaporan', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 32, color: Color(0xFF1B5E20))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: isMobile ? 24 : 32),

              // 2. AKSI CEPAT (Isi Laporan, Laporan Saya, Materi, Profil)
              GridView.count(
                crossAxisCount: isMobile ? 2 : 4,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: isMobile ? 1.05 : 1.15,
                children: [
                  _AksiCepatKaca(
                    icon: Icons.add_rounded,
                    label: 'Isi Laporan',
                    sublabel: 'Laporan Kegiatan Baru',
                    color: const Color(0xFF2E7D32),
                    onTap: () => _openIsiLaporan(context),
                  ),
                  _AksiCepatKaca(
                    icon: Icons.description_rounded,
                    label: 'Laporan Saya',
                    sublabel: 'Riwayat Kegiatan',
                    color: const Color(0xFF1D4ED8),
                    onTap: () => _openLaporanSaya(context),
                  ),
                  _AksiCepatKaca(
                    icon: Icons.menu_book_rounded,
                    label: 'Materi',
                    sublabel: 'Buku & Modul',
                    color: const Color(0xFFD97706),
                    onTap: () => _openMateri(context),
                  ),
                  _AksiCepatKaca(
                    icon: Icons.person_rounded,
                    label: 'Profil',
                    sublabel: 'Pengaturan Akun',
                    color: const Color(0xFF7B1FA2),
                    onTap: () => _openProfil(context),
                  ),
                ],
              ),
              SizedBox(height: isMobile ? 24 : 32),

              // 3. TABEL KEGIATAN TERAKHIR (data asli dari Supabase)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SectionTitle('5 Kegiatan Terakhir Anda'),
                  TextButton(
                    onPressed: () => _openLaporanSaya(context),
                    child: const Text('Lihat Semua →', style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
              if (hasError)
                KartuKaca(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.cloud_off, color: Colors.orange, size: 40),
                      const SizedBox(height: 12),
                      const Text('Gagal memuat kegiatan. Tarik ke bawah untuk mencoba lagi.', textAlign: TextAlign.center),
                    ],
                  ),
                )
              else if (isLoading)
                const KartuKaca(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32))),
                )
              else if (terbaru.isEmpty)
                const KartuKaca(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text('Belum ada kegiatan tercatat. Ketuk "Isi Laporan" untuk membuat yang pertama.',
                        textAlign: TextAlign.center, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black54)),
                  ),
                )
              else
                KartuKaca(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      for (var i = 0; i < terbaru.length; i++) ...[
                        _BarisKegiatan(activity: terbaru[i]),
                        if (i != terbaru.length - 1) const Divider(height: 1, color: Colors.black12, indent: 16, endIndent: 16),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 80), // Biar gak nabrak tombol Nav bar bawah
            ],
          );
        },
      ),
    );
  }
}

class _AksiCepatKaca extends StatelessWidget {
  const _AksiCepatKaca({required this.icon, required this.label, required this.sublabel, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: KartuKaca(
        padding: EdgeInsets.symmetric(vertical: isMobile ? 16 : 20, horizontal: 8),
        // FITTEDBOX DITAMBAHKAN DI SINI
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: isMobile ? 26 : 30),
              ),
              const SizedBox(height: 12),
              Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: isMobile ? 14 : 15, fontWeight: FontWeight.w900, color: Colors.black87)),
              const SizedBox(height: 2),
              Text(sublabel, textAlign: TextAlign.center, style: TextStyle(fontSize: isMobile ? 11 : 12, fontWeight: FontWeight.w600, color: Colors.black54)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarisKegiatan extends StatelessWidget {
  const _BarisKegiatan({required this.activity});
  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;
    final isSelesai = (activity.status ?? 'draft') != 'draft';
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0xFF2E7D32).withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.event_note_rounded, color: Color(0xFF2E7D32), size: 22),
      ),
      title: Text(activity.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.black87)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          '${DateFormat('dd MMM yyyy', 'id_ID').format(activity.activityDate)} • ${activity.categoryName}',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: (isSelesai ? Colors.green : Colors.orange).withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          isSelesai ? 'Selesai' : 'Draft',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: isSelesai ? Colors.green.shade800 : Colors.orange.shade800),
        ),
      ),
    );
  }
}

// ========================================================
// WIDGET UI KACA (MOBILE OPTIMIZED)
// ========================================================

class SectionTitle extends StatelessWidget {
  final String title;
  const SectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 4),
      child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF3E2723))),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.label, required this.value, required this.icon, required this.color});
  final String label, value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Mengecek apakah dibuka di HP
    final isMobile = MediaQuery.of(context).size.width < 600;

    return KartuKaca(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      // FITTEDBOX DITAMBAHKAN DI SINI
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(isMobile ? 10 : 14),
              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(isMobile ? 12 : 16)),
              child: Icon(icon, color: color, size: isMobile ? 28 : 36),
            ),
            const SizedBox(height: 24),
            Text(value, style: TextStyle(fontSize: isMobile ? 28 : 38, fontWeight: FontWeight.w900, color: Colors.black87, height: 1.2)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: isMobile ? 13 : 16, color: Colors.grey.shade800, fontWeight: FontWeight.w800), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class QuickActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const QuickActionBtn({super.key, required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: KartuKaca(
          width: 120, // Diperkecil dikit agar muat banyak di scroll HP
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 36)
              ),
              const SizedBox(height: 12),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black87, height: 1.3)),
            ],
          ),
        ),
      ),
    );
  }
}

class TimelineItem extends StatelessWidget {
  final String title, time;
  final IconData icon;
  final Color color;
  final bool isLast;

  const TimelineItem({super.key, required this.title, required this.time, required this.icon, required this.color, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20),
            ),
            if (!isLast)
              Container(width: 2, height: 32, color: Colors.black12, margin: const EdgeInsets.symmetric(vertical: 6)),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.black87)),
                const SizedBox(height: 4),
                Text(time, style: TextStyle(color: Colors.grey[700], fontSize: 13, fontWeight: FontWeight.w700)),
                if (!isLast) const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class SystemInfoRow extends StatelessWidget {
  final String label, value;
  final bool isStatus;

  const SystemInfoRow({super.key, required this.label, required this.value, this.isStatus = false});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[800], fontSize: isMobile ? 14 : 16, fontWeight: FontWeight.w700)),
        if (isStatus)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                const Icon(Icons.circle, color: Colors.green, size: 10),
                const SizedBox(width: 6),
                Text(value, style: TextStyle(fontWeight: FontWeight.w900, color: Colors.green, fontSize: isMobile ? 13 : 15)),
              ],
            ),
          )
        else
          Text(value, style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black87, fontSize: isMobile ? 14 : 16)),
      ],
    );
  }
}

class GrafikKegiatan extends StatelessWidget {
  const GrafikKegiatan({super.key, required this.items, required this.warnaBar});
  final List<Activity> items;
  final Color warnaBar;
  
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return BarChart(
      BarChartData(
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: Colors.black.withOpacity(0.05), strokeWidth: 2)),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, m) => Padding(
                padding: const EdgeInsets.only(top: 10), 
                child: Text(['Jan','Feb','Mar','Apr','Mei','Jun'][v.toInt()], style: TextStyle(fontSize: isMobile ? 11 : 13, fontWeight: FontWeight.w900, color: Colors.grey[800]))
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(
          6,
          (index) => BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: items.where((i) => i.activityDate.month == index + 1).length.toDouble(),
                color: warnaBar.withOpacity(0.85),
                width: isMobile ? 24 : 36, // Mengecil otomatis di HP agar tidak desak-desakan
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}