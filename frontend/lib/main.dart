import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String baseUrl = 'http://127.0.0.1:8001';

void main() {
  runApp(const PhonebookApp());
}

class PhonebookApp extends StatelessWidget {
  const PhonebookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Phonebook',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
        scaffoldBackgroundColor: const Color(0xFFF7FAF7),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
        ),
      ),
      home: const LoginPage(),
    );
  }
}

// ============================================================
// LOGIN
// ============================================================

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;
  bool obscurePassword = true;

  Future<void> _login() async {
    if (emailController.text.trim().isEmpty ||
        passwordController.text.isEmpty) {
      _showMessage('Email dan password wajib diisi.');
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
        body: jsonEncode({
          'email': emailController.text.trim(),
          'password': passwordController.text,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        final prefs = await SharedPreferences.getInstance();

        final user = responseData['data']['user'];
        final token = responseData['data']['token'];

        await prefs.setString('token', token);
        await prefs.setString('user_name', user['name'] ?? '');
        await prefs.setString('user_email', user['email'] ?? '');

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DashboardPage(
              userName: user['name'] ?? 'Pengguna',
            ),
          ),
        );
      } else {
        String message = 'Email atau password salah.';

        if (responseData['message'] != null) {
          message = responseData['message'].toString();
        }

        _showMessage(message);
      }
    } catch (e) {
      _showMessage(
        'Tidak dapat terhubung ke server Laravel.\n'
        'Pastikan API Laravel sedang berjalan.',
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                const SizedBox(height: 40),

                // LOGO
                Container(
                  width: 85,
                  height: 85,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.forest,
                    size: 52,
                    color: Color(0xFF43A047),
                  ),
                ),

                const SizedBox(height: 22),

                const Text(
                  'PHONEBOOK',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    color: Color(0xFF1B1B1B),
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Aplikasi Pelaporan Kehutanan',
                  style: TextStyle(
                    fontSize: 17,
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height: 45),

                // EMAIL
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // PASSWORD
                TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          obscurePassword = !obscurePassword;
                        });
                      },
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE8F5E9),
                      foregroundColor: const Color(0xFF2E6B35),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 25,
                            height: 25,
                            child: CircularProgressIndicator(),
                          )
                        : const Text(
                            'LOGIN',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// DASHBOARD USER
// ============================================================

class DashboardPage extends StatefulWidget {
  final String userName;

  const DashboardPage({
    super.key,
    required this.userName,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int selectedNav = 0;

  // Data sementara untuk tampilan dashboard.
  // Nanti kita sambungkan ke API Laravel.
  final int totalLaporan = 12;
  final int totalMateri = 5;
  final int totalJadwal = 3;
  final int totalKategori = 4;

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();

    final token = prefs.getString('token');

    try {
      if (token != null) {
        await http.post(
          Uri.parse('$baseUrl/api/logout'),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
      }
    } catch (_) {
      // Tetap logout dari aplikasi meskipun API logout gagal.
    }

    await prefs.clear();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginPage(),
      ),
      (route) => false,
    );
  }

  void _showComingSoon(String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$name akan dibuat pada tahap berikutnya.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),

      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isWide = constraints.maxWidth >= 800;

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isWide ? 1100 : 700,
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          isWide ? 30 : 18,
                          18,
                          isWide ? 30 : 18,
                          30,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ==========================================
                            // WELCOME
                            // ==========================================

                            _buildWelcomeCard(),

                            const SizedBox(height: 22),

                            // ==========================================
                            // STATS
                            // ==========================================

                            _buildStatsCard(),

                            const SizedBox(height: 28),

                            // ==========================================
                            // MENU UTAMA
                            // ==========================================

                            const Text(
                              'Menu Utama',
                              style: TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF163D25),
                              ),
                            ),

                            const SizedBox(height: 15),

                            GridView.count(
                              crossAxisCount: 2,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              childAspectRatio: isWide ? 2.8 : 1.35,
                              children: [
                                _buildMenuCard(
                                  icon: Icons.description_outlined,
                                  title: 'Laporan',
                                  subtitle: 'Kelola laporan kegiatan',
                                  color: const Color(0xFF2E7D32),
                                  background: const Color(0xFFEAF7ED),
                                  onTap: () {
                                    _showComingSoon('Laporan');
                                  },
                                ),
                                _buildMenuCard(
                                  icon: Icons.menu_book_outlined,
                                  title: 'Materi',
                                  subtitle: 'Akses materi pembelajaran',
                                  color: const Color(0xFF1976D2),
                                  background: const Color(0xFFEAF4FF),
                                  onTap: () {
                                    _showComingSoon('Materi');
                                  },
                                ),
                                _buildMenuCard(
                                  icon: Icons.calendar_month_outlined,
                                  title: 'Jadwal',
                                  subtitle: 'Lihat jadwal kegiatan',
                                  color: const Color(0xFFF57C00),
                                  background: const Color(0xFFFFF4E8),
                                  onTap: () {
                                    _showComingSoon('Jadwal');
                                  },
                                ),
                                _buildMenuCard(
                                  icon: Icons.folder_outlined,
                                  title: 'Kategori',
                                  subtitle: 'Kelola kategori laporan',
                                  color: const Color(0xFF673AB7),
                                  background: const Color(0xFFF2EDFF),
                                  onTap: () {
                                    _showComingSoon('Kategori');
                                  },
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // ==========================================
                            // LIHAT SELENGKAPNYA
                            // ==========================================

                            SizedBox(
                              width: double.infinity,
                              height: 58,
                              child: OutlinedButton(
                                onPressed: () {
                                  _showComingSoon('Menu lainnya');
                                },
                                style: OutlinedButton.styleFrom(
                                  backgroundColor:
                                      const Color(0xFFEAF6ED),
                                  side: BorderSide.none,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Lihat Selengkapnya',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF216B2C),
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Icon(
                                      Icons.arrow_forward,
                                      color: Color(0xFF216B2C),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ==========================================
                    // BOTTOM NAVIGATION
                    // ==========================================

                    _buildBottomNavigation(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ==========================================================
  // WELCOME CARD
  // ==========================================================

  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5EA),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFF2E7D32),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person,
              size: 45,
              color: Colors.white,
            ),
          ),

          const SizedBox(width: 18),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Selamat Datang,',
                  style: TextStyle(
                    fontSize: 17,
                    color: Color(0xFF356343),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.userName,
                  style: const TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF153C21),
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Semangat dalam menjalankan tugas\npelaporan kehutanan!',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: Color(0xFF52705A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // STATS
  // ==========================================================

  Widget _buildStatsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFE1E8E1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.bar_chart_rounded,
                color: Color(0xFF2E7D32),
                size: 28,
              ),
              const SizedBox(width: 10),
              const Text(
                'Ringkasan Data',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF163D25),
                ),
              ),
              const Spacer(),
              Text(
                'Total',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 17),

          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  icon: Icons.description_outlined,
                  title: 'Laporan',
                  value: totalLaporan,
                  color: const Color(0xFF2E7D32),
                  background: const Color(0xFFEAF7ED),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.menu_book_outlined,
                  title: 'Materi',
                  value: totalMateri,
                  color: const Color(0xFF1976D2),
                  background: const Color(0xFFEAF4FF),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.calendar_month_outlined,
                  title: 'Jadwal',
                  value: totalJadwal,
                  color: const Color(0xFFF57C00),
                  background: const Color(0xFFFFF4E8),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.folder_outlined,
                  title: 'Kategori',
                  value: totalKategori,
                  color: const Color(0xFF673AB7),
                  background: const Color(0xFFF2EDFF),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String title,
    required int value,
    required Color color,
    required Color background,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 15,
        horizontal: 7,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value.toString(),
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.bold,
              color: Color(0xFF17251B),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // MENU CARD
  // ==========================================================

  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color background,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 27,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF18261C),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        color: Color(0xFF617064),
                      ),
                    ),
                  ],
                ),
              ),

              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 17,
                color: color,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // BOTTOM NAVIGATION
  // ==========================================================

  Widget _buildBottomNavigation() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Colors.grey.shade200,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Row(
        children: [
          Expanded(
            child: _buildNavButton(
              icon: Icons.home_rounded,
              label: 'Beranda',
              index: 0,
              onTap: () {
                setState(() {
                  selectedNav = 0;
                });
              },
            ),
          ),

          Expanded(
            child: _buildNavButton(
              icon: Icons.description_outlined,
              label: 'Laporan',
              index: 1,
              onTap: () {
                setState(() {
                  selectedNav = 1;
                });
                _showComingSoon('Laporan');
              },
            ),
          ),

          Expanded(
            child: _buildNavButton(
              icon: Icons.calendar_month_outlined,
              label: 'Jadwal',
              index: 2,
              onTap: () {
                setState(() {
                  selectedNav = 2;
                });
                _showComingSoon('Jadwal');
              },
            ),
          ),

          Expanded(
            child: _buildNavButton(
              icon: Icons.menu_book_outlined,
              label: 'Materi',
              index: 3,
              onTap: () {
                setState(() {
                  selectedNav = 3;
                });
                _showComingSoon('Materi');
              },
            ),
          ),

          Expanded(
            child: _buildExitNavButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required String label,
    required int index,
    required VoidCallback onTap,
  }) {
    final bool active = selectedNav == index;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 7,
          horizontal: 4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 25,
              color: active
                  ? const Color(0xFF2E7D32)
                  : Colors.grey.shade600,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight:
                    active ? FontWeight.bold : FontWeight.normal,
                color: active
                    ? const Color(0xFF2E7D32)
                    : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 5),

            // Garis indikator halaman aktif
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: active ? 48 : 0,
              height: 3,
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // EXIT NAV BUTTON + HOVER
  // ==========================================================

  Widget _buildExitNavButton() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: 'Keluar Aplikasi',
        preferBelow: false,
        verticalOffset: 12,
        waitDuration: const Duration(milliseconds: 300),
        child: InkWell(
          onTap: () async {
            final bool? confirm = await showDialog<bool>(
              context: context,
              builder: (context) {
                return AlertDialog(
                  title: const Text('Keluar Aplikasi'),
                  content: const Text(
                    'Apakah kamu yakin ingin keluar dari aplikasi?',
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

            if (confirm == true) {
              await _logout();
            }
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(
              vertical: 7,
              horizontal: 5,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEEEE),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.logout_rounded,
                  size: 25,
                  color: Color(0xFFD32F2F),
                ),
                SizedBox(height: 4),
                Text(
                  'Keluar',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFD32F2F),
                  ),
                ),
                SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}