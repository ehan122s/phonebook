import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Lightweight wrapper around [connectivity_plus] that exposes a
/// simple boolean API for network availability checks.
class ConnectivityService {
  ConnectivityService._();

  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();

  /// Returns `true` when the device is connected via WiFi or mobile
  /// data. Returns `false` for no connectivity.
  Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return _hasConnection(results);
  }

  /// Emits `true` when the device gains a network connection and
  /// `false` when it loses connectivity.
  Stream<bool> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged.map(_hasConnection);
  }

  bool _hasConnection(List<ConnectivityResult> results) {
    return results.any(
      (r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.ethernet,
    );
  }
}
