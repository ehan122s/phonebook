import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/api_constants.dart';
import '../constants/jadwal_constants.dart';
import 'connectivity_service.dart';
import 'notification_service.dart';

class JadwalService {
  static const String storageKey = 'phonebook_jadwal_items_v1';
  static const String userPrefsKey = 'phonebook_jadwal_user_prefs_v3';

  /// Daftar interval reminder yang valid (dalam menit)
  static const Set<int> validReminderIntervals = {5, 10, 15, 30, 60, 1440};

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

    if (clean.contains('T')) {
      final parsed = DateTime.tryParse(clean);
      if (parsed != null) {
        final wib = parsed.isUtc
            ? parsed.add(JadwalDateUtils.wibOffset)
            : parsed;
        return '${wib.hour.toString().padLeft(2, '0')}:${wib.minute.toString().padLeft(2, '0')}';
      }
    }

    String first = clean.contains('-') ? clean.split('-').first.trim() : clean;
    first = first
        .replaceAll(RegExp(r'\s*(WIB|WITA|WIT)\s*$', caseSensitive: false), '')
        .trim();

    final normalizedSep = first.replaceAll('.', ':');
    final regex =
        RegExp(r'^([0-1]?[0-9]|2[0-3]):([0-5][0-9])(?::([0-5][0-9]))?$');
    final match = regex.firstMatch(normalizedSep);
    if (match != null) {
      final h = match.group(1)!.padLeft(2, '0');
      final m = match.group(2)!.padLeft(2, '0');
      return '$h:$m';
    }

    return fallback;
  }

  /// Membuat kunci pencarian berdasarkan judul + tanggal agar pilihan waktu & reminder
  /// pengguna tidak pernah hilang meskipun ID lokal berganti menjadi ID server.
  static String _buildTitleDateKey(String judul, String tanggalIso) {
    return '${judul.trim().toLowerCase()}|${tanggalIso.trim()}';
  }

  /// Membaca peta preferensi jadwal & reminder yang pernah diatur pengguna
  static Future<Map<String, Map<String, dynamic>>> _loadUserPrefsMap() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(userPrefsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final Map<String, dynamic> decoded = jsonDecode(raw);
      return decoded.map(
        (key, value) =>
            MapEntry(key, Map<String, dynamic>.from(value as Map)),
      );
    } catch (_) {
      return {};
    }
  }

  /// Menyimpan pilihan waktu & reminderMinutes pengguna ke penyimpanan persisten khusus
  static Future<void> _saveUserPreferenceForItem(
    Map<String, dynamic> item,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final map = await _loadUserPrefsMap();

    final idKey = 'id_${item['id']}';
    final titleDateKey = _buildTitleDateKey(
      (item['judul'] ?? item['title'] ?? '').toString(),
      (item['tanggalIso'] ?? '').toString(),
    );

    final entry = <String, dynamic>{
      'waktu': item['waktu'],
      'reminderMinutes': item['reminderMinutes'],
      'reminderTime': item['reminderTime'],
      'kategori': item['kategori'],
      'enableWaNotification': item['enableWaNotification'] ?? true,
      'waPhone': item['waPhone'] ?? '089602976525',
      'isCompleted': item['isCompleted'] ?? false,
      'reminderTriggered': item['reminderTriggered'] ?? false,
      'reminderTriggeredAt': item['reminderTriggeredAt'],
    };

    map[idKey] = entry;
    map[titleDateKey] = entry;

    await prefs.setString(userPrefsKey, jsonEncode(map));
  }

  /// Mengekstrak interval reminder (dalam menit) secara akurat:
  /// - Mengabaikan nilai `reminder_at` `00:00:00Z` (`07:00 WIB`) dari server Vercel lama
  ///   yang sebelumnya menyebabkan bug `240 / 195 / 360 menit sebelum (07:00 WIB)`.
  /// - Memvalidasi agar hanya nilai interval reminder yang valid yang digunakan.
  static int extractReminderMinutes(
    Map<String, dynamic> raw, {
    required String waktuHHmm,
    Map<String, dynamic>? savedPref,
    Map<String, dynamic>? existingLocal,
  }) {
    // 1. Cek langsung dari raw['reminderMinutes'] / raw['reminder_minutes'] jika valid
    final directVal = raw['reminderMinutes'] ?? raw['reminder_minutes'];
    if (directVal != null) {
      final parsed = int.tryParse(directVal.toString());
      if (parsed != null && validReminderIntervals.contains(parsed)) {
        return parsed;
      }
    }

    // 2. Cek dari preferensi pengguna yang tersimpan khusus untuk jadwal ini
    if (savedPref != null && savedPref['reminderMinutes'] != null) {
      final prefMin =
          int.tryParse(savedPref['reminderMinutes'].toString());
      if (prefMin != null && validReminderIntervals.contains(prefMin)) {
        return prefMin;
      }
    }

    // 3. Cek dari existingLocal jika nilainya valid (bukan 240/195/360 hasil bug 07:00 WIB)
    if (existingLocal != null && existingLocal['reminderMinutes'] != null) {
      final localMin =
          int.tryParse(existingLocal['reminderMinutes'].toString());
      if (localMin != null && validReminderIntervals.contains(localMin)) {
        return localMin;
      }
    }

    // 4. Cek selisih antara start_time (waktuHHmm) dan end_time (tempat kita menyimpan jam reminder di server Vercel)
    final rawEndTime = raw['end_time'] ?? raw['endTime'];
    if (rawEndTime != null &&
        rawEndTime.toString().trim().isNotEmpty &&
        rawEndTime.toString().toLowerCase() != 'null') {
      final endHHmm = formatTimeString(rawEndTime.toString(), fallback: '');
      if (endHHmm.isNotEmpty) {
        final startParts = waktuHHmm.split(':');
        final endParts = endHHmm.split(':');
        if (startParts.length >= 2 && endParts.length >= 2) {
          final sh = int.tryParse(startParts[0]) ?? 8;
          final sm = int.tryParse(startParts[1]) ?? 0;
          final eh = int.tryParse(endParts[0]) ?? 8;
          final em = int.tryParse(endParts[1]) ?? 0;

          final startTotal = sh * 60 + sm;
          final endTotal = eh * 60 + em;
          int diff = startTotal - endTotal;
          if (diff < 0) diff += 1440;
          if (diff == 0) diff = 1440;
          if (validReminderIntervals.contains(diff)) {
            return diff;
          }
        }
      }
    }

    // Default fallback yang bersih (10 menit sebelum jadwal)
    return 10;
  }

  /// Normalizes schedule item map so all pages (jadwal, history reminder, kategori, admin_folder)
  /// read accurate time & reminder intervals without overwriting user input.
  static Map<String, dynamic> normalizeItem(
    Map<String, dynamic> raw, {
    Map<String, dynamic>? existingLocal,
    Map<String, dynamic>? savedPref,
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
            savedPref?['kategori'] ??
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

    // Ambil waktu dari raw, gunakan savedPref atau existingLocal sebagai fallback sebelum '08:00'
    final fallbackTime = (savedPref?['waktu'] ??
            existingLocal?['waktu'] ??
            existingLocal?['time'] ??
            '08:00')
        .toString();
    final rawTimeCandidate =
        raw['waktu'] ?? raw['start_time'] ?? raw['time'] ?? fallbackTime;
    final waktu = formatTimeString(
      rawTimeCandidate.toString(),
      fallback: formatTimeString(fallbackTime),
    );

    final reminderMinutes = extractReminderMinutes(
      raw,
      waktuHHmm: waktu,
      savedPref: savedPref,
      existingLocal: existingLocal,
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
            (savedPref?['isCompleted'] == true ||
                existingLocal?['isCompleted'] == true));

    final reminderEnabled = raw['reminderEnabled'] ??
        raw['reminder_enabled'] ??
        existingLocal?['reminderEnabled'] ??
        true;

    final enableWaNotification = raw['enableWaNotification'] ??
        savedPref?['enableWaNotification'] ??
        existingLocal?['enableWaNotification'] ??
        true;

    final waPhone = (raw['waPhone'] ??
            savedPref?['waPhone'] ??
            existingLocal?['waPhone'] ??
            '089602976525')
        .toString();

    final reminderTriggered = raw['reminderTriggered'] == true ||
        savedPref?['reminderTriggered'] == true ||
        existingLocal?['reminderTriggered'] == true;

    final reminderTriggeredAt = raw['reminderTriggeredAt'] ??
        savedPref?['reminderTriggeredAt'] ??
        existingLocal?['reminderTriggeredAt'];

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
    final userPrefsMap = await _loadUserPrefsMap();
    final rawLocal = prefs.getString(storageKey);

    List<Map<String, dynamic>> items = [];

    if (rawLocal != null && rawLocal.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(rawLocal);
        items = decoded.map((e) {
          final map = Map<String, dynamic>.from(e);
          final idKey = 'id_${map['id']}';
          final tdKey = _buildTitleDateKey(
            (map['judul'] ?? map['title'] ?? '').toString(),
            (map['tanggalIso'] ?? map['date'] ?? '').toString().split('T').first,
          );
          final savedPref = userPrefsMap[idKey] ?? userPrefsMap[tdKey];
          return normalizeItem(map, savedPref: savedPref);
        }).toList();
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
              final rowTitle =
                  (rowMap['title'] ?? rowMap['judul'] ?? '').toString();
              final rowDateIso = JadwalDateUtils.toIsoDate(
                JadwalDateUtils.parseIsoDate(
                  (rowMap['date'] ?? rowMap['tanggalIso'] ?? '').toString(),
                ),
              );

              final existingIndex = items.indexWhere(
                (e) =>
                    e['id'].toString() == rowId ||
                    (_buildTitleDateKey(
                          (e['judul'] ?? '').toString(),
                          (e['tanggalIso'] ?? '').toString(),
                        ) ==
                        _buildTitleDateKey(rowTitle, rowDateIso)),
              );
              final existingLocal =
                  existingIndex >= 0 ? items[existingIndex] : null;

              final savedPref = userPrefsMap['id_$rowId'] ??
                  userPrefsMap[_buildTitleDateKey(rowTitle, rowDateIso)];

              final norm = normalizeItem(
                rowMap,
                existingLocal: existingLocal,
                savedPref: savedPref,
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

    // Simpan preferensi pilihan waktu & reminder pengguna sebelum request API
    await _saveUserPreferenceForItem(item);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final isOnline = await ConnectivityService.instance.isOnline();
    final isValidServerToken = token != null &&
        token.isNotEmpty &&
        !token.startsWith('offline_') &&
        !token.startsWith('google_session_');

    if (isValidServerToken && isOnline) {
      try {
        // Kirim end_time berisi jam pengingat (HH:mm) agar server Vercel yang belum
        // memiliki kolom reminder_minutes tetap menyimpan jam pengingat dengan akurat!
        final payload = {
          'title': item['judul'],
          'category': item['kategori'],
          'date': item['tanggalIso'],
          'start_time': item['waktu'],
          'end_time': item['reminderTime'],
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
    item = normalizeItem(item, savedPref: item);
    await _saveUserPreferenceForItem(item);

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
    }

    current.removeWhere(
      (e) =>
          e['id'].toString() == item['id'].toString() ||
          _buildTitleDateKey(
                (e['judul'] ?? '').toString(),
                (e['tanggalIso'] ?? '').toString(),
              ) ==
              _buildTitleDateKey(
                (item['judul'] ?? '').toString(),
                (item['tanggalIso'] ?? '').toString(),
              ),
    );
    current.insert(0, item);
    await saveLocalSchedules(current);

    // 1. Catat ke daftar halaman Notifikasi (tanpa memicu alarm sistem prematur)
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
      savedPref: updatedRaw,
    );

    await _saveUserPreferenceForItem(item);

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
          'end_time': item['reminderTime'],
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
      await _saveUserPreferenceForItem(items[index]);
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
