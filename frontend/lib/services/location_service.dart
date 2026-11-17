import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

/// Status kondisi layanan GPS & izin lokasi perangkat.
enum LocationStatus {
  initial,
  loading,
  available,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  error,
}

/// Model data lokasi pengguna beserta hasil reverse geocoding.
class UserLocationData {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final String shortLocationName;
  final String fullAddress;
  final DateTime updatedAt;

  const UserLocationData({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    required this.shortLocationName,
    required this.fullAddress,
    required this.updatedAt,
  });

  String get coordinatesText =>
      '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'shortLocationName': shortLocationName,
        'fullAddress': fullAddress,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory UserLocationData.fromJson(Map<String, dynamic> json) {
    return UserLocationData(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      shortLocationName:
          (json['shortLocationName'] ?? 'Lokasi Terdeteksi').toString(),
      fullAddress: (json['fullAddress'] ?? '').toString(),
      updatedAt: DateTime.tryParse((json['updatedAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

/// Service tunggal (Singleton) untuk mengelola GPS perangkat, permission lokasi,
/// reverse geocoding alamat, pembaruan lokasi real-time, serta geotagging foto laporan.
///
/// Dirancang agar Dashboard Header, Widget Lokasi Dashboard, dan Form Laporan
/// berbagi satu sistem GPS yang sama tanpa duplikasi listener.
class LocationService extends ChangeNotifier {
  LocationService._();
  static final LocationService instance = LocationService._();

  static const String _cacheKey = 'phonebook_last_real_gps_location_v1';

  LocationStatus _status = LocationStatus.initial;
  UserLocationData? _currentLocation;
  String? _errorMessage;
  bool _isRefreshing = false;
  bool _initialized = false;
  StreamSubscription<Position>? _positionSub;

  LocationStatus get status => _status;
  UserLocationData? get currentLocation => _currentLocation;
  String? get errorMessage => _errorMessage;
  bool get isRefreshing => _isRefreshing;
  bool get hasLocation => _currentLocation != null;

  /// Inisialisasi awal: muat cache GPS terakhir (jika pernah diambil dari GPS nyata)
  /// lalu ambil titik GPS terbaru dari perangkat.
  Future<void> ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;
    await _loadCachedRealLocation();
    await refreshLocation(startStream: true);
  }

  Future<void> _loadCachedRealLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _currentLocation = UserLocationData.fromJson(decoded);
        _status = LocationStatus.available;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _saveCachedRealLocation(UserLocationData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(data.toJson()));
    } catch (_) {}
  }

  /// Memperbarui lokasi pengguna menggunakan GPS perangkat secara nyata.
  /// Mengembalikan [UserLocationData] jika berhasil, atau `null` jika izin/GPS tidak tersedia.
  Future<UserLocationData?> refreshLocation({bool startStream = false}) async {
    if (_isRefreshing) return _currentLocation;

    _isRefreshing = true;
    if (_currentLocation == null) {
      _status = LocationStatus.loading;
    }
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Periksa apakah layanan lokasi (GPS) aktif
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _status = LocationStatus.serviceDisabled;
        _errorMessage =
            'Layanan lokasi (GPS) perangkat sedang nonaktif. Silakan aktifkan GPS.';
        _isRefreshing = false;
        notifyListeners();
        return null;
      }

      // 2. Periksa & minta izin lokasi
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _status = LocationStatus.permissionDenied;
          _errorMessage =
              'Izin akses lokasi ditolak. Aktifkan izin lokasi untuk menampilkan posisi Anda.';
          _isRefreshing = false;
          notifyListeners();
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _status = LocationStatus.permissionDeniedForever;
        _errorMessage =
            'Izin lokasi ditolak permanen. Buka pengaturan aplikasi untuk mengizinkan akses lokasi.';
        _isRefreshing = false;
        notifyListeners();
        return null;
      }

      // 3. Ambil posisi GPS perangkat secara nyata
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      final resolved = await _buildLocationDataFromPosition(position);
      _currentLocation = resolved;
      _status = LocationStatus.available;
      _errorMessage = null;
      await _saveCachedRealLocation(resolved);

      if (startStream) {
        _startPositionStreamIfNeeded();
      }

      return resolved;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('PermissionDenied') ||
          msg.contains('permission denied')) {
        _status = LocationStatus.permissionDenied;
        _errorMessage =
            'Izin akses lokasi ditolak oleh perangkat atau browser.';
      } else if (msg.contains('LocationServiceDisabled')) {
        _status = LocationStatus.serviceDisabled;
        _errorMessage = 'Layanan GPS perangkat sedang tidak aktif.';
      } else {
        if (_currentLocation == null) {
          _status = LocationStatus.error;
        }
        _errorMessage =
            'Lokasi GPS belum dapat diperoleh. Pastikan sinyal GPS aktif dan izin lokasi diberikan.';
      }
      return _currentLocation;
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  /// Menjalankan satu stream GPS tunggal yang hemat baterai (hanya memicu pembaruan
  /// apabila pengguna berpindah minimal 25 meter).
  void _startPositionStreamIfNeeded() {
    if (_positionSub != null) return;
    try {
      const settings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 25,
      );
      _positionSub =
          Geolocator.getPositionStream(locationSettings: settings).listen(
        (position) async {
          final prev = _currentLocation;
          if (prev != null) {
            final dist = Geolocator.distanceBetween(
              prev.latitude,
              prev.longitude,
              position.latitude,
              position.longitude,
            );
            if (dist < 20) return;
          }
          final updated = await _buildLocationDataFromPosition(position);
          _currentLocation = updated;
          _status = LocationStatus.available;
          _errorMessage = null;
          await _saveCachedRealLocation(updated);
          notifyListeners();
        },
        onError: (_) {},
      );
    } catch (_) {}
  }

  /// Melakukan Reverse Geocoding nyata menggunakan layanan OpenStreetMap Nominatim
  /// untuk mengubah koordinat Latitude & Longitude menjadi nama wilayah dan alamat.
  Future<UserLocationData> _buildLocationDataFromPosition(
    Position position,
  ) async {
    final lat = position.latitude;
    final lon = position.longitude;

    final geo = await reverseGeocode(lat, lon);
    return UserLocationData(
      latitude: lat,
      longitude: lon,
      accuracy: position.accuracy,
      shortLocationName: geo.shortName,
      fullAddress: geo.fullAddress,
      updatedAt: DateTime.now(),
    );
  }

  Future<({String shortName, String fullAddress})> reverseGeocode(
    double latitude,
    double longitude,
  ) async {
    final fallbackCoord =
        'Koordinat ${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=jsonv2&lat=$latitude&lon=$longitude&zoom=18&addressdetails=1&accept-language=id',
      );

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'PhonebookCDKVGarut/1.0 (kehutanan.jabarprov.go.id)',
        },
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final displayName = (data['display_name'] ?? '').toString().trim();
        final addr = data['address'] is Map
            ? Map<String, dynamic>.from(data['address'] as Map)
            : <String, dynamic>{};

        final village = (addr['village'] ??
                addr['suburb'] ??
                addr['neighbourhood'] ??
                addr['hamlet'] ??
                addr['town'] ??
                '')
            .toString()
            .trim();
        final district = (addr['municipality'] ??
                addr['city_district'] ??
                addr['district'] ??
                addr['county'] ??
                '')
            .toString()
            .trim();
        final city = (addr['city'] ??
                addr['regency'] ??
                addr['county'] ??
                addr['state_district'] ??
                '')
            .toString()
            .trim();
        final state = (addr['state'] ?? '').toString().trim();

        final parts = <String>[];
        if (village.isNotEmpty) parts.add(village);
        if (district.isNotEmpty && !parts.contains(district)) {
          parts.add(district);
        }
        if (city.isNotEmpty && !parts.contains(city)) {
          parts.add(city);
        }
        if (state.isNotEmpty && parts.length < 2) {
          parts.add(state);
        }

        String shortName = '';
        if (city.isNotEmpty && state.isNotEmpty) {
          shortName = village.isNotEmpty
              ? '$village, $city, $state'
              : '$city, $state';
        } else if (parts.isNotEmpty) {
          shortName = parts.take(3).join(', ');
        } else if (displayName.isNotEmpty) {
          final segs = displayName
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
          shortName = segs.take(3).join(', ');
        }

        if (shortName.isNotEmpty) {
          return (
            shortName: shortName,
            fullAddress: displayName.isNotEmpty ? displayName : shortName,
          );
        }
      }
    } catch (_) {}

    return (
      shortName: fallbackCoord,
      fullAddress:
          'Titik GPS: ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
    );
  }

  /// Membuka pengaturan lokasi/GPS perangkat Android.
  Future<bool> openLocationSettings() async {
    if (kIsWeb) return false;
    try {
      return await Geolocator.openLocationSettings();
    } catch (_) {
      return false;
    }
  }

  /// Membuka pengaturan izin aplikasi di Android.
  Future<bool> openAppSettings() async {
    if (kIsWeb) return false;
    try {
      return await Geolocator.openAppSettings();
    } catch (_) {
      return false;
    }
  }

  /// Membubuhkan watermark/stamp informasi geolokasi (Koordinat GPS, Alamat/Lokasi,
  /// dan Waktu WIB) secara langsung pada gambar foto dokumentasi laporan.
  static Uint8List stampPhotoWithGeolocation(
    Uint8List rawBytes, {
    double? latitude,
    double? longitude,
    String? locationName,
    String? address,
  }) {
    try {
      final decoded = img.decodeImage(rawBytes);
      if (decoded == null) return rawBytes;

      var canvas = img.bakeOrientation(decoded);
      if (canvas.width > 1280 || canvas.height > 1280) {
        if (canvas.width >= canvas.height) {
          canvas = img.copyResize(canvas, width: 1280);
        } else {
          canvas = img.copyResize(canvas, height: 1280);
        }
      }

      final now = DateTime.now();
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'Mei',
        'Jun',
        'Jul',
        'Agu',
        'Sep',
        'Okt',
        'Nov',
        'Des',
      ];
      final timeStr =
          '${now.day} ${months[now.month - 1]} ${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} WIB';
      final coordStr = (latitude != null && longitude != null)
          ? 'GPS: ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}'
          : 'GPS: Koordinat belum tersedia';
      final locStr = (locationName != null && locationName.trim().isNotEmpty)
          ? locationName.trim()
          : 'Dokumentasi Lapangan CDK Wilayah V';
      final addrStr = (address != null && address.trim().isNotEmpty)
          ? (address.trim().length > 76
              ? '${address.trim().substring(0, 76)}...'
              : address.trim())
          : '';

      final barHeight = addrStr.isNotEmpty ? 96 : 74;
      final barTop = (canvas.height - barHeight).clamp(0, canvas.height);

      // Gambar pita latar belakang semi-transparan di bagian bawah foto
      img.fillRect(
        canvas,
        x1: 0,
        y1: barTop,
        x2: canvas.width,
        y2: canvas.height,
        color: img.ColorRgba8(16, 32, 22, 195),
      );

      // Garis aksen hijau di atas pita geotag
      img.fillRect(
        canvas,
        x1: 0,
        y1: barTop,
        x2: canvas.width,
        y2: barTop + 3,
        color: img.ColorRgba8(129, 199, 132, 255),
      );

      img.drawString(
        canvas,
        '$coordStr  |  $timeStr',
        font: img.arial14,
        x: 16,
        y: barTop + 12,
        color: img.ColorRgba8(165, 214, 167, 255),
      );

      img.drawString(
        canvas,
        locStr.length > 76 ? '${locStr.substring(0, 76)}...' : locStr,
        font: img.arial14,
        x: 16,
        y: barTop + 34,
        color: img.ColorRgba8(255, 255, 255, 255),
      );

      if (addrStr.isNotEmpty) {
        img.drawString(
          canvas,
          addrStr,
          font: img.arial14,
          x: 16,
          y: barTop + 56,
          color: img.ColorRgba8(220, 235, 222, 255),
        );
      }

      return Uint8List.fromList(img.encodeJpg(canvas, quality: 86));
    } catch (_) {
      return rawBytes;
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }
}