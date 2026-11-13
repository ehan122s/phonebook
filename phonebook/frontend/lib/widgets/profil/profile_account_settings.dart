import 'package:flutter/material.dart';

class ProfileAccountSettings extends StatelessWidget {
  final VoidCallback onEditProfile;
  final VoidCallback onChangePassword;
  final VoidCallback onManagePhoto;
  final VoidCallback onSecurityInfo;
  final String loginMethod;

  const ProfileAccountSettings({
    super.key,
    required this.onEditProfile,
    required this.onChangePassword,
    required this.onManagePhoto,
    required this.onSecurityInfo,
    this.loginMethod = 'email',
  });

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconBg = isDark ? const Color(0xFF26352B) : const Color(0xFFF1F8E9);
    final iconColor = isDark ? const Color(0xFF81C784) : const Color(0xFF285C2E);
    final titleColor = isDark ? Colors.white : const Color(0xFF1E2923);
    final subColor = isDark ? Colors.white60 : Colors.grey.shade600;
    final chevronColor = isDark ? Colors.white38 : Colors.grey;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: subColor,
                    ),
                  ),
                ],
              ),
            ),
            trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  color: chevronColor,
                  size: 22,
                ),
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
    final headerIconColor = isDark ? const Color(0xFF81C784) : const Color(0xFF285C2E);
    final titleColor = isDark ? Colors.white : const Color(0xFF1E2923);
    final dividerColor = isDark ? const Color(0xFF2E3D34) : const Color(0xFFEDF2EE);
    final isGoogle = loginMethod.toLowerCase() == 'google';

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
                  Icons.manage_accounts_rounded,
                  size: 20,
                  color: headerIconColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Pengaturan Akun & Keamanan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: dividerColor),
          const SizedBox(height: 6),

          _buildMenuItem(
            context: context,
            icon: Icons.person_outline_rounded,
            title: 'Edit Informasi Profil',
            subtitle: 'Ubah nama, nomor WhatsApp, dan wilayah kerja',
            onTap: onEditProfile,
          ),
          Divider(height: 1, indent: 48, color: dividerColor),

          _buildMenuItem(
            context: context,
            icon: Icons.add_a_photo_outlined,
            title: 'Kelola Foto Profil',
            subtitle: 'Unggah foto resmi dari galeri atau kamera HP',
            onTap: onManagePhoto,
          ),
          Divider(height: 1, indent: 48, color: dividerColor),

          _buildMenuItem(
            context: context,
            icon: Icons.lock_outline_rounded,
            title: 'Ubah Kata Sandi (Password)',
            subtitle: isGoogle
                ? 'Akun terhubung melalui Google OAuth'
                : 'Perbarui kata sandi akun secara berkala',
            onTap: onChangePassword,
            trailing: isGoogle
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1B2B3A) : const Color(0xFFE8F0FE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Google',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF90CAF9) : const Color(0xFF1A73E8),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : null,
          ),
          Divider(height: 1, indent: 48, color: dividerColor),

          _buildMenuItem(
            context: context,
            icon: Icons.security_rounded,
            title: 'Informasi Keamanan & Sesi',
            subtitle: 'Cek metode autentikasi dan status token',
            onTap: onSecurityInfo,
          ),
        ],
      ),
    );
  }
}
