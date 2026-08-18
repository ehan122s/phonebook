import 'package:supabase_flutter/supabase_flutter.dart';

import 'activity_repository.dart';
import 'connectivity_service.dart';
import 'offline_activity_repository.dart';
import 'offline_queue_service.dart';

/// Titik akses tunggal untuk repository yang dipakai di banyak halaman.
///
/// PENTING: berbeda dari versi yang bikin crash — [activityRepository] TIDAK
/// dibangun otomatis begitu field-nya pertama kali diakses (pola
/// `static final` lazy itu yang rawan `LateInitializationError` kalau Hive
/// box belum sempat kebuka). Sekarang harus lewat [init] yang eksplisit dan
/// WAJIB di-`await` di `main.dart` sebelum `runApp()`.
class AppServices {
  AppServices._();

  static final OfflineQueueService offlineQueueService = OfflineQueueService();
  static OfflineActivityRepository? _activityRepository;

  /// Panggil SEKALI di `main.dart`, setelah `Hive.initFlutter()` dan
  /// `Supabase.initialize()`, SEBELUM `runApp()`.
  static Future<void> init() async {
    // Idempotent -- aman dipanggil berkali-kali (mis. karena hot restart),
    // box yang sudah terbuka tidak dibuka ulang oleh Hive.
    await offlineQueueService.init();

    _activityRepository ??= OfflineActivityRepository(
      ActivityRepository(Supabase.instance.client),
      ConnectivityService(),
      offlineQueueService,
    );
  }

  /// Dipakai di seluruh halaman. Melempar [StateError] yang jelas kalau
  /// [init] belum dipanggil, supaya gampang di-debug ketimbang
  /// `LateInitializationError` yang membingungkan.
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