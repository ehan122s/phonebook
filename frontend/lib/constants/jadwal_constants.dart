// ============================================================================
// [FILE CONSTANTS - WARNA & FORMAT TANGGAL JADWAL]
// Simpan file ini di: constants/jadwal_constants.dart
// (Letakkan satu folder dengan laporan_constants.dart)
// ============================================================================

import 'package:flutter/material.dart';

/// Color palette for the Jadwal feature, aligned with LaporanColors.
class JadwalColors {
  JadwalColors._();

  static const Color pageBackground = Color(0xFFF6F8F5);
  static const Color cardBackground = Colors.white;
  static const Color primary = Color(0xFF285C2E);
  static const Color primaryLight = Color(0xFFE6F2E7);
  static const Color outlineGreen = Color(0xFFB7D7B9);

  static const Color textDark = Color(0xFF1E2923);
  static const Color textCard = Color(0xFF222B25);
  static const Color textMuted = Color(0xFF6E7A72);
  static const Color textSubtle = Color(0xFF5A655E);
  static const Color textIcon = Color(0xFF7A877E);

  static const Color borderCard = Color(0xFFE5ECE6);
  static const Color divider = Color(0xFFEEF2EE);

  // Time box & status colors
  static const Color timeBoxBg = Color(0xFFE3F2FD);
  static const Color timeBoxText = Color(0xFF1565C0);

  static const Color upcomingBg = Color(0xFFFFF4E5);
  static const Color upcomingText = Color(0xFFE65100);

  static const Color completedBg = Color(0xFFE8F5E9);
  static const Color completedText = Color(0xFF2E7D32);
}

/// Date & formatting utilities for Jadwal (without external packages).
class JadwalDateUtils {
  JadwalDateUtils._();

  static const List<String> bulanIndonesia = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  static const List<String> hariSingkat = [
    'Sen',
    'Sel',
    'Rab',
    'Kam',
    'Jum',
    'Sab',
    'Min',
  ];

  static const List<String> hariLengkap = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];

  /// Returns true if [a] and [b] fall on the exact same calendar day.
  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Formats [date] as `20 Oktober 2026`.
  static String formatTanggal(DateTime date) {
    return '${date.day} ${bulanIndonesia[date.month - 1]} ${date.year}';
  }

  /// Formats [date] as `Selasa, 20 Oktober 2026`.
  static String formatHariTanggal(DateTime date) {
    final namaHari = hariLengkap[date.weekday - 1];
    return '$namaHari, ${formatTanggal(date)}';
  }

  /// Formats [date] as `Oktober 2026`.
  static String formatBulanTahun(DateTime date) {
    return '${bulanIndonesia[date.month - 1]} ${date.year}';
  }

  /// Formats [date] as `YYYY-MM-DD` for storage/comparison.
  static String toIsoDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Parses `YYYY-MM-DD` string into a [DateTime].
  static DateTime parseIsoDate(String raw) {
    final parts = raw.split('-');
    if (parts.length == 3) {
      return DateTime(
        int.tryParse(parts[0]) ?? 2026,
        int.tryParse(parts[1]) ?? 10,
        int.tryParse(parts[2]) ?? 20,
      );
    }
    return DateTime(2026, 10, 20);
  }
}

/// Default initial schedules so the calendar, upcoming list, and history
/// are immediately populated.
List<Map<String, dynamic>> buildDefaultJadwalList() {
  return [
    {
      'id': 'jadwal_1',
      'judul': 'Penyuluhan Kehutanan',
      'kategori': 'Penyuluhan',
      'tanggalIso': '2026-10-20',
      'waktu': '08:00',
      'lokasi': 'Kecamatan Garut',
      'catatan':
          'Sosialisasi program perhutanan sosial dan pembagian bibit produktif kepada kelompok tani hutan.',
      'isCompleted': false,
    },
    {
      'id': 'jadwal_2',
      'judul': 'Monitoring Lapangan',
      'kategori': 'Monitoring',
      'tanggalIso': '2026-10-20',
      'waktu': '13:00',
      'lokasi': 'Kawasan Hutan Garut',
      'catatan':
          'Pengecekan kondisi patok batas kawasan dan pemantauan titik rawan kebakaran hutan.',
      'isCompleted': false,
    },
    {
      'id': 'jadwal_3',
      'judul': 'Evaluasi Kelompok Tani Hutan',
      'kategori': 'Evaluasi',
      'tanggalIso': '2026-10-22',
      'waktu': '09:30',
      'lokasi': 'Desa Sukamaju, Garut',
      'catatan':
          'Pendampingan administrasi dan evaluasi hasil panen komoditas agroforestri triwulan III.',
      'isCompleted': false,
    },
    {
      'id': 'jadwal_4',
      'judul': 'Penanaman Bibit Bersama Warga',
      'kategori': 'Rehabilitasi',
      'tanggalIso': '2026-10-25',
      'waktu': '07:30',
      'lokasi': 'Lereng Gunung Guntur',
      'catatan':
          'Kegiatan penanaman 500 bibit pohon keras di lahan kritis bersama masyarakat sekitar.',
      'isCompleted': false,
    },
    {
      'id': 'jadwal_5',
      'judul': 'Patroli Pengamanan Hutan',
      'kategori': 'Patroli',
      'tanggalIso': '2026-10-15',
      'waktu': '08:30',
      'lokasi': 'Blok Cikuray Selatan',
      'catatan':
          'Patroli rutin bersama tim Polisi Kehutanan. Situasi aman dan kondusif.',
      'isCompleted': true,
    },
    {
      'id': 'jadwal_6',
      'judul': 'Pendataan Potensi Hasil Hutan Bukan Kayu',
      'kategori': 'Pendataan',
      'tanggalIso': '2026-10-10',
      'waktu': '10:00',
      'lokasi': 'Kecamatan Cisurupan',
      'catatan':
          'Inventarisasi produksi madu hutan dan kopi bawah tegakan milik KTH setempat.',
      'isCompleted': true,
    },
  ];
}