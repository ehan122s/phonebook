import 'package:hive_flutter/hive_flutter.dart';

/// Cache generik untuk data referensi yang jarang berubah (kategori
/// kegiatan, daftar kecamatan, dsb) — bukan data transaksional seperti
/// kegiatan/laporan (itu urusan [OfflineQueueService]).
///
/// Tujuannya: kalau HP offline atau koneksi ke Supabase lambat/hang saat
/// dialog "Buat Kegiatan" dibuka, dropdown tetap bisa dipakai pakai data
/// hasil fetch TERAKHIR yang berhasil, bukan macet di "Memuat...".
class ReferenceCacheService {
  static const _boxName = 'reference_cache';
  static Box? _box;

  /// Panggil sekali saat startup (dipanggil dari [AppServices.init]).
  static Future<void> init() async {
    _box ??= await Hive.openBox(_boxName);
  }

  static List<Map<String, dynamic>>? getMapList(String key) {
    final raw = _box?.get(key);
    if (raw == null) return null;
    return (raw as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<void> setMapList(String key, List<Map<String, dynamic>> value) async {
    await _box?.put(key, value);
  }

  static List<String>? getStringList(String key) {
    final raw = _box?.get(key);
    if (raw == null) return null;
    return (raw as List).cast<String>();
  }

  static Future<void> setStringList(String key, List<String> value) async {
    await _box?.put(key, value);
  }
}