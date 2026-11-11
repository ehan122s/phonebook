import 'package:flutter/material.dart';

class ProfileAppSettings extends StatelessWidget {
  final String currentTheme;
  final String textScale;
  final String language;
  final String storageUsage;
  final ValueChanged<String> onChangeTheme;
  final ValueChanged<String> onChangeTextScale;
  final VoidCallback onClearCache;

  const ProfileAppSettings({
    super.key,
    required this.currentTheme,
    required this.textScale,
    this.language = 'Bahasa Indonesia',
    required this.storageUsage,
    required this.onChangeTheme,
    required this.onChangeTextScale,
    required this.onClearCache,
  });

  void _showThemeDialog(BuildContext context) {
    final themes = ['Sistem', 'Terang', 'Gelap'];
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text(
            'Pilih Tema Tampilan',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: themes.map((t) {
              final isSelected = t == currentTheme;
              return RadioListTile<String>(
                value: t,
                groupValue: currentTheme,
                activeColor: const Color(0xFF285C2E),
                title: Text(
                  t,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? const Color(0xFF285C2E) : Colors.black87,
                  ),
                ),
                onChanged: (val) {
                  if (val != null) {
                    Navigator.pop(ctx);
                    onChangeTheme(val);
                  }
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showTextScaleDialog(BuildContext context) {
    final scales = [
      {'title': 'Normal (Standar)', 'val': 'Normal', 'desc': 'Ukuran teks standar smartphone'},
      {'title': 'Besar (Nyaman Dibaca)', 'val': 'Besar', 'desc': 'Direkomendasikan untuk usia 40–60 tahun agar teks lebih terbaca'},
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.format_size_rounded, color: Color(0xFF285C2E)),
              SizedBox(width: 8),
              Text(
                'Ukuran Teks Aplikasi',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: scales.map((s) {
              final val = s['val']!;
              final isSelected = val == textScale;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFE8F5E9) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF2E7D32) : Colors.grey.shade300,
                  ),
                ),
                child: RadioListTile<String>(
                  value: val,
                  groupValue: textScale,
                  activeColor: const Color(0xFF285C2E),
                  title: Text(
                    s['title']!,
                    style: TextStyle(
                      fontSize: val == 'Besar' ? 15 : 13.5,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? const Color(0xFF1B5E20) : Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    s['desc']!,
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                  ),
                  onChanged: (v) {
                    if (v != null) {
                      Navigator.pop(ctx);
                      onChangeTextScale(v);
                    }
                  },
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F8E9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: const Color(0xFF285C2E)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E2923),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0E7E1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  size: 20,
                  color: Color(0xFF285C2E),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pengaturan Aplikasi & Penyimpanan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E2923),
                      ),
                    ),
                    Text(
                      'Tampilan, bahasa, dan pengelolaan berkas lokal',
                      style: TextStyle(fontSize: 11.5, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFEDF2EE)),
          const SizedBox(height: 6),

          // Tema
          _buildItem(
            icon: Icons.palette_outlined,
            title: 'Tema Aplikasi',
            subtitle: 'Pilihan mode visual antarmuka',
            onTap: () => _showThemeDialog(context),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F8E9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFC8E6C9)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    currentTheme,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF285C2E),
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(Icons.arrow_drop_down, size: 16, color: Color(0xFF285C2E)),
                ],
              ),
            ),
          ),
          const Divider(height: 1, indent: 48, color: Color(0xFFF1F5F2)),

          // Ukuran Teks
          _buildItem(
            icon: Icons.format_size_rounded,
            title: 'Ukuran Teks',
            subtitle: 'Pengaturan kenyamanan baca teks',
            onTap: () => _showTextScaleDialog(context),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F8E9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFC8E6C9)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    textScale,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF285C2E),
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(Icons.arrow_drop_down, size: 16, color: Color(0xFF285C2E)),
                ],
              ),
            ),
          ),
          const Divider(height: 1, indent: 48, color: Color(0xFFF1F5F2)),

          // Bahasa
          _buildItem(
            icon: Icons.translate_rounded,
            title: 'Bahasa Aplikasi',
            subtitle: 'Bahasa baku sistem',
            trailing: const Text(
              'Bahasa Indonesia',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E2923),
              ),
            ),
          ),
          const Divider(height: 1, indent: 48, color: Color(0xFFF1F5F2)),

          // Penyimpanan & Bersihkan Cache
          _buildItem(
            icon: Icons.storage_rounded,
            title: 'Penyimpanan & Cache',
            subtitle: 'Total arsip lokal: $storageUsage',
            onTap: onClearCache,
            trailing: OutlinedButton(
              onPressed: onClearCache,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                side: const BorderSide(color: Color(0xFF285C2E)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text(
                'Bersihkan Cache',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF285C2E),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
