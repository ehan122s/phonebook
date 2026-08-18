import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/report_template.dart';
import '../../services/template_repository.dart';

/// Halaman admin untuk mengelola template laporan PDF/Docx: logo instansi,
/// teks header (judul di bagian atas laporan), dan teks penutup/tanda
/// tangan (bagian bawah laporan). Hanya SATU template yang boleh aktif
/// dalam satu waktu — begitu satu diaktifkan, yang lain otomatis
/// dinonaktifkan (diatur oleh trigger di database, bukan di sisi app).
class HalamanAdminTemplateLaporan extends StatefulWidget {
  const HalamanAdminTemplateLaporan({super.key});

  @override
  State<HalamanAdminTemplateLaporan> createState() => _HalamanAdminTemplateLaporanState();
}

class _HalamanAdminTemplateLaporanState extends State<HalamanAdminTemplateLaporan> {
  late final TemplateRepository _repository;
  late Future<List<ReportTemplate>> _future;

  @override
  void initState() {
    super.initState();
    _repository = TemplateRepository(Supabase.instance.client);
    _muatUlang();
  }

  void _muatUlang() => _future = _repository.list();

  Future<void> _refresh() async {
    setState(_muatUlang);
    await _future;
  }

  Future<void> _hapus(ReportTemplate template) async {
    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Template?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Template "${template.name}" akan dihapus permanen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (konfirmasi != true) return;
    if (template.logoPath != null) {
      // Best-effort — kalau gagal hapus logo lama, tidak perlu blokir hapus template.
      unawaited(_repository.deleteLogo(template.logoPath!));
    }
    await _repository.delete(template.id);
    await _refresh();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Template dihapus')),
      );
    }
  }

  void _bukaFormTemplate({ReportTemplate? template}) {
    showDialog(
      context: context,
      builder: (_) => _DialogFormTemplate(
        repository: _repository,
        template: template,
      ),
    ).then((_) => _refresh());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Template Laporan'),
          backgroundColor: const Color(0xFF1B5E20),
          foregroundColor: Colors.white,
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _bukaFormTemplate(),
          backgroundColor: const Color(0xFF1B5E20),
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Template Baru', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        body: RefreshIndicator(
          color: const Color(0xFF1B5E20),
          onRefresh: _refresh,
          child: FutureBuilder<List<ReportTemplate>>(
            future: _future,
            builder: (context, snapshot) {
              final isLoading = snapshot.connectionState == ConnectionState.waiting;
              final templates = snapshot.data ?? const <ReportTemplate>[];

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B5E20).withOpacity(0.06),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Color(0xFF1B5E20)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Template yang ditandai "Aktif" akan otomatis dipakai saat penyuluh membuat Laporan PDF/Docx. Cuma boleh satu yang aktif.',
                            style: TextStyle(color: Colors.grey.shade800, fontSize: 13, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(child: CircularProgressIndicator(color: Color(0xFF1B5E20))),
                    )
                  else if (templates.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(48),
                      child: Center(
                        child: Text(
                          'Belum ada template. Ketuk "Template Baru" untuk membuat yang pertama.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    )
                  else
                    ...templates.map((template) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _KartuTemplate(
                            template: template,
                            repository: _repository,
                            onEdit: () => _bukaFormTemplate(template: template),
                            onDelete: () => _hapus(template),
                          ),
                        )),
                ],
              );
            },
          ),
        ),
      );
}

class _KartuTemplate extends StatelessWidget {
  const _KartuTemplate({
    required this.template,
    required this.repository,
    required this.onEdit,
    required this.onDelete,
  });
  final ReportTemplate template;
  final TemplateRepository repository;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: template.isActive ? Border.all(color: const Color(0xFF1B5E20), width: 2) : null,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LogoThumbnail(logoPath: template.logoPath, repository: repository),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          template.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      if (template.isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B5E20),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('AKTIF',
                              style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    template.headerHtml?.isNotEmpty == true ? template.headerHtml! : '(Tanpa teks header khusus)',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        label: const Text('Edit'),
                        style: TextButton.styleFrom(foregroundColor: const Color(0xFF1B5E20)),
                      ),
                      TextButton.icon(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                        label: const Text('Hapus'),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _LogoThumbnail extends StatelessWidget {
  const _LogoThumbnail({required this.logoPath, required this.repository});
  final String? logoPath;
  final TemplateRepository repository;

  @override
  Widget build(BuildContext context) {
    if (logoPath == null) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
        child: Icon(Icons.image_not_supported_outlined, color: Colors.grey.shade400, size: 24),
      );
    }
    return FutureBuilder<String>(
      future: repository.signedLogoUrl(logoPath!),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
            child: const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            snapshot.data!,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 56,
              height: 56,
              color: Colors.grey.shade100,
              child: const Icon(Icons.broken_image_outlined, color: Colors.redAccent),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------
// FORM TAMBAH / EDIT TEMPLATE
// ---------------------------------------------------------------------

class _DialogFormTemplate extends StatefulWidget {
  const _DialogFormTemplate({required this.repository, this.template});
  final TemplateRepository repository;
  final ReportTemplate? template;

  @override
  State<_DialogFormTemplate> createState() => _DialogFormTemplateState();
}

class _DialogFormTemplateState extends State<_DialogFormTemplate> {
  late final TextEditingController _namaController;
  late final TextEditingController _headerController;
  late final TextEditingController _bodyController;
  bool _aktif = false;
  bool _sedangProses = false;

  PlatformFile? _logoBaru; // logo yang baru dipilih (belum diupload)
  String? _logoPathSaatIni; // logo yang sudah tersimpan (kalau edit)
  bool _hapusLogo = false; // user menekan "Hapus Logo" tanpa pilih logo baru

  bool get _isEdit => widget.template != null;

  @override
  void initState() {
    super.initState();
    final t = widget.template;
    _namaController = TextEditingController(text: t?.name ?? '');
    _headerController = TextEditingController(text: t?.headerHtml ?? '');
    _bodyController = TextEditingController(text: t?.bodyHtml ?? '');
    _aktif = t?.isActive ?? false;
    _logoPathSaatIni = t?.logoPath;
  }

  @override
  void dispose() {
    _namaController.dispose();
    _headerController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _pilihLogo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _logoBaru = result.files.first;
        _hapusLogo = false;
      });
    }
  }

  Future<void> _simpan() async {
    final nama = _namaController.text.trim();
    if (nama.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama template tidak boleh kosong')),
      );
      return;
    }

    setState(() => _sedangProses = true);
    try {
      String? logoPath = _logoPathSaatIni;

      if (_logoBaru != null && _logoBaru!.bytes != null) {
        // Ganti logo: upload baru, lalu hapus yang lama (kalau ada).
        final extensi = _logoBaru!.extension?.toLowerCase() ?? 'png';
        final pathBaru = await widget.repository.uploadLogo(_logoBaru!.bytes!, extensi);
        if (_logoPathSaatIni != null) {
          unawaited(widget.repository.deleteLogo(_logoPathSaatIni!));
        }
        logoPath = pathBaru;
      } else if (_hapusLogo && _logoPathSaatIni != null) {
        unawaited(widget.repository.deleteLogo(_logoPathSaatIni!));
        logoPath = null;
      }

      await widget.repository.save(
        id: widget.template?.id,
        name: nama,
        logoPath: logoPath,
        header: _headerController.text.trim(),
        body: _bodyController.text.trim(),
        active: _aktif,
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _sedangProses = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(_isEdit ? 'Edit Template' : 'Template Baru',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _namaController,
                  decoration: const InputDecoration(labelText: 'Nama Template', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),

                // --- LOGO ---
                const Text('Logo Instansi', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _PreviewLogo(
                      fileBaru: _logoBaru,
                      pathLama: _hapusLogo ? null : _logoPathSaatIni,
                      repository: widget.repository,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _pilihLogo,
                            icon: const Icon(Icons.upload_rounded, size: 18),
                            label: Text(_logoBaru != null ? 'Ganti Lagi' : 'Pilih Logo'),
                          ),
                          if ((_logoPathSaatIni != null && !_hapusLogo) || _logoBaru != null)
                            TextButton(
                              onPressed: () => setState(() {
                                _logoBaru = null;
                                _hapusLogo = true;
                              }),
                              style: TextButton.styleFrom(foregroundColor: Colors.red, padding: EdgeInsets.zero),
                              child: const Text('Hapus Logo'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // --- HEADER ---
                TextField(
                  controller: _headerController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Teks Header (judul atas laporan)',
                    hintText: 'Contoh: DINAS KEHUTANAN KABUPATEN GARUT',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _bodyController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Teks Penutup / Tanda Tangan (bagian bawah laporan)',
                    hintText: 'Contoh: Mengetahui,\n{{nama}}\nNIP. {{nip}}',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Token yang bisa dipakai: {{nama}}, {{nip}}, {{tanggal}}, {{desa}}, {{kecamatan}}, {{kabupaten}} — otomatis diganti sesuai data kegiatan saat laporan dibuat.',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600, height: 1.4),
                ),
                const SizedBox(height: 16),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Jadikan Template Aktif', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  subtitle: const Text('Template lain otomatis nonaktif', style: TextStyle(fontSize: 12)),
                  activeThumbColor: const Color(0xFF1B5E20),
                  value: _aktif,
                  onChanged: (v) => setState(() => _aktif = v),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _sedangProses ? null : () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: _sedangProses ? null : _simpan,
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1B5E20)),
            child: _sedangProses
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Simpan'),
          ),
        ],
      );
}

class _PreviewLogo extends StatelessWidget {
  const _PreviewLogo({required this.fileBaru, required this.pathLama, required this.repository});
  final PlatformFile? fileBaru;
  final String? pathLama;
  final TemplateRepository repository;

  @override
  Widget build(BuildContext context) {
    const size = 64.0;
    if (fileBaru?.bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(fileBaru!.bytes!, width: size, height: size, fit: BoxFit.cover),
      );
    }
    if (pathLama != null) {
      return FutureBuilder<String>(
        future: repository.signedLogoUrl(pathLama!),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Container(
              width: size, height: size,
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
            );
          }
          return ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(snapshot.data!, width: size, height: size, fit: BoxFit.cover),
          );
        },
      );
    }
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
      child: Icon(Icons.image_outlined, color: Colors.grey.shade400),
    );
  }
}

// Helper kecil supaya Future yang sengaja tidak ditunggu (best-effort
// cleanup logo lama) tidak memicu warning "unawaited_futures" dari linter.
void unawaited(Future<void> future) {}