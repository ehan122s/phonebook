import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class LeafletMap extends StatelessWidget {
  const LeafletMap({super.key, this.latitude, this.longitude});
  final double? latitude;
  final double? longitude;
  static bool _registered = false;
  static const _viewType = 'sipenyuluh-leaflet-map';
  static final _frames = <int, web.HTMLIFrameElement>{};

  @override
  Widget build(BuildContext context) {
    if (!_registered) {
      ui_web.platformViewRegistry.registerViewFactory(_viewType, (viewId) {
        final frame = web.HTMLIFrameElement()
          ..style.border = '0'
          ..style.width = '100%'
          ..style.height = '100%';
        _frames[viewId] = frame;
        return frame;
      });
      _registered = true;
    }
    final source =
        'leaflet_map.html?lat=${latitude ?? ''}&lng=${longitude ?? ''}';
    return HtmlElementView(
      key: ValueKey(source),
      viewType: _viewType,
      onPlatformViewCreated: (viewId) {
        final frame = _frames[viewId];
        if (frame != null) frame.src = source;
      },
    );
  }
}
