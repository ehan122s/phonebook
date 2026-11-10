// ============================================================================
// [FILE LOGIN - OTOMATIS MASUK SESUAI AKUN (ADMIN vs USER)]
// Simpan file ini di: lib/pages/login.dart  (path sesuai project Anda)
// - Jika login memakai akun Admin (role == 'admin' atau email admin) -> AdminPage()
// - Jika login memakai akun User biasa -> HomePage()
//
// REDESAIN UI: Modern Soft Green (layout ref. #5, palet ref. #4)
// Seluruh logika autentikasi (API, token, Ingat Saya, Google, fallback offline)
// TIDAK diubah. Hanya method build() dan beberapa widget pendukung UI.
//
// PENTING: logo membutuhkan aset di  assets/images/logo_phonebook.png
// dan harus didaftarkan di pubspec.yaml (lihat catatan di akhir jawaban).
// ============================================================================

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/api_constants.dart';
import '../../services/google_auth_service.dart';
import '../admin/admin_page.dart';
import '../home/home.dart';

String get baseUrl => ApiConstants.baseUrl;

// ---------------------------------------------------------------------------
// Palet warna login (hanya dipakai di halaman ini)
// ---------------------------------------------------------------------------
class _LoginColors {
  static const primary = Color(0xFF086B45);
  static const dark = Color(0xFF064E38);
  static const secondary = Color(0xFF21834A);
  static const light = Color(0xFFDCEFE2);
  static const background = Color(0xFFF7FAF7);
  static const white = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF26352D);
  static const textSecondary = Color(0xFF858D88);
  static const border = Color(0xFFC9D8CE); // hijau keabu-abuan
  static const divider = Color(0xFFDDE6DF);
}

const String _logoAsset = 'assets/images/logo_phonebook.png';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  bool isGoogleLoading = false;
  bool obscurePassword = true;
  bool rememberMe = false;

  Future<void> _handleGoogleSignIn() async {
    if (isLoading || isGoogleLoading) return;
    setState(() {
      isGoogleLoading = true;
    });

    try {
      await GoogleAuthService.signInWithGoogle(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kendala login Google: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isGoogleLoading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadRememberedCredentials();
  }

  Future<void> _loadRememberedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    bool isRemember = false;
    try {
      isRemember = prefs.getBool('remember_me') ?? false;
    } catch (_) {
      isRemember = prefs.getString('remember_me') == 'true';
    }
    if (isRemember) {
      final savedEmail = prefs.getString('remember_email') ?? '';
      final savedPassword = prefs.getString('remember_password') ?? '';
      if (mounted) {
        setState(() {
          rememberMe = true;
          emailController.text = savedEmail;
          passwordController.text = savedPassword;
        });
      }
    }
  }

  /// Mengecek apakah akun yang login adalah akun khusus Admin
  bool _isAdminAccount({required String email, required String role}) {
    final lowerEmail = email.trim().toLowerCase();
    final lowerRole = role.trim().toLowerCase();

    return lowerRole == 'admin' ||
        lowerEmail == 'admin@kehutanan.go.id' ||
        lowerEmail == 'admin@phonebook.com' ||
        lowerEmail == 'admin@gmail.com' ||
        lowerEmail.startsWith('admin@');
  }

  Future<void> login() async {
    final inputEmail = emailController.text.trim();
    final inputPassword = passwordController.text;

    if (inputEmail.isEmpty || inputPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email dan password wajib diisi')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/login'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'email': inputEmail, 'password': inputPassword}),
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode == 200 &&
          data['success'] == true &&
          data['data']?['token'] != null) {
        final prefs = await SharedPreferences.getInstance();

        final userMap = data['data']['user'] ?? {};
        final userEmail = (userMap['email'] ?? inputEmail).toString();
        final userName = (userMap['name'] ?? '').toString();
        final userRole = (userMap['role'] ?? '').toString();

        final isAdmin = _isAdminAccount(email: userEmail, role: userRole);

        await prefs.setString('token', data['data']['token']);
        await prefs.setString('name', userName);
        await prefs.setString('email', userEmail);
        await prefs.setString('role', isAdmin ? 'admin' : 'user');

        try {
          const userKey = 'phonebook_admin_users_v1';
          final rawUsers = prefs.getString(userKey);
          List<dynamic> users = [];
          if (rawUsers != null && rawUsers.isNotEmpty) {
            users = jsonDecode(rawUsers);
          }
          final alreadyPresent = users.any(
            (u) => (u['email'] ?? '').toString().toLowerCase() == userEmail.toLowerCase(),
          );
          if (!alreadyPresent) {
            users.add({
              'id': 'USR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
              'nip': (userMap['nip'] ?? '').toString().isNotEmpty ? userMap['nip'].toString() : '-',
              'name': userName.isNotEmpty ? userName : userEmail.split('@').first,
              'email': userEmail,
              'whatsapp': (userMap['whatsapp_number'] ?? '').toString(),
              'wilayah': (userMap['wilayah'] ?? '').toString().isNotEmpty ? userMap['wilayah'].toString() : 'CDK Wilayah Garut',
              'role': isAdmin ? 'Administrator' : 'Penyuluh',
              'status': 'Aktif',
            });
            await prefs.setString(userKey, jsonEncode(users));
          }
        } catch (_) {}

        if (rememberMe) {
          await prefs.setBool('remember_me', true);
          await prefs.setString('remember_email', inputEmail);
          await prefs.setString('remember_password', inputPassword);
        } else {
          await prefs.setBool('remember_me', false);
          await prefs.remove('remember_email');
          await prefs.remove('remember_password');
        }

        if (!mounted) return;

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => isAdmin ? const AdminPage() : const HomePage(),
          ),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Email atau password salah'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      // Offline fallback login for testing credentials when server is offline
      if (inputEmail == 'admin@kehutanan.go.id' && inputPassword == 'admin123') {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', 'offline_admin_token');
        await prefs.setString('name', 'Admin Kehutanan');
        await prefs.setString('email', inputEmail);
        await prefs.setString('role', 'admin');
        if (rememberMe) {
          await prefs.setBool('remember_me', true);
          await prefs.setString('remember_email', inputEmail);
          await prefs.setString('remember_password', inputPassword);
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login berhasil (Mode Offline)')),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AdminPage()),
          (route) => false,
        );
        return;
      } else if (inputEmail == 'ehan@gmail.com' && inputPassword == '12345678') {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', 'offline_user_token');
        await prefs.setString('name', 'Ehan (Penyuluh Kehutanan)');
        await prefs.setString('email', inputEmail);
        await prefs.setString('role', 'user');
        if (rememberMe) {
          await prefs.setBool('remember_me', true);
          await prefs.setString('remember_email', inputEmail);
          await prefs.setString('remember_password', inputPassword);
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login berhasil (Mode Offline)')),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomePage()),
          (route) => false,
        );
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal terhubung ke server: $e')));
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ==========================================================================
  // UI (REDESAIN)
  // ==========================================================================

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: _LoginColors.textSecondary,
        fontSize: 16,
      ),
      prefixIcon: Icon(icon, color: _LoginColors.textPrimary, size: 24),
      suffixIcon: suffix,
      filled: true,
      fillColor: _LoginColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      enabledBorder: border(_LoginColors.border),
      border: border(_LoginColors.border),
      focusedBorder: border(_LoginColors.primary, 1.6),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        SizedBox(
          height: 96,
          child: Image.asset(
            _logoAsset,
            fit: BoxFit.contain,
            // Cadangan agar halaman tidak error bila aset belum terdaftar.
            errorBuilder: (_, __, ___) => const Icon(
              Icons.forest,
              size: 80,
              color: _LoginColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'PHONEBOOK',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: _LoginColors.primary,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Aplikasi Pelaporan Kehutanan',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: _LoginColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildRememberMe() {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        setState(() {
          rememberMe = !rememberMe;
        });
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 26,
              width: 26,
              child: Checkbox(
                value: rememberMe,
                activeColor: _LoginColors.primary,
                side: const BorderSide(color: _LoginColors.border, width: 1.6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                onChanged: (val) {
                  setState(() {
                    rememberMe = val ?? false;
                  });
                },
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Ingat Saya',
              style: TextStyle(
                fontSize: 15,
                color: _LoginColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    final disabled = isLoading;
    return Opacity(
      opacity: disabled ? 0.85 : 1,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_LoginColors.primary, _LoginColors.secondary],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33086B45),
              blurRadius: 12,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: disabled ? null : login,
          child: isLoading
              ? const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.6,
                    color: Colors.white,
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'MASUK',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: const [
        Expanded(child: Divider(color: _LoginColors.divider, thickness: 1)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'ATAU',
            style: TextStyle(
              color: _LoginColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Expanded(child: Divider(color: _LoginColors.divider, thickness: 1)),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: (isLoading || isGoogleLoading) ? null : _handleGoogleSignIn,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: BorderSide(
            color: isGoogleLoading ? _LoginColors.primary : _LoginColors.border,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: isGoogleLoading
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: _LoginColors.primary,
                    ),
                  ),
                  SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'Menghubungkan Akun Google...',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _LoginColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GoogleLogoWidget(size: 24),
                  SizedBox(width: 12),
                  Text(
                    'Masuk dengan Google',
                    style: TextStyle(
                      color: _LoginColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _circle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  /// Dekorasi abstrak: lingkaran/lengkungan hijau muda transparan.
  Widget _buildBackgroundDecoration() {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -90,
            left: -80,
            child: _circle(250, const Color(0x66DCEFE2)),
          ),
          Positioned(
            top: 40,
            right: -70,
            child: _circle(190, const Color(0x4D21834A)),
          ),
          Positioned(
            top: 70,
            right: 34,
            child: _circle(18, const Color(0x6621834A)),
          ),
          Positioned(
            bottom: -110,
            left: -90,
            child: _circle(290, const Color(0x59DCEFE2)),
          ),
          Positioned(
            bottom: -60,
            right: -70,
            child: _circle(210, const Color(0x40086B45)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _LoginColors.background,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned.fill(child: _buildBackgroundDecoration()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
                    decoration: BoxDecoration(
                      color: _LoginColors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1A064E38),
                          blurRadius: 28,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 28),
                        TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          style: const TextStyle(
                            fontSize: 16,
                            color: _LoginColors.textPrimary,
                          ),
                          decoration: _inputDecoration(
                            hint: 'Email',
                            icon: Icons.email_outlined,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: passwordController,
                          obscureText: obscurePassword,
                          style: const TextStyle(
                            fontSize: 16,
                            color: _LoginColors.textPrimary,
                          ),
                          onSubmitted: (_) {
                            if (!isLoading) login();
                          },
                          decoration: _inputDecoration(
                            hint: 'Password',
                            icon: Icons.lock_outline,
                            suffix: IconButton(
                              tooltip: obscurePassword
                                  ? 'Tampilkan password'
                                  : 'Sembunyikan password',
                              icon: Icon(
                                obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: _LoginColors.textSecondary,
                              ),
                              onPressed: () {
                                setState(() {
                                  obscurePassword = !obscurePassword;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _buildRememberMe(),
                        ),
                        const SizedBox(height: 8),
                        _buildLoginButton(),
                        const SizedBox(height: 22),
                        _buildDivider(),
                        const SizedBox(height: 22),
                        _buildGoogleButton(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}