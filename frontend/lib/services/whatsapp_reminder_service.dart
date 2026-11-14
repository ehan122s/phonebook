import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/api_constants.dart';
import '../constants/jadwal_constants.dart';
import 'connectivity_service.dart';

class WhatsappReminderService {
  WhatsappReminderService._internal();
  static final WhatsappReminderService instance =
      WhatsappReminderService._internal();

  /// Membersihkan & menormalkan nomor telepon ke format internasional (misal: 628123456789)
  static String normalizePhoneNumber(String raw) {
    String clean = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.startsWith('0')) {
      clean = '62${clean.substring(1)}';
    } else if (clean.startsWith('8')) {
      clean = '62$clean';
    }
    return clean;
  }

  /// Format teks pengingat resmi CDK Wilayah V Garut
  static String formatScheduleMessage(Map<String, dynamic> schedule) {
    final title = (schedule['judul'] ?? schedule['title'] ?? 'Kegiatan Dinas')
        .toString();
    final category =
        (schedule['kategori'] ?? schedule['category'] ?? 'Kegiatan Kehutanan')
            .toString();
    final dateStr = (schedule['tanggalIso'] ?? schedule['date'] ?? '')
        .toString();
    final timeStr =
        (schedule['waktu'] ?? schedule['start_time'] ?? schedule['time'] ?? '08:00')
            .toString();
    final location =
        (schedule['lokasi'] ?? schedule['location'] ?? 'Wilayah Kerja')
            .toString();
    final notes =
        (schedule['catatan'] ?? schedule['description'] ?? '').toString();
    final reminderMin =
        (schedule['reminderMinutes'] ?? schedule['reminder_minutes'] ?? 30)
            .toString();

    String formattedDate = dateStr;
    try {
      final dt = JadwalDateUtils.parseIsoDate(dateStr);
      formattedDate = JadwalDateUtils.formatHariTanggal(dt);
    } catch (_) {}

    final buffer = StringBuffer();
    buffer.writeln('*PENGINGAT JADWAL KEGIATAN CDK WILAYAH V GARUT*');
    buffer.writeln('--------------------------------------------------');
    buffer.writeln('Halo Rekan Kehutanan, ini adalah pengingat untuk kegiatan Anda:');
    buffer.writeln();
    buffer.writeln('📌 *Kegiatan:* $title');
    buffer.writeln('🏷️ *Kategori:* $category');
    buffer.writeln('📅 *Tanggal :* $formattedDate');
    buffer.writeln('⏰ *Waktu   :* $timeStr WIB (Pengingat $reminderMin menit sebelumnya)');
    buffer.writeln('📍 *Lokasi  :* $location');
    if (notes.trim().isNotEmpty) {
      buffer.writeln('📝 *Catatan :* $notes');
    }
    buffer.writeln();
    buffer.writeln('Mohon persiapkan perlengkapan dan dokumen terkait.');
    buffer.write('_Aplikasi Phonebook CDK Wilayah V - Dinas Kehutanan Jabar_');

    return buffer.toString();
  }

  /// Format teks konfirmasi pembuatan jadwal baru
  static String formatScheduleCreatedMessage(Map<String, dynamic> schedule) {
    final title = (schedule['judul'] ?? schedule['title'] ?? 'Kegiatan Dinas').toString();
    final category = (schedule['kategori'] ?? schedule['category'] ?? 'Kegiatan Kehutanan').toString();
    final dateStr = (schedule['tanggalIso'] ?? schedule['date'] ?? '').toString();
    final timeStr = (schedule['waktu'] ?? schedule['start_time'] ?? schedule['time'] ?? '08:00').toString();
    final location = (schedule['lokasi'] ?? schedule['location'] ?? 'Wilayah Kerja').toString();
    final notes = (schedule['catatan'] ?? schedule['description'] ?? '').toString();
    final reminderMin = (schedule['reminderMinutes'] ?? schedule['reminder_minutes'] ?? 30).toString();

    String formattedDate = dateStr;
    try {
      final dt = JadwalDateUtils.parseIsoDate(dateStr);
      formattedDate = JadwalDateUtils.formatHariTanggal(dt);
    } catch (_) {}

    final buffer = StringBuffer();
    buffer.writeln('*JADWAL KEGIATAN BERHASIL DITAMBAHKAN*');
    buffer.writeln('--------------------------------------------------');
    buffer.writeln('Halo Rekan Kehutanan, jadwal kegiatan baru Anda telah tersimpan:');
    buffer.writeln();
    buffer.writeln('📌 *Kegiatan:* $title');
    buffer.writeln('🏷️ *Kategori:* $category');
    buffer.writeln('📅 *Tanggal :* $formattedDate');
    buffer.writeln('⏰ *Waktu   :* $timeStr WIB (Pengingat $reminderMin menit sebelumnya)');
    buffer.writeln('📍 *Lokasi  :* $location');
    if (notes.trim().isNotEmpty) {
      buffer.writeln('📝 *Catatan :* $notes');
    }
    buffer.writeln();
    buffer.writeln('Sistem Phonebook akan otomatis mengirimkan pengingat WhatsApp ini sebelum jadwal dimulai.');
    buffer.write('_Aplikasi Phonebook CDK Wilayah V - Dinas Kehutanan Jabar_');

    return buffer.toString();
  }

  /// Mengambil nomor WhatsApp prioritas:
  /// 1. Nomor eksplisit yang dipassing
  /// 2. Nomor yang tersimpan di jadwal (`waPhone` / `wa_phone`)
  /// 3. Nomor profil user dari SharedPreferences
  /// 4. Fallback ke nomor WhatsApp pengguna bot dari sistem
  static Future<String> resolveTargetPhone({
    String? explicitPhone,
    Map<String, dynamic>? schedule,
  }) async {
    if (explicitPhone != null && explicitPhone.trim().isNotEmpty) {
      final norm = normalizePhoneNumber(explicitPhone);
      if (norm.isNotEmpty) return norm;
    }

    final schedulePhone =
        schedule?['waPhone'] ?? schedule?['wa_phone'];
    if (schedulePhone != null && schedulePhone.toString().trim().isNotEmpty) {
      final norm = normalizePhoneNumber(schedulePhone.toString());
      if (norm.isNotEmpty) return norm;
    }

    final prefs = await SharedPreferences.getInstance();
    final userPhone = prefs.getString('profil_whatsapp') ??
        prefs.getString('whatsapp_number') ??
        prefs.getString('telepon') ??
        prefs.getString('phone') ??
        prefs.getString('user_phone') ??
        '';

    if (userPhone.trim().isNotEmpty) {
      final norm = normalizePhoneNumber(userPhone);
      if (norm.isNotEmpty) return norm;
    }

    try {
      final userRaw = prefs.getString('user');
      if (userRaw != null && userRaw.isNotEmpty) {
        final decoded = jsonDecode(userRaw);
        if (decoded is Map) {
          final uPhone = decoded['whatsapp_number'] ?? decoded['phone'] ?? decoded['telepon'];
          if (uPhone != null && uPhone.toString().trim().isNotEmpty) {
            final norm = normalizePhoneNumber(uPhone.toString());
            if (norm.isNotEmpty) return norm;
          }
        }
      }
    } catch (_) {}

    // Fallback nomor WhatsApp dari akun perangkat Fonnte terdaftar
    return '6289602692362';
  }

  /// Langsung membuka aplikasi WhatsApp dengan pesan dan penerima yang ditentukan.
  /// Mencoba skema 'whatsapp://send' terlebih dahulu, jika gagal memakai 'https://wa.me'.
  static Future<bool> launchWhatsAppDirect({
    required String phone,
    required String message,
  }) async {
    final cleanPhone = normalizePhoneNumber(phone);
    if (cleanPhone.isEmpty) return false;

    final encodedText = Uri.encodeComponent(message);

    // 1. Coba skema native WhatsApp
    final nativeUri = Uri.parse('whatsapp://send?phone=$cleanPhone&text=$encodedText');
    try {
      if (await canLaunchUrl(nativeUri)) {
        final launched = await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
        if (launched) return true;
      }
    } catch (_) {}

    // 2. Fallback ke URL universal wa.me
    final webUri = Uri.parse('https://wa.me/$cleanPhone?text=$encodedText');
    try {
      if (await canLaunchUrl(webUri)) {
        return await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}

    // 3. Fallback terakhir tanpa canLaunchUrl check
    try {
      return await launchUrl(webUri, mode: LaunchMode.externalNonBrowserApplication);
    } catch (_) {
      return false;
    }
  }

  /// Menghitung Unix epoch timestamp (dalam detik) tepat pada saat pengingat harus berbunyi/terkirim
  /// (yaitu: tanggal jadwal + waktu mulai - reminderMinutes) dalam zona waktu Asia/Jakarta (WIB)
  static int calculateReminderUnixTimestamp(Map<String, dynamic> schedule) {
    try {
      final tanggalIso = (schedule['tanggalIso'] ?? schedule['date'] ?? '').toString();
      final date = JadwalDateUtils.parseIsoDate(tanggalIso);
      final timeStr = (schedule['waktu'] ?? schedule['start_time'] ?? schedule['time'] ?? '08:00').toString();
      final parts = timeStr.split(':');
      final hour = parts.isNotEmpty ? (int.tryParse(parts[0]) ?? 8) : 8;
      final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
      final reminderMinutes =
          int.tryParse((schedule['reminderMinutes'] ?? schedule['reminder_minutes'] ?? 30).toString()) ?? 30;

      final schedWib = DateTime(date.year, date.month, date.day, hour, minute);
      final reminderWib = schedWib.subtract(Duration(minutes: reminderMinutes));

      final epochMillis = JadwalDateUtils.wibToEpochMillis(
        reminderWib.year,
        reminderWib.month,
        reminderWib.day,
        reminderWib.hour,
        reminderWib.minute,
        0,
      );

      return epochMillis ~/ 1000;
    } catch (_) {
      return 0;
    }
  }

  /// Mengirim pesan pengingat langsung ke nomor WhatsApp penerima
  /// menggunakan Fonnte API Gateway resmi dengan token dari sistem.
  /// Jika [scheduleUnixTimestamp] diisi untuk waktu mendatang, Fonnte akan menjadwalkan
  /// pesan dan otomatis mengirimkannya pada detik tersebut tanpa perlu aplikasi dibuka.
  static Future<Map<String, dynamic>> sendViaFonnteGateway({
    required String phone,
    required String message,
    int? scheduleUnixTimestamp,
  }) async {
    final cleanPhone = normalizePhoneNumber(phone);
    if (cleanPhone.isEmpty) {
      return {'success': false, 'reason': 'Nomor WhatsApp tidak valid'};
    }

    try {
      final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final body = <String, String>{
        'target': cleanPhone,
        'message': message,
        'countryCode': '62',
      };

      // Jika waktu reminder berada di masa depan (> 20 detik dari sekarang),
      // jadwalkan di server Fonnte agar otomatis terkirim tanpa campur tangan user
      if (scheduleUnixTimestamp != null && scheduleUnixTimestamp > (nowSec + 20)) {
        body['schedule'] = scheduleUnixTimestamp.toString();
      }

      final response = await http.post(
        Uri.parse('https://api.fonnte.com/send'),
        headers: {
          'Authorization': ApiConstants.fonnteToken,
        },
        body: body,
      ).timeout(const Duration(seconds: 10));

      final json = jsonDecode(response.body);
      final isSuccess = response.statusCode == 200 && (json['status'] == true);

      if (isSuccess) {
        return {
          'success': true,
          'gateway': 'fonnte',
          'detail': json['detail'] ?? 'Pesan berhasil masuk antrean Fonnte',
          'target': cleanPhone,
          'response': json,
        };
      } else {
        final reason = json['reason'] ?? json['message'] ?? 'Fonnte device belum siap';
        return {
          'success': false,
          'gateway': 'fonnte',
          'reason': reason,
          'target': cleanPhone,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'gateway': 'fonnte',
        'reason': e.toString(),
        'target': cleanPhone,
      };
    }
  }

  /// Menjadwalkan pengingat otomatis di server Fonnte secara langsung saat jadwal dibuat/diedit.
  /// Pesan akan otomatis terkirim tepat waktu (misal 5 menit sebelum jam 10) tanpa harus pencet tombol apa pun!
  Future<Map<String, dynamic>> scheduleAutomaticReminder(
    Map<String, dynamic> schedule, {
    String? targetPhone,
  }) async {
    final phone = await resolveTargetPhone(
      explicitPhone: targetPhone,
      schedule: schedule,
    );
    if (phone.isEmpty) return {'success': false, 'reason': 'Nomor WhatsApp kosong'};

    final message = formatScheduleMessage(schedule);
    final reminderTs = calculateReminderUnixTimestamp(schedule);

    return await sendViaFonnteGateway(
      phone: phone,
      message: message,
      scheduleUnixTimestamp: reminderTs,
    );
  }

  /// Mengirim notifikasi konfirmasi pembuatan jadwal baru otomatis ke WhatsApp pengguna
  Future<Map<String, dynamic>> sendScheduleCreatedNotification(
    Map<String, dynamic> schedule, {
    String? targetPhone,
  }) async {
    final phone = await resolveTargetPhone(
      explicitPhone: targetPhone,
      schedule: schedule,
    );
    if (phone.isEmpty) return {'success': false, 'reason': 'Nomor WhatsApp kosong'};

    final message = formatScheduleCreatedMessage(schedule);
    return await sendViaFonnteGateway(phone: phone, message: message);
  }

  /// Mengirim pengingat WhatsApp secara cerdas:
  /// 1. Menggunakan Fonnte API Gateway otomatis (langsung terkirim ke WhatsApp pengguna tanpa perlu ketik/buka WhatsApp)
  /// 2. Jika Fonnte offline / gagal: fallback ke endpoint server backend
  /// 3. Jika offline total: fallback ke direct launch WhatsApp di perangkat
  Future<Map<String, dynamic>> sendOrLaunchReminder(
    Map<String, dynamic> schedule, {
    String? targetPhone,
    BuildContext? context,
    bool showFeedback = true,
  }) async {
    final phone = await resolveTargetPhone(
      explicitPhone: targetPhone,
      schedule: schedule,
    );

    if (phone.isEmpty) {
      if (showFeedback && context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nomor WhatsApp belum ditentukan. Silakan periksa pengaturan jadwal.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return {
        'success': false,
        'reason': 'Nomor WhatsApp kosong',
      };
    }

    final message = formatScheduleMessage(schedule);
    final scheduleId = schedule['id'];
    final isNumericId = int.tryParse(scheduleId.toString()) != null;

    final isOnline = await ConnectivityService.instance.isOnline();
    bool fonnteDelivered = false;

    // 1. Jalur Utama: Otomatis kirim via Fonnte Gateway resmi
    if (isOnline) {
      final fonnteResult = await sendViaFonnteGateway(
        phone: phone,
        message: message,
      );

      if (fonnteResult['success'] == true) {
        fonnteDelivered = true;
      }
    }

    // 2. Jika via Fonnte Gateway langsung berhasil terkirim
    if (fonnteDelivered) {
      if (showFeedback && context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pengingat WhatsApp otomatis terkirim ke +$phone via Fonnte!',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF245C3A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return {
        'success': true,
        'gateway': 'fonnte',
        'target': phone,
      };
    }

    // 3. Jalur Kedua: Coba melalui endpoint server backend
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final isValidServerToken = token != null &&
        token.isNotEmpty &&
        !token.startsWith('offline_') &&
        !token.startsWith('google_session_');

    bool serverDelivered = false;
    if (isOnline && isValidServerToken && isNumericId) {
      try {
        final url = Uri.parse('${ApiConstants.baseUrl}/api/schedules/$scheduleId/send-whatsapp');
        final response = await http.post(
          url,
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'target_phone': phone,
          }),
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final resBody = jsonDecode(response.body);
          if (resBody['server_delivered'] == true) {
            serverDelivered = true;
          }
        }
      } catch (_) {}
    }

    if (serverDelivered) {
      if (showFeedback && context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pengingat WhatsApp berhasil dikirim ke +$phone melalui server!',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF245C3A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return {
        'success': true,
        'gateway': 'server',
        'target': phone,
      };
    }

    // 4. Fallback Terakhir: Buka aplikasi WhatsApp langsung di perangkat HANYA jika dipicu secara interaktif (showFeedback == true)
    bool launched = false;
    if (showFeedback) {
      launched = await launchWhatsAppDirect(
        phone: phone,
        message: message,
      );

      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  launched ? Icons.send_rounded : Icons.info_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    launched
                        ? 'Membuka WhatsApp untuk mengirim pengingat ke +$phone...'
                        : 'Tidak dapat membuka WhatsApp. Pastikan aplikasi WhatsApp terpasang.',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: launched ? const Color(0xFF245C3A) : Colors.orange.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    return {
      'success': launched,
      'gateway': 'direct_whatsapp',
      'target': phone,
    };
  }
}
