import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Layanan sederhana untuk memantau status koneksi internet perangkat.
///
/// Dipakai oleh [OfflineActivityRepository] untuk memutuskan apakah suatu
/// aksi (create kegiatan, upload file) harus langsung dikirim ke Supabase
/// atau diantre dulu secara lokal, dan untuk memicu sinkronisasi otomatis
/// begitu koneksi kembali tersedia.
class ConnectivityService {
  ConnectivityService() {
    _sub = Connectivity().onConnectivityChanged.listen(_handleChange);
    // Cek status koneksi awal begitu service ini dibuat, supaya isOnline
    // tidak salah default ke true sebelum listener sempat jalan.
    Connectivity().checkConnectivity().then(_handleChange);
  }

  final _controller = StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _isOnline = true;

  /// Status koneksi saat ini. Nilainya "optimis" (true) sebelum
  /// pengecekan pertama selesai, supaya aplikasi tidak langsung
  /// menampilkan mode offline saat baru dibuka.
  bool get isOnline => _isOnline;

  /// Stream yang mengirim event setiap kali status online/offline berubah.
  Stream<bool> get onStatusChange => _controller.stream;

  void _handleChange(List<ConnectivityResult> results) {
    final online = results.any((r) => r != ConnectivityResult.none);
    if (online != _isOnline) {
      _isOnline = online;
      _controller.add(online);
    }
  }

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}