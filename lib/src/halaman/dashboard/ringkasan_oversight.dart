import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/activity.dart';
import '../../models/app_user.dart';
import '../../services/offline_activity_repository.dart';
import '../../widgets/glashmorp.dart';
import '../../widgets/file_downloader.dart';
import 'ringkasan.dart' show SectionTitle, StatCard, GrafikKegiatan;

/// Kartu kegiatan read-only yang aman dipakai oleh role yang HANYA punya
/// izin SELECT di RLS (pengelola/penelaah), tanpa memunculkan tombol
/// edit/hapus/upload yang pasti gagal karena kebijakan database.
class _KartuKegiatanReadOnly extends StatelessWidget {
  const _KartuKegiatanReadOnly({required this.activity});
  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final isSelesai = (activity.status ?? 'draft') != 'draft';
    return KartuKaca(
      padding: const EdgeInsets.all(8),
      child: ListTile(
        leading: Container(
          height: 52,
          width: 52,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.forest, color: Color(0xFF2E7D32), size: 26),
        ),
        title: Text(activity.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.black87)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            'Oleh ${activity.creatorName ?? '-'} • ${activity.categoryName}\n'
            '${DateFormat('dd MMM yyyy', 'id_ID').format(activity.activityDate)} • ${activity.village}, ${activity.district}, ${activity.regency}',
            style: TextStyle(color: Colors.grey.shade800, height: 1.4, fontSize: 13),
          ),
        ),
        isThreeLine: true,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: (isSelesai ? Colors.green : Colors.orange).withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
          child: Text(isSelesai ? 'Selesai' : 'Draft', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: isSelesai ? Colors.green.shade800 : Colors.orange.shade800)),
        ),
      ),
    );
  }
}

/// Halaman arsip / laporan read-only. Dipakai bersama oleh dashboard
/// Pengelola ("Laporan") dan Penelaah ("Arsip Laporan") karena keduanya
/// butuh melihat seluruh laporan kegiatan penyuluh apa adanya, tanpa
/// mengedit data milik orang lain.
class HalamanArsipLaporan extends StatefulWidget {
  const HalamanArsipLaporan({super.key, required this.repository});
final OfflineActivityRepository repository;

  @override
  State<HalamanArsipLaporan> createState() => _HalamanArsipLaporanState();
}

class _HalamanArsipLaporanState extends State<HalamanArsipLaporan> {
  late Future<List<Activity>> _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = widget.repository.list();
  }

  Future<void> _refresh() async {
    setState(() => _future = widget.repository.list(query: _query.isEmpty ? null : _query));
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: const Color(0xFF2E7D32),
      onRefresh: _refresh,
      child: FutureBuilder<List<Activity>>(
        future: _future,
        builder: (context, snapshot) {
          final isLoading = snapshot.connectionState == ConnectionState.waiting;
          final items = snapshot.data ?? const <Activity>[];
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            children: [
              KartuKaca(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                borderRadius: 30,
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  onSubmitted: (_) => _refresh(),
                  decoration: InputDecoration(
                    icon: const Icon(Icons.search, color: Colors.black54),
                    hintText: 'Cari judul, desa, atau kecamatan...',
                    border: InputBorder.none,
                    suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF2E7D32)), onPressed: _refresh),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (isLoading)
                const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32))))
              else if (items.isEmpty)
                const KartuKaca(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('Belum ada laporan kegiatan yang tercatat di sistem.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700))),
                )
              else
                ...items.map((a) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _KartuKegiatanReadOnly(activity: a))),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }
}

/// ========================================================
/// DASHBOARD PENGELOLA — "Ekosistem" (ringkasan)
/// ========================================================
class HalamanRingkasanPengelola extends StatefulWidget {
  const HalamanRingkasanPengelola({super.key, required this.repository, required this.user});
  final OfflineActivityRepository repository;
  final AppUser user;

  @override
  State<HalamanRingkasanPengelola> createState() => _HalamanRingkasanPengelolaState();
}

class _HalamanRingkasanPengelolaState extends State<HalamanRingkasanPengelola> {
  late Future<List<Activity>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.list();
  }

  Future<void> _refresh() async => setState(() => _future = widget.repository.list());

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    return RefreshIndicator(
      color: const Color(0xFF00695C),
      onRefresh: _refresh,
      child: FutureBuilder<List<Activity>>(
        future: _future,
        builder: (context, snapshot) {
          final isLoading = snapshot.connectionState == ConnectionState.waiting;
          final items = snapshot.data ?? const <Activity>[];
          final kabupatenSet = items.map((a) => a.regency).where((r) => r.isNotEmpty).toSet();
          final byCategory = <String, int>{};
          for (final a in items) {
            byCategory[a.categoryName] = (byCategory[a.categoryName] ?? 0) + 1;
          }
          final kategoriUrut = byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

          return ListView(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32, vertical: 24),
            children: [
              KartuKaca(
                padding: EdgeInsets.all(isMobile ? 24 : 32),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: const Color(0xFF00695C).withOpacity(0.15), shape: BoxShape.circle),
                      child: const Icon(Icons.eco_rounded, color: Color(0xFF00695C), size: 40),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Halo, ${widget.user.fullName.split(' ')[0]} 👋', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF004D40))),
                          const SizedBox(height: 6),
                          const Text('Pantau kondisi ekosistem dari seluruh laporan kegiatan penyuluh.', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              const SectionTitle('Rekapitulasi Laporan'),
              GridView.count(
                crossAxisCount: isMobile ? 2 : 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: isMobile ? 1.0 : 1.3,
                children: [
                  StatCard(label: 'Total Laporan', value: isLoading ? '-' : '${items.length}', icon: Icons.description_rounded, color: const Color(0xFF00695C)),
                  StatCard(label: 'Kabupaten Terpantau', value: isLoading ? '-' : '${kabupatenSet.length}', icon: Icons.map_rounded, color: const Color(0xFF2E7D32)),
                  StatCard(label: 'Kategori Kegiatan', value: isLoading ? '-' : '${byCategory.length}', icon: Icons.category_rounded, color: const Color(0xFFD97706)),
                ],
              ),
              const SizedBox(height: 28),
              const SectionTitle('Grafik Kegiatan per Bulan'),
              KartuKaca(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  height: 240,
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF00695C)))
                      : GrafikKegiatan(items: items, warnaBar: const Color(0xFF00695C)),
                ),
              ),
              const SizedBox(height: 28),
              const SectionTitle('Kategori Kegiatan Terbanyak'),
              KartuKaca(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: kategoriUrut.isEmpty
                    ? const Padding(padding: EdgeInsets.all(24), child: Text('Belum ada data.', style: TextStyle(color: Colors.black54)))
                    : Column(
                        children: kategoriUrut.take(6).map((e) => ListTile(
                              leading: const Icon(Icons.forest_rounded, color: Color(0xFF00695C)),
                              title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w700)),
                              trailing: Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                            )).toList(),
                      ),
              ),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }
}

/// ========================================================
/// DASHBOARD PENGELOLA — "Peta Hutan" (sebaran lokasi kegiatan)
/// ========================================================
class HalamanPetaKegiatan extends StatefulWidget {
  const HalamanPetaKegiatan({super.key, required this.repository});
  final OfflineActivityRepository repository;

  @override
  State<HalamanPetaKegiatan> createState() => _HalamanPetaKegiatanState();
}

class _HalamanPetaKegiatanState extends State<HalamanPetaKegiatan> {
  late Future<List<Activity>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.list();
  }

  Future<void> _refresh() async => setState(() => _future = widget.repository.list());

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: const Color(0xFF00695C),
      onRefresh: _refresh,
      child: FutureBuilder<List<Activity>>(
        future: _future,
        builder: (context, snapshot) {
          final isLoading = snapshot.connectionState == ConnectionState.waiting;
          final items = snapshot.data ?? const <Activity>[];

          final perKabupaten = <String, int>{};
          for (final a in items) {
            final key = a.regency.isEmpty ? 'Tidak diketahui' : a.regency;
            perKabupaten[key] = (perKabupaten[key] ?? 0) + 1;
          }
          final urut = perKabupaten.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
          final maxValue = urut.isEmpty ? 1 : urut.first.value;
          final berKoordinat = items.where((a) => a.latitude != null && a.longitude != null).toList();

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SectionTitle('Sebaran Kegiatan per Kabupaten'),
              if (isLoading)
                const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator(color: Color(0xFF00695C))))
              else if (urut.isEmpty)
                const KartuKaca(padding: EdgeInsets.all(32), child: Center(child: Text('Belum ada data lokasi kegiatan.', style: TextStyle(color: Colors.black54))))
              else
                KartuKaca(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: urut.map((e) {
                      final ratio = e.value / maxValue;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(e.key, style: const TextStyle(fontWeight: FontWeight.w800)),
                                Text('${e.value} kegiatan', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF00695C))),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(value: ratio, minHeight: 10, backgroundColor: Colors.black12, color: const Color(0xFF00695C)),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 28),
              const SectionTitle('Titik Koordinat Kegiatan'),
              if (!isLoading && berKoordinat.isEmpty)
                const KartuKaca(
                  padding: EdgeInsets.all(24),
                  child: Text('Belum ada kegiatan dengan koordinat GPS tercatat.', style: TextStyle(color: Colors.black54)),
                )
              else if (!isLoading)
                ...berKoordinat.map((a) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: KartuKaca(
                        padding: const EdgeInsets.all(8),
                        child: ListTile(
                          leading: const Icon(Icons.location_on_rounded, color: Color(0xFF00695C), size: 32),
                          title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text('${a.village}, ${a.district}, ${a.regency}\n${a.latitude!.toStringAsFixed(5)}, ${a.longitude!.toStringAsFixed(5)}'),
                          isThreeLine: true,
                          trailing: TextButton.icon(
                            onPressed: () => openExternalUrl('https://www.google.com/maps/search/?api=1&query=${a.latitude},${a.longitude}'),
                            icon: const Icon(Icons.map_rounded, size: 18),
                            label: const Text('Buka Peta'),
                          ),
                        ),
                      ),
                    )),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }
}

/// ========================================================
/// DASHBOARD PENELAAH — "Kebijakan" (ringkasan)
/// ========================================================
class HalamanRingkasanPenelaah extends StatefulWidget {
  const HalamanRingkasanPenelaah({super.key, required this.repository, required this.user});
  final OfflineActivityRepository repository;
  final AppUser user;

  @override
  State<HalamanRingkasanPenelaah> createState() => _HalamanRingkasanPenelaahState();
}

class _HalamanRingkasanPenelaahState extends State<HalamanRingkasanPenelaah> {
  late Future<List<Activity>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.list();
  }

  Future<void> _refresh() async => setState(() => _future = widget.repository.list());

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    return RefreshIndicator(
      color: const Color(0xFF4E342E),
      onRefresh: _refresh,
      child: FutureBuilder<List<Activity>>(
        future: _future,
        builder: (context, snapshot) {
          final isLoading = snapshot.connectionState == ConnectionState.waiting;
          final items = snapshot.data ?? const <Activity>[];
          final selesai = items.where((a) => (a.status ?? 'draft') != 'draft').length;
          final draft = items.length - selesai;
          final penyuluhTerlibat = items.map((a) => a.creatorName).where((n) => n != null && n.isNotEmpty).toSet().length;

          return ListView(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32, vertical: 24),
            children: [
              KartuKaca(
                padding: EdgeInsets.all(isMobile ? 24 : 32),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: const Color(0xFF4E342E).withOpacity(0.15), shape: BoxShape.circle),
                      child: const Icon(Icons.gavel_rounded, color: Color(0xFF4E342E), size: 40),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Halo, ${widget.user.fullName.split(' ')[0]} 👋', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF3E2723))),
                          const SizedBox(height: 6),
                          const Text('Telaah kepatuhan dan capaian program penyuluhan kehutanan.', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              const SectionTitle('Status Laporan'),
              GridView.count(
                crossAxisCount: isMobile ? 2 : 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: isMobile ? 1.0 : 1.3,
                children: [
                  StatCard(label: 'Laporan Selesai', value: isLoading ? '-' : '$selesai', icon: Icons.check_circle_rounded, color: const Color(0xFF2E7D32)),
                  StatCard(label: 'Laporan Draft', value: isLoading ? '-' : '$draft', icon: Icons.edit_note_rounded, color: const Color(0xFFD97706)),
                  StatCard(label: 'Penyuluh Terlibat', value: isLoading ? '-' : '$penyuluhTerlibat', icon: Icons.groups_rounded, color: const Color(0xFF4E342E)),
                ],
              ),
              const SizedBox(height: 28),
              const SectionTitle('Laporan Terbaru untuk Ditelaah'),
              if (isLoading)
                const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator(color: Color(0xFF4E342E))))
              else if (items.isEmpty)
                const KartuKaca(padding: EdgeInsets.all(32), child: Text('Belum ada laporan.', style: TextStyle(color: Colors.black54)))
              else
                ...items.take(5).map((a) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _KartuKegiatanReadOnly(activity: a))),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }
}

/// ========================================================
/// DASHBOARD PENELAAH — "Statistik Kebijakan"
/// ========================================================
class HalamanStatistikKebijakan extends StatefulWidget {
  const HalamanStatistikKebijakan({super.key, required this.repository});
  final OfflineActivityRepository repository;

  @override
  State<HalamanStatistikKebijakan> createState() => _HalamanStatistikKebijakanState();
}

class _HalamanStatistikKebijakanState extends State<HalamanStatistikKebijakan> {
  late Future<List<Activity>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.list();
  }

  Future<void> _refresh() async => setState(() => _future = widget.repository.list());

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: const Color(0xFF4E342E),
      onRefresh: _refresh,
      child: FutureBuilder<List<Activity>>(
        future: _future,
        builder: (context, snapshot) {
          final isLoading = snapshot.connectionState == ConnectionState.waiting;
          final items = snapshot.data ?? const <Activity>[];
          final byCategory = <String, int>{};
          for (final a in items) {
            byCategory[a.categoryName] = (byCategory[a.categoryName] ?? 0) + 1;
          }
          final urut = byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
          final total = items.length == 0 ? 1 : items.length;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SectionTitle('Tren Kegiatan Bulanan'),
              KartuKaca(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  height: 240,
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF4E342E)))
                      : GrafikKegiatan(items: items, warnaBar: const Color(0xFF4E342E)),
                ),
              ),
              const SizedBox(height: 28),
              const SectionTitle('Proporsi per Kategori Kebijakan'),
              if (isLoading)
                const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator(color: Color(0xFF4E342E))))
              else if (urut.isEmpty)
                const KartuKaca(padding: EdgeInsets.all(32), child: Text('Belum ada data.', style: TextStyle(color: Colors.black54)))
              else
                KartuKaca(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: urut.map((e) {
                      final persen = (e.value / total * 100);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(e.key, style: const TextStyle(fontWeight: FontWeight.w800)),
                                Text('${e.value} (${persen.toStringAsFixed(0)}%)', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF4E342E))),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(value: e.value / total, minHeight: 10, backgroundColor: Colors.black12, color: const Color(0xFF4E342E)),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }
}

/// ========================================================
/// PENYULUH — "Arsip Pribadi" (rekap kegiatan milik sendiri)
/// ========================================================
class HalamanArsipPenyuluh extends StatefulWidget {
  const HalamanArsipPenyuluh({super.key, required this.repository});
  final OfflineActivityRepository repository;

  @override
  State<HalamanArsipPenyuluh> createState() => _HalamanArsipPenyuluhState();
}

class _HalamanArsipPenyuluhState extends State<HalamanArsipPenyuluh> {
  late Future<List<Activity>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.list();
  }

  Future<void> _refresh() async => setState(() => _future = widget.repository.list());

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: const Color(0xFF2E7D32),
      onRefresh: _refresh,
      child: FutureBuilder<List<Activity>>(
        future: _future,
        builder: (context, snapshot) {
          final isLoading = snapshot.connectionState == ConnectionState.waiting;
          final items = snapshot.data ?? const <Activity>[];
          final tahunIni = DateTime.now().year;
          final tahunIniCount = items.where((a) => a.activityDate.year == tahunIni).length;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  Expanded(child: StatCard(label: 'Total Arsip', value: isLoading ? '-' : '${items.length}', icon: Icons.inventory_2_rounded, color: const Color(0xFF2E7D32))),
                  const SizedBox(width: 16),
                  Expanded(child: StatCard(label: 'Tahun $tahunIni', value: isLoading ? '-' : '$tahunIniCount', icon: Icons.calendar_month_rounded, color: const Color(0xFF1D4ED8))),
                ],
              ),
              const SizedBox(height: 24),
              const SectionTitle('Grafik Kegiatan per Bulan'),
              KartuKaca(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  height: 220,
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
                      : GrafikKegiatan(items: items, warnaBar: const Color(0xFF2E7D32)),
                ),
              ),
              const SizedBox(height: 24),
              const SectionTitle('Seluruh Riwayat Kegiatan'),
              if (isLoading)
                const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32))))
              else if (items.isEmpty)
                const KartuKaca(padding: EdgeInsets.all(32), child: Text('Belum ada kegiatan yang diarsipkan.', style: TextStyle(color: Colors.black54)))
              else
                ...items.map((a) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _KartuKegiatanReadOnly(activity: a))),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }
}
