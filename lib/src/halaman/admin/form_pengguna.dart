import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../services/user_repository.dart';
import '../../widgets/glashmorp.dart'; 

class FormPengguna extends StatefulWidget {
  const FormPengguna({super.key, this.user, required this.repository});
  final AppUser? user;
  final UserRepository repository;

  @override
  State<FormPengguna> createState() => _FormPenggunaState();
}

class _FormPenggunaState extends State<FormPengguna> {
  late final TextEditingController _email;
  late final TextEditingController _password;
  late final TextEditingController _name;
  late final TextEditingController _nip;
  late String _role;
  bool _saving = false;

  bool get _isEdit => widget.user != null;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController();
    _password = TextEditingController();
    _name = TextEditingController(text: widget.user?.fullName ?? '');
    _nip = TextEditingController(text: widget.user?.nip ?? '');
    _role = widget.user?.role ?? 'penyuluh';
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _nip.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        // Panggil method 'update'
        await widget.repository.update(
          widget.user!,
          fullName: _name.text.trim(),
          nip: _nip.text.trim().isEmpty ? null : _nip.text.trim(),
          role: _role,
        );
      } else {
        // Panggil method 'createUser' yang menggunakan Edge Function
        if (_email.text.trim().isEmpty || _password.text.trim().isEmpty) {
          throw 'Email dan Kata Sandi wajib diisi!';
        }
        await widget.repository.createUser(
          email: _email.text.trim(),
          password: _password.text.trim(),
          fullName: _name.text.trim(),
          nip: _nip.text.trim().isEmpty ? null : _nip.text.trim(),
          role: _role,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: KartuKaca(
          padding: const EdgeInsets.all(32),
          width: 450,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isEdit ? 'Ubah Pengguna' : 'Tambah Pengguna Baru',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                if (!_isEdit) ...[
                  TextField(
                    controller: _email,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _password,
                    decoration: const InputDecoration(labelText: 'Kata Sandi'),
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nama Lengkap')),
                const SizedBox(height: 16),
                TextField(controller: _nip, decoration: const InputDecoration(labelText: 'NIP (Opsional)')),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _role,
                  decoration: const InputDecoration(labelText: 'Peran Akses'),
                  items: const [
                    DropdownMenuItem(value: 'penyuluh', child: Text('Penyuluh (Standar)')),
                    DropdownMenuItem(value: 'admin', child: Text('Administrator')),
                  ],
                  onChanged: (value) => setState(() => _role = value!),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Batal', style: TextStyle(color: Colors.black54)),
                    ),
                    const SizedBox(width: 16),
                    FilledButton(
                      onPressed: _saving ? null : _simpan,
                      child: Text(_saving ? 'Menyimpan...' : 'Simpan'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}