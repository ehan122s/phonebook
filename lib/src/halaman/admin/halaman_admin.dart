import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/app_user.dart';
import '../../models/category.dart';
import '../../models/report_template.dart';
import '../../services/category_repository.dart';
import '../../services/template_repository.dart';
import '../../services/user_repository.dart';
import '../../widgets/glashmorp.dart';

// ---------------------------------------------------------
// HALAMAN ADMIN: PENGGUNA
// ---------------------------------------------------------

class HalamanAdminPengguna extends StatefulWidget {
  const HalamanAdminPengguna({super.key, required this.repository});
  final UserRepository repository;
  @override
  State<HalamanAdminPengguna> createState() => _HalamanAdminPenggunaState();
}

class _HalamanAdminPenggunaState extends State<HalamanAdminPengguna> {
  late Future<List<AppUser>> _users;
  
  @override
  void initState() {
    super.initState();
    _users = widget.repository.list();
  }

  void _muatUlang() => setState(() => _users = widget.repository.list());
  
  @override
  Widget build(BuildContext context) => FutureBuilder<List<AppUser>>(
        future: _users,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Gagal memuat pengguna: ${snapshot.error}'));
          }
          final users = snapshot.data ?? [];
          
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            children: [
              KartuKaca(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Manajemen Pengguna', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      'Kelola hak akses penyuluh dan administrator. Semua perubahan akan langsung aktif.',
                      style: TextStyle(color: Colors.grey.shade800),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: users.map((user) => SizedBox(
                  width: 450, // Card tetap rapi di grid/wrap
                  child: KartuKaca(
                    padding: const EdgeInsets.all(8),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: user.role == 'admin' ? Colors.orange.withValues(alpha: 0.3) : const Color(0xFF2E7D32).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          user.role == 'admin' ? Icons.admin_panel_settings : Icons.person,
                          color: user.role == 'admin' ? Colors.orange.shade900 : const Color(0xFF2E7D32),
                        ),
                      ),
                      title: Text(user.fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      subtitle: Text('${user.role == 'admin' ? 'Administrator' : 'Penyuluh'} ${user.nip == null || user.nip!.isEmpty ? '' : '• NIP ${user.nip}'}'),
                      trailing: FilledButton.tonal(
                        style: FilledButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.7)),
                        onPressed: () async {
                          await showDialog<void>(
                            context: context,
                            builder: (_) => FormPengguna(user: user, repository: widget.repository),
                          );
                          _muatUlang();
                        },
                        child: const Text('Ubah'),
                      ),
                    ),
                  ),
                )).toList(),
              ),
            ],
          );
        },
      );
}

class FormPengguna extends StatefulWidget {
  const FormPengguna({super.key, required this.user, required this.repository});
  final AppUser user;
  final UserRepository repository;
  @override
  State<FormPengguna> createState() => _FormPenggunaState();
}

class _FormPenggunaState extends State<FormPengguna> {
  late final TextEditingController _name;
  late final TextEditingController _nip;
  late String _role;
  bool _saving = false;
  
  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.user.fullName);
    _nip = TextEditingController(text: widget.user.nip);
    _role = widget.user.role;
  }

  Future<void> _simpan() async {
    setState(() => _saving = true);
    try {
      await widget.repository.update(
        widget.user,
        fullName: _name.text.trim(),
        nip: _nip.text.trim().isEmpty ? null : _nip.text.trim(),
        role: _role,
      );
      if (mounted) Navigator.pop(context);
    } on PostgrestException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Ubah Pengguna', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nama Lengkap')),
              const SizedBox(height: 16),
              TextField(controller: _nip, decoration: const InputDecoration(labelText: 'NIP (Opsional)')),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _role,
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
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal', style: TextStyle(color: Colors.black54))),
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
      );
}

// ---------------------------------------------------------
// HALAMAN ADMIN: KATALOG (Kategori & Template)
// ---------------------------------------------------------

class HalamanAdminKatalog extends StatefulWidget {
  const HalamanAdminKatalog({super.key});
  @override
  State<HalamanAdminKatalog> createState() => _HalamanAdminKatalogState();
}

class _HalamanAdminKatalogState extends State<HalamanAdminKatalog> {
  int _tab = 0;
  final _categories = CategoryRepository(Supabase.instance.client);
  final _templates = TemplateRepository(Supabase.instance.client);
  
  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        children: [
          KartuKaca(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Referensi Sistem', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Kategori'))),
                    ButtonSegment(value: 1, label: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Template'))),
                  ],
                  selected: {_tab},
                  onSelectionChanged: (value) => setState(() => _tab = value.first),
                  style: ButtonStyle(backgroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? Colors.white.withValues(alpha: 0.6) : Colors.transparent)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          if (_tab == 0) _daftarKategori() else _daftarTemplate(),
        ],
      );

  Widget _daftarKategori() => FutureBuilder<List<Category>>(
        future: _categories.list(),
        builder: (context, snapshot) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FilledButton.icon(
              onPressed: () => _dialogKategori(),
              icon: const Icon(Icons.add),
              label: const Text('Tambah Kategori'),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 16, runSpacing: 16,
              children: (snapshot.data ?? []).map((item) => SizedBox(
                width: 400,
                child: KartuKaca(
                  padding: const EdgeInsets.all(8),
                  child: ListTile(
                    title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    subtitle: Text(item.description ?? '-'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _dialogKategori(item)),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () async {
                            await _categories.delete(item.id);
                            if (mounted) setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              )).toList(),
            ),
          ],
        ),
      );

  Widget _daftarTemplate() => FutureBuilder<List<ReportTemplate>>(
        future: _templates.list(),
        builder: (context, snapshot) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FilledButton.icon(
              onPressed: () => _dialogTemplate(),
              icon: const Icon(Icons.add),
              label: const Text('Tambah Template Laporan'),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 16, runSpacing: 16,
              children: (snapshot.data ?? []).map((item) => SizedBox(
                width: 400,
                child: KartuKaca(
                  padding: const EdgeInsets.all(8),
                  child: ListTile(
                    title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    subtitle: Text(item.isActive ? 'Status: Aktif' : 'Status: Nonaktif', style: TextStyle(color: item.isActive ? Colors.green.shade800 : Colors.grey.shade600, fontWeight: FontWeight.w600)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _dialogTemplate(item)),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () async {
                            await _templates.delete(item.id);
                            if (mounted) setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              )).toList(),
            ),
          ],
        ),
      );

  Future<void> _dialogKategori([Category? item]) async {
    final name = TextEditingController(text: item?.name);
    final description = TextEditingController(text: item?.description);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: KartuKaca(
          padding: const EdgeInsets.all(32),
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(item == null ? 'Kategori Baru' : 'Ubah Kategori', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Nama Kategori')),
              const SizedBox(height: 16),
              TextField(controller: description, decoration: const InputDecoration(labelText: 'Deskripsi Singkat')),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Batal', style: TextStyle(color: Colors.black54))),
                  const SizedBox(width: 16),
                  FilledButton(
                    onPressed: () async {
                      await _categories.save(id: item?.id, name: name.text, description: description.text);
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                    },
                    child: const Text('Simpan'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    setState(() {});
  }

  Future<void> _dialogTemplate([ReportTemplate? item]) async {
    final name = TextEditingController(text: item?.name);
    final header = TextEditingController(text: item?.headerHtml);
    final body = TextEditingController(text: item?.bodyHtml);
    var active = item?.isActive ?? true;
    
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: StatefulBuilder(
          builder: (context, setDialogState) => KartuKaca(
            padding: const EdgeInsets.all(32),
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item == null ? 'Template Laporan Baru' : 'Ubah Template', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  TextField(controller: name, decoration: const InputDecoration(labelText: 'Nama Template')),
                  const SizedBox(height: 16),
                  TextField(controller: header, maxLines: 3, decoration: const InputDecoration(labelText: 'Header HTML (Kop Surat/Judul)')),
                  const SizedBox(height: 16),
                  TextField(controller: body, maxLines: 7, decoration: const InputDecoration(labelText: 'Isi (Body) HTML')),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(16)),
                    child: SwitchListTile(
                      value: active,
                      onChanged: (value) => setDialogState(() => active = value),
                      title: const Text('Aktifkan Template ini?', style: TextStyle(fontWeight: FontWeight.w600)),
                      activeColor: const Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Batal', style: TextStyle(color: Colors.black54))),
                      const SizedBox(width: 16),
                      FilledButton(
                        onPressed: () async {
                          await _templates.save(id: item?.id, name: name.text, header: header.text, body: body.text, active: active);
                          if (dialogContext.mounted) Navigator.pop(dialogContext);
                        },
                        child: const Text('Simpan'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }
}