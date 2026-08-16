import 'package:flutter/material.dart';

import '../services/offline_activity_repository.dart';
import 'glashmorp.dart';

/// Banner kaca yang muncul otomatis kalau masih ada kegiatan/file yang
/// belum tersinkron ke server. Sembunyi sendiri (SizedBox.shrink) kalau
/// antriannya kosong.
class SyncStatusBanner extends StatelessWidget {
  const SyncStatusBanner({super.key, required this.repository});
  final OfflineActivityRepository repository;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: repository.pendingCountNotifier,
        builder: (context, count, _) {
          if (count == 0) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: KartuKaca(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off_rounded, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      count == 1
                          ? '1 data belum tersinkron ke server'
                          : '$count data belum tersinkron ke server',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
                    ),
                  ),
                  _TombolSinkron(repository: repository),
                ],
              ),
            ),
          );
        },
      );
}

class _TombolSinkron extends StatefulWidget {
  const _TombolSinkron({required this.repository});
  final OfflineActivityRepository repository;

  @override
  State<_TombolSinkron> createState() => _TombolSinkronState();
}

class _TombolSinkronState extends State<_TombolSinkron> {
  bool _sedangProses = false;

  Future<void> _sinkronkan() async {
    setState(() => _sedangProses = true);
    final hasil = await widget.repository.syncPending();
    if (!mounted) return;
    setState(() => _sedangProses = false);

    if (hasil.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada koneksi internet, coba lagi nanti.')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          hasil.hasFailure
              ? 'Sinkron selesai: ${hasil.success} berhasil, ${hasil.failed} gagal'
              : 'Semua data berhasil disinkronkan (${hasil.success})',
        ),
        backgroundColor: hasil.hasFailure ? Colors.orange : const Color(0xFF2E7D32),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => TextButton.icon(
        onPressed: _sedangProses ? null : _sinkronkan,
        icon: _sedangProses
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.sync_rounded, size: 20),
        label: const Text('Sinkronkan', style: TextStyle(fontWeight: FontWeight.bold)),
      );
}