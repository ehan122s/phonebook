import 'package:flutter/material.dart';

class HalamanMateriEdukasi extends StatelessWidget {
  const HalamanMateriEdukasi({super.key});

  void _showFormUpload(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upload Materi Baru', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TextField(decoration: InputDecoration(labelText: 'Judul Materi', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            const TextField(decoration: InputDecoration(labelText: 'Kategori (cth: Panduan, Jurnal)', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {}, 
              icon: const Icon(Icons.upload_file),
              label: const Text('Pilih File PDF/Word'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context), style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1B5E20)), child: const Text('Upload')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.orange.shade200)),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange.shade800),
                const SizedBox(width: 16),
                Expanded(child: Text('Temukan panduan, modul, dan jurnal kehutanan di sini. Anda juga dapat membagikan materi untuk pengguna lain.', style: TextStyle(color: Colors.orange.shade900))),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _MateriCard(judul: 'Panduan Budidaya Kopi Di Bawah Tegakan', penulis: 'Dinas Kehutanan', tipe: 'PDF', warna: Colors.red),
          const _MateriCard(judul: 'Modul Pencegahan Kebakaran Hutan 2026', penulis: 'KLHK Pusat', tipe: 'DOCX', warna: Colors.blue),
          const _MateriCard(judul: 'Teknik Pemetaan Partisipatif KTH', penulis: 'Budi Santoso', tipe: 'PDF', warna: Colors.red),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFormUpload(context),
        backgroundColor: const Color(0xFF1B5E20),
        icon: const Icon(Icons.cloud_upload, color: Colors.white),
        label: const Text('Upload Materi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _MateriCard extends StatelessWidget {
  final String judul;
  final String penulis;
  final String tipe;
  final Color warna;

  const _MateriCard({required this.judul, required this.penulis, required this.tipe, required this.warna});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: warna.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Text(tipe, style: TextStyle(color: warna, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
        title: Text(judul, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text('Oleh: $penulis', style: const TextStyle(fontSize: 13)),
        trailing: IconButton(
          icon: const Icon(Icons.download_rounded, color: Colors.grey),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Mengunduh $judul...')));
          },
        ),
      ),
    );
  }
}