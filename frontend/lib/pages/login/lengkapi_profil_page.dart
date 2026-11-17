import 'package:flutter/material.dart';

import '../../services/google_auth_service.dart';

class LengkapiProfilPage extends StatefulWidget {
  final Map<String, dynamic> googleData;

  const LengkapiProfilPage({
    super.key,
    required this.googleData,
  });

  @override
  State<LengkapiProfilPage> createState() => _LengkapiProfilPageState();
}

class _LengkapiProfilPageState extends State<LengkapiProfilPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _emailCtrl;
  late final TextEditingController _namaCtrl;
  final _nipCtrl = TextEditingController();
  final _jabatanCtrl = TextEditingController(text: 'Penyuluh Kehutanan');
  final _wilayahCtrl = TextEditingController(text: 'CDK Wilayah Garut');
  final _waCtrl = TextEditingController();

  bool _isLoading = false;

  static const Color primaryGreen = Color(0xFF285C2E);

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(
      text: (widget.googleData['email'] ?? '').toString(),
    );
    _namaCtrl = TextEditingController(
      text: (widget.googleData['name'] ?? '').toString(),
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _namaCtrl.dispose();
    _nipCtrl.dispose();
    _jabatanCtrl.dispose();
    _wilayahCtrl.dispose();
    _waCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final registrationData = {
      'email': _emailCtrl.text.trim().toLowerCase(),
      'name': _namaCtrl.text.trim(),
      'nip': _nipCtrl.text.trim(),
      'jabatan': _jabatanCtrl.text.trim(),
      'wilayah': _wilayahCtrl.text.trim(),
      'whatsapp_number': _waCtrl.text.trim(),
      'google_id': widget.googleData['google_id'] ?? '',
      'avatar': widget.googleData['avatar'] ?? '',
      'id_token': widget.googleData['id_token'] ?? '',
    };

    try {
      await GoogleAuthService.registerAndEnterDashboard(
        context,
        registrationData,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = (widget.googleData['avatar'] ?? '').toString();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121814) : const Color(0xFFF6F8F5);
    final cardBg = isDark ? const Color(0xFF1E2822) : Colors.white;
    final borderCol =
        isDark ? const Color(0xFF2E3D34) : Colors.grey.shade200;
    final textColor = isDark ? Colors.white : const Color(0xFF1E2923);
    final subColor = isDark ? Colors.white70 : Colors.grey.shade600;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          'Lengkapi Data Diri Pegawai',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        backgroundColor: primaryGreen,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Info Banner
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderCol),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: isDark ? 0.2 : 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: primaryGreen.withValues(alpha: 0.12),
                        backgroundImage: avatarUrl.isNotEmpty
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: avatarUrl.isEmpty
                            ? Icon(
                                Icons.person_rounded,
                                size: 32,
                                color: isDark
                                    ? const Color(0xFF81C784)
                                    : primaryGreen,
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const GoogleLogoWidget(size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _emailCtrl.text,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                      color: textColor,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF152C44)
                                    : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Akun Google Terverifikasi',
                                style: TextStyle(
                                  color: isDark
                                      ? const Color(0xFF90CAF9)
                                      : Colors.blue.shade800,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Form Card
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: borderCol),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: isDark ? 0.2 : 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Data Kepegawaian & Wilayah',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Akun Google Anda belum terdaftar di sistem. Lengkapi data di bawah ini untuk pembuatan akun baru.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: subColor,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Nama Lengkap
                        _buildLabel('Nama Lengkap & Gelar *', isDark),
                        TextFormField(
                          controller: _namaCtrl,
                          style: TextStyle(color: textColor),
                          decoration: _inputDecoration(
                            hint: 'Masukkan nama lengkap beserta gelar',
                            icon: Icons.badge_outlined,
                            isDark: isDark,
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Nama lengkap wajib diisi';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // NIP
                        _buildLabel('NIP (Nomor Induk Pegawai)', isDark),
                        TextFormField(
                          controller: _nipCtrl,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: textColor),
                          decoration: _inputDecoration(
                            hint: 'Masukkan NIP (Kosongkan jika non-ASN)',
                            icon: Icons.pin_outlined,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Jabatan
                        _buildLabel('Jabatan *', isDark),
                        TextFormField(
                          controller: _jabatanCtrl,
                          style: TextStyle(color: textColor),
                          decoration: _inputDecoration(
                            hint: 'Contoh: Penyuluh Kehutanan Ahli Pertama',
                            icon: Icons.work_outline_rounded,
                            isDark: isDark,
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Jabatan wajib diisi';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Wilayah Kerja / Instansi
                        _buildLabel('Wilayah Kerja / Instansi *', isDark),
                        TextFormField(
                          controller: _wilayahCtrl,
                          style: TextStyle(color: textColor),
                          decoration: _inputDecoration(
                            hint: 'Contoh: CDK Wilayah Garut',
                            icon: Icons.location_city_outlined,
                            isDark: isDark,
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Wilayah kerja wajib diisi';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Nomor WhatsApp
                        _buildLabel('Nomor WhatsApp / HP Aktif *', isDark),
                        TextFormField(
                          controller: _waCtrl,
                          keyboardType: TextInputType.phone,
                          style: TextStyle(color: textColor),
                          decoration: _inputDecoration(
                            hint: '08xxxxxxxxxx (Untuk notifikasi kegiatan)',
                            icon: Icons.phone_outlined,
                            isDark: isDark,
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Nomor WhatsApp wajib diisi';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 26),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryGreen,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 2,
                            ),
                            onPressed: _isLoading ? null : _submitRegistration,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.check_circle_outline_rounded),
                            label: Text(
                              _isLoading
                                  ? 'Menyimpan...'
                                  : 'Daftar & Masuk ke Dashboard',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
    );
  }

  Widget _buildLabel(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : const Color(0xFF2E3D32),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    required bool isDark,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: isDark ? Colors.white38 : Colors.grey.shade400,
        fontSize: 13,
      ),
      prefixIcon: Icon(
        icon,
        color: isDark ? const Color(0xFF81C784) : primaryGreen,
        size: 20,
      ),
      filled: true,
      fillColor: isDark ? const Color(0xFF243329) : const Color(0xFFF9FBF9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF2E3D34) : Colors.grey.shade300,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF2E3D34) : Colors.grey.shade300,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF81C784) : primaryGreen,
          width: 1.8,
        ),
      ),
    );
  }
}