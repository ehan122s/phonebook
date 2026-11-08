// ============================================================================
// [FILE LOGIN - OTOMATIS MASUK SESUAI AKUN (ADMIN vs USER)]
// Simpan file ini di: lib/pages/login.dart
// - Jika login memakai akun Admin (role == 'admin' atau email admin) -> AdminPage()
// - Jika login memakai akun User biasa -> HomePage()
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

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  bool obscurePassword = true;
  bool rememberMe = false;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 6,
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.forest,
                      size: 70,
                      color: Color(0xFF2E7D32),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'PHONEBOOK',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Aplikasi Pelaporan Kehutanan',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 30),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      onSubmitted: (_) {
                        if (!isLoading) login();
                      },
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              obscurePassword = !obscurePassword;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        SizedBox(
                          height: 24,
                          width: 24,
                          child: Checkbox(
                            value: rememberMe,
                            activeColor: const Color(0xFF2E7D32),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            onChanged: (val) {
                              setState(() {
                                rememberMe = val ?? false;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              rememberMe = !rememberMe;
                            });
                          },
                          child: const Text(
                            'Ingat Saya',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF2E7D32),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        onPressed: isLoading ? null : login,
                        child: isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'MASUK',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey.shade300)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            'ATAU',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.grey.shade300)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: isLoading
                            ? null
                            : () => GoogleAuthService.signInWithGoogle(context),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GoogleLogoWidget(size: 22),
                            SizedBox(width: 12),
                            Text(
                              'Masuk dengan Google',
                              style: TextStyle(
                                color: Color(0xFF1E2923),
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
