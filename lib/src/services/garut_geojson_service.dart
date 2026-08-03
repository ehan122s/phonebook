import 'dart:convert';
import 'package:http/http.dart' as http;

class GarutGeoJsonService {
  static const _url =
      'https://arcgis.jabarprov.go.id/arcgis/rest/services/kabupaten_kota/Kabupaten_Garut/MapServer/1/query?where=remark%3D%27Ibukota%20Kecamatan%27&outFields=namobj&returnGeometry=true&f=geojson&outSR=4326';
  Future<List<String>> districts() async {
    final response = await http.get(Uri.parse(_url));
    if (response.statusCode != 200) {
      throw Exception('GeoJSON kecamatan Garut tidak dapat dimuat');
    }
    final features =
        (jsonDecode(response.body) as Map<String, dynamic>)['features'] as List;
    final names =
        features
            .map(
              (feature) => (feature['properties'] as Map)['namobj'] as String,
            )
            .toSet()
            .toList()
          ..sort();
    return names;
  }
}
