import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../models/activity.dart';
import '../../services/activity_repository.dart';
import '../../widgets/glashmorp.dart';

// ========================================================
// 1. DASHBOARD PENYULUH (Tema Hijau Hutan)
// Fokus: Kegiatan lapangan pribadi
// ========================================================
class HalamanRingkasanPenyuluh extends StatelessWidget {
  const HalamanRingkasanPenyuluh({super.key, required this.repository});
  final ActivityRepository repository;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Activity>>(
        future: repository.list(), 
        builder: (_, snapshot) {
          final items = snapshot.data ?? [];
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _HeaderSelamatDatang(
                tema: const Color(0xFF2E7D32),
                ikon: Icons.forest,
                judul: 'Selamat Bertugas!',
                subjudul: 'Semangat memberikan edukasi dan penyuluhan untuk masyarakat sekitar hutan hari ini.',
              ),
              const SizedBox(height: 24),
              // Mobile Grid 2 Kolom
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _KotakMetrik(label: 'Kegiatanku', value: '${items.length}', icon: Icons.event_available, color: const Color(0xFF2E7D32)),
                  const _KotakMetrik(label: 'Dokumen', value: '12', icon: Icons.file_present, color: Color(0xFF558B2F)),
                ],
              ),
              const SizedBox(height: 32),
              const Text('Kegiatan Terakhir', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1B5E20))),
              const SizedBox(height: 16),
              if (items.isEmpty)
                const KartuKaca(padding: EdgeInsets.all(24), child: Text('Anda belum memiliki kegiatan.', style: TextStyle(color: Colors.grey)))
              else
                ...items.take(3).map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: KartuKaca(
                    padding: const EdgeInsets.all(8),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: const Color(0xFF2E7D32).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.park, color: Color(0xFF2E7D32))
                      ),
                      title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      subtitle: Text('${item.village} • ${item.categoryName}'),
                    ),
                  ),
                )),
            ],
          );
        },
      );
}

// ========================================================
// 2. DASHBOARD PENGELOLA EKOSISTEM (Tema Teal/Tosca)
// Fokus: Kondisi hutan, reboisasi, pemantauan
// ========================================================
class HalamanRingkasanPengelola extends StatelessWidget {
  const HalamanRingkasanPengelola({super.key, required this.repository});
  final ActivityRepository repository;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      _HeaderSelamatDatang(
        tema: const Color(0xFF00695C),
        ikon: Icons.eco,
        judul: 'Pantau Ekosistem',
        subjudul: 'Ringkasan kondisi kelestarian hutan dan kegiatan rehabilitasi area.',
      ),
      const SizedBox(height: 24),
      GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          _KotakMetrik(label: 'Area Tanam', value: '34', icon: Icons.landscape, color: Color(0xFF00695C)),
          _KotakMetrik(label: 'Bibit (Ribu)', value: '120', icon: Icons.nature, color: Color(0xFF00897B)),
          _KotakMetrik(label: 'Patroli', value: '15', icon: Icons.local_police, color: Color(0xFF004D40)),
          _KotakMetrik(label: 'Ancaman', value: '2', icon: Icons.warning_amber, color: Colors.orange),
        ],
      ),
    ],
  );
}

// ========================================================
// 3. DASHBOARD PENELAAH TEKNIS (Tema Ungu)
// Fokus: Membaca laporan, statistik, merumuskan kebijakan
// ========================================================
class HalamanRingkasanPenelaah extends StatelessWidget {
  const HalamanRingkasanPenelaah({super.key, required this.repository});
  final ActivityRepository repository;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Activity>>(
    future: repository.list(),
    builder: (context, snapshot) {
      final items = snapshot.data ?? [];
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _HeaderSelamatDatang(
            tema: const Color(0xFF4527A0),
            ikon: Icons.gavel,
            judul: 'Tinjauan Kebijakan',
            subjudul: 'Analisis data lapangan untuk penyusunan rumusan kebijakan kehutanan yang tepat guna.',
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _KotakMetrik(label: 'Laporan Masuk', value: '${items.length}', icon: Icons.drive_folder_upload, color: const Color(0xFF4527A0))),
              const SizedBox(width: 16),
              const Expanded(child: _KotakMetrik(label: 'Kebijakan Aktif', value: '5', icon: Icons.assignment_turned_in, color: Color(0xFF651FFF))),
            ],
          ),
          const SizedBox(height: 32),
          const Text('Tren Evaluasi Bulanan', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF311B92))),
          const SizedBox(height: 16),
          KartuKaca(
            padding: const EdgeInsets.all(24),
            child: SizedBox(height: 220, child: GrafikKegiatan(items: items, warnaBar: const Color(0xFF4527A0))),
          ),
        ],
      );
    }
  );
}

// ========================================================
// 4. DASHBOARD ADMIN SISTEM (Tema Coklat Kayu)
// ========================================================
class HalamanRingkasanAdmin extends StatelessWidget {
  const HalamanRingkasanAdmin({super.key, required this.repository});
  final ActivityRepository repository;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Activity>>(
        future: repository.list(), 
        builder: (_, snapshot) {
          final items = snapshot.data ?? [];
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _HeaderSelamatDatang(
                tema: const Color(0xFF5D4037),
                ikon: Icons.admin_panel_settings,
                judul: 'Sistem Terpusat',
                subjudul: 'Pemantauan penuh seluruh operasi aplikasi, pengguna, dan kelancaran sistem.',
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: _KotakMetrik(label: 'Total Kegiatan', value: '${items.length}', icon: Icons.map, color: const Color(0xFF5D4037))),
                  const SizedBox(width: 16),
                  const Expanded(child: _KotakMetrik(label: 'Total Akun', value: '18', icon: Icons.groups, color: Color(0xFF795548))),
                ],
              ),
              const SizedBox(height: 32),
              const Text('Tren Aktivitas Global', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF3E2723))),
              const SizedBox(height: 16),
              KartuKaca(
                padding: const EdgeInsets.all(16),
                child: SizedBox(height: 220, child: GrafikKegiatan(items: items, warnaBar: const Color(0xFF5D4037))),
              ),
            ],
          );
        },
      );
}

// ========================================================
// WIDGET BANTUAN KHUSUS MOBILE
// ========================================================

class _HeaderSelamatDatang extends StatelessWidget {
  const _HeaderSelamatDatang({required this.tema, required this.ikon, required this.judul, required this.subjudul});
  final Color tema;
  final IconData ikon;
  final String judul;
  final String subjudul;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tema.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tema.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: tema.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: Icon(ikon, color: tema, size: 32)
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(judul, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: tema)),
                const SizedBox(height: 6),
                Text(subjudul, style: TextStyle(color: Colors.grey.shade800, fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KotakMetrik extends StatelessWidget {
  const _KotakMetrik({required this.label, required this.value, required this.icon, required this.color});
  final String label, value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return KartuKaca(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.black87)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade800, fontWeight: FontWeight.bold), maxLines: 2),
        ],
      ),
    );
  }
}

class GrafikKegiatan extends StatelessWidget {
  const GrafikKegiatan({super.key, required this.items, required this.warnaBar});
  final List<Activity> items;
  final Color warnaBar;
  
  @override
  Widget build(BuildContext context) => BarChart(
        BarChartData(
          gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: Colors.white.withValues(alpha: 0.7), strokeWidth: 1)),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, m) => Padding(
                  padding: const EdgeInsets.only(top: 8), 
                  child: Text(['Jan','Feb','Mar','Apr','Mei','Jun'][v.toInt()], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))
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
                  color: warnaBar.withValues(alpha: 0.9),
                  width: 20,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                ),
              ],
            ),
          ),
        ),
      );
}