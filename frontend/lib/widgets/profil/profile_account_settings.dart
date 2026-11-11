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
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
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
                color: const Color(0xFFF1F8E9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: const Color(0xFF285C2E)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E2923),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            trailing ??
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey,
                  size: 22,
                ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isGoogle = loginMethod.toLowerCase() == 'google';

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
                  Icons.manage_accounts_rounded,
                  size: 20,
                  color: Color(0xFF285C2E),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Pengaturan Akun & Keamanan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E2923),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFEDF2EE)),
          const SizedBox(height: 6),

          _buildMenuItem(
            icon: Icons.person_outline_rounded,
            title: 'Edit Informasi Profil',
            subtitle: 'Ubah nama, nomor WhatsApp, dan wilayah kerja',
            onTap: onEditProfile,
          ),
          const Divider(height: 1, indent: 48, color: Color(0xFFF1F5F2)),

          _buildMenuItem(
            icon: Icons.add_a_photo_outlined,
            title: 'Kelola Foto Profil',
            subtitle: 'Unggah foto resmi dari galeri atau kamera HP',
            onTap: onManagePhoto,
          ),
          const Divider(height: 1, indent: 48, color: Color(0xFFF1F5F2)),

          _buildMenuItem(
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
                      color: const Color(0xFFE8F0FE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Google',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF1A73E8),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : null,
          ),
          const Divider(height: 1, indent: 48, color: Color(0xFFF1F5F2)),

          _buildMenuItem(
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
