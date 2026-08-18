import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/activity.dart';
import '../../services/offline_activity_repository.dart';
import '../../services/app_services.dart';
import 'halaman_detail_kegiatan.dart';

/// Dipanggil oleh route `/kegiatan/:id`. Berbeda dari sebelumnya
/// (yang langsung dioper objek [Activity] dari halaman daftar), loader ini
/// mengambil ulang data kegiatan langsung dari Supabase berdasarkan id di
/// URL. Ini yang membuat halaman detail tahan terhadap refresh browser:
/// begitu URL `/kegiatan/<id>` dibuka (baik lewat klik dari daftar maupun
/// lewat refresh/reload), datanya selalu diambil ulang dari server.
class HalamanDetailKegiatanLoader extends StatefulWidget {
  const HalamanDetailKegiatanLoader({super.key, required this.activityId});
  final String activityId;

  @override
  State<HalamanDetailKegiatanLoader> createState() => _HalamanDetailKegiatanLoaderState();
}

class _HalamanDetailKegiatanLoaderState extends State<HalamanDetailKegiatanLoader> {
  late final OfflineActivityRepository _repository;
  late Future<Activity> _future;

  @override
  void initState() {
    super.initState();
    _repository = AppServices.activityRepository;
    _future = _repository.getById(widget.activityId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Activity>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Detail Kegiatan')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Kegiatan tidak ditemukan atau kamu tidak punya akses.\n${snapshot.error ?? ''}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
            ),
          );
        }
        return HalamanDetailKegiatan(
          activity: snapshot.data!,
          repository: _repository,
        );
      },
    );
  }
}