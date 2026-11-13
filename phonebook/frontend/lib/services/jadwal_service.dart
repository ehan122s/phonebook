import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/api_constants.dart';
import '../constants/jadwal_constants.dart';
import 'connectivity_service.dart';
import 'notification_service.dart';

class JadwalService {
  static const String storageKey = 'phonebook_jadwal_items_v1';
  static String get baseUrl => ApiConstants.baseUrl;

  /// Formats time string ensuring HH:mm format for both frontend and backend.
  /// Supports:
  /// - "13:00" -> "13:00"
  /// - "13:00:00" (MySQL/PostgreSQL TIME column) -> "13:00"
  /// - "13.00" or "13.00.00" -> "13:00"
  /// - "13:00 - 15:00" -> "13:00"
  /// - ISO 8601 datetime strings -> converted to Asia/Jakarta HH:mm
  static String formatTimeString(String raw, {String fallback = '08:00'}) {
    final clean = raw.trim();
    if (clean.isEmpty || clean.toLowerCase() == 'null') return fallback;

    // Jika berupa ISO datetime lengkap (misal "2026-11-13T13:00:00.000000Z")
    if (clean.contains('T')) {
      final parsed = DateTime.tryParse(clean);
      if (parsed != null) {
        final wib = parsed.isUtc
            ? parsed.add(JadwalDateUtils.wibOffset)
            : parsed;
        return '${wib.hour.toString().padLeft(2, '0')}:${wib.minute.toString().padLeft(2, '0')}';
      }
    }

    // Jika berupa rentang waktu seperti "13:00 - 15:00", ambil waktu mulai
    String first = clean.contains('-') ? clean.split('-').first.trim() : clean;
    // Hapus label WIB/WITA/WIT jika ada
    first = first.replaceAll(RegExp(r'\s*(WIB|WITA|WIT)\s*$', caseSensitive: false), '').trim();

    // Cek format HH:mm atau HH:mm:ss (dengan pemisah titik dua ':' atau titik '.')
    final normalizedSep = first.replaceAll('.', ':');
    final regex = RegExp(r'^([0-1]?[0-9]|2[0-3]):([0-5][0-9])(?::([0-5][0-9]))?$');
    final match = regex.firstMatch(normalizedSep);
    if (match != null) {
      final h = match.group(1)!.padLeft(2, '0');
      final m = match.group(2)!.padLeft(2, '0');
      return '$h:$m';
    }

    return fallback;
  }

  /// Mengekstrak interval reminder (dalam menit) secara akurat dari data jadwal
  /// tanpa menimpa pilihan pengguna dengan nilai default 30.
  static int extractReminderMinutes(
    Map<String, dynamic> raw, {
    required String tanggalIso,
    required String waktuHHmm,
    int? fallbackMinutes,
  }) {
    // 1. Cek langsung dari field reminderMinutes / reminder_minutes
    final directVal = raw['reminderMinutes'] ?? raw['reminder_minutes'];
    if (directVal != null) {
      final parsed = int.tryParse(directVal.toString());
      if (parsed != null && parsed > 0) {
        return parsed;
      }
    }

    // 2. Cek apakah ada selisih yang valid antara jadwal (date + start_time) dan reminder_at dari API
    final rawReminderAt = raw['reminder_at'] ?? raw['reminderAt'];
    if (rawReminderAt != null && rawReminderAt.toString().isNotEmpty) {
      final parsedRem = DateTime.tryParse(rawReminderAt.toString());
      if (parsedRem != null) {
        final remWib = parsedRem.isUtc
            ? parsedRem.add(JadwalDateUtils.wibOffset)
            : parsedRem;
        final schedDate = JadwalDateUtils.parseIsoDate(tanggalIso);
        final timeParts = waktuHHmm.split(':');
        final h = timeParts.isNotEmpty ? (int.tryParse(timeParts[0]) ?? 8) : 8;
        final m = timeParts.length > 1 ? (int.tryParse(timeParts[1]) ?? 0) : 0;
        final schedDateTime = DateTime(
          schedDate.year,
          schedDate.month,
          schedDate.day,
          h,
          m,
        );
        final diff = schedDateTime.difference(
          DateTime(
            remWib.year,
            remWib.month,
            remWib.day,
            remWib.hour,
            remWib.minute,
          ),
        ).inMinutes;

        // Pastikan bukan hasil bug lama startOfDay() kecuali memang 1440 menit
        if (diff > 0 && diff <= 10080 && !(remWib.hour == 0 && remWib.minute == 0 && diff != 1440 && h != 0)) {
          return diff;
        }
      }
    }

    return fallbackMinutes ?? 30;
  }

  /// Normalizes schedule item map so all pages (jadwal, history reminder, kategori, admin_folder)
  /// read accurate time & reminder intervals without overwriting user input.
  static Map<String, dynamic> normalizeItem(
    Map<String, dynamic> raw, {
    Map<String, dynamic>? existingLocal,
  }) {
    final id = raw['id'] ??
        existingLocal?['id'] ??
        'jadwal_${JadwalDateUtils.nowWib().millisecondsSinceEpoch}';
    final judul = (raw['judul'] ??
            raw['title'] ??
            existingLocal?['judul'] ??
            'Kegiatan Lapangan')
        .toString();
    final kategori = (raw['kategori'] ??
            raw['category'] ??
            existingLocal?['kategori'] ??
            'Penyuluhan')
        .toString();

    String tanggalIso = '';
    if (raw['tanggalIso'] != null && raw['tanggalIso'].toString().isNotEmpty) {
      final d = JadwalDateUtils.parseIsoDate(raw['tanggalIso'].toString());
      tanggalIso = JadwalDateUtils.toIsoDate(d);
    } else if (raw['date'] is String && raw['date'].toString().isNotEmpty) {
      final d = JadwalDateUtils.parseIsoDate(raw['date'].toString());
      tanggalIso = JadwalDateUtils.toIsoDate(d);
    } else if (raw['date'] is DateTime) {
      tanggalIso = JadwalDateUtils.toIsoDate(raw['date'] as DateTime);
    } else if (existingLocal?['tanggalIso'] != null) {
      tanggalIso = existingLocal!['tanggalIso'].toString();
    } else {
      tanggalIso = JadwalDateUtils.toIsoDate(JadwalDateUtils.nowWib());
    }

    // Ambil waktu dari raw, gunakan existingLocal sebagai fallback sebelum '08:00'
    final fallbackTime =
        (existingLocal?['waktu'] ?? existingLocal?['time'] ?? '08:00')
            .toString();
    final rawTimeCandidate =
        raw['waktu'] ?? raw['start_time'] ?? raw['time'] ?? fallbackTime;
    final waktu = formatTimeString(
      rawTimeCandidate.toString(),
      fallback: formatTimeString(fallbackTime),
    );

    final fallbackReminder = existingLocal != null
        ? int.tryParse((existingLocal['reminderMinutes'] ?? '').toString())
        : null;
    final reminderMinutes = extractReminderMinutes(
      raw,
      tanggalIso: tanggalIso,
      waktuHHmm: waktu,
      fallbackMinutes: fallbackReminder,
    );

    final reminderTime =
        JadwalDateUtils.calculateReminderTimeStr(waktu, reminderMinutes);

    final lokasi = (raw['lokasi'] ??
            raw['location'] ??
            existingLocal?['lokasi'] ??
            'Lokasi belum ditentukan')
        .toString();
    final catatan = (raw['catatan'] ??
            raw['description'] ??
            existingLocal?['catatan'] ??
            '')
        .toString();

    final isCompleted = raw['isCompleted'] == true ||
        raw['is_completed'] == true ||
        (raw['isCompleted'] == null &&
            raw['is_completed'] == null &&
            existingLocal?['isCompleted'] == true);

    final reminderEnabled = raw['reminderEnabled'] ??
        raw['reminder_enabled'] ??
        existingLocal?['reminderEnabled'] ??
        true;

    final enableWaNotification = raw['enableWaNotification'] ??
        existingLocal?['enableWaNotification'] ??
        true;

    final waPhone =
        (raw['waPhone'] ?? existingLocal?['waPhone'] ?? '089602976525')
            .toString();

    final reminderTriggered = raw['reminderTriggered'] == true ||
        existingLocal?['reminderTriggered'] == true;

    final reminderTriggeredAt =
        raw['reminderTriggeredAt'] ?? existingLocal?['reminderTriggeredAt'];

    final createdAt = (raw['createdAt'] ??
            raw['created_at'] ??
            existingLocal?['createdAt'] ??
            JadwalDateUtils.nowWib().toIso8601String())
        .toString();

    return {
      'id': id,
      'judul': judul,
      'title': judul,
      'kategori': kategori,
      'category': kategori,
      'tanggalIso': tanggalIso,
      'date': JadwalDateUtils.parseIsoDate(tanggalIso),
      'waktu': waktu,
      'time': waktu,
      'start_time': waktu,
      'reminderMinutes': reminderMinutes,
      'reminder_minutes': reminderMinutes,
      'reminderTime': reminderTime,
      'reminderEnabled': reminderEnabled == true,
      'enableWaNotification': enableWaNotification == true,
      'waPhone': waPhone,
      'reminderTriggered': reminderTriggered,
      'reminderTriggeredAt': reminderTriggeredAt,
      'lokasi': lokasi,
      'location': lokasi,
      'catatan': catatan,
      'description': catatan,
      'isCompleted': isCompleted,
      'createdAt': createdAt,
    };
  }

  /// Load all schedules from local storage and optionally sync with backend API
  static Future<List<Map<String, dynamic>>> loadSchedules() async {
    final prefs = await SharedPreferences.getInstance();
    final rawLocal = prefs.getString(storageKey);

    List<Map<String, dynamic>> items = [];

    if (rawLocal != null && rawLocal.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(rawLocal);
        items = decoded
            .map((e) => normalizeItem(Map<String, dynamic>.from(e)))
            .toList();
      } catch (_) {}
    }

    // Try fetching from backend if token exists and online
    final token = prefs.getString('token');
    final isOnline = await ConnectivityService.instance.isOnline();
    final isValidServerToken = token != null &&
        token.isNotEmpty &&
        !token.startsWith('offline_') &&
        !token.startsWith('google_session_');

    if (isValidServerToken && isOnline) {
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/api/schedules'),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final body = jsonDecode(response.body);
          if (body['data'] is List) {
            final List<dynamic> apiList = body['data'];
            for (final row in apiList) {
              final rowMap = Map<String, dynamic>.from(row);
              final rowId = (rowMap['id'] ?? '').toString();
              final existingIndex = items.indexWhere(
                (e) => e['id'].toString() == rowId,
              );
              final existingLocal =
                  existingIndex >= 0 ? items[existingIndex] : null;

              final norm = normalizeItem(
                rowMap,
                existingLocal: existingLocal,
              );

              if (existingIndex >= 0) {
                items[existingIndex] = norm;
              } else {
                items.add(norm);
              }
            }
          }
        }
      } catch (_) {
        // Fall back to local items
      }
    }

    if (items.isEmpty) {
      items = buildDefaultJadwalList().map((e) => normalizeItem(e)).toList();
      await saveLocalSchedules(items);
    } else {
      await saveLocalSchedules(items);
    }

    // Sinkronkan penjadwalan reminder otomatis untuk seluruh jadwal
    await NotificationService.instance.rescheduleAllFromList(items);

    return items;
  }

  /// Save list to local SharedPreferences
  static Future<void> saveLocalSchedules(
    List<Map<String, dynamic>> items,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final serializable = items.map((e) {
      final copy = Map<String, dynamic>.from(e);
      // Remove raw DateTime object before json encoding
      copy.remove('date');
      return copy;
    }).toList();
    await prefs.setString(storageKey, jsonEncode(serializable));
  }

  /// Add a new schedule locally and to the server
  static Future<Map<String, dynamic>> addSchedule(
    Map<String, dynamic> raw,
  ) async {
    var item = normalizeItem(raw);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final isOnline = await ConnectivityService.instance.isOnline();
    final isValidServerToken = token != null &&
        token.isNotEmpty &&
        !token.startsWith('offline_') &&
        !token.startsWith('google_session_');

    if (isValidServerToken && isOnline) {
      try {
        final payload = {
          'title': item['judul'],
          'category': item['kategori'],
          'date': item['tanggalIso'],
          'start_time': item['waktu'],
          'location': item['lokasi'],
          'description': item['catatan'],
          'reminder_enabled': item['reminderEnabled'] ?? true,
          'reminder_minutes': item['reminderMinutes'],
        };

        final response = await http.post(
          Uri.parse('$baseUrl/api/schedules'),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200 || response.statusCode == 201) {
          final body = jsonDecode(response.body);
          if (body['data']?['id'] != null) {
            item['id'] = body['data']['id'];
          }
        }
      } catch (_) {}
    }

    // Pastikan item tetap mempertahankan waktu dan reminderMinutes pilihan pengguna
    item = normalizeItem(item);

    final prefsNow = await SharedPreferences.getInstance();
    final rawLocal = prefsNow.getString(storageKey);
    List<Map<String, dynamic>> current = [];
    if (rawLocal != null && rawLocal.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(rawLocal);
        current = decoded
            .map((e) => normalizeItem(Map<String, dynamic>.from(e)))
            .toList();
      } catch (_) {}
    } else {
      current = await loadSchedules();
    }

    current.removeWhere((e) => e['id'].toString() == item['id'].toString());
    current.insert(0, item);
    await saveLocalSchedules(current);

    // 1. Catat notifikasi pembuatan jadwal baru
    await NotificationService.instance.addScheduleCreatedNotification(item);
    // 2. Jadwalkan reminder otomatis sesuai waktu jadwal & interval pilihan pengguna
    await NotificationService.instance.scheduleReminderForItem(item);

    return item;
  }

  /// Update an existing schedule and reschedule its reminder
  static Future<Map<String, dynamic>> updateSchedule(
    dynamic id,
    Map<String, dynamic> updatedRaw,
  ) async {
    final items = await loadSchedules();
    final index = items.indexWhere((e) => e['id'].toString() == id.toString());
    final existingLocal = index >= 0 ? items[index] : null;

    // Batalkan reminder lama terlebih dahulu
    await NotificationService.instance.cancelReminderForScheduleId(id);

    var item = normalizeItem(
      {
        ...updatedRaw,
        'id': id,
        'reminderTriggered': false,
        'reminderTriggeredAt': null,
      },
      existingLocal: existingLocal,
    );

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final isOnline = await ConnectivityService.instance.isOnline();
    final isValidServerToken = token != null &&
        token.isNotEmpty &&
        !token.startsWith('offline_') &&
        !token.startsWith('google_session_');

    if (isValidServerToken && isOnline && int.tryParse(id.toString()) != null) {
      try {
        final payload = {
          'title': item['judul'],
          'category': item['kategori'],
          'date': item['tanggalIso'],
          'start_time': item['waktu'],
          'location': item['lokasi'],
          'description': item['catatan'],
          'reminder_enabled': item['reminderEnabled'] ?? true,
          'reminder_minutes': item['reminderMinutes'],
          'is_completed': item['isCompleted'] ?? false,
        };

        await http.put(
          Uri.parse('$baseUrl/api/schedules/$id'),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 10));
      } catch (_) {}
    }

    if (index >= 0) {
      items[index] = item;
    } else {
      items.insert(0, item);
    }

    await saveLocalSchedules(items);

    // Jadwalkan reminder baru
    await NotificationService.instance.scheduleReminderForItem(item);

    return item;
  }

  /// Toggle completed status and update reminder scheduling
  static Future<void> toggleComplete(dynamic id) async {
    final items = await loadSchedules();
    final index = items.indexWhere((e) => e['id'].toString() == id.toString());
    if (index >= 0) {
      final newStatus = !(items[index]['isCompleted'] == true);
      items[index]['isCompleted'] = newStatus;
      await saveLocalSchedules(items);

      if (newStatus) {
        await NotificationService.instance.cancelReminderForScheduleId(
          id,
          removeTriggeredHistory: false,
        );
      } else {
        await NotificationService.instance.scheduleReminderForItem(items[index]);
      }
    }
  }

  /// Delete schedule and cancel its scheduled reminder
  static Future<void> deleteSchedule(dynamic id) async {
    // Batalkan reminder yang terkait dengan jadwal ini
    await NotificationService.instance.cancelReminderForScheduleId(id);

    final items = await loadSchedules();
    items.removeWhere((e) => e['id'].toString() == id.toString());
    await saveLocalSchedules(items);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final isOnline = await ConnectivityService.instance.isOnline();

    final isValidServerToken = token != null &&
        token.isNotEmpty &&
        !token.startsWith('offline_') &&
        !token.startsWith('google_session_');

    if (isValidServerToken && isOnline && int.tryParse(id.toString()) != null) {
      try {
        await http.delete(
          Uri.parse('$baseUrl/api/schedules/$id'),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 8));
      } catch (_) {}
    }
  }
}
