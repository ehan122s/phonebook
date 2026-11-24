import 'package:flutter/material.dart';

/// Palet warna & helper tema terang/gelap khusus modul Admin
/// (Soft Green Forest - selaras dengan DashboardPage & KategoriPage).
class AdminTheme {
  static const Color kPrimary = Color(0xFF245C3A);
  static const Color kSecondary = Color(0xFF4F8A5B);
  static const Color kLightGreen = Color(0xFFE8F2E8);
  static const Color kSoftGreen = Color(0xFFF2F7F0);
  static const Color kBackground = Color(0xFFF7F9F6);
  static const Color kWhite = Color(0xFFFFFFFF);
  static const Color kTextPrimary = Color(0xFF24352A);
  static const Color kTextSecondary = Color(0xFF758278);
  static const Color kBorder = Color(0xFFE1EAE0);

  final bool isDark;

  const AdminTheme._(this.isDark);

  factory AdminTheme.of(BuildContext context) {
    return AdminTheme._(Theme.of(context).brightness == Brightness.dark);
  }

  Color get bgColor => isDark ? const Color(0xFF121814) : kBackground;
  Color get cardBg => isDark ? const Color(0xFF1E2822) : kWhite;
  Color get surfaceBg =>
      isDark ? const Color(0xFF18221B) : const Color(0xFFF2F6F2);
  Color get borderColor => isDark ? const Color(0xFF2E3D34) : kBorder;
  Color get textPrimary => isDark ? kWhite : kTextPrimary;
  Color get textSecondary => isDark ? Colors.white70 : kTextSecondary;
  Color get primaryAccent => isDark ? const Color(0xFF81C784) : kPrimary;
  Color get lightGreenBg => isDark ? const Color(0xFF233829) : kLightGreen;
  Color get softGreenBg => isDark ? const Color(0xFF1B2B20) : kSoftGreen;
}
