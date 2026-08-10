import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; // Pastikan package ini di-import
import 'package:latlong2/latlong.dart'; // Untuk koordinat peta

class LeafletMap extends StatelessWidget {
  const LeafletMap({super.key, this.latitude, this.longitude});
  final double? latitude;
  final double? longitude;

  @override
  Widget build(BuildContext context) {
    // Koordinat default jika latitude/longitude null
    final lat = latitude ?? -7.250445; 
    final lng = longitude ?? 112.768845;

    return FlutterMap(
      options: MapOptions(
        initialCenter: LatLng(lat, lng),
        initialZoom: 13.0,
      ),
      children: [
       TileLayer(
          urlTemplate: 'https://a.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.hype.sipenyuluh',
        ),
      ],
    );
  }
}