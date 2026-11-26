import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:frontend/services/location_service.dart';

void main() {
  group('LocationService Watermark GPS Tests (BUG-01)', () {
    test('stampPhotoWithGeolocation handles landscape 1280x720 without clipping or error', () {
      final source = img.Image(width: 1280, height: 720);
      img.fill(source, color: img.ColorRgba8(40, 100, 60, 255));
      final rawBytes = Uint8List.fromList(img.encodeJpg(source));

      final stampedBytes = LocationService.stampPhotoWithGeolocation(
        rawBytes,
        latitude: -7.216123,
        longitude: 107.901456,
        locationName: 'Kawasan Hutan Lindung Gunung Papandayan Garut Selatan',
        address: 'Jl. Raya Cisurupan No. 123, Kecamatan Cisurupan, Kabupaten Garut, Jawa Barat 44163',
      );

      final decoded = img.decodeImage(stampedBytes);
      expect(decoded, isNotNull);
      expect(decoded!.width, 1280);
      expect(decoded.height, 720);
    });

    test('stampPhotoWithGeolocation handles compact landscape 640x360 and portrait 720x1280', () {
      final compactLandscape = img.Image(width: 640, height: 360);
      img.fill(compactLandscape, color: img.ColorRgba8(50, 80, 55, 255));
      final landscapeBytes = Uint8List.fromList(img.encodeJpg(compactLandscape));

      final stampedLandscape = LocationService.stampPhotoWithGeolocation(
        landscapeBytes,
        latitude: -7.123456,
        longitude: 107.654321,
        locationName: 'Lokasi Penyuluhan Sangat Panjang Sekali Untuk Menguji Pemotongan Teks Responsif',
        address: 'Alamat Lengkap Yang Sangat Panjang Sekali Di Wilayah Garut Selatan Jawa Barat Indonesia',
      );

      final decodedLandscape = img.decodeImage(stampedLandscape);
      expect(decodedLandscape, isNotNull);
      expect(decodedLandscape!.width, 640);
      expect(decodedLandscape.height, 360);

      final portrait = img.Image(width: 720, height: 1280);
      img.fill(portrait, color: img.ColorRgba8(50, 80, 55, 255));
      final portraitBytes = Uint8List.fromList(img.encodeJpg(portrait));

      final stampedPortrait = LocationService.stampPhotoWithGeolocation(
        portraitBytes,
        latitude: -7.123456,
        longitude: 107.654321,
      );

      final decodedPortrait = img.decodeImage(stampedPortrait);
      expect(decodedPortrait, isNotNull);
      expect(decodedPortrait!.width, 720);
      expect(decodedPortrait.height, 1280);
    });
  });
}
