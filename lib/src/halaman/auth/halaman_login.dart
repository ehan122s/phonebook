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
  final _name = TextEditingController();
  bool _loading = false;
  bool _register = false;

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
    } on AuthException catch (error) {
      if (mounted) _pesan(error.message, error: true);
    } catch (error) {
      if (mounted) _pesan('Terjadi kesalahan saat masuk. Silakan coba lagi.', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;

    if (email.isEmpty || password.isEmpty) {
      if (mounted) _pesan('Email dan kata sandi harus diisi.', error: true);
      return;
    }

    if (_register && _name.text.trim().isEmpty) {
      if (mounted) _pesan('Nama lengkap wajib diisi.', error: true);
      return;
    }

    if (_register) {
      setState(() => _loading = true);
      try {
        await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
          data: {'full_name': _name.text.trim()},
        );
        if (mounted) {
          _pesan('Akun penyuluh dibuat. Periksa email untuk konfirmasi.');
          setState(() => _register = false);
        }
      } on AuthException catch (error) {
        if (mounted) _pesan(error.message, error: true);
      } catch (error) {
        if (mounted) _pesan('Terjadi kesalahan saat mendaftar.', error: true);
      } finally {
        if (mounted) setState(() => _loading = false);
      }
      return;
    }
    await _login();
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
  Widget build(BuildContext context) => Scaffold(
        body: LatarBelakangGradien(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                // MENGGUNAKAN EFEK KACA DI SINI
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
                        _register ? 'Buat Akun Baru' : 'Masuk',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _register
                            ? 'Lengkapi data untuk bergabung'
                            : 'Selamat datang kembali di SIPENYULUH',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 36),
                      if (_register) ...[
                        TextField(
                          controller: _name,
                          decoration: const InputDecoration(labelText: 'Nama lengkap'),
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _password,
                        obscureText: true,
                        onSubmitted: (_) => _submit(),
                        decoration: const InputDecoration(labelText: 'Kata sandi'),
                      ),
                      const SizedBox(height: 36),
                      FilledButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text(_register ? 'Daftar Sekarang' : 'Masuk'),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _loading ? null : () => setState(() => _register = !_register),
                        child: Text(
                          _register ? 'Sudah punya akun? Masuk' : 'Belum punya akun? Daftar',
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