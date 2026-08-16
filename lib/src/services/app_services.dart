import 'package:supabase_flutter/supabase_flutter.dart';
import 'connectivity_service.dart'; 
import 'activity_repository.dart';
import 'offline_activity_repository.dart';
import 'offline_queue_service.dart';

class AppServices {
  // 1. Kita bikin instance queue-nya di luar biar bisa dipanggil init()-nya
  static final OfflineQueueService offlineQueueService = OfflineQueueService();

  // 2. Baru kita masukin ke dalam repository
  static final OfflineActivityRepository offlineActivityRepository = 
      OfflineActivityRepository(
        ActivityRepository(Supabase.instance.client), 
        ConnectivityService(),                        
        offlineQueueService, // <-- Masuk ke sini
      );
}