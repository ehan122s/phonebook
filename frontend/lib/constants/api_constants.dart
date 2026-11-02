/// Central configuration for API endpoints & third-party services.
abstract final class ApiConstants {
  /// Base URL backend Laravel di Vercel.
  static const String baseUrl = 'https://phonebook-five-umber.vercel.app';

  /// Google OAuth 2.0 Web Client ID (Google Cloud Console).
  /// Dapat diisi Client ID dari https://console.cloud.google.com/
  static const String googleClientId =
      '1038472910243-phonebookkehutanan.apps.googleusercontent.com';
}
