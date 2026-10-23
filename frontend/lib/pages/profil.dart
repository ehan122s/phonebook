
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/logout_button.dart';

class ProfilPage extends StatefulWidget {
  const ProfilPage({super.key});

  @override
  State<ProfilPage> createState() => _ProfilPageState();
}

class _ProfilPageState extends State<ProfilPage> {
  String _nama = 'Rizky Pratama, S.Hut.';
  String _emailNip = '19940812 202012 1 004 • rizky@kehutanan.go.id';
  String _wilayahJabatan = 'Penyuluh Kehutanan • CDK Wilayah Garut';

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _nama = prefs.getString('profil_nama') ??
          prefs.getString('name') ??
          'Rizky Pratama, S.Hut.';
      _emailNip = prefs.getString('profil_email_nip') ??
          prefs.getString('email') ??
          '19940812 202012 1 004 • rizky@kehutanan.go.id';
      _wilayahJabatan = prefs.getString('profil_wilayah') ??
          'Penyuluh Kehutanan • CDK Wilayah Garut';
    });
  }

  Future<void> _saveProfileData({
    required String nama,
    required String emailNip,
    required String wilayah,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profil_nama', nama);
    await prefs.setString('profil_email_nip', emailNip);
    await prefs.setString('profil_wilayah', wilayah);

    if (!mounted) return;
    setState(() {
      _nama = nama;
      _emailNip = emailNip;
      _wilayahJabatan = wilayah;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Identitas profil berhasil diperbarui.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showEditProfileDialog() {
    final namaCtrl = TextEditingController(text: _nama);
    final emailNipCtrl = TextEditingController(text: _emailNip);
    final wilayahCtrl = TextEditingController(text: _wilayahJabatan);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Edit Identitas Profil',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: namaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nama Lengkap',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailNipCtrl,
                decoration: const InputDecoration(
                  labelText: 'NIP / Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: wilayahCtrl,
                decoration: const InputDecoration(
                  labelText: 'Jabatan & Wilayah Tugas',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Batal',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF285C2E),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _saveProfileData(
                nama: namaCtrl.text.trim().isEmpty
                    ? _nama
                    : namaCtrl.text.trim(),
                emailNip: emailNipCtrl.text.trim().isEmpty
                    ? _emailNip
                    : emailNipCtrl.text.trim(),
                wilayah: wilayahCtrl.text.trim().isEmpty
                    ? _wilayahJabatan
                    : wilayahCtrl.text.trim(),
              );
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // =================================================================
            // 1. LAYER "Prof": Header Melengkung Setengah Lingkaran + Avatar
            // =================================================================
            ClipPath(
              clipper: _ProfileHeaderClipper(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 44, 20, 64),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF285C2E),
                      Color(0xFF3B7A42),
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    // Baris Judul Halaman & Tombol Edit di Pojok Kanan Atas
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: _showEditProfileDialog,
                          tooltip: 'Edit Profil',
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Lingkaran Avatar di Tengah Lengkungan (Sesuai Figma)
                    GestureDetector(
                      onTap: _showEditProfileDialog,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                            child: const CircleAvatar(
                              radius: 48,
                              backgroundColor: Color(0xFFE8F5E9),
                              child: Icon(
                                Icons.person_rounded,
                                size: 54,
                                color: Color(0xFF285C2E),
                              ),
                            ),
                          ),
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF285C2E),
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.camera_alt_outlined,
                              size: 16,
                              color: Color(0xFF285C2E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // =================================================================
            // 2. LAYER "Identitas": 3 Grup Label Kecil + Kotak Isi di Bawahnya
            // =================================================================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _IdentitasField(
                    label: 'Nama Lengkap',
                    value: _nama,
                    icon: Icons.badge_outlined,
                  ),
                  const SizedBox(height: 22),
                  _IdentitasField(
                    label: 'NIP / Email',
                    value: _emailNip,
                    icon: Icons.alternate_email_rounded,
                  ),
                  const SizedBox(height: 22),
                  _IdentitasField(
                    label: 'Jabatan & Wilayah Tugas',
                    value: _wilayahJabatan,
                    icon: Icons.location_on_outlined,
                  ),
                  const SizedBox(height: 32),

                  // Tombol Edit Identitas
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton.icon(
                      onPressed: _showEditProfileDialog,
                      icon: const Icon(Icons.edit_note_rounded, size: 20),
                      label: const Text(
                        'Ubah Data Identitas',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF285C2E),
                        side: const BorderSide(color: Color(0xFFB7D7B9)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Tombol Logout
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton.icon(
                      onPressed: () => const LogoutButton().logout(context),
                      icon: const Icon(Icons.logout_rounded, size: 20),
                      label: const Text(
                        'Keluar Akun',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFD32F2F),
                        side: const BorderSide(color: Color(0xFFEFB8B8)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widget Item Identitas (Label Kecil di Atas + Kotak Persegi Panjang di Bawah)
// Persis mengikuti 3 blok pada layer "Identitas" di Figma
// ---------------------------------------------------------------------------

class _IdentitasField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _IdentitasField({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Kotak label kecil di bagian atas
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFE6F2E7),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF285C2E),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Kotak nilai persegi panjang di bagian bawah
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE0E7E1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: const Color(0xFF285C2E),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E2923),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// CustomClipper untuk membuat lengkungan setengah lingkaran di bagian bawah
// header (Layer "Prof" pada Figma)
// ---------------------------------------------------------------------------

class _ProfileHeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 65);

    // Kurva melengkung halus di bagian bawah tengah
    path.quadraticBezierTo(
      size.width / 2,
      size.height + 35,
      size.width,
      size.height - 65,
    );

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}