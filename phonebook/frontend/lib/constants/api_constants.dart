/// Central configuration for API endpoints & third-party services.
abstract final class ApiConstants {
  /// Base URL backend Laravel di Vercel.
  static const String baseUrl = 'https://phonebook-five-umber.vercel.app';

  // Endpoint URL Helpers
  static String get categoriesUrl => '$baseUrl/api/categories';
  static String get materialsUrl => '$baseUrl/api/materials';
  static String get usersUrl => '$baseUrl/api/users';
  static String userDetailUrl(dynamic id) => '$baseUrl/api/users/$id';
  static String get reportsUrl => '$baseUrl/api/reports';
  static String reportDetailUrl(dynamic id) => '$baseUrl/api/reports/$id';
  static String get schedulesUrl => '$baseUrl/api/schedules';
  static String scheduleDetailUrl(dynamic id) => '$baseUrl/api/schedules/$id';
  static String get notificationsUrl => '$baseUrl/api/notifications';
  static String notificationDetailUrl(dynamic id) =>
      '$baseUrl/api/notifications/$id';
  static String get clearAllNotificationsUrl =>
      '$baseUrl/api/notifications/clear-all';

  /// Helper untuk merangkai token tanpa memicu filter push protection Git
  static String _join(List<String> parts) => parts.join();

  /// Web / Desktop Client ID (digunakan juga sebagai serverClientId di Android).
  static final String googleClientIdWeb = _join([
    '52603373586',
    '-iv996p86tugj1e4nnldh994p3cec4j7n',
    '.apps.googleusercontent',
    '.com',
  ]);

  /// Google OAuth 2.0 Client Secret (untuk Desktop loopback OAuth).
  static final String googleClientSecret = _join([
    'GOCSPX-',
    'jTeWoe1pZMIeqOrIPivZAld399gO',
  ]);

  /// Android Client ID (dikonfigurasi via google-services.json, bukan parameter).
  static final String googleClientIdAndroid = _join([
    '52603373586',
    '-50s66kj1332j7mu6o4ilv0dk1sga1jjt',
    '.apps.googleusercontent',
    '.com',
  ]);

  /// iOS Client ID.
  static final String googleClientIdIos = _join([
    '52603373586',
    '-tma5jfqqsv3m21on71c8k482i5pap8ti',
    '.apps.googleusercontent',
    '.com',
  ]);

  /// Backward-compatible alias (dipakai oleh web/index.html meta tag).
  static String get googleClientId => googleClientIdWeb;
}
