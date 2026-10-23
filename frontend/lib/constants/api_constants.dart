/// Central configuration for API endpoints.
///
/// Ganti [baseUrl] sesuai dengan mode pengetesan:
/// - Pengujian di HP (WiFi lokal sama): gunakan IP laptop Anda, misal: 'http://10.125.48.202:8001'
/// - Pengujian di Browser / Emulator: 'http://127.0.0.1:8001' atau 'http://10.0.2.2:8001'
/// - Production / Deploy: URL server yang di-deploy (misal: 'https://backend-phonebook.vercel.app')
abstract final class ApiConstants {
  /// Base URL backend Laravel.
  static const String baseUrl = 'http://10.125.48.202:8001';
}
