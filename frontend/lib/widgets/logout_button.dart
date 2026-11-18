import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/api_constants.dart';
import '../pages/dashboard/dashboard.dart';
import '../pages/login/login.dart';
import '../services/google_auth_service.dart';
import '../services/laporan_service.dart';
import '../services/notification_service.dart';

class LogoutButton extends StatelessWidget {
  final VoidCallback? onLoggedOut;

  const LogoutButton({
    super.key,
    this.onLoggedOut,
  });

  /// Dialog konfirmasi logout: "Apakah Anda yakin ingin logout dari aplikasi?"
  static Future<bool> confirmLogout(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryDark = isDark ? Colors.white : const Color(0xFF1E2923);
    final subColor = isDark ? Colors.white70 : Colors.grey.shade600;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E2822) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFC62828).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: Color(0xFFC62828),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Konfirmasi Keluar',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryDark,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin logout dari aplikasi?',
          style: TextStyle(
            fontSize: 14.5,
            color: subColor,
            height: 1.4,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: primaryDark,
              side: BorderSide(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Ya, Logout',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    return result == true;
  }

  Future<void> logout(BuildContext context, {bool showConfirmation = true}) async {
    if (showConfirmation) {
      final confirmed = await confirmLogout(context);
      if (!confirmed) return;
    }

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

    // Bersihkan seluruh cache in-memory dan isolasi data jadwal antar-akun
    DashboardPage.clearStaticCache();
    LaporanService.clearCache();
    await NotificationService.instance.rescheduleAllFromList([]);
    await prefs.remove('phonebook_jadwal_items_v1'); // Hapus legacy global cache yang tercampur

    onLoggedOut?.call();

    if (!context.mounted) return;

    // Tampilkan notifikasi berhasil logout
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Anda telah berhasil logout dari aplikasi.'),
        backgroundColor: Color(0xFF245C3A),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ),
    );

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
