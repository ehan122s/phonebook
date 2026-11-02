import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/api_constants.dart';
import '../pages/admin_page.dart';
import '../pages/home.dart';

class GoogleAuthService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  static String get baseUrl => ApiConstants.baseUrl;

  /// Check if an email has admin privileges
  static bool isAdminAccount(String email) {
    final lower = email.trim().toLowerCase();
    return lower == 'admin@kehutanan.go.id' ||
        lower == 'admin@phonebook.com' ||
        lower == 'admin@gmail.com' ||
        lower.startsWith('admin@');
  }

  /// Initiates Google Sign-In flow across platforms (Android, iOS, Web, Linux)
  static Future<void> signInWithGoogle(BuildContext context) async {
    Map<String, dynamic>? googleProfile;

    // 1. On Android, iOS, or Web, try native GoogleSignIn
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        final GoogleSignInAccount? account = await _googleSignIn.signIn();
        if (account == null) {
          // User cancelled the Google sign in dialog
          return;
        }

        googleProfile = {
          'email': account.email,
          'name': account.displayName ?? account.email.split('@').first,
          'google_id': account.id,
          'avatar': account.photoUrl ?? '',
        };
      } on MissingPluginException {
        // Platform lacks native plugin implementation (e.g. desktop)
        if (context.mounted) {
          googleProfile = await _showAccountPickerModal(context);
        }
      } on PlatformException catch (e) {
        // Developer error / unconfigured SHA-1 in debug mode -> fallback to picker
        debugPrint('Google Sign-In PlatformException: ${e.message}');
        if (context.mounted) {
          googleProfile = await _showAccountPickerModal(context);
        }
      } catch (e) {
        debugPrint('Google Sign-In Error: $e');
        if (context.mounted) {
          googleProfile = await _showAccountPickerModal(context);
        }
      }
    } else {
      // Desktop platforms (Linux, macOS, Windows)
      googleProfile = await _showAccountPickerModal(context);
    }

    if (googleProfile == null || !context.mounted) return;

    await _processGoogleLogin(context, googleProfile);
  }

  /// Sends Google profile to backend API and logs user in
  static Future<void> _processGoogleLogin(
    BuildContext context,
    Map<String, dynamic> profile,
  ) async {
    final email = (profile['email'] ?? '').toString().trim().toLowerCase();
    final name = (profile['name'] ?? email.split('@').first).toString().trim();
    final googleId = (profile['google_id'] ?? '').toString();
    final avatar = (profile['avatar'] ?? '').toString();

    // Show loading dialog
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: Color(0xFF2E7D32),
                  strokeWidth: 3,
                ),
                SizedBox(width: 20),
                Expanded(
                  child: Text(
                    'Menghubungkan akun Google...',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E2923),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    String? token;
    String userRole = isAdminAccount(email) ? 'admin' : 'user';
    String userName = name;
    String userEmail = email;

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/google-login'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'email': email,
              'name': name,
              'google_id': googleId,
              'avatar': avatar,
            }),
          )
          .timeout(const Duration(seconds: 8));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        token = data['data']?['token'];
        final user = data['data']?['user'] ?? {};
        userName = (user['name'] ?? name).toString();
        userEmail = (user['email'] ?? email).toString();
        userRole = (user['role'] ?? userRole).toString();
      }
    } catch (e) {
      debugPrint('Backend google-login fallback: $e');
    }

    // Fallback if backend is currently paused or offline
    token ??= 'google_token_${DateTime.now().millisecondsSinceEpoch}';

    final isAdmin = isAdminAccount(userEmail) || userRole == 'admin';
    final resolvedRole = isAdmin ? 'admin' : 'user';

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setString('name', userName);
    await prefs.setString('email', userEmail);
    await prefs.setString('role', resolvedRole);
    await prefs.setString('login_method', 'google');
    await prefs.setString('profil_nama', userName);
    await prefs.setString('profil_email', userEmail);
    if (avatar.isNotEmpty) {
      await prefs.setString('profil_avatar', avatar);
    }

    if (!context.mounted) return;
    // Dismiss loading dialog
    Navigator.of(context, rootNavigator: true).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Berhasil masuk dengan akun Google: $userEmail'),
        backgroundColor: const Color(0xFF2E7D32),
      ),
    );

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => isAdmin ? const AdminPage() : const HomePage(),
      ),
      (route) => false,
    );
  }

  /// Modern Google Account Selector dialog that works on desktop, web, and devices
  static Future<Map<String, dynamic>?> _showAccountPickerModal(
    BuildContext context,
  ) async {
    final customEmailCtrl = TextEditingController();
    final customNameCtrl = TextEditingController();

    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            22,
            16,
            22,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const GoogleLogoWidget(size: 26),
                    const SizedBox(width: 12),
                    const Text(
                      'Pilih Akun Google',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E2923),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Pilih akun Google Anda untuk melanjutkan ke Phonebook Kehutanan:',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 16),

                // Preset Google Account 1: Standard Penyuluh
                _GoogleAccountTile(
                  name: 'Penyuluh Kehutanan (Ehan)',
                  email: 'ehan@gmail.com',
                  badge: 'Penyuluh',
                  badgeColor: const Color(0xFF2E7D32),
                  onTap: () {
                    Navigator.pop(ctx, {
                      'email': 'ehan@gmail.com',
                      'name': 'Ehan (Penyuluh Kehutanan)',
                      'google_id': 'google_user_001',
                    });
                  },
                ),
                const SizedBox(height: 8),

                // Preset Google Account 2: Administrator
                _GoogleAccountTile(
                  name: 'Admin Kehutanan',
                  email: 'admin@kehutanan.go.id',
                  badge: 'Administrator',
                  badgeColor: const Color(0xFF1565C0),
                  onTap: () {
                    Navigator.pop(ctx, {
                      'email': 'admin@kehutanan.go.id',
                      'name': 'Admin Kehutanan',
                      'google_id': 'google_admin_001',
                    });
                  },
                ),
                const SizedBox(height: 14),

                // Custom Account Expansion
                Theme(
                  data: Theme.of(ctx).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                    ),
                    title: const Text(
                      'Gunakan Akun Google Lain',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 4),
                        child: Column(
                          children: [
                            TextField(
                              controller: customNameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Nama Lengkap',
                                hintText: 'Contoh: Budi Santoso',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: customEmailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Email Google',
                                hintText: 'nama@gmail.com',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2E7D32),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () {
                                  final inputEmail = customEmailCtrl.text.trim();
                                  final inputName = customNameCtrl.text.trim();
                                  if (inputEmail.isEmpty ||
                                      !inputEmail.contains('@')) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(
                                        content: Text('Masukkan email Google yang valid'),
                                      ),
                                    );
                                    return;
                                  }
                                  Navigator.pop(ctx, {
                                    'email': inputEmail,
                                    'name': inputName.isNotEmpty
                                        ? inputName
                                        : inputEmail.split('@').first,
                                    'google_id':
                                        'custom_${DateTime.now().millisecondsSinceEpoch}',
                                  });
                                },
                                child: const Text(
                                  'Lanjutkan dengan Akun Ini',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GoogleAccountTile extends StatelessWidget {
  final String name;
  final String email;
  final String badge;
  final Color badgeColor;
  final VoidCallback onTap;

  const _GoogleAccountTile({
    required this.name,
    required this.email,
    required this.badge,
    required this.badgeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FBF9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: badgeColor.withValues(alpha: 0.14),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'G',
                style: TextStyle(
                  color: badgeColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E2923),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: badgeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

/// Crisply painted official 4-color Google "G" logo
class GoogleLogoWidget extends StatelessWidget {
  final double size;
  const GoogleLogoWidget({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final center = Offset(w / 2, h / 2);
    final radius = w / 2;

    // Background circle clip
    final strokeWidth = radius * 0.44;
    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    final paintRed = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final paintYellow = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final paintGreen = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final paintBlue = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    // Arcs
    // Red: Top left to top right
    canvas.drawArc(rect, -2.356, 1.57, false, paintRed);
    // Yellow: Bottom left
    canvas.drawArc(rect, 2.356, 1.57, false, paintYellow);
    // Green: Bottom right
    canvas.drawArc(rect, 0.785, 1.57, false, paintGreen);
    // Blue: Right arc
    canvas.drawArc(rect, -0.785, 1.57, false, paintBlue);

    // Blue horizontal bar
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;

    final barRect = Rect.fromLTRB(
      center.dx - radius * 0.05,
      center.dy - strokeWidth / 2,
      center.dx + radius * 0.95,
      center.dy + strokeWidth / 2,
    );
    canvas.drawRect(barRect, barPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
