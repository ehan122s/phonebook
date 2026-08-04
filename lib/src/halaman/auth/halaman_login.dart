import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/glashmorp.dart';

class HalamanLogin extends StatefulWidget {
  const HalamanLogin({super.key});
  @override
  State<HalamanLogin> createState() => _HalamanLoginState();
}

class _HalamanLoginState extends State<HalamanLogin> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  
  // Controller baru untuk OTP dan Password Baru
  final _otp = TextEditingController();
  final _newPassword = TextEditingController();
  
  bool _loading = false;
  
  // State untuk melacak langkah Lupa Password
  // 0 = Mode Login
  // 1 = Lupa Password (Input Email)
  // 2 = Lupa Password (Input Kode OTP/Token)
  // 3 = Lupa Password (Input Password Baru)
  int _alurLupaPassword = 0;

  // 1. Fungsi Login Normal
  Future<void> _login() async {
    final email = _email.text.trim();
    final password = _password.text;

    if (email.isEmpty || password.isEmpty) {
      if (mounted) _pesan('Email dan kata sandi harus diisi.', error: true);
      return;
    }

    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      // CATATAN: Jika Anda menggunakan navigasi manual (bukan onAuthStateChange di main.dart), 
      // masukkan kode perpindahan ke Dashboard di sini:
      // if (mounted) {
      //   Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => HalamanDashboard()));
      // }
      
    } on AuthException catch (error) {
      if (mounted) _pesan(error.message, error: true);
    } catch (error) {
      if (mounted) _pesan('Terjadi kesalahan saat masuk. Silakan coba lagi.', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // 2. Fungsi Mengirim Kode Pemulihan ke Email
  Future<void> _kirimKodePemulihan() async {
    final email = _email.text.trim();

    if (email.isEmpty) {
      if (mounted) _pesan('Masukkan alamat email Anda terlebih dahulu.', error: true);
      return;
    }

    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      
      if (mounted) {
        _pesan('Kode verifikasi telah dikirim ke email Anda.');
        setState(() {
          _otp.clear();
          _alurLupaPassword = 2; // Pindah ke langkah input kode
        });
      }
    } on AuthException catch (error) {
      if (mounted) _pesan(error.message, error: true);
    } catch (error) {
      if (mounted) _pesan('Terjadi kesalahan. Silakan coba lagi nanti.', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // 3. Fungsi Memverifikasi Kode OTP 
  Future<void> _verifikasiKode() async {
    final email = _email.text.trim();
    final otp = _otp.text.trim().replaceAll(RegExp(r'\s+'), '');

    if (otp.isEmpty) {
      if (mounted) _pesan('Masukkan kode verifikasi yang dikirim ke email Anda.', error: true);
      return;
    }

    setState(() => _loading = true);
    try {
      // Verifikasi kodenya sebagai OTP pemulihan
      await Supabase.instance.client.auth.verifyOTP(
        email: email,
        token: otp,
        type: OtpType.recovery,
      );
      
      // PENTING: Saat baris di atas berhasil, Supabase OTOMATIS membuat sesi login aktif.
      // Pastikan di main.dart Anda TIDAK langsung melempar user ke Dashboard jika eventnya "passwordRecovery".
      
      if (mounted) {
        _pesan('Verifikasi berhasil! Silakan buat kata sandi baru Anda.');
        setState(() => _alurLupaPassword = 3); // Tampilkan kolom password baru
      }
    } on AuthException catch (error) {
      if (mounted) _pesan('Gagal: Kode tidak valid atau kedaluwarsa.', error: true);
    } catch (error) {
      if (mounted) _pesan('Terjadi kesalahan saat verifikasi kode.', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // 4. Fungsi Menyimpan Kata Sandi Baru
  Future<void> _simpanPasswordBaru() async {
    final newPassword = _newPassword.text;

    if (newPassword.length < 6) {
      if (mounted) _pesan('Kata sandi baru minimal harus 6 karakter.', error: true);
      return;
    }

    setState(() => _loading = true);
    try {
      // Mengubah kata sandi untuk sesi pemulihan yang sedang aktif
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      
      if (mounted) {
        _pesan('Kata sandi berhasil diubah! Anda berhasil masuk.');
        
        // KARENA PENGGUNA SUDAH MEMILIKI SESI AKTIF SETELAH RESET PASSWORD,
        // ARAHKAN MEREKA KE DASHBOARD SECARA MANUAL DI SINI:
        
        // TODO: Buka komentar kode di bawah dan ganti "HalamanDashboard()" sesuai nama halaman Anda
        // Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => HalamanDashboard()));
        
        // (Sebagai fallback jika navigasi manual di atas tidak diaktifkan)
        setState(() {
          _alurLupaPassword = 0;
          _password.clear();
          _otp.clear();
          _newPassword.clear();
        });
      }
    } on AuthException catch (error) {
      if (mounted) _pesan(error.message, error: true);
    } catch (error) {
      if (mounted) _pesan('Terjadi kesalahan saat mengubah kata sandi.', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _prosesAksiUtama() {
    if (_alurLupaPassword == 0) {
      _login();
    } else if (_alurLupaPassword == 1) {
      _kirimKodePemulihan();
    } else if (_alurLupaPassword == 2) {
      _verifikasiKode();
    } else if (_alurLupaPassword == 3) {
      _simpanPasswordBaru();
    }
  }

  void _pesan(String text, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: error ? Colors.red.shade400 : const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _otp.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String titleText;
    String subtitleText;
    String buttonText;

    if (_alurLupaPassword == 0) {
      titleText = 'Masuk';
      subtitleText = 'Selamat datang kembali di SIPENYULUH';
      buttonText = 'Masuk';
    } else if (_alurLupaPassword == 1) {
      titleText = 'Lupa Kata Sandi';
      subtitleText = 'Masukkan email Anda untuk menerima kode verifikasi.';
      buttonText = 'Kirim Kode';
    } else if (_alurLupaPassword == 2) {
      titleText = 'Verifikasi Kode';
      subtitleText = 'Cek email Anda dan masukkan kode verifikasi.';
      buttonText = 'Verifikasi';
    } else {
      titleText = 'Kata Sandi Baru';
      subtitleText = 'Silakan buat kata sandi baru untuk akun Anda.';
      buttonText = 'Simpan Kata Sandi';
    }

    return Scaffold(
      body: LatarBelakangGradien(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: KartuKaca(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: Icon(Icons.forest, color: Color(0xFF2E7D32), size: 56),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      titleText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitleText,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 36),
                    
                    if (_alurLupaPassword <= 2) ...[
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email'),
                        enabled: _alurLupaPassword <= 1, 
                      ),
                    ],

                    if (_alurLupaPassword == 0) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _password,
                        obscureText: true,
                        onSubmitted: (_) => _prosesAksiUtama(),
                        decoration: const InputDecoration(labelText: 'Kata sandi'),
                      ),
                    ],

                    if (_alurLupaPassword == 2) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _otp,
                        keyboardType: TextInputType.text,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 4),
                        onSubmitted: (_) => _prosesAksiUtama(),
                        decoration: const InputDecoration(
                          labelText: 'Kode Verifikasi',
                        ),
                      ),
                    ],

                    if (_alurLupaPassword == 3) ...[
                      TextField(
                        controller: _newPassword,
                        obscureText: true,
                        onSubmitted: (_) => _prosesAksiUtama(),
                        decoration: const InputDecoration(
                          labelText: 'Kata Sandi Baru (Min. 6 Karakter)',
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 36),
                    FilledButton(
                      onPressed: _loading ? null : _prosesAksiUtama,
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(buttonText),
                    ),
                    const SizedBox(height: 16),
                    
                    TextButton(
                      onPressed: _loading ? null : () {
                        setState(() {
                          _alurLupaPassword = _alurLupaPassword == 0 ? 1 : 0;
                        });
                      },
                      child: Text(
                        _alurLupaPassword == 0 ? 'Lupa kata sandi?' : 'Batal & Kembali untuk Masuk',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2E7D32)),
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