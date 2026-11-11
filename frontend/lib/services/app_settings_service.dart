import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service global untuk mengelola preferensi Tema (Light, Dark, Sistem)
/// dan Skala Ukuran Font (Kecil, Sedang, Besar) secara reaktif di seluruh aplikasi.
class AppSettingsService extends ChangeNotifier {
  AppSettingsService._();
  static final AppSettingsService instance = AppSettingsService._();

  static const String _keyThemeMode = 'app_theme_mode';
  static const String _keyTextScale = 'app_text_scale';

  ThemeMode _themeMode = ThemeMode.system;
  String _themeString = 'Sistem';

  double _textScaleFactor = 1.0;
  String _textScaleString = 'Sedang';

  ThemeMode get themeMode => _themeMode;
  String get themeString => _themeString;

  double get textScaleFactor => _textScaleFactor;
  String get textScaleString => _textScaleString;

  /// Inisialisasi pengaturan dari SharedPreferences saat aplikasi pertama kali berjalan
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Muat Tema
      final savedTheme = prefs.getString(_keyThemeMode) ?? 'Sistem';
      _setThemeInternal(savedTheme);

      // 2. Muat Ukuran Teks (Kecil, Sedang, Besar)
      final savedScale = prefs.getString(_keyTextScale) ?? 'Sedang';
      _setTextScaleInternal(savedScale);

      notifyListeners();
    } catch (e) {
      debugPrint('AppSettingsService init error: $e');
    }
  }

  void _setThemeInternal(String themeStr) {
    final lower = themeStr.toLowerCase();
    if (lower == 'terang' || lower == 'light') {
      _themeMode = ThemeMode.light;
      _themeString = 'Terang';
    } else if (lower == 'gelap' || lower == 'dark') {
      _themeMode = ThemeMode.dark;
      _themeString = 'Gelap';
    } else {
      _themeMode = ThemeMode.system;
      _themeString = 'Sistem';
    }
  }

  /// Mengubah tema aplikasi ke 'Sistem', 'Terang', atau 'Gelap'
  Future<void> setTheme(String themeStr) async {
    _setThemeInternal(themeStr);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyThemeMode, _themeString);
    } catch (_) {}
    notifyListeners();
  }

  void _setTextScaleInternal(String scaleStr) {
    final lower = scaleStr.toLowerCase();
    if (lower == 'kecil' || lower == 'small') {
      _textScaleFactor = 0.85;
      _textScaleString = 'Kecil';
    } else if (lower == 'besar' || lower == 'large') {
      _textScaleFactor = 1.25;
      _textScaleString = 'Besar';
    } else {
      _textScaleFactor = 1.0;
      _textScaleString = 'Sedang';
    }
  }

  /// Mengubah ukuran font aplikasi ke 'Kecil', 'Sedang', atau 'Besar'
  Future<void> setTextScale(String scaleStr) async {
    _setTextScaleInternal(scaleStr);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyTextScale, _textScaleString);
    } catch (_) {}
    notifyListeners();
  }
}
