import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../models/activity.dart';
import '../../services/activity_repository.dart';
import '../../widgets/glashmorp.dart';
// import '../kegiatan/halaman_kegiatan.dart'; // Uncomment jika ActivityTile tersedia

class HalamanRingkasan extends StatelessWidget {
  const HalamanRingkasan({super.key, required this.repository});
  final ActivityRepository repository;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Activity>>(
        future: repository.list(),
        builder: (_, snapshot) {
          final items = snapshot.data ?? [];
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  KartuMetrikKaca(label: 'Total Kegiatan', value: '${items.length}', icon: Icons.event, color: const Color(0xFF2E7D32)),
                  const KartuMetrikKaca(label: 'Dokumen', value: '12', icon: Icons.description_outlined, color: Colors.blue),
                  const KartuMetrikKaca(label: 'Foto Galeri', value: '45', icon: Icons.photo_library_outlined, color: Colors.orange),
                  const KartuMetrikKaca(label: 'Kategori Aktif', value: '8', icon: Icons.category_outlined, color: Colors.purple),
                ],
              ),
              const SizedBox(height: 40),
              
              const Text('Aktivitas per Bulan', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              KartuKaca(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  height: 260,
                  child: GrafikKegiatan(items: items),
                ),
              ),
              const SizedBox(height: 40),
              
              const Text('Kegiatan Terbaru', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              if (items.isEmpty)
                const KartuKaca(padding: EdgeInsets.all(24), child: Text('Belum ada kegiatan.', style: TextStyle(color: Colors.grey)))
              else
                ...items.take(5).map((item) => KartuKaca(
                  padding: const EdgeInsets.all(16),
                  // margin: const EdgeInsets.only(bottom: 12), 
                  child: ListTile(
                    leading: const CircleAvatar(backgroundColor: Colors.white54, child: Icon(Icons.forest, color: Color(0xFF2E7D32))),
                    title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${item.village} • ${item.categoryName}'),
                  ),
                )),
            ],
          );
        },
      );
}

class KartuMetrikKaca extends StatelessWidget {
  const KartuMetrikKaca({super.key, required this.label, required this.value, required this.icon, required this.color});
  final String label, value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => KartuKaca(
        width: 200,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 24),
            Text(value, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 14, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
          ],
        ),
      );
}

class GrafikKegiatan extends StatelessWidget {
  const GrafikKegiatan({super.key, required this.items});
  final List<Activity> items;
  
  @override
  Widget build(BuildContext context) => BarChart(
        BarChartData(
          gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: Colors.white.withValues(alpha: 0.4), strokeWidth: 1)),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, m) => Padding(padding: const EdgeInsets.only(top: 8), child: Text(['Jan','Feb','Mar','Apr','Mei','Jun'][v.toInt()], style: const TextStyle(fontSize: 12))),
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
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.8),
                  width: 24,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                ),
              ],
            ),
          ),
        ),
      );
}