import 'package:flutter/material.dart';

class LeafletMap extends StatelessWidget {
  const LeafletMap({super.key, this.latitude, this.longitude});
  final double? latitude;
  final double? longitude;
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Peta tersedia pada Flutter Web'));
}
