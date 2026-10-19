import 'package:flutter/material.dart';

/// Centralized color and decoration constants for the Laporan feature.
abstract final class LaporanColors {
  // Primary
  static const Color primary = Color(0xFF2E7D32);
  static const Color primaryLight = Color(0xFF4C944F);

  // Backgrounds
  static const Color pageBackground = Color(0xFFF6F8F5);
  static const Color cardBackground = Colors.white;
  static const Color greenBackgroundLight = Color(0xFFE8F5E9);
  static const Color greenBackground = Color(0xFFEAF4EA);
  static const Color fieldFill = Color(0xFFF7F9F7);
  static const Color templateBackground = Color(0xFFF6F9F6);
  static const Color tabBackground = Color(0xFFE8EDE8);

  // Text
  static const Color textDark = Color(0xFF1F2D21);
  static const Color textTitle = Color(0xFF253127);
  static const Color textCard = Color(0xFF263329);
  static const Color textMuted = Color(0xFF6E776F);
  static const Color textSubtle = Color(0xFF596259);
  static const Color textIcon = Color(0xFF718071);
  static const Color textFieldIcon = Color(0xFF527054);

  // Borders
  static const Color borderLight = Color(0xFFDCE6DC);
  static const Color borderCard = Color(0xFFE1E7E1);
  static const Color borderTemplate = Color(0xFFE0E7E0);
  static const Color borderDetail = Color(0xFFE0E8E0);
  static const Color borderField = Color(0xFFDDE5DD);
  static const Color divider = Color(0xFFE9EDE9);
  static const Color outlineGreen = Color(0xFFB9CCBA);

  // Status
  static const Color statusDraft = Color(0xFF757575);
  static const Color statusDraftBg = Color(0xFFE0E0E0);
  static const Color statusComplete = Color(0xFF2E7D32);
  static const Color statusCompleteBg = Color(0xFFE8F5E9);
  static const Color statusProcess = Color(0xFFB26A00);
  static const Color statusProcessBg = Color(0xFFFFF4DC);
  static const Color statusProcessBorder = Color(0xFFE7C98A);
}

/// Common month names used for Indonesian date formatting.
abstract final class LaporanDateUtils {
  static const List<String> monthNames = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  static String monthName(int month) => monthNames[month - 1];

  static String formatApiDate(String date) {
    final parsed = DateTime.tryParse(date);
    if (parsed == null) return date;
    return '${parsed.day} ${monthName(parsed.month)} ${parsed.year}';
  }

  static String displayStatus(String status) {
    return switch (status) {
      'draft' => 'Draft',
      'terkirim' => 'Selesai',
      'diperiksa' => 'Diproses',
      'disetujui' => 'Disetujui',
      'ditolak' => 'Ditolak',
      _ => status,
    };
  }
}
