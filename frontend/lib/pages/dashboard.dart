import 'package:flutter/material.dart';

import '../widgets/animated_menu_card.dart';

class DashboardPage extends StatelessWidget {
  final Function(int)? onNavigate;

  const DashboardPage({
    super.key,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 190,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF2E7D32),
                            Color(0xFF66BB6A),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Selamat Datang 👋',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 25,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Kelola kegiatan dan laporan\nlapangan dengan mudah.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 15,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 22),

            const Text(
              'Ringkasan',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.description_outlined,
                    title: 'Laporan',
                    value: '0',
                    color: const Color(0xFF2E7D32),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.calendar_month_outlined,
                    title: 'Jadwal',
                    value: '0',
                    color: const Color(0xFF1976D2),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            const Text(
              'Menu Utama',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 14),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.05,
              children: [
                AnimatedMenuCard(
                  icon: Icons.description_outlined,
                  title: 'Laporan',
                  subtitle: 'Buat laporan kegiatan',
                  color: const Color(0xFF2E7D32),
                  background: const Color(0xFFE8F5E9),
                  onTap: () => onNavigate?.call(1),
                ),
                AnimatedMenuCard(
                  icon: Icons.calendar_month_outlined,
                  title: 'Jadwal',
                  subtitle: 'Lihat jadwal kegiatan',
                  color: const Color(0xFF1976D2),
                  background: const Color(0xFFE3F2FD),
                  onTap: () => onNavigate?.call(2),
                ),
                AnimatedMenuCard(
                  icon: Icons.menu_book_outlined,
                  title: 'Materi',
                  subtitle: 'Materi penyuluhan',
                  color: const Color(0xFFF57C00),
                  background: const Color(0xFFFFF3E0),
                  onTap: () => onNavigate?.call(3),
                ),
                AnimatedMenuCard(
                  icon: Icons.folder_outlined,
                  title: 'Kategori',
                  subtitle: 'Kelola kategori',
                  color: const Color(0xFF7B1FA2),
                  background: const Color(0xFFF3E5F5),
                  onTap: () {},
                ),
              ],
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.apps),
                label: const Text('Lihat Selengkapnya'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}