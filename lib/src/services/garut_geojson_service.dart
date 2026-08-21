import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show compute;
import 'package:http/http.dart' as http;

import 'reference_cache_service.dart';

/// Parsing JSON dijalankan di isolate terpisah (bukan main thread) lewat
/// [compute], supaya UI tidak freeze kalau response-nya besar.
List<String> _parseDistrictNames(String body) {
  final features = (jsonDecode(body) as Map<String, dynamic>)['features'] as List;
  final names = features
      .map((feature) => (feature['properties'] as Map)['namobj'] as String)
      .toSet()
      .toList()
    ..sort();
  return names;
}

class GarutGeoJsonService {
  // returnGeometry=false -- kode ini cuma butuh nama kecamatan (`namobj`),
  // bukan koordinat poligon batas wilayah, jadi tidak perlu diminta ke server.
  static const _url =
      'https://arcgis.jabarprov.go.id/arcgis/rest/services/kabupaten_kota/Kabupaten_Garut/MapServer/1/query?where=remark%3D%27Ibukota%20Kecamatan%27&outFields=namobj&returnGeometry=false&f=geojson&outSR=4326';

  static const _cacheKey = 'garut_districts';

  // Cache in-memory untuk sesi berjalan (biar tidak fetch ulang tiap dialog
  // "Buat Kegiatan" dibuka), TERPISAH dari cache persisten di Hive yang
  // dipakai untuk fallback saat offline / gagal fetch.
  static List<String>? _cache;
  static Future<List<String>>? _inFlight;

  Future<List<String>> districts() {
    final cached = _cache;
    if (cached != null) return Future.value(cached);

    final existing = _inFlight;
    if (existing != null) return existing;

    final future = _fetch();
    _inFlight = future;
    return future;
  }

  Future<List<String>> _fetch() async {
    try {
      final response = await http
          .get(Uri.parse(_url))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw Exception('GeoJSON kecamatan Garut tidak dapat dimuat (status ${response.statusCode})');
      }
      final names = await compute(_parseDistrictNames, response.body);
      _cache = names;
      // BARU -- simpan ke cache persisten (Hive) untuk fallback offline.
      unawaited(ReferenceCacheService.setStringList(_cacheKey, names));
      return names;
    } catch (e) {
      // BARU -- offline / timeout / gagal fetch: pakai cache Hive dari
      // sesi sebelumnya kalau ada, supaya dropdown Kecamatan tetap jalan.
      final cached = ReferenceCacheService.getStringList(_cacheKey);
      if (cached != null && cached.isNotEmpty) {
        _cache = cached;
        return cached;
      }
      rethrow;
    } finally {
      _inFlight = null;
    }
  }
}