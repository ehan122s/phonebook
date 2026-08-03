import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/material_item.dart';
import '../../services/material_repository.dart';
import '../../widgets/glashmorp.dart';
import '../../widgets/file_downloader.dart';

class HalamanMateriEdukasi extends StatefulWidget {
  const HalamanMateriEdukasi({super.key});

  @override
  State<HalamanMateriEdukasi> createState() => _HalamanMateriEdukasiState();
}

class _HalamanMateriEdukasiState extends State<HalamanMateriEdukasi> {
  late final MaterialRepository _repository;
  late Future<List<MaterialItem>> _future;
  String _query = '';
  String _kategori = 'Semua Kategori';

  @override
  void initState() {
    super.initState();
    _repository = MaterialRepository(Supabase.instance.client);
    _future = _repository.list();
  }

  Future<void> _refresh() async {
    setState(() => _future = _repository.list());
  }

  static const _badge = {
    'pdf': (label: 'PDF', color: Color(0xFFDC2626)),
    'word': (label: 'Word', color: Color(0xFF2563EB)),
    'excel': (label: 'Excel', color: Color(0xFF16A34A)),
    'video': (label: 'Video', color: Color(0xFF7C3AED)),
    'image': (label: 'Gambar', color: Color(0xFF0891B2)),
    'other': (label: 'File', color: Color(0xFF6B7280)),
  };

  Future<void> _unduh(BuildContext context, MaterialItem item) async {
    try {
      if (item.hasRealFile) {
        final url = await _repository.signedUrl(item.storagePath!);
        final opened = openExternalUrl(url);
        if (!opened && context.mounted) {
          _tampilkanFallback(context, item, url: url);
        }
      } else {
        final berhasil = downloadTextFile(
          fileName: item.fileName,
          content: item.contentText ?? 'Konten tidak tersedia.',
        );
        if (!berhasil && context.mounted) {
          _tampilkanFallback(context, item);
        }
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengunduh: $error')),
        );
      }
    }
  }

  void _tampilkanFallback(BuildContext context, MaterialItem item, {String? url}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: SingleChildScrollView(
          child: Text(url ?? item.contentText ?? 'Konten tidak tersedia.'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Materi Edukasi', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: LatarBelakangGradien(
        child: RefreshIndicator(
          color: const Color(0xFF2E7D32),
          onRefresh: _refresh,
          child: FutureBuilder<List<MaterialItem>>(
            future: _future,
            builder: (context, snapshot) {
              final isLoading = snapshot.connectionState == ConnectionState.waiting;
              final hasError = snapshot.hasError;
              final semua = snapshot.data ?? const <MaterialItem>[];
              final kategoriTersedia = <String>{'Semua Kategori', ...semua.map((m) => m.category)}.toList();

              final hasil = semua.where((m) {
                final cocokQuery = _query.isEmpty ||
                    m.title.toLowerCase().contains(_query.toLowerCase()) ||
                    m.category.toLowerCase().contains(_query.toLowerCase());
                final cocokKategori = _kategori == 'Semua Kategori' || m.category == _kategori;
                return cocokQuery && cocokKategori;
              }).toList();

              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // SEARCH + FILTER KATEGORI
                  KartuKaca(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    borderRadius: 20,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isMobile = constraints.maxWidth < 560;
                        final search = TextField(
                          onChanged: (v) => setState(() => _query = v),
                          decoration: const InputDecoration(
                            icon: Icon(Icons.search, color: Colors.black54),
                            hintText: 'Cari nama modul / buku...',
                            border: InputBorder.none,
                          ),
                        );
                        final filter = DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _kategori,
                            borderRadius: BorderRadius.circular(16),
                            items: kategoriTersedia
                                .map((k) => DropdownMenuItem(value: k, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w700))))
                                .toList(),
                            onChanged: (v) => setState(() => _kategori = v ?? 'Semua Kategori'),
                          ),
                        );
                        if (isMobile) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                search,
                                const Divider(height: 1, color: Colors.black12),
                                Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8), child: filter),
                              ],
                            ),
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: search),
                            Container(width: 1, height: 28, color: Colors.black12, margin: const EdgeInsets.symmetric(horizontal: 8)),
                            Padding(padding: const EdgeInsets.only(right: 12), child: filter),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (hasError)
                    KartuKaca(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          const Icon(Icons.cloud_off, color: Colors.orange, size: 40),
                          const SizedBox(height: 12),
                          const Text('Gagal memuat materi. Tarik ke bawah untuk mencoba lagi.', textAlign: TextAlign.center),
                        ],
                      ),
                    )
                  else if (isLoading)
                    const KartuKaca(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32))),
                    )
                  else if (hasil.isEmpty)
                    const KartuKaca(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('Materi tidak ditemukan.', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700))),
                    )
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final lebar = constraints.maxWidth;
                        final kolom = lebar >= 1100 ? 3 : (lebar >= 700 ? 2 : 1);
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: hasil.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: kolom,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: kolom == 1 ? 2.6 : 1.35,
                          ),
                          itemBuilder: (context, i) => _KartuMateri(item: hasil[i], badge: _badge, onUnduh: () => _unduh(context, hasil[i])),
                        );
                      },
                    ),
                  const SizedBox(height: 40),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _KartuMateri extends StatelessWidget {
  const _KartuMateri({required this.item, required this.badge, required this.onUnduh});
  final MaterialItem item;
  final Map<String, ({String label, Color color})> badge;
  final VoidCallback onUnduh;

  @override
  Widget build(BuildContext context) {
    final b = badge[item.fileType] ?? badge['other']!;
    return KartuKaca(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: b.color, borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: Text(b.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.category.toUpperCase(),
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.grey.shade600, letterSpacing: 0.4)),
                    const SizedBox(height: 3),
                    Text(item.title,
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.black87, height: 1.25)),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          const SizedBox(height: 8),
          Text('Ukuran: ${item.sizeLabel}', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: onUnduh,
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32).withOpacity(0.12),
                foregroundColor: const Color(0xFF1B5E20),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Unduh File', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}
