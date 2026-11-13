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
    final themes = [
      {'val': 'Sistem', 'title': 'Sistem (Default)', 'desc': 'Mengikuti pengaturan tema smartphone Anda'},
      {'val': 'Terang', 'title': 'Terang (Light)', 'desc': 'Tampilan putih bersih cerah nuansa kehutanan'},
      {'val': 'Gelap', 'title': 'Gelap (Dark)', 'desc': 'Tampilan gelap hemat baterai & nyaman di mata'},
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        final dialogDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: dialogDark ? const Color(0xFF1E2822) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Icon(
                Icons.palette_outlined,
                color: dialogDark ? const Color(0xFF81C784) : const Color(0xFF285C2E),
              ),
              const SizedBox(width: 8),
              Text(
                'Pilih Tema Tampilan',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: dialogDark ? Colors.white : const Color(0xFF1E2923),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: themes.map((t) {
              final val = t['val']!;
              final isSelected = val.toLowerCase() == currentTheme.toLowerCase();
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (dialogDark ? const Color(0xFF285C2E).withValues(alpha: 0.3) : const Color(0xFFE8F5E9))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? (dialogDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32))
                        : (dialogDark ? const Color(0xFF2E3D34) : Colors.grey.shade300),
                  ),
                ),
                child: RadioListTile<String>(
                  value: val,
                  groupValue: currentTheme,
                  activeColor: dialogDark ? const Color(0xFF81C784) : const Color(0xFF285C2E),
                  title: Text(
                    t['title']!,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected
                          ? (dialogDark ? const Color(0xFFA5D6A7) : const Color(0xFF1B5E20))
                          : (dialogDark ? Colors.white : Colors.black87),
                    ),
                  ),
                  subtitle: Text(
                    t['desc']!,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: dialogDark ? Colors.white60 : Colors.grey.shade600,
                    ),
                  ),
                  onChanged: (selected) {
                    if (selected != null) {
                      Navigator.pop(ctx);
                      onChangeTheme(selected);
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

  void _showTextScaleDialog(BuildContext context) {
    final scales = [
      {
        'title': 'Kecil',
        'val': 'Kecil',
        'desc': 'Ukuran teks lebih ringkas, memuat lebih banyak informasi',
        'factor': '0.85x',
      },
      {
        'title': 'Sedang (Normal)',
        'val': 'Sedang',
        'desc': 'Ukuran teks standar default smartphone',
        'factor': '1.0x',
      },
      {
        'title': 'Besar (Nyaman Dibaca)',
        'val': 'Besar',
        'desc': 'Direkomendasikan untuk usia 40–60 tahun agar teks lebih terbaca',
        'factor': '1.25x',
      },
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        final dialogDark = Theme.of(ctx).brightness == Brightness.dark;
        final normalizedCurrent = (textScale == 'Normal' || textScale == 'Standar') ? 'Sedang' : textScale;

        return AlertDialog(
          backgroundColor: dialogDark ? const Color(0xFF1E2822) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Icon(
                Icons.format_size_rounded,
                color: dialogDark ? const Color(0xFF81C784) : const Color(0xFF285C2E),
              ),
              const SizedBox(width: 8),
              Text(
                'Ukuran Teks Aplikasi',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: dialogDark ? Colors.white : const Color(0xFF1E2923),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: scales.map((s) {
              final val = s['val']!;
              final isSelected = val.toLowerCase() == normalizedCurrent.toLowerCase();

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (dialogDark ? const Color(0xFF285C2E).withValues(alpha: 0.3) : const Color(0xFFE8F5E9))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? (dialogDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32))
                        : (dialogDark ? const Color(0xFF2E3D34) : Colors.grey.shade300),
                  ),
                ),
                child: RadioListTile<String>(
                  value: val,
                  groupValue: normalizedCurrent,
                  activeColor: dialogDark ? const Color(0xFF81C784) : const Color(0xFF285C2E),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        s['title']!,
                        style: TextStyle(
                          fontSize: val == 'Besar' ? 14.5 : (val == 'Kecil' ? 12.5 : 13.5),
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? (dialogDark ? const Color(0xFFA5D6A7) : const Color(0xFF1B5E20))
                              : (dialogDark ? Colors.white : Colors.black87),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (dialogDark ? const Color(0xFF2E3D34) : const Color(0xFFC8E6C9))
                              : (dialogDark ? const Color(0xFF26332A) : Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          s['factor']!,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: dialogDark ? Colors.white70 : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    s['desc']!,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: dialogDark ? Colors.white60 : Colors.grey.shade600,
                    ),
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
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconBg = isDark ? const Color(0xFF26352B) : const Color(0xFFF1F8E9);
    final iconColor = isDark ? const Color(0xFF81C784) : const Color(0xFF285C2E);
    final titleColor = isDark ? Colors.white : const Color(0xFF1E2923);
    final subColor = isDark ? Colors.white60 : Colors.grey.shade600;

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
                color: iconBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11.5, color: subColor),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E2822) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF2E3D34) : const Color(0xFFE0E7E1);
    final headerBg = isDark ? const Color(0xFF26352B) : const Color(0xFFE8F5E9);
    final primaryGreen = isDark ? const Color(0xFF81C784) : const Color(0xFF285C2E);
    final titleColor = isDark ? Colors.white : const Color(0xFF1E2923);
    final subColor = isDark ? Colors.white60 : Colors.grey.shade600;
    final badgeBg = isDark ? const Color(0xFF26352B) : const Color(0xFFF1F8E9);
    final badgeBorder = isDark ? const Color(0xFF2E3D34) : const Color(0xFFC8E6C9);
    final dividerColor = isDark ? const Color(0xFF2E3D34) : const Color(0xFFEDF2EE);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
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
                  color: headerBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.tune_rounded,
                  size: 20,
                  color: primaryGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pengaturan Aplikasi & Penyimpanan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: titleColor,
                      ),
                    ),
                    Text(
                      'Tampilan, bahasa, dan pengelolaan berkas lokal',
                      style: TextStyle(fontSize: 11.5, color: subColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: dividerColor),
          const SizedBox(height: 6),

          // Tema
          _buildItem(
            context: context,
            icon: Icons.palette_outlined,
            title: 'Tema Aplikasi',
            subtitle: 'Pilihan mode visual antarmuka',
            onTap: () => _showThemeDialog(context),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: badgeBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    currentTheme,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: primaryGreen,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(Icons.arrow_drop_down, size: 16, color: primaryGreen),
                ],
              ),
            ),
          ),
          Divider(height: 1, indent: 48, color: dividerColor),

          // Ukuran Teks
          _buildItem(
            context: context,
            icon: Icons.format_size_rounded,
            title: 'Ukuran Teks',
            subtitle: 'Kecil, Sedang (Normal), atau Besar',
            onTap: () => _showTextScaleDialog(context),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: badgeBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    textScale,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: primaryGreen,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(Icons.arrow_drop_down, size: 16, color: primaryGreen),
                ],
              ),
            ),
          ),
          Divider(height: 1, indent: 48, color: dividerColor),

          // Bahasa
          _buildItem(
            context: context,
            icon: Icons.translate_rounded,
            title: 'Bahasa Aplikasi',
            subtitle: 'Bahasa baku sistem',
            trailing: Text(
              'Bahasa Indonesia',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: titleColor,
              ),
            ),
          ),
          Divider(height: 1, indent: 48, color: dividerColor),

          // Penyimpanan & Bersihkan Cache
          _buildItem(
            context: context,
            icon: Icons.storage_rounded,
            title: 'Penyimpanan & Cache',
            subtitle: 'Total arsip lokal: $storageUsage',
            onTap: onClearCache,
            trailing: OutlinedButton(
              onPressed: onClearCache,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                side: BorderSide(color: primaryGreen),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                'Bersihkan Cache',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: primaryGreen,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
