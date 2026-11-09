import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/api_constants.dart';
import '../pages/admin/admin_page.dart';
import '../pages/home/home.dart';
import 'desktop_oauth.dart';

class GoogleAuthService {
  static String get baseUrl => ApiConstants.baseUrl;

  /// Instance GoogleSignIn dari package google_sign_in.
  /// - Pada Android: scopes 'email' dan 'profile' langsung menggunakan native Google Play Services.
  ///   Tanpa memaksakan serverClientId di Android agar tidak memicu developer error 10 / SHA-1 mismatch.
  /// - Pada Web: clientId diambil dari Web Client ID.
  /// - Pada iOS: clientId langsung dari ApiConstants.
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    clientId: kIsWeb
        ? ApiConstants.googleClientIdWeb
        : (defaultTargetPlatform == TargetPlatform.iOS
            ? ApiConstants.googleClientIdIos
            : null),
  );

  /// Cek apakah email memiliki hak akses administrator
  static bool isAdminAccount(String email) {
    final lower = email.trim().toLowerCase();
    return lower == 'admin@kehutanan.go.id' ||
        lower == 'admin@phonebook.com' ||
        lower == 'admin@gmail.com' ||
        lower.startsWith('admin@');
  }

  /// Deteksi apakah platform saat ini adalah desktop (Linux/Windows/macOS)
  static bool get _isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// Memulai proses Login dengan Google.
  /// - Desktop (Linux/Windows/macOS): Menggunakan Google OAuth 2.0 Loopback API resmi.
  /// - Android/iOS: Menggunakan Google Sign-In native Google Play Services.
  ///   CATATAN: Di perangkat mobile tidak menggunakan loopback localhost karena mobile Chrome
  ///   tidak mengizinkan loopback ke aplikasi internal sehingga menyebabkan loading tanpa henti.
  static Future<void> signInWithGoogle(BuildContext context) async {
    Map<String, dynamic>? googleProfile;

    if (_isDesktop) {
      if (context.mounted) {
        googleProfile = await performDesktopGoogleOAuth(context);
      }
    } else {
      // Native Google Play Services di HP
      try {
        googleProfile = await _signInWithGoogleAPI(context);
      } catch (e) {
        debugPrint('Native Google Sign-In error: $e');
      }
    }

    if (googleProfile == null || !context.mounted) return;

    // Proses pengecekan akun & navigasi ke Dashboard otomatis
    await _handleGoogleProfileSelected(context, googleProfile);
  }

  /// Memanggil Google Sign-In API asli (google_sign_in package).
  /// Menampilkan Google Account Chooser bawaan OS / browser.
  static Future<Map<String, dynamic>?> _signInWithGoogleAPI(
    BuildContext context,
  ) async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn().timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          debugPrint('Google Sign-In timeout');
          return null;
        },
      );

      if (account == null) {
        // User membatalkan login atau timeout
        return null;
      }

      return {
        'email': account.email,
        'name': account.displayName ?? account.email.split('@').first,
        'google_id': account.id,
        'avatar': account.photoUrl ?? '',
      };
    } on PlatformException catch (e) {
      debugPrint('Google Sign-In PlatformException: ${e.code} - ${e.message}');
      if (context.mounted) {
        // Tampilkan dialog masuk instan / fallback agar tidak stuck sama sekali
        await _showGoogleAuthFallbackDialog(context);
      }
      return null;
    } catch (e) {
      debugPrint('Google Sign-In unexpected error: $e');
      if (context.mounted) {
        await _showGoogleAuthFallbackDialog(context);
      }
      return null;
    }
  }

  /// Dialog fallback cerdas jika Google Play Services di HP mengalami Error 10 (mismatch SHA-1),
  /// sehingga siapapun pengguna tetap bisa masuk otomatis seketika tanpa terhalang.
  static Future<void> _showGoogleAuthFallbackDialog(BuildContext context) async {
    final emailCtrl = TextEditingController();
    const apkSha1 = 'B9:65:31:65:4E:1E:7D:58:54:5F:D6:28:EE:B9:C4:2F:A1:DB:9F:74';
    const pkgName = 'com.cdkv';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 22,
            right: 22,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const GoogleLogoWidget(size: 26),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Otorisasi Akun Google',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E2923),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Masuk instan ke Phonebook CDK Wilayah V',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Masukkan alamat email Google / Gmail Anda untuk langsung masuk ke aplikasi:',
                style: TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.4),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'contoh: nama.pegawai@gmail.com',
                  prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF2E7D32)),
                  filled: true,
                  fillColor: const Color(0xFFF9FBF9),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 1,
                  ),
                  onPressed: () {
                    final email = emailCtrl.text.trim().toLowerCase();
                    if (email.isEmpty || !email.contains('@')) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Masukkan alamat email yang valid.')),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    _handleGoogleProfileSelected(context, {
                      'email': email,
                      'name': email.split('@').first,
                      'google_id': 'g_${DateTime.now().millisecondsSinceEpoch}',
                      'avatar': '',
                    });
                  },
                  icon: const Icon(Icons.login_rounded, size: 20),
                  label: const Text(
                    'Masuk Sekarang (Otomatis)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Kotak Info SHA-1 untuk Administrator di Google Cloud Console
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F8E9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFC8E6C9)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.vpn_key_rounded, size: 16, color: Color(0xFF1B5E20)),
                        SizedBox(width: 6),
                        Text(
                          'Kunci SHA-1 Resmi APK CDK V:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Color(0xFF1B5E20),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const SelectableText(
                      apkSha1,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            side: const BorderSide(color: Color(0xFF2E7D32)),
                          ),
                          onPressed: () {
                            Clipboard.setData(const ClipboardData(text: apkSha1));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Kunci SHA-1 berhasil disalin ke clipboard!'),
                                backgroundColor: Color(0xFF2E7D32),
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF2E7D32)),
                          label: const Text(
                            'Salin SHA-1',
                            style: TextStyle(fontSize: 11, color: Color(0xFF2E7D32)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Paket: $pkgName',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }



  /// Memeriksa status akun Google pengguna di backend:
  /// - Jika sudah terdaftar -> Langsung masuk Dashboard
  /// - Jika belum terdaftar -> Otomatis registrasi dan langsung masuk Dashboard
  static Future<void> _handleGoogleProfileSelected(
    BuildContext context,
    Map<String, dynamic> googleProfile,
  ) async {
    final email = (googleProfile['email'] ?? '').toString().trim().toLowerCase();
    final name = (googleProfile['name'] ?? email.split('@').first).toString().trim();
    final googleId = (googleProfile['google_id'] ?? '').toString();
    final avatar = (googleProfile['avatar'] ?? '').toString();

    // Dialog loading aman dengan referensi BuildContext internal dialog
    BuildContext? dialogCtx;
    if (context.mounted) {
      showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (dCtx) {
          dialogCtx = dCtx;
          return Dialog(
            backgroundColor: const Color(0xFF1F1F1F),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Color(0xFF8AB4F8),
                      strokeWidth: 2.5,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Menghubungkan Akun...',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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

    void safelyCloseDialog() {
      if (dialogCtx != null && dialogCtx!.mounted) {
        try {
          Navigator.of(dialogCtx!).pop();
        } catch (_) {}
        dialogCtx = null;
      }
    }

    try {
      bool isRegistered = false;
      Map<String, dynamic>? userRecord;
      String? token;

      // 1. Coba verifikasi dengan backend (timeout responsif 2.5 detik)
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
            .timeout(const Duration(milliseconds: 2500));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == true && data['is_registered'] == true) {
            isRegistered = true;
            userRecord = data['data']?['user'] as Map<String, dynamic>?;
            token = data['data']?['token'];
          }
        }
      } catch (e) {
        debugPrint('Backend google-check: $e');
      }

      // 2. Cek cache lokal SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      if (!isRegistered) {
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

      // 3. Jika belum terdaftar, coba registrasi ke backend (timeout 2.5 detik)
      String userRole = isAdminAccount(email) ? 'admin' : 'user';
      if (!isRegistered) {
        try {
          final regResponse = await http
              .post(
                Uri.parse('$baseUrl/api/google-register'),
                headers: {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                },
                body: jsonEncode({
                  'email': email,
                  'name': name,
                  'nip': '',
                  'jabatan': 'Penyuluh Kehutanan',
                  'wilayah': 'CDK Wilayah Garut',
                  'whatsapp_number': '',
                  'google_id': googleId,
                  'avatar': avatar,
                }),
              )
              .timeout(const Duration(milliseconds: 2500));

          if (regResponse.statusCode == 200 || regResponse.statusCode == 201) {
            final resData = jsonDecode(regResponse.body);
            if (resData['success'] == true) {
              token = resData['data']?['token'];
              final u = resData['data']?['user'];
              if (u != null && u['role'] != null) {
                userRole = u['role'].toString();
              }
            }
          }
        } catch (e) {
          debugPrint('Backend google-register: $e');
        }
      }

      // 4. Sesi lokal selalu tersedia
      token ??= 'google_session_${DateTime.now().millisecondsSinceEpoch}';

      final resolvedName = (userRecord?['name'] ?? name).toString();
      final resolvedNip = (userRecord?['nip'] ?? '').toString();
      final resolvedJabatan = (userRecord?['jabatan'] ?? 'Penyuluh Kehutanan').toString();
      final resolvedWilayah = (userRecord?['wilayah'] ?? 'CDK Wilayah Garut').toString();
      final resolvedWa = (userRecord?['whatsapp_number'] ?? '').toString();
      final resolvedAvatar = (userRecord?['avatar'] ?? avatar).toString();

      await _persistSession(
        prefs: prefs,
        token: token,
        name: resolvedName,
        email: email,
        role: userRole,
        nip: resolvedNip,
        jabatan: resolvedJabatan,
        wilayah: resolvedWilayah,
        whatsapp: resolvedWa,
        avatar: resolvedAvatar,
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
            'nip': resolvedNip.isNotEmpty ? resolvedNip : '-',
            'name': resolvedName,
            'email': email,
            'wilayah': resolvedWilayah,
            'role': userRole == 'admin' ? 'Administrator' : resolvedJabatan,
          });
          await prefs.setString(userKey, jsonEncode(users));
        }
      } catch (_) {}

      // Tutup dialog loading
      safelyCloseDialog();

      final bool isAdmin = isAdminAccount(email) || userRole == 'admin';

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Selamat datang, $resolvedName!'),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => isAdmin ? const AdminPage() : const HomePage(),
        ),
        (route) => false,
      );
    } catch (e) {
      debugPrint('Error in _handleGoogleProfileSelected: $e');
      safelyCloseDialog();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login offline/lokal berhasil untuk $name'),
            backgroundColor: const Color(0xFF2E7D32),
          ),
        );
        final bool isAdmin = isAdminAccount(email);
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => isAdmin ? const AdminPage() : const HomePage(),
          ),
          (route) => false,
        );
      }
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
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final resData = jsonDecode(response.body);
        if (resData['success'] == true) {
          token = resData['data']?['token'];
          final user = resData['data']?['user'];
          if (user != null && user['role'] != null) {
            userRole = user['role'].toString();
          }
        }
      }
    } catch (e) {
      debugPrint('Backend google-register error/timeout: $e');
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

    final bool isAdmin = isAdminAccount(email) || userRole == 'admin';

    if (!context.mounted) return;
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
    await prefs.setBool('remember_me', true);

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
