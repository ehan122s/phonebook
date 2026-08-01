import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../models/activity.dart';
import '../../models/app_user.dart';
import '../../services/activity_repository.dart';
import '../../widgets/glashmorp.dart';

// ========================================================
// 1. DASHBOARD KHUSUS ADMIN (SISTEM)
// Tema: Mewah, Glassmorphism, 100% Mobile Responsive
// ========================================================
class HalamanRingkasanAdmin extends StatelessWidget {
  const HalamanRingkasanAdmin({super.key, required this.repository, required this.user});
  final ActivityRepository repository;
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;

    return FutureBuilder<List<Activity>>(
      future: repository.list(), 
      builder: (_, snapshot) {
        final items = snapshot.data ?? [];
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
                        Text('Halo, ${user.fullName.split(' ')[0]} 👋', style: TextStyle(fontSize: isMobile ? 24 : 28, fontWeight: FontWeight.w900, color: const Color(0xFF1B5E20))),
                        const SizedBox(height: 8),
                        Text('Pusat Administrasi SIMPUL', style: TextStyle(fontSize: isMobile ? 14 : 18, color: Colors.black87, fontWeight: FontWeight.w600, height: 1.4)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: isMobile ? 24 : 40),

            // 2. QUICK SHORTCUTS (Bisa di-scroll nyamping di HP)
            const SectionTitle('Jalan Pintas Administrasi'),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  QuickActionBtn(icon: Icons.person_add_alt_1_rounded, label: 'Tambah\nPengguna', color: const Color(0xFF047857), onTap: (){}),
                  QuickActionBtn(icon: Icons.campaign_rounded, label: 'Buat\nPengumuman', color: const Color(0xFFF59E0B), onTap: (){}),
                  QuickActionBtn(icon: Icons.topic_rounded, label: 'Kelola\nMateri', color: const Color(0xFF1D4ED8), onTap: (){}),
                  QuickActionBtn(icon: Icons.backup_rounded, label: 'Backup\nDatabase', color: const Color(0xFF5D4037), onTap: (){}),
                ],
              ),
            ),
            SizedBox(height: isMobile ? 24 : 40),
            
            // 3. STATISTIK UTAMA (Grid Responsif 2 Kolom di HP)
            const SectionTitle('Rekapitulasi Data Sistem'),
            GridView.count(
              crossAxisCount: isMobile ? 2 : 4,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: isMobile ? 1.0 : 1.4, // Di HP dibikin kotak agar teks ga kepotong
              children: [
                StatCard(label: 'Total Pengguna', value: '1,248', icon: Icons.groups_rounded, color: const Color(0xFF2E7D32)),
                StatCard(label: 'Penyuluh Aktif', value: '864', icon: Icons.nature_people_rounded, color: const Color(0xFF047857)),
                StatCard(label: 'Total Laporan', value: '${items.length}', icon: Icons.description_rounded, color: const Color(0xFFD97706)),
                StatCard(label: 'Giat Hari Ini', value: '24', icon: Icons.today_rounded, color: const Color(0xFF2563EB)),
              ],
            ),
            SizedBox(height: isMobile ? 24 : 40),
            
            // 4. CHART & TIMELINE (Responsive Flex/Wrap)
            Wrap(
              spacing: 24, 
              runSpacing: 24,
              children: [
                // GRAFIK
                SizedBox(
                  width: isMobile ? double.infinity : 500, // Di HP melebar full
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle('Grafik Aktivitas Semester Ini'),
                      KartuKaca(
                        padding: EdgeInsets.all(isMobile ? 16 : 24),
                        child: SizedBox(
                          height: isMobile ? 220 : 280, // Lebih pendek dikit di HP
                          child: GrafikKegiatan(items: items, warnaBar: const Color(0xFF1B5E20))
                        ),
                      ),
                    ],
                  ),
                ),
                
                // AKTIVITAS TERBARU & INFO SISTEM
                SizedBox(
                  width: isMobile ? double.infinity : 400, // Di HP melebar full
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle('Aktivitas Lapangan Terbaru'),
                      KartuKaca(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: const [
                            TimelineItem(title: 'Bapak Budi mengunggah laporan', time: 'Hari ini, 10:30', icon: Icons.upload_file_rounded, color: Colors.blue),
                            TimelineItem(title: 'Ibu Rina membuat kegiatan', time: 'Hari ini, 09:15', icon: Icons.event_available_rounded, color: Colors.green),
                            TimelineItem(title: 'Anda menambahkan pengguna', time: 'Kemarin', icon: Icons.person_add_rounded, color: Colors.orange, isLast: true),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const SectionTitle('Status Server & Sistem'),
                      KartuKaca(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: const [
                            SystemInfoRow(label: 'Versi Aplikasi', value: 'v2.4.1'),
                            Divider(height: 24, color: Colors.black12),
                            SystemInfoRow(label: 'Koneksi Server', value: 'Online', isStatus: true),
                            Divider(height: 24, color: Colors.black12),
                            SystemInfoRow(label: 'Backup Terakhir', value: 'Hari ini, 02:00'),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 80), // Jarak aman untuk bottom nav di HP
          ],
        );
      },
    );
  }
}

// ========================================================
// 2. DASHBOARD PENYULUH (Tema Hijau Hutan & Personal)
// ========================================================
class HalamanRingkasanPenyuluh extends StatelessWidget {
  const HalamanRingkasanPenyuluh({super.key, required this.repository, required this.user});
  final ActivityRepository repository;
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;

    return FutureBuilder<List<Activity>>(
      future: repository.list(), 
      builder: (_, snapshot) {
        final items = snapshot.data ?? [];
        return ListView(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 16),
          children: [
            // HEADER KACA
            KartuKaca(
              padding: EdgeInsets.all(isMobile ? 20 : 32),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Selamat Bertugas, Bapak/Ibu ${user.fullName.split(' ')[0]}!', style: TextStyle(fontSize: isMobile ? 22 : 28, fontWeight: FontWeight.w900, color: const Color(0xFF1B5E20))),
                        const SizedBox(height: 8),
                        Text('Semoga lancar dalam memberikan edukasi dan penyuluhan untuk masyarakat sekitar hutan hari ini.', style: TextStyle(fontSize: isMobile ? 14 : 16, color: Colors.black87, fontWeight: FontWeight.w600, height: 1.4)),
                      ],
                    ),
                  ),
                  // Cuaca Ringkas (Hanya muncul jika layar agak lebar, di HP sembunyikan agar tidak sumpek)
                  if (!isMobile)
                    Container(
                      margin: const EdgeInsets.only(left: 24),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.6), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white, width: 2)),
                      child: Column(
                        children: [
                          const Icon(Icons.wb_sunny_rounded, color: Colors.orange, size: 48),
                          const SizedBox(height: 8),
                          Text('Cerah', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.blue[900])),
                          Text('28°C', style: TextStyle(color: Colors.blue[800], fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )
                ],
              ),
            ),
            SizedBox(height: isMobile ? 24 : 40),

            // TARGET & METRIK KACA
            Wrap(
              spacing: 16, 
              runSpacing: 16,
              children: [
                SizedBox(
                  width: isMobile ? double.infinity : 380,
                  child: KartuKaca(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Target Kegiatan Bulan Ini', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black87)),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${items.length} Selesai', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF2E7D32))),
                            const Text('Target: 20', style: TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: LinearProgressIndicator(
                            value: (items.length / 20).clamp(0.0, 1.0),
                            minHeight: 12, 
                            backgroundColor: Colors.white.withOpacity(0.5),
                            color: const Color(0xFF2E7D32),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: isMobile ? double.infinity : 400,
                  child: Row(
                    children: [
                      Expanded(child: StatCard(label: 'Total\nDokumen', value: '12', icon: Icons.folder_open_rounded, color: const Color(0xFF047857))),
                      const SizedBox(width: 16),
                      Expanded(child: StatCard(label: 'Pengumuman\nBaru', value: '1', icon: Icons.notifications_active_rounded, color: Colors.orange[800]!)),
                    ],
                  ),
                )
              ],
            ),
            SizedBox(height: isMobile ? 24 : 40),
            
            // AGENDA & RIWAYAT KACA
            Wrap(
              spacing: 16, 
              runSpacing: 24,
              children: [
                SizedBox(
                  width: isMobile ? double.infinity : 380,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle('Jadwal Agenda Hari Ini'),
                      KartuKaca(
                        padding: EdgeInsets.all(isMobile ? 12 : 16),
                        child: Column(
                          children: [
                            ListTile(
                              leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.schedule_rounded, color: Colors.green, size: 24)),
                              title: const Text('Kunjungan Desa Mekarsari', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                              subtitle: const Padding(padding: EdgeInsets.only(top: 4), child: Text('13:00 WIB • Evaluasi Tanam', style: TextStyle(fontSize: 14, color: Colors.black87))),
                            ),
                            const Divider(height: 16, color: Colors.black12),
                            ListTile(
                              leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.edit_document, color: Colors.orange, size: 24)),
                              title: const Text('Menyusun Laporan Kuartal', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                              subtitle: const Padding(padding: EdgeInsets.only(top: 4), child: Text('15:30 WIB • Di Kantor', style: TextStyle(fontSize: 14, color: Colors.black87))),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: isMobile ? double.infinity : 500,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle('Riwayat Kegiatan Terakhir Anda'),
                      if (items.isEmpty)
                        const KartuKaca(padding: EdgeInsets.all(32), child: Center(child: Text('Belum ada riwayat kegiatan yang tercatat.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54))))
                      else
                        ...items.take(3).map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: KartuKaca(
                            padding: const EdgeInsets.all(8),
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: const Color(0xFF2E7D32).withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                                child: const Icon(Icons.nature_rounded, color: Color(0xFF2E7D32), size: 28)
                              ),
                              title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF1B5E20))),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text('${item.village} • ${item.categoryName}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded, color: Colors.black54, size: 28),
                            ),
                          ),
                        )),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 80), // Biar gak nabrak tombol Nav bar bawah
          ],
        );
      },
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 10 : 14),
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(isMobile ? 12 : 16)),
            child: Icon(icon, color: color, size: isMobile ? 28 : 36),
          ),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: isMobile ? 28 : 38, fontWeight: FontWeight.w900, color: Colors.black87, height: 1.2)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: isMobile ? 13 : 16, color: Colors.grey.shade800, fontWeight: FontWeight.w800), maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
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