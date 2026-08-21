import 'package:supabase_flutter/supabase_flutter.dart';

import 'activity_repository.dart';
import 'connectivity_service.dart';
import 'offline_activity_repository.dart';
import 'offline_queue_service.dart';
import 'reference_cache_service.dart'; // BARU

/// Titik akses tunggal untuk repository yang dipakai di banyak halaman.
///
/// [init] WAJIB dipanggil dan di-`await` di `main.dart`, setelah
/// `Hive.initFlutter()` dan `Supabase.initialize()`, SEBELUM `runApp()`.
class AppServices {
  AppServices._();

  static final OfflineQueueService offlineQueueService = OfflineQueueService();
  static OfflineActivityRepository? _activityRepository;

  static Future<void> init() async {
    // Idempotent -- aman dipanggil berkali-kali, box yang sudah terbuka
    // tidak dibuka ulang oleh Hive.
    await offlineQueueService.init();
    await ReferenceCacheService.init(); // BARU -- cache kategori & kecamatan

    _activityRepository ??= OfflineActivityRepository(
      ActivityRepository(Supabase.instance.client),
      ConnectivityService(),
      offlineQueueService,
    );
  }

  static OfflineActivityRepository get activityRepository {
    final repo = _activityRepository;
    if (repo == null) {
      throw StateError(
        'AppServices.init() belum di-await di main.dart sebelum runApp().',
      );
    }
    return repo;
  }
}