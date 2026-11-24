import 'package:flutter/material.dart';

import '../admin_theme.dart';
import '../services/admin_service.dart';

/// Menampilkan modal bottom sheet untuk Tambah / Edit Pengguna
/// lengkap dengan input password, konfirmasi password, toggle visibilitas,
/// dan validasi sebelum dikirim ke backend.
Future<void> showUserFormSheet(
  BuildContext context, {
  Map<String, String>? existing,
  required Future<AdminApiResult<Map<String, String>>> Function(
    Map<String, String> userData, {
    String? password,
    String? passwordConfirmation,
  })
  onSubmit,
}) {
  final t = AdminTheme.of(context);
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: t.cardBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (_) =>
        _UserFormSheetContent(existing: existing, onSubmit: onSubmit),
  );
}

class _UserFormSheetContent extends StatefulWidget {
  final Map<String, String>? existing;
  final Future<AdminApiResult<Map<String, String>>> Function(
    Map<String, String> userData, {
    String? password,
    String? passwordConfirmation,
  })
  onSubmit;

  const _UserFormSheetContent({this.existing, required this.onSubmit});

  @override
  State<_UserFormSheetContent> createState() => _UserFormSheetContentState();
}

class _UserFormSheetContentState extends State<_UserFormSheetContent> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _nipCtrl;
  late final TextEditingController _whatsappCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _wilayahCtrl;
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _confirmPasswordCtrl = TextEditingController();

  late String _role;
  late String _status;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;
  String? _serverError;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?['name'] ?? '');
    _nipCtrl = TextEditingController(
      text: (e?['nip'] == '-' ? '' : e?['nip']) ?? '',
    );
    _whatsappCtrl = TextEditingController(
      text: (e?['whatsapp'] == '-' ? '' : e?['whatsapp']) ?? '',
    );
    _emailCtrl = TextEditingController(text: e?['email'] ?? '');
    _wilayahCtrl = TextEditingController(
      text: e?['wilayah'] ?? 'CDK Wilayah Garut',
    );

    final rawRole = e?['role'] ?? 'Penyuluh';
    _role = ['Penyuluh', 'Koordinator', 'Admin'].contains(rawRole)
        ? rawRole
        : (rawRole.toLowerCase() == 'admin' ? 'Admin' : 'Penyuluh');

    final rawStatus = e?['status'] ?? 'Aktif';
    _status = ['Aktif', 'Nonaktif'].contains(rawStatus) ? rawStatus : 'Aktif';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nipCtrl.dispose();
    _whatsappCtrl.dispose();
    _emailCtrl.dispose();
    _wilayahCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(
    AdminTheme t,
    String label,
    String hint,
    IconData icon, {
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: t.primaryAccent, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: t.softGreenBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: t.borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: t.borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: t.primaryAccent, width: 1.6),
      ),
    );
  }

  Future<void> _handleSave() async {
    setState(() => _serverError = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final userData = <String, String>{
      'id': widget.existing?['id'] ?? '',
      'nip': _nipCtrl.text.trim(),
      'name': _nameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'whatsapp': _whatsappCtrl.text.trim(),
      'wilayah': _wilayahCtrl.text.trim().isEmpty
          ? 'CDK Wilayah Garut'
          : _wilayahCtrl.text.trim(),
      'role': _role,
      'status': _status,
    };

    final pwd = _passwordCtrl.text;
    final confirmPwd = _confirmPasswordCtrl.text;

    final result = await widget.onSubmit(
      userData,
      password: pwd.isNotEmpty ? pwd : null,
      passwordConfirmation: pwd.isNotEmpty ? confirmPwd : null,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result.success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.message)));
    } else {
      setState(() => _serverError = result.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AdminTheme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isNarrow = MediaQuery.of(context).size.width < 520;

    return Padding(
      padding: EdgeInsets.fromLTRB(22, 6, 22, bottomInset + 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: t.lightGreenBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        _isEditing
                            ? Icons.manage_accounts_rounded
                            : Icons.person_add_alt_1_rounded,
                        color: t.primaryAccent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isEditing
                                ? 'Edit Data Pengguna'
                                : 'Tambah Pengguna Baru',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: t.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Lengkapi identitas, wilayah tugas, dan keamanan akun.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: t.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_serverError != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDECEA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFD32F2F).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: Color(0xFFD32F2F),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _serverError!,
                            style: const TextStyle(
                              color: Color(0xFFD32F2F),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                TextFormField(
                  controller: _nameCtrl,
                  style: TextStyle(color: t.textPrimary),
                  decoration: _fieldDecoration(
                    t,
                    'Nama Lengkap & Gelar',
                    'Nama lengkap beserta gelar',
                    Icons.badge_outlined,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Nama lengkap wajib diisi'
                      : null,
                ),
                const SizedBox(height: 12),
                if (isNarrow) ...[
                  TextFormField(
                    controller: _nipCtrl,
                    style: TextStyle(color: t.textPrimary),
                    decoration: _fieldDecoration(
                      t,
                      'NIP / ID Petugas',
                      '19940812 202012 1 004',
                      Icons.numbers_rounded,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _whatsappCtrl,
                    keyboardType: TextInputType.phone,
                    style: TextStyle(color: t.textPrimary),
                    decoration: _fieldDecoration(
                      t,
                      'No. WhatsApp',
                      '0812-xxxx-xxxx',
                      Icons.chat_outlined,
                    ),
                  ),
                ] else
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _nipCtrl,
                          style: TextStyle(color: t.textPrimary),
                          decoration: _fieldDecoration(
                            t,
                            'NIP / ID Petugas',
                            '19940812 202012 1 004',
                            Icons.numbers_rounded,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _whatsappCtrl,
                          keyboardType: TextInputType.phone,
                          style: TextStyle(color: t.textPrimary),
                          decoration: _fieldDecoration(
                            t,
                            'No. WhatsApp',
                            '0812-xxxx-xxxx',
                            Icons.chat_outlined,
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: t.textPrimary),
                  decoration: _fieldDecoration(
                    t,
                    'Alamat Email Dinas / Akun',
                    'nama@kehutanan.go.id',
                    Icons.alternate_email_rounded,
                  ),
                  validator: (v) {
                    final val = v?.trim() ?? '';
                    if (val.isEmpty) return 'Email wajib diisi';
                    if (!val.contains('@') || !val.contains('.')) {
                      return 'Format email tidak valid';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _wilayahCtrl,
                  style: TextStyle(color: t.textPrimary),
                  decoration: _fieldDecoration(
                    t,
                    'Wilayah Tugas / Kawasan',
                    'Contoh: CDK Wilayah Garut',
                    Icons.location_on_outlined,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _role,
                        dropdownColor: t.cardBg,
                        style: TextStyle(color: t.textPrimary, fontSize: 14),
                        decoration: _fieldDecoration(
                          t,
                          'Peran / Jabatan',
                          '',
                          Icons.work_outline_rounded,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Penyuluh',
                            child: Text('Penyuluh'),
                          ),
                          DropdownMenuItem(
                            value: 'Koordinator',
                            child: Text('Koordinator'),
                          ),
                          DropdownMenuItem(
                            value: 'Admin',
                            child: Text('Admin'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _role = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _status,
                        dropdownColor: t.cardBg,
                        style: TextStyle(color: t.textPrimary, fontSize: 14),
                        decoration: _fieldDecoration(
                          t,
                          'Status Akun',
                          '',
                          Icons.verified_user_outlined,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Aktif',
                            child: Text('Aktif'),
                          ),
                          DropdownMenuItem(
                            value: 'Nonaktif',
                            child: Text('Nonaktif'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _status = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Divider(color: t.borderColor),
                const SizedBox(height: 12),
                Text(
                  _isEditing ? 'Ubah Password (Opsional)' : 'Keamanan Akun',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isEditing
                      ? 'Kosongkan kedua kolom di bawah jika tidak ingin mengubah password user.'
                      : 'Tentukan password awal untuk akun pengguna (minimal 6 karakter).',
                  style: TextStyle(fontSize: 12, color: t.textSecondary),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  style: TextStyle(color: t.textPrimary),
                  decoration: _fieldDecoration(
                    t,
                    _isEditing ? 'Password Baru' : 'Password',
                    'Minimal 6 karakter',
                    Icons.lock_outline_rounded,
                    suffixIcon: IconButton(
                      tooltip: _obscurePassword
                          ? 'Tampilkan password'
                          : 'Sembunyikan password',
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: t.textSecondary,
                        size: 20,
                      ),
                    ),
                  ),
                  validator: (v) {
                    final val = v ?? '';
                    if (!_isEditing && val.isEmpty) {
                      return 'Password wajib diisi';
                    }
                    if (val.isNotEmpty && val.length < 6) {
                      return 'Password minimal 6 karakter';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmPasswordCtrl,
                  obscureText: _obscureConfirm,
                  style: TextStyle(color: t.textPrimary),
                  decoration: _fieldDecoration(
                    t,
                    _isEditing
                        ? 'Konfirmasi Password Baru'
                        : 'Konfirmasi Password',
                    'Ulangi password di atas',
                    Icons.lock_reset_rounded,
                    suffixIcon: IconButton(
                      tooltip: _obscureConfirm
                          ? 'Tampilkan password'
                          : 'Sembunyikan password',
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: t.textSecondary,
                        size: 20,
                      ),
                    ),
                  ),
                  validator: (v) {
                    final pwd = _passwordCtrl.text;
                    final confirm = v ?? '';
                    if (!_isEditing && confirm.isEmpty) {
                      return 'Konfirmasi password wajib diisi';
                    }
                    if (pwd.isNotEmpty && confirm != pwd) {
                      return 'Konfirmasi password tidak cocok';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: t.textPrimary,
                          side: BorderSide(color: t.borderColor),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Batal',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AdminTheme.kPrimary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _isSubmitting ? null : _handleSave,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_outlined, size: 18),
                        label: Text(
                          _isSubmitting ? 'Menyimpan...' : 'Simpan Pengguna',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
