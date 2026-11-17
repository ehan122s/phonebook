// ============================================================================
// [HALAMAN LOGIN - REDESIGN UI "MODERN SOFT GREEN"]
// File: lib/pages/login/login.dart
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

const Color kPrimaryGreen = Color(0xFF086B45);
const Color kDarkGreen = Color(0xFF064E38);
const Color kSecondaryGreen = Color(0xFF21834A);
const Color kLightGreen = Color(0xFFDCEFE2);
const Color kBackground = Color(0xFFF7FAF7);
const Color kTextMain = Color(0xFF26352D);
const Color kTextSecondary = Color(0xFF858D88);

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
        final userId = (userMap['id'] ?? '').toString().trim();
        final userEmail = (userMap['email'] ?? inputEmail).toString().trim();
        final rawName = (userMap['name'] ?? '').toString().trim();
        final userName =
            rawName.isNotEmpty ? rawName : userEmail.split('@').first;
        final userRole = (userMap['role'] ?? '').toString();
        final userNip = (userMap['nip'] ?? '').toString().trim();
        final userJabatan = (userMap['jabatan'] ?? '').toString().trim();
        final userWilayah = (userMap['wilayah'] ?? '').toString().trim();
        final userWhatsapp =
            (userMap['whatsapp_number'] ?? '').toString().trim();
        final userAvatar = (userMap['avatar'] ?? '').toString().trim();

        final isAdmin = _isAdminAccount(email: userEmail, role: userRole);

        await prefs.setString('token', data['data']['token']);
        if (userId.isNotEmpty) {
          await prefs.setString('user_id', userId);
        }
        await prefs.setString('name', userName);
        await prefs.setString('profil_nama', userName);
        await prefs.setString('email', userEmail);
        await prefs.setString('profil_email', userEmail);
        await prefs.setString('role', isAdmin ? 'admin' : 'user');
        await prefs.setString('login_method', 'email');
        await prefs.setString('nip', userNip);
        await prefs.setString('profil_nip', userNip);
        await prefs.setString(
          'jabatan',
          userJabatan.isNotEmpty
              ? userJabatan
              : (isAdmin ? 'Administrator CDK V' : 'Penyuluh Kehutanan'),
        );
        await prefs.setString(
          'profil_jabatan',
          userJabatan.isNotEmpty
              ? userJabatan
              : (isAdmin ? 'Administrator CDK V' : 'Penyuluh Kehutanan'),
        );
        await prefs.setString(
          'wilayah',
          userWilayah.isNotEmpty ? userWilayah : 'CDK Wilayah Garut',
        );
        await prefs.setString(
          'profil_wilayah',
          userWilayah.isNotEmpty ? userWilayah : 'CDK Wilayah Garut',
        );
        await prefs.setString('whatsapp_number', userWhatsapp);
        await prefs.setString('profil_whatsapp', userWhatsapp);
        await prefs.setString('avatar', userAvatar);
        await prefs.setString('profil_avatar', userAvatar);

        // Simpan kredensial terverifikasi terakhir untuk mendukung mode offline akun asli
        await prefs.setString('last_verified_email', userEmail.toLowerCase());
        await prefs.setString('last_verified_password', inputPassword);

        try {
          const userKey = 'phonebook_admin_users_v1';
          final rawUsers = prefs.getString(userKey);
          List<dynamic> users = [];
          if (rawUsers != null && rawUsers.isNotEmpty) {
            users = jsonDecode(rawUsers);
          }
          final alreadyPresent = users.any(
            (u) =>
                (u['email'] ?? '').toString().toLowerCase() ==
                userEmail.toLowerCase(),
          );
          if (!alreadyPresent) {
            users.add({
              'id': userId.isNotEmpty
                  ? userId
                  : 'USR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
              'nip': userNip.isNotEmpty ? userNip : '-',
              'name': userName,
              'email': userEmail,
              'whatsapp': userWhatsapp,
              'wilayah':
                  userWilayah.isNotEmpty ? userWilayah : 'CDK Wilayah Garut',
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

      // Mode offline hanya untuk akun asli yang sebelumnya pernah login di perangkat ini
      final prefs = await SharedPreferences.getInstance();
      final lastVerifiedEmail =
          (prefs.getString('last_verified_email') ?? '').toLowerCase();
      final lastVerifiedPassword =
          prefs.getString('last_verified_password') ?? '';

      if (lastVerifiedEmail.isNotEmpty &&
          inputEmail.toLowerCase() == lastVerifiedEmail &&
          inputPassword == lastVerifiedPassword) {
        final savedRole = prefs.getString('role') ?? 'user';
        final isAdmin =
            _isAdminAccount(email: inputEmail, role: savedRole);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Masuk menggunakan sesi tersimpan (Mode Offline).'),
          ),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => isAdmin ? const AdminPage() : const HomePage(),
          ),
          (route) => false,
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal terhubung ke server. Periksa koneksi internet Anda ($e)',
          ),
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgCol = isDark ? const Color(0xFF121814) : kBackground;

    return Scaffold(
      backgroundColor: bgCol,
      body: Stack(
        children: [
          const _SoftGreenDecoration(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: _buildLoginCard(isDark),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginCard(bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E2822) : Colors.white;
    final borderCol = isDark
        ? const Color(0xFF2E3D34)
        : kLightGreen.withValues(alpha: 0.6);

    return Container(
      padding: const EdgeInsets.fromLTRB(26, 34, 26, 30),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: kPrimaryGreen.withValues(alpha: isDark ? 0.22 : 0.10),
            blurRadius: 32,
            spreadRadius: 0,
            offset: const Offset(0, 14),
          ),
        ],
        border: Border.all(color: borderCol, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(isDark),
          const SizedBox(height: 30),
          _buildEmailField(isDark),
          const SizedBox(height: 18),
          _buildPasswordField(isDark),
          const SizedBox(height: 14),
          _buildRememberMe(isDark),
          const SizedBox(height: 26),
          _buildLoginButton(),
          const SizedBox(height: 24),
          _buildOrDivider(isDark),
          const SizedBox(height: 24),
          _buildGoogleButton(isDark),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.asset(
            'assets/images/logo_phonebook.jpeg',
            width: 104,
            height: 104,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 104,
                height: 104,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: kLightGreen.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.forest_outlined,
                  size: 56,
                  color: kPrimaryGreen,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'PHONEBOOK',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w800,
            letterSpacing: 3,
            color: isDark ? Colors.white : kDarkGreen,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF26352B)
                : kLightGreen.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Aplikasi Pelaporan Kehutanan',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: isDark ? const Color(0xFF81C784) : kSecondaryGreen,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmailField(bool isDark) {
    return TextField(
      controller: emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      style: TextStyle(
        fontSize: 16,
        color: isDark ? Colors.white : kTextMain,
      ),
      decoration: _inputDecoration(
        label: 'Email',
        icon: Icons.email_outlined,
        isDark: isDark,
      ),
    );
  }

  Widget _buildPasswordField(bool isDark) {
    return TextField(
      controller: passwordController,
      obscureText: obscurePassword,
      textInputAction: TextInputAction.done,
      style: TextStyle(
        fontSize: 16,
        color: isDark ? Colors.white : kTextMain,
      ),
      onSubmitted: (_) {
        if (!isLoading) login();
      },
      decoration: _inputDecoration(
        label: 'Password',
        icon: Icons.lock_outline,
        isDark: isDark,
        suffix: IconButton(
          tooltip:
              obscurePassword ? 'Tampilkan password' : 'Sembunyikan password',
          icon: Icon(
            obscurePassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: isDark ? const Color(0xFF81C784) : kSecondaryGreen,
            size: 24,
          ),
          onPressed: () {
            setState(() {
              obscurePassword = !obscurePassword;
            });
          },
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    required bool isDark,
    Widget? suffix,
  }) {
    OutlineInputBorder border(Color color, {double width = 1}) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    final borderCol = isDark ? const Color(0xFF2E3D34) : kLightGreen;
    final focusCol = isDark ? const Color(0xFF81C784) : kPrimaryGreen;

    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        fontSize: 15.5,
        color: isDark ? Colors.white70 : kTextSecondary,
      ),
      floatingLabelStyle: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: focusCol,
      ),
      prefixIcon: Icon(
        icon,
        color: isDark ? const Color(0xFF81C784) : kSecondaryGreen,
        size: 24,
      ),
      suffixIcon: suffix,
      filled: true,
      fillColor: isDark ? const Color(0xFF243329) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: border(borderCol),
      enabledBorder: border(borderCol),
      focusedBorder: border(focusCol, width: 1.6),
      errorBorder: border(Colors.red.shade300),
      focusedErrorBorder: border(Colors.red.shade400, width: 1.4),
    );
  }

  Widget _buildRememberMe(bool isDark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: () {
          setState(() {
            rememberMe = !rememberMe;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 26,
                width: 26,
                child: Checkbox(
                  value: rememberMe,
                  activeColor: kPrimaryGreen,
                  checkColor: Colors.white,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  side: BorderSide(
                    color: isDark ? Colors.white54 : kLightGreen,
                    width: 1.6,
                  ),
                  onChanged: (val) {
                    setState(() {
                      rememberMe = val ?? false;
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Ingat Saya',
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.white : kTextMain,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimaryGreen,
          foregroundColor: Colors.white,
          disabledBackgroundColor: kPrimaryGreen.withValues(alpha: 0.6),
          disabledForegroundColor: Colors.white70,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
          shadowColor: kPrimaryGreen.withValues(alpha: 0.35),
        ),
        onPressed: isLoading ? null : login,
        child: isLoading
            ? const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : const Text(
                'MASUK',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16.5,
                  letterSpacing: 1.2,
                ),
              ),
      ),
    );
  }

  Widget _buildOrDivider(bool isDark) {
    final divColor = isDark ? const Color(0xFF2E3D34) : kLightGreen;
    return Row(
      children: [
        Expanded(child: Divider(color: divColor, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'ATAU',
            style: TextStyle(
              color: isDark ? Colors.white60 : kTextSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.4,
            ),
          ),
        ),
        Expanded(child: Divider(color: divColor, thickness: 1)),
      ],
    );
  }

  Widget _buildGoogleButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: (isLoading || isGoogleLoading) ? null : _handleGoogleSignIn,
        style: OutlinedButton.styleFrom(
          backgroundColor: isDark ? const Color(0xFF243329) : Colors.white,
          foregroundColor: isDark ? Colors.white : kTextMain,
          side: BorderSide(
            color: isGoogleLoading
                ? kPrimaryGreen
                : (isDark ? const Color(0xFF2E3D34) : kLightGreen),
            width: 1.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: isGoogleLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color:
                          isDark ? const Color(0xFF81C784) : kPrimaryGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Menghubungkan Akun Google...',
                    style: TextStyle(
                      color:
                          isDark ? const Color(0xFF81C784) : kPrimaryGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const GoogleLogoWidget(size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'Masuk dengan Google',
                    style: TextStyle(
                      color: isDark ? Colors.white : kTextMain,
                      fontWeight: FontWeight.bold,
                      fontSize: 15.5,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _SoftGreenDecoration extends StatelessWidget {
  const _SoftGreenDecoration();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned(
          top: -110,
          right: -80,
          child: _Circle(
            size: 260,
            color: kLightGreen,
            opacity: 0.85,
          ),
        ),
        Positioned(
          top: 92,
          right: 34,
          child: _Ring(size: 46, color: kSecondaryGreen, opacity: 0.22),
        ),
        Positioned(
          top: 170,
          right: 78,
          child: _Circle(size: 14, color: kSecondaryGreen, opacity: 0.30),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 190,
          child: _TopWavePainter(),
        ),
        Positioned(
          bottom: -120,
          left: -90,
          child: _Circle(
            size: 300,
            color: kLightGreen,
            opacity: 0.7,
          ),
        ),
        Positioned(
          bottom: 150,
          left: 30,
          child: _Ring(size: 34, color: kPrimaryGreen, opacity: 0.16),
        ),
        Positioned(
          bottom: 90,
          right: 46,
          child: _Circle(size: 18, color: kLightGreen, opacity: 0.9),
        ),
        Positioned(
          bottom: -40,
          right: -60,
          child: _Circle(
            size: 160,
            color: kSecondaryGreen,
            opacity: 0.10,
          ),
        ),
      ],
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle({
    required this.size,
    required this.color,
    required this.opacity,
  });

  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: opacity),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({
    required this.size,
    required this.color,
    required this.opacity,
  });

  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withValues(alpha: opacity),
          width: 4,
        ),
      ),
    );
  }
}

class _TopWavePainter extends StatelessWidget {
  const _TopWavePainter();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _WaveCustomPainter(),
    );
  }
}

class _WaveCustomPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = kLightGreen.withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(0, size.height * 0.65)
      ..quadraticBezierTo(
        size.width * 0.35,
        size.height * 0.95,
        size.width * 0.72,
        size.height * 0.48,
      )
      ..quadraticBezierTo(
        size.width * 0.88,
        size.height * 0.25,
        size.width,
        size.height * 0.38,
      )
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}