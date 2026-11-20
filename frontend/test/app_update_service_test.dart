import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/app_update_service.dart';

void main() {
  group('AppUpdateService Version Comparison Tests', () {
    test('isNewerVersion returns true when server version is higher', () {
      expect(AppUpdateService.isNewerVersion('1.1.0', '1.0.0'), isTrue);
      expect(AppUpdateService.isNewerVersion('1.2.0', '1.1.9'), isTrue);
      expect(AppUpdateService.isNewerVersion('2.0.0', '1.9.9'), isTrue);
      expect(AppUpdateService.isNewerVersion('1.0.1', '1.0.0'), isTrue);
      expect(AppUpdateService.isNewerVersion('1.0.0.1', '1.0.0'), isTrue);
      expect(AppUpdateService.isNewerVersion('v1.2.0', '1.1.0'), isTrue);
    });

    test('isNewerVersion returns false when server version is equal or lower', () {
      expect(AppUpdateService.isNewerVersion('1.0.0', '1.0.0'), isFalse);
      expect(AppUpdateService.isNewerVersion('1.0.0', '1.1.0'), isFalse);
      expect(AppUpdateService.isNewerVersion('1.0.0', '2.0.0'), isFalse);
      expect(AppUpdateService.isNewerVersion('1.2.0', '1.2.0+1'), isFalse);
      expect(AppUpdateService.isNewerVersion('v1.0.0', '1.0.0'), isFalse);
    });

    test('AppUpdateInfo correctly parses json and detects mandatory flag', () {
      final jsonOptional = {
        'id': 1,
        'version': '1.2.0',
        'title': 'Pembaruan Biasa',
        'description': 'Fitur baru',
        'apk_url': 'https://example.com/app.apk',
        'type': 'optional',
        'is_published': true,
      };

      final infoOptional = AppUpdateInfo.fromJson(jsonOptional);
      expect(infoOptional.id, 1);
      expect(infoOptional.version, '1.2.0');
      expect(infoOptional.isMandatory, isFalse);
      expect(infoOptional.isPublished, isTrue);

      final jsonMandatory = {
        'id': 2,
        'version': '2.0.0',
        'title': 'Pembaruan Wajib',
        'description': 'Pembaruan wajib',
        'apk_url': 'https://example.com/app.apk',
        'type': 'mandatory',
        'is_published': true,
      };

      final infoMandatory = AppUpdateInfo.fromJson(jsonMandatory);
      expect(infoMandatory.isMandatory, isTrue);
    });
  });
}
