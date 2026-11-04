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
import '../pages/lengkapi_profil_page.dart';

class GoogleAuthService {
  /// Instance resmi Google Sign-In API.
  /// CATATAN PENTING: clientId HANYA digunakan pada platform Web.
  /// Pada Android/iOS, clientId HARUS bernilai null agar Google Play Services
  /// dapat memunculkan bottom-sheet akun Google resmi asli dari HP pengguna (seperti aplikasi Shopee).
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb && ApiConstants.googleClientId.isNotEmpty
        ? ApiConstants.googleClientId
        : null,
    scopes: const [
      'email',
      'https://www.googleapis.com/auth/userinfo.profile',
    ],
  );

  static String get baseUrl => ApiConstants.baseUrl;

  /// Cek apakah email memiliki hak akses administrator
  static bool isAdminAccount(String email) {
    final lower = email.trim().toLowerCase();
    return lower == 'admin@kehutanan.go.id' ||
        lower == 'admin@phonebook.com' ||
        lower == 'admin@gmail.com' ||
        lower.startsWith('admin@');
  }

  /// Memulai proses Login dengan Google API resmi secara langsung.
  /// Menampilkan bottom-sheet pemilih akun Google bawaan HP (Google Play Services) seperti Shopee.
  static Future<void> signInWithGoogle(BuildContext context) async {
    try {
      // 1. Reset sesi sebelumnya agar dialog pemilih akun Google Play Services
      // selalu muncul di layar HP pengguna untuk memilih akun yang diinginkan
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      // 2. Panggil API Google Sign-In resmi bawaan perangkat
      final GoogleSignInAccount? account = await _googleSignIn.signIn();

      if (account == null) {
        // Pengguna membatalkan pemilihan akun di bottom-sheet Google
        return;
      }

      final googleProfile = {
        'email': account.email,
        'name': account.displayName ?? account.email.split('@').first,
        'google_id': account.id,
        'avatar': account.photoUrl ?? '',
      };

      if (!context.mounted) return;

      // 3. Proses pengecekan akun & navigasi ke Dashboard atau Lengkapi Profil
      await _handleGoogleProfileSelected(context, googleProfile);
    } on MissingPluginException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Google Sign-In asli membutuhkan Google Play Services di perangkat HP (Android/iOS) atau browser Web.',
            ),
            backgroundColor: Color(0xFFC62828),
          ),
        );
      }
    } on PlatformException catch (e) {
      debugPrint('Google Sign-In PlatformException: ${e.code} - ${e.message}');
      if (context.mounted) {
        if (e.code != 'sign_in_canceled') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Google Sign-In: ${e.message ?? e.code}'),
              backgroundColor: const Color(0xFFC62828),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menghubungkan Google API: $e'),
            backgroundColor: const Color(0xFFC62828),
          ),
        );
      }
    }
  }

  /// Memeriksa status akun Google pengguna di backend:
  /// - Jika sudah terdaftar -> Langsung masuk Dashboard
  /// - Jika belum terdaftar -> Arahkan ke formulir Lengkapi Profil Pegawai
  static Future<void> _handleGoogleProfileSelected(
    BuildContext context,
    Map<String, dynamic> googleProfile,
  ) async {
    final email = (googleProfile['email'] ?? '').toString().trim().toLowerCase();
    final name = (googleProfile['name'] ?? email.split('@').first).toString().trim();
    final googleId = (googleProfile['google_id'] ?? '').toString();
    final avatar = (googleProfile['avatar'] ?? '').toString();

    // Tampilkan loading dialog in-app
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
                    'Memeriksa Akun Google...',
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

    bool isRegistered = false;
    Map<String, dynamic>? userRecord;
    String? token;

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/google-check'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'email': email}),
          )
          .timeout(const Duration(seconds: 8));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        if (data['is_registered'] == true) {
          isRegistered = true;
          userRecord = data['data']?['user'] as Map<String, dynamic>?;
          token = data['data']?['token'];
        } else {
          isRegistered = false;
        }
      }
    } catch (e) {
      debugPrint('Backend google-check error: $e');

      // Offline fallback: Cek SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final cachedEmail = (prefs.getString('email') ?? '').trim().toLowerCase();
      final rawUsers = prefs.getString('phonebook_admin_users_v1');

      if (cachedEmail.isNotEmpty && cachedEmail == email) {
        isRegistered = true;
      } else if (rawUsers != null && rawUsers.contains(email)) {
        isRegistered = true;
      } else if (isAdminAccount(email)) {
        isRegistered = true;
      }
    }

    if (!context.mounted) return;
    // Tutup loading dialog
    Navigator.of(context, rootNavigator: true).pop();

    if (isRegistered) {
      // 1. Akun SUDAH TERDAFTAR -> Masuk langsung ke Dashboard
      final prefs = await SharedPreferences.getInstance();
      final userRole = (userRecord?['role'] ?? (isAdminAccount(email) ? 'admin' : 'user')).toString();
      final resolvedName = (userRecord?['name'] ?? name).toString();
      final resolvedNip = (userRecord?['nip'] ?? '').toString();
      final resolvedJabatan = (userRecord?['jabatan'] ?? '').toString();
      final resolvedWilayah = (userRecord?['wilayah'] ?? '').toString();
      final resolvedWa = (userRecord?['whatsapp_number'] ?? '').toString();
      final resolvedAvatar = (userRecord?['avatar'] ?? avatar).toString();

      await _persistSession(
        prefs: prefs,
        token: token ?? 'google_session_${DateTime.now().millisecondsSinceEpoch}',
        name: resolvedName,
        email: email,
        role: userRole,
        nip: resolvedNip,
        jabatan: resolvedJabatan,
        wilayah: resolvedWilayah,
        whatsapp: resolvedWa,
        avatar: resolvedAvatar,
      );

      final bool isAdmin = isAdminAccount(email) || userRole == 'admin';

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Selamat datang kembali, $resolvedName!'),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => isAdmin ? const AdminPage() : const HomePage(),
        ),
        (route) => false,
      );
    } else {
      // 2. Akun BELUM TERDAFTAR -> Arahkan ke formulir Lengkapi Profil
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Akun Google belum terdaftar. Silakan lengkapi formulir pendaftaran.'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LengkapiProfilPage(
            googleData: {
              'email': email,
              'name': name,
              'google_id': googleId,
              'avatar': avatar,
            },
          ),
        ),
      );
    }
  }

  /// Mendaftarkan data profil pegawai baru dari Google dan langsung mengarahkan ke Dashboard
  static Future<void> registerAndEnterDashboard(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    final email = (data['email'] ?? '').toString().trim().toLowerCase();
    final name = (data['name'] ?? email.split('@').first).toString().trim();
    final nip = (data['nip'] ?? '').toString().trim();
    final jabatan = (data['jabatan'] ?? '').toString().trim();
    final wilayah = (data['wilayah'] ?? '').toString().trim();
    final wa = (data['whatsapp_number'] ?? '').toString().trim();
    final googleId = (data['google_id'] ?? '').toString();
    final avatar = (data['avatar'] ?? '').toString();

    // Tampilkan loading dialog
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
                    'Menyimpan Profil & Menuju Dashboard...',
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

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/google-register'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'email': email,
              'name': name,
              'nip': nip,
              'jabatan': jabatan,
              'wilayah': wilayah,
              'whatsapp_number': wa,
              'google_id': googleId,
              'avatar': avatar,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final resData = jsonDecode(response.body);

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          resData['success'] == true) {
        token = resData['data']?['token'];
        final user = resData['data']?['user'];
        if (user != null && user['role'] != null) {
          userRole = user['role'].toString();
        }
      }
    } catch (e) {
      debugPrint('Backend google-register error: $e');
    }

    token ??= 'google_reg_${DateTime.now().millisecondsSinceEpoch}';

    final prefs = await SharedPreferences.getInstance();
    await _persistSession(
      prefs: prefs,
      token: token,
      name: name,
      email: email,
      role: userRole,
      nip: nip,
      jabatan: jabatan,
      wilayah: wilayah,
      whatsapp: wa,
      avatar: avatar,
    );

    // Sinkronkan ke daftar folder user admin di SharedPreferences
    try {
      const userKey = 'phonebook_admin_users_v1';
      final rawUsers = prefs.getString(userKey);
      List<dynamic> users = [];
      if (rawUsers != null && rawUsers.isNotEmpty) {
        users = jsonDecode(rawUsers);
      }
      final alreadyPresent = users.any(
        (u) => (u['email'] ?? '').toString().toLowerCase() == email,
      );
      if (!alreadyPresent) {
        users.add({
          'id': 'USR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
          'nip': nip.isNotEmpty ? nip : '-',
          'name': name,
          'email': email,
          'wilayah': wilayah.isNotEmpty ? wilayah : 'CDK Wilayah Garut',
          'role': userRole == 'admin' ? 'Administrator' : (jabatan.isNotEmpty ? jabatan : 'Penyuluh'),
        });
        await prefs.setString(userKey, jsonEncode(users));
      }
    } catch (_) {}

    if (!context.mounted) return;
    // Tutup loading dialog
    Navigator.of(context, rootNavigator: true).pop();

    final bool isAdmin = isAdminAccount(email) || userRole == 'admin';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Pendaftaran berhasil! Selamat datang, $name.'),
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

  /// Menyimpan sesi autentikasi dan profil pengguna ke SharedPreferences (Auto-Login aktif)
  static Future<void> _persistSession({
    required SharedPreferences prefs,
    required String token,
    required String name,
    required String email,
    required String role,
    String nip = '',
    String jabatan = '',
    String wilayah = '',
    String whatsapp = '',
    String avatar = '',
  }) async {
    final isAdmin = isAdminAccount(email) || role.toLowerCase() == 'admin';
    final resolvedRole = isAdmin ? 'admin' : 'user';

    final emailNip = nip.isNotEmpty ? '$nip • $email' : email;
    final wilayahJabatan = (jabatan.isNotEmpty && wilayah.isNotEmpty)
        ? '$jabatan • $wilayah'
        : (jabatan.isNotEmpty ? jabatan : wilayah);

    await prefs.setString('token', token);
    await prefs.setString('name', name);
    await prefs.setString('email', email);
    await prefs.setString('role', resolvedRole);
    await prefs.setString('login_method', 'google');
    await prefs.setString('remember_me', 'true');

    await prefs.setString('profil_nama', name);
    await prefs.setString('profil_nip', nip);
    await prefs.setString('profil_jabatan', jabatan);
    await prefs.setString('profil_wilayah', wilayahJabatan);
    await prefs.setString('profil_email_nip', emailNip);

    if (whatsapp.isNotEmpty) {
      await prefs.setString('profil_whatsapp', whatsapp);
    }
    if (avatar.isNotEmpty) {
      await prefs.setString('profil_avatar', avatar);
    }
  }
}

/// Logo 4 warna resmi Google
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
    canvas.drawArc(rect, -2.356, 1.57, false, paintRed);
    canvas.drawArc(rect, 2.356, 1.57, false, paintYellow);
    canvas.drawArc(rect, 0.785, 1.57, false, paintGreen);
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
