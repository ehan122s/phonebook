import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/activity.dart';
import '../../services/activity_repository.dart';
import '../../widgets/glashmorp.dart';
import 'halaman_detail_kegiatan.dart';

class HalamanKegiatan extends StatefulWidget {
  const HalamanKegiatan({super.key, required this.repository});
  final ActivityRepository repository;
  
  @override
  State<HalamanKegiatan> createState() => _HalamanKegiatanState();
}

class _HalamanKegiatanState extends State<HalamanKegiatan> {
  String _query = '';

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Activity>>(
        future: widget.repository.list(query: _query),
        builder: (_, snapshot) => ListView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          children: [
            // Search Bar dengan efek Glassmorphism
            KartuKaca(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              borderRadius: 30,
              child: TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  icon: Icon(Icons.search, color: Colors.black54),
                  hintText: 'Cari kegiatan, desa, atau kecamatan...',
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  filled: false,
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(48),
                  child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
                ),
              )
            else if (snapshot.data?.isEmpty ?? true)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(48),
                  child: Text(
                    'Tidak ada kegiatan yang ditemukan.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  ),
                ),
              )
            else
              // Menampilkan daftar kegiatan secara responsif menggunakan Wrap/Grid pada desktop, 
              // namun ListView biasa sudah cukup baik jika itemnya lebar.
              ...?snapshot.data?.map(
                (activity) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ItemKegiatanKaca(activity: activity, repository: widget.repository),
                ),
              ),
          ],
        ),
      );
}

class ItemKegiatanKaca extends StatelessWidget {
  const ItemKegiatanKaca({super.key, required this.activity, this.repository});
  final Activity activity;
  final ActivityRepository? repository;

  @override
  Widget build(BuildContext context) => KartuKaca(
        padding: const EdgeInsets.all(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: repository == null
              ? null
              : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HalamanDetailKegiatan(
                        activity: activity,
                        repository: repository!,
                      ),
                    ),
                  ),
          child: ListTile(
            leading: Container(
              height: 56,
              width: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.forest, color: Color(0xFF2E7D32), size: 30),
            ),
            title: Text(
              activity.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.black87),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                '${activity.categoryName} • ${DateFormat('dd MMM yyyy', 'id_ID').format(activity.activityDate)}\n${activity.village}, ${activity.district}',
                style: TextStyle(color: Colors.grey.shade800, height: 1.5),
              ),
            ),
            isThreeLine: true,
            trailing: repository == null
                ? null
                : PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.black54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    color: Colors.white.withValues(alpha: 0.95), // Sedikit transparan
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'upload',
                        child: Row(
                          children: [
                            Icon(Icons.upload_file, size: 20, color: Colors.blue),
                            SizedBox(width: 12),
                            Text('Upload Berkas'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'report',
                        child: Row(
                          children: [
                            Icon(Icons.print, size: 20, color: Colors.green),
                            SizedBox(width: 12),
                            Text('Buat Laporan'),
                          ],
                        ),
                      ),
                      PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 20, color: Colors.red),
                            SizedBox(width: 12),
                            Text('Hapus', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) => _pilihAksi(context, value),
                  ),
          ),
        ),
      );

  Future<void> _pilihAksi(BuildContext context, String value) async {
    if (value == 'delete') {
      await repository!.delete(activity.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Data kegiatan berhasil dihapus')));
      }
      return;
    }
    if (value == 'upload') {
      final file = await FilePicker.platform.pickFiles(withData: true);
      if (file?.files.single.bytes != null) {
        await repository!.uploadFile(
          activityId: activity.id,
          name: file!.files.single.name,
          bytes: file.files.single.bytes!,
          contentType: file.files.single.extension?.toLowerCase() == 'png'
              ? 'image/png'
              : file.files.single.extension?.toLowerCase() == 'jpg' ||
                      file.files.single.extension?.toLowerCase() == 'jpeg'
                  ? 'image/jpeg'
                  : 'application/octet-stream',
          isPhoto: ['jpg', 'jpeg', 'png'].contains(file.files.single.extension?.toLowerCase()),
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('File berhasil diupload!')));
        }
      }
      return;
    }
    try {
      await repository!.createReport(activity.id, 'pdf');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Laporan PDF berhasil dibuat dan disimpan.')),
        );
      }
    } on Exception catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.toString())));
      }
    }
  }
}