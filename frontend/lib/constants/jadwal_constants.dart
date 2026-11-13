// ============================================================================
// [FILE CONSTANTS - WARNA, TIMEZONE ASIA/JAKARTA & FORMAT TANGGAL JADWAL]
// Simpan file ini di: constants/jadwal_constants.dart
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

/// Date, Time & Asia/Jakarta (WIB / UTC+7) utilities for Jadwal & Reminder.
class JadwalDateUtils {
  JadwalDateUtils._();

  static const String timezoneName = 'Asia/Jakarta';
  static const Duration wibOffset = Duration(hours: 7);

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

  /// Mengambil waktu sekarang dalam zona waktu Asia/Jakarta (WIB / UTC+7).
  static DateTime nowWib() {
    final utcNow = DateTime.now().toUtc();
    final wibWall = utcNow.add(wibOffset);
    return DateTime(
      wibWall.year,
      wibWall.month,
      wibWall.day,
      wibWall.hour,
      wibWall.minute,
      wibWall.second,
      wibWall.millisecond,
    );
  }

  /// Konversi komponen waktu lokal Asia/Jakarta (WIB) menjadi epoch milliseconds UTC
  /// yang akurat untuk penjadwalan AlarmManager Android.
  static int wibToEpochMillis(
    int year,
    int month,
    int day,
    int hour,
    int minute, [
    int second = 0,
  ]) {
    final utcMoment =
        DateTime.utc(year, month, day, hour, minute, second).subtract(wibOffset);
    return utcMoment.millisecondsSinceEpoch;
  }

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

  /// Parses `YYYY-MM-DD` or ISO timestamp string into a local calendar [DateTime]
  /// without UTC day-shifting bugs.
  static DateTime parseIsoDate(String raw) {
    final clean = raw.trim();
    if (clean.isEmpty) {
      return nowWib();
    }

    // Ambil bagian YYYY-MM-DD terlebih dahulu agar tidak bergeser hari karena timezone UTC
    final datePart = clean.split('T').first.split(' ').first;
    final parts = datePart.split('-');
    if (parts.length == 3) {
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y != null && m != null && d != null) {
        return DateTime(y, m, d);
      }
    }

    final parsed = DateTime.tryParse(clean);
    if (parsed != null) {
      if (parsed.isUtc) {
        final wib = parsed.add(wibOffset);
        return DateTime(wib.year, wib.month, wib.day);
      }
      return DateTime(parsed.year, parsed.month, parsed.day);
    }

    return nowWib();
  }

  /// Menghitung jam munculnya reminder dalam format `HH:mm`
  /// Contoh: waktu jadwal `13:00` dengan reminder `5` menit -> `12:55`
  /// Contoh: waktu jadwal `13:00` dengan reminder `10` menit -> `12:50`
  static String calculateReminderTimeStr(String scheduleTimeHHmm, int reminderMinutes) {
    final parts = scheduleTimeHHmm.split(':');
    final hour = parts.isNotEmpty ? (int.tryParse(parts[0]) ?? 8) : 8;
    final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;

    final base = DateTime(2026, 1, 2, hour, minute);
    final rem = base.subtract(Duration(minutes: reminderMinutes));
    final h = rem.hour.toString().padLeft(2, '0');
    final m = rem.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Label interval reminder yang mudah dibaca pengguna
  static String formatReminderIntervalLabel(int minutes) {
    if (minutes == 60) return '1 Jam sebelumnya';
    if (minutes == 1440) return '1 Hari sebelumnya';
    if (minutes % 60 == 0 && minutes > 60) {
      return '${minutes ~/ 60} Jam sebelumnya';
    }
    return '$minutes Menit sebelumnya';
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
      'reminderMinutes': 30,
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
      'reminderMinutes': 10,
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
      'reminderMinutes': 15,
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
      'reminderMinutes': 30,
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
      'reminderMinutes': 15,
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
      'reminderMinutes': 10,
      'lokasi': 'Kecamatan Cisurupan',
      'catatan':
          'Inventarisasi produksi madu hutan dan kopi bawah tegakan milik KTH setempat.',
      'isCompleted': true,
    },
  ];
}