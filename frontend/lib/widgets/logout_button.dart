import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/api_constants.dart';
import '../pages/login/login.dart';
import '../services/google_auth_service.dart';

class LogoutButton extends StatelessWidget {
  final VoidCallback? onLoggedOut;

  const LogoutButton({
    super.key,
    this.onLoggedOut,
  });

  Future<void> logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    // Panggil endpoint logout backend secara asynchronous dengan timeout singkat
    if (token != null && token.isNotEmpty) {
      try {
        await http
            .post(
              Uri.parse('${ApiConstants.baseUrl}/logout'),
              headers: {
                'Accept': 'application/json',
                'Authorization': 'Bearer $token',
              },
            )
            .timeout(const Duration(seconds: 4));
      } catch (_) {
        // Tetap lanjutkan proses logout lokal meskipun jaringan sedang offline
      }
    }

    // Putuskan sesi Google Sign-In bila pengguna login menggunakan Google
    try {
      await GoogleAuthService.signOut();
    } catch (_) {}

    // Bersihkan kredensial sesi login tanpa menghapus pengaturan tema/preferensi perangkat
    await prefs.remove('token');
    await prefs.remove('user_id');
    await prefs.remove('name');
    await prefs.remove('email');
    await prefs.remove('role');
    await prefs.remove('whatsapp_number');

    onLoggedOut?.call();

    if (!context.mounted) return;

    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const LoginPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: const Cubic(0.22, 1.0, 0.36, 1.0),
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.98, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => logout(context),
        icon: const Icon(Icons.logout_rounded, size: 20),
        label: const Text(
          'Keluar dari Akun',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark
              ? const Color(0xFF3B1E1E)
              : const Color(0xFFFFEBEE),
          foregroundColor: isDark
              ? const Color(0xFFEF9A9A)
              : const Color(0xFFC62828),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isDark
                  ? const Color(0xFFEF9A9A).withValues(alpha: 0.25)
                  : const Color(0xFFEF5350).withValues(alpha: 0.30),
            ),
          ),
        ),
      ),
    );
  }
}