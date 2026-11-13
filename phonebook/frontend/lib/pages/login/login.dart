// ============================================================================
// [HALAMAN LOGIN - REDESIGN UI "MODERN SOFT GREEN"]
// File: lib/pages/login.dart
//
// DESAIN:
// - Layout referensi nomor 5 : Modern Soft Green (minimalis, dekorasi abstrak
//   berupa lingkaran & lengkungan transparan, card putih rounded, shadow lembut)
// - Palet warna referensi nomor 4 : hijau tua / hijau sedang / putih (split green)
// - Logo pohon resmi aplikasi (assets/images/logo_phonebook.jpeg)
//
// CATATAN PENTING:
// - Seluruh logika autentikasi dipertahankan 100% dari versi sebelumnya:
//   login API Laravel, validasi, token SharedPreferences, Ingat Saya,
//   login Google, fallback offline, dan routing Admin/User.
// - Perubahan hanya pada tampilan (UI/UX).
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

// ----------------------------------------------------------------------------
// PALET WARNA (referensi desain nomor 4 - Split Green)
// ----------------------------------------------------------------------------
const Color kPrimaryGreen = Color(0xFF086B45); // Hijau utama
const Color kDarkGreen = Color(0xFF064E38); // Hijau gelap
const Color kSecondaryGreen = Color(0xFF21834A); // Hijau sekunder
const Color kLightGreen = Color(0xFFDCEFE2); // Hijau muda
const Color kBackground = Color(0xFFF7FAF7); // Background putih kehijauan
const Color kTextMain = Color(0xFF26352D); // Teks utama
const Color kTextSecondary = Color(0xFF858D88); // Teks sekunder

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

  // --------------------------------------------------------------------------
  // ============================ BUILD UI ====================================
  // --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      // resizeToAvoidBottomInset default true: form otomatis naik saat keyboard muncul
      body: Stack(
        children: [
          // Dekorasi abstrak latar belakang (lingkaran & lengkungan transparan)
          const _SoftGreenDecoration(),

          // Konten utama (bisa di-scroll pada layar kecil)
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: _buildLoginCard(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Card putih utama berisi seluruh elemen form login
  Widget _buildLoginCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(26, 34, 26, 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          // Shadow lembut kehijauan, tidak berlebihan
          BoxShadow(
            color: kPrimaryGreen.withOpacity(0.10),
            blurRadius: 32,
            spreadRadius: 0,
            offset: const Offset(0, 14),
          ),
        ],
        border: Border.all(color: kLightGreen.withOpacity(0.6), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          const SizedBox(height: 30),
          _buildEmailField(),
          const SizedBox(height: 18),
          _buildPasswordField(),
          const SizedBox(height: 14),
          _buildRememberMe(),
          const SizedBox(height: 26),
          _buildLoginButton(),
          const SizedBox(height: 24),
          _buildOrDivider(),
          const SizedBox(height: 24),
          _buildGoogleButton(),
        ],
      ),
    );
  }

  /// A. Bagian Header : logo pohon, judul PHONEBOOK, dan subtitle
  Widget _buildHeader() {
    return Column(
      children: [
        // Logo pohon resmi aplikasi (tidak diubah / tidak diganti).
        // errorBuilder memakai ikon cadangan agar aplikasi tetap aman
        // bila asset belum ditambahkan ke pubspec.yaml.
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
                  color: kLightGreen.withOpacity(0.45),
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
        const Text(
          'PHONEBOOK',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w800,
            letterSpacing: 3,
            color: kDarkGreen,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: kLightGreen.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'Aplikasi Pelaporan Kehutanan',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: kSecondaryGreen,
            ),
          ),
        ),
      ],
    );
  }

  /// Input Email dengan ikon email
  Widget _buildEmailField() {
    return TextField(
      controller: emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      style: const TextStyle(fontSize: 16, color: kTextMain),
      decoration: _inputDecoration(
        label: 'Email',
        icon: Icons.email_outlined,
      ),
    );
  }

  /// Input Password dengan ikon gembok + tombol lihat/sembunyikan password
  Widget _buildPasswordField() {
    return TextField(
      controller: passwordController,
      obscureText: obscurePassword,
      textInputAction: TextInputAction.done,
      style: const TextStyle(fontSize: 16, color: kTextMain),
      onSubmitted: (_) {
        if (!isLoading) login();
      },
      decoration: _inputDecoration(
        label: 'Password',
        icon: Icons.lock_outline,
        suffix: IconButton(
          tooltip: obscurePassword ? 'Tampilkan password' : 'Sembunyikan password',
          icon: Icon(
            obscurePassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: kSecondaryGreen,
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

  /// Gaya input standar: border tipis hijau keabu-abuan, fokus hijau utama
  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    OutlineInputBorder border(Color color, {double width = 1}) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 15.5, color: kTextSecondary),
      floatingLabelStyle: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: kPrimaryGreen,
      ),
      prefixIcon: Icon(icon, color: kSecondaryGreen, size: 24),
      prefixIconColor: kSecondaryGreen,
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: border(kLightGreen),
      enabledBorder: border(kLightGreen),
      focusedBorder: border(kPrimaryGreen, width: 1.6),
      errorBorder: border(Colors.red.shade300),
      focusedErrorBorder: border(Colors.red.shade400, width: 1.4),
    );
  }

  /// Checkbox "Ingat Saya" dengan area sentuh yang besar
  Widget _buildRememberMe() {
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
                  side: const BorderSide(color: kLightGreen, width: 1.6),
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
                  color: kTextMain,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Tombol MASUK - hijau utama, tinggi nyaman ditekan (56)
  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimaryGreen,
          foregroundColor: Colors.white,
          disabledBackgroundColor: kPrimaryGreen.withOpacity(0.6),
          disabledForegroundColor: Colors.white70,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
          shadowColor: kPrimaryGreen.withOpacity(0.35),
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

  /// Pemisah dengan tulisan "ATAU"
  Widget _buildOrDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: kLightGreen, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'ATAU',
            style: TextStyle(
              color: kTextSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.4,
            ),
          ),
        ),
        Expanded(child: Divider(color: kLightGreen, thickness: 1)),
      ],
    );
  }

  /// C. Tombol "Masuk dengan Google" (ikon Google resmi dari project)
  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: (isLoading || isGoogleLoading) ? null : _handleGoogleSignIn,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: kTextMain,
          side: BorderSide(
            color: isGoogleLoading ? kPrimaryGreen : kLightGreen,
            width: 1.2,
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
                      color: kPrimaryGreen,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Menghubungkan Akun Google...',
                    style: TextStyle(
                      color: kPrimaryGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
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
                      color: kTextMain,
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

// ============================================================================
// DEKORASI LATAR BELAKANG - Modern Soft Green
// Lingkaran & lengkungan transparan berwarna hijau muda.
// Semua elemen diposisikan "overflow" ke luar tepi layar dan otomatis
// terpotong oleh Stack, sehingga aman untuk semua ukuran layar.
// ============================================================================
class _SoftGreenDecoration extends StatelessWidget {
  const _SoftGreenDecoration();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        // Lingkaran besar transparan kanan atas (hijau muda)
        Positioned(
          top: -110,
          right: -80,
          child: _Circle(
            size: 260,
            color: kLightGreen,
            opacity: 0.85,
          ),
        ),
        // Cincin (ring) kecil kanan atas
        Positioned(
          top: 92,
          right: 34,
          child: _Ring(size: 46, color: kSecondaryGreen, opacity: 0.22),
        ),
        // Titik hijau sekunder kecil
        Positioned(
          top: 170,
          right: 78,
          child: _Circle(size: 14, color: kSecondaryGreen, opacity: 0.30),
        ),
        // Lengkungan gelombang halus di bagian atas layar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 190,
          child: _TopWavePainter(),
        ),
        // Lingkaran besar transparan kiri bawah (hijau muda)
        Positioned(
          bottom: -120,
          left: -90,
          child: _Circle(
            size: 300,
            color: kLightGreen,
            opacity: 0.7,
          ),
        ),
        // Cincin kecil kiri bawah
        Positioned(
          bottom: 150,
          left: 30,
          child: _Ring(size: 34, color: kPrimaryGreen, opacity: 0.16),
        ),
        // Titik kecil kanan bawah
        Positioned(
          bottom: 90,
          right: 46,
          child: _Circle(size: 18, color: kLightGreen, opacity: 0.9),
        ),
        // Lingkaran sedikit lebih gelap kanan bawah
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

/// Lingkaran solid transparan
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
        color: color.withOpacity(opacity),
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Cincin / outline lingkaran transparan
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
          color: color.withOpacity(opacity),
          width: 2.4,
        ),
      ),
    );
  }
}

/// Lengkungan halus (dua kurva bezier) sebagai aksen bagian atas layar
class _TopWavePainter extends StatelessWidget {
  const _TopWavePainter();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 190),
      painter: _WavePainter(),
    );
  }
}

class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..color = kSecondaryGreen.withOpacity(0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;

    final paint2 = Paint()
      ..color = kPrimaryGreen.withOpacity(0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Kurva pertama
    final path1 = Path();
    path1.moveTo(0, size.height * 0.38);
    path1.quadraticBezierTo(
      size.width * 0.28,
      size.height * 0.10,
      size.width * 0.55,
      size.height * 0.34,
    );
    path1.quadraticBezierTo(
      size.width * 0.80,
      size.height * 0.56,
      size.width,
      size.height * 0.30,
    );

    // Kurva kedua, sedikit di bawah kurva pertama
    final path2 = Path();
    path2.moveTo(0, size.height * 0.52);
    path2.quadraticBezierTo(
      size.width * 0.30,
      size.height * 0.24,
      size.width * 0.58,
      size.height * 0.48,
    );
    path2.quadraticBezierTo(
      size.width * 0.82,
      size.height * 0.68,
      size.width,
      size.height * 0.44,
    );

    canvas.drawPath(path1, paint1);
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
