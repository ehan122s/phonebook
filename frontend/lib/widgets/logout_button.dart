import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../pages/login/login.dart';

class LogoutButton extends StatelessWidget {
  const LogoutButton({super.key});

  Future<void> logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Keluar Aplikasi'),
          content: const Text(
            'Apakah kamu yakin ingin keluar?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                foregroundColor: Colors.white,
              ),
              child: const Text('Keluar'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    final prefs = await SharedPreferences.getInstance();

    bool isRemember = false;
    try {
      isRemember = prefs.getBool('remember_me') ?? false;
    } catch (_) {
      isRemember = prefs.getString('remember_me') == 'true';
    }
    // Hapus hanya data sesi pengguna yang sedang login,
    // JANGAN memanggil prefs.clear() agar data database pengguna, arsip folder,
    // materi, dan draft laporan tidak hilang saat logout.
    const sessionKeys = [
      'token',
      'name',
      'email',
      'role',
      'login_method',
      'profil_nama',
      'profil_nip',
      'profil_jabatan',
      'profil_wilayah',
      'profil_email_nip',
      'profil_whatsapp',
      'profil_avatar',
    ];

    for (final key in sessionKeys) {
      await prefs.remove(key);
    }

    if (!isRemember) {
      await prefs.remove('remember_me');
      await prefs.remove('remember_email');
      await prefs.remove('remember_password');
    }

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginPage(),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => logout(context),
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 11,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2822) : Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: isDark ? const Color(0xFF2E3D34) : const Color(0xFFE0E7E1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.08),
                blurRadius: 9,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.logout_rounded,
            color: Color(0xFFD32F2F),
            size: 22,
          ),
        ),
      ),
    );
  }
}