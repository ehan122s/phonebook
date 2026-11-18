import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/api_constants.dart';
import '../constants/jadwal_constants.dart';
import 'connectivity_service.dart';
import 'notification_service.dart';
import 'whatsapp_reminder_service.dart';

class JadwalService {
  static const String legacyStorageKey = 'phonebook_jadwal_items_v1';
  static const String legacyUserPrefsKey = 'phonebook_jadwal_user_prefs_v3';

  /// Mendapatkan ID atau identitas pengguna yang sedang login untuk isolasi data antar-akun
  static Future<String> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = (prefs.getString('user_id') ?? '').trim();
    if (uid.isNotEmpty) return uid;
    final email = (prefs.getString('email') ?? '').trim().toLowerCase();
    if (email.isNotEmpty) return email;
    return 'guest';
  }

  /// Kunci penyimpanan jadwal lokal terisolasi per akun pengguna
  static Future<String> getScopedStorageKey() async {
    final uid = await getCurrentUserId();
    return 'phonebook_jadwal_items_u$uid';
  }

  /// Kunci preferensi jadwal lokal terisolasi per akun pengguna
  static Future<String> getScopedUserPrefsKey() async {
    final uid = await getCurrentUserId();
    return 'phonebook_jadwal_prefs_u$uid';
  }

  /// Daftar interval reminder yang valid (dalam menit)
  static const Set<int> validReminderIntervals = {5, 10, 15, 30, 60, 1440};

  static String get baseUrl => ApiConstants.baseUrl;

  /// Formats time string ensuring HH:mm format for both frontend and backend.
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

  static String _buildTitleDateKey(String judul, String tanggalIso) {
    return '${judul.trim().toLowerCase()}|${tanggalIso.trim()}';
  }

  static Future<Map<String, Map<String, dynamic>>> _loadUserPrefsMap() async {
    final prefs = await SharedPreferences.getInstance();
    final userPrefsKey = await getScopedUserPrefsKey();
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

  static Future<void> _saveUserPreferenceForItem(
    Map<String, dynamic> item,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final userPrefsKey = await getScopedUserPrefsKey();
    final map = await _loadUserPrefsMap();

    final idKey = 'id_${item['id']}';
    final titleDateKey = _buildTitleDateKey(
      (item['judul'] ?? item['title'] ?? '').toString(),
      (item['tanggalIso'] ?? '').toString(),
    );

    final entry = <String, dynamic>{
      'user_id': item['user_id'] ?? item['userId'],
      'userId': item['user_id'] ?? item['userId'],
      'waktu': item['waktu'],
      'reminderMinutes': item['reminderMinutes'],
      'reminderTime': item['reminderTime'],
      'kategori': item['kategori'],
      'enableWaNotification': item['enableWaNotification'] ?? true,
      'waPhone': item['waPhone'] ?? '',
      'isCompleted': item['isCompleted'] ?? false,
      'reminderTriggered': item['reminderTriggered'] ?? false,
      'reminderTriggeredAt': item['reminderTriggeredAt'],
      'whatsappStatus': item['whatsappStatus'] ?? item['whatsapp_status'],
      'whatsappError': item['whatsappError'] ?? item['whatsapp_error'],
      'whatsappSentAt': item['whatsappSentAt'] ?? item['whatsapp_sent_at'],
      'whatsappMessageId':
          item['whatsappMessageId'] ?? item['whatsapp_message_id'],
      'whatsappSent': item['whatsappSent'] ?? item['whatsapp_sent'],
    };

    map[idKey] = entry;
    map[titleDateKey] = entry;

    await prefs.setString(userPrefsKey, jsonEncode(map));
  }

  static int extractReminderMinutes(
    Map<String, dynamic> raw, {
    required String waktuHHmm,
    Map<String, dynamic>? savedPref,
    Map<String, dynamic>? existingLocal,
  }) {
    final directVal = raw['reminderMinutes'] ?? raw['reminder_minutes'];
    if (directVal != null) {
      final parsed = int.tryParse(directVal.toString());
      if (parsed != null && validReminderIntervals.contains(parsed)) {
        return parsed;
      }
    }

    if (savedPref != null && savedPref['reminderMinutes'] != null) {
      final prefMin =
          int.tryParse(savedPref['reminderMinutes'].toString());
      if (prefMin != null && validReminderIntervals.contains(prefMin)) {
        return prefMin;
      }
    }

    if (existingLocal != null && existingLocal['reminderMinutes'] != null) {
      final localMin =
          int.tryParse(existingLocal['reminderMinutes'].toString());
      if (localMin != null && validReminderIntervals.contains(localMin)) {
        return localMin;
      }
    }

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

    return 10;
  }

  static Map<String, dynamic> normalizeItem(
    Map<String, dynamic> raw, {
    Map<String, dynamic>? existingLocal,
    Map<String, dynamic>? savedPref,
    String? currentUserId,
  }) {
    final id = raw['id'] ??
        existingLocal?['id'] ??
        'jadwal_${JadwalDateUtils.nowWib().millisecondsSinceEpoch}';

    final ownerUserId = (raw['user_id'] ??
            raw['userId'] ??
            existingLocal?['user_id'] ??
            existingLocal?['userId'] ??
            savedPref?['user_id'] ??
            savedPref?['userId'] ??
            currentUserId ??
            '')
        .toString()
        .trim();
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

    final dynamic rawWa = raw['enableWaNotification'] ??
        raw['enable_wa_notification'] ??
        savedPref?['enableWaNotification'] ??
        existingLocal?['enableWaNotification'];
    final bool enableWaNotification = rawWa == null ||
        rawWa == true ||
        rawWa == 1 ||
        rawWa == '1' ||
        rawWa.toString().toLowerCase() == 'true';

    final waPhone = (raw['waPhone'] ??
            raw['wa_phone'] ??
            savedPref?['waPhone'] ??
            existingLocal?['waPhone'] ??
            existingLocal?['wa_phone'] ??
            '')
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

    final String? rawWaStatus = (raw['whatsapp_status'] ??
            raw['whatsappStatus'] ??
            savedPref?['whatsappStatus'] ??
            existingLocal?['whatsappStatus'])
        ?.toString();

    final bool isWaSent = raw['whatsapp_sent'] == true ||
        raw['whatsappSent'] == true ||
        savedPref?['whatsappSent'] == true ||
        existingLocal?['whatsappSent'] == true ||
        rawWaStatus == 'sent';

    String whatsappStatus = 'pending';
    if (!enableWaNotification) {
      whatsappStatus = 'disabled';
    } else if (rawWaStatus != null && rawWaStatus.isNotEmpty) {
      whatsappStatus = rawWaStatus;
    } else if (isWaSent) {
      whatsappStatus = 'sent';
    }

    final String? whatsappError = (raw['whatsapp_error'] ??
            raw['whatsappError'] ??
            savedPref?['whatsappError'] ??
            existingLocal?['whatsappError'])
        ?.toString();

    final String? whatsappSentAt = (raw['whatsapp_sent_at'] ??
            raw['whatsappSentAt'] ??
            savedPref?['whatsappSentAt'] ??
            existingLocal?['whatsappSentAt'])
        ?.toString();

    final String? whatsappMessageId = (raw['whatsapp_message_id'] ??
            raw['whatsappMessageId'] ??
            savedPref?['whatsappMessageId'] ??
            existingLocal?['whatsappMessageId'])
        ?.toString();

    return {
      'id': id,
      'user_id': ownerUserId,
      'userId': ownerUserId,
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
      'whatsapp_status': whatsappStatus,
      'whatsappStatus': whatsappStatus,
      'whatsapp_sent': isWaSent || whatsappStatus == 'sent',
      'whatsappSent': isWaSent || whatsappStatus == 'sent',
      'whatsapp_error': whatsappError,
      'whatsappError': whatsappError,
      'whatsapp_sent_at': whatsappSentAt,
      'whatsappSentAt': whatsappSentAt,
      'whatsapp_message_id': whatsappMessageId,
      'whatsappMessageId': whatsappMessageId,
      'lokasi': lokasi,
      'location': lokasi,
      'catatan': catatan,
      'description': catatan,
      'isCompleted': isCompleted,
      'createdAt': createdAt,
    };
  }

  /// Ambil jadwal dari penyimpanan lokal (SharedPreferences) secara instan (<5ms) khusus akun yang aktif
  static Future<List<Map<String, dynamic>>> getLocalCachedSchedules() async {
    final prefs = await SharedPreferences.getInstance();
    final currentUid = await getCurrentUserId();
    final scopedKey = await getScopedStorageKey();
    final userPrefsMap = await _loadUserPrefsMap();
    final rawLocal = prefs.getString(scopedKey);

    if (rawLocal == null || rawLocal.isEmpty) return [];

    try {
      final List<dynamic> decoded = jsonDecode(rawLocal);
      return decoded
          .map((e) => Map<String, dynamic>.from(e))
          .where((map) {
            if (isDummyScheduleId(map['id'])) return false;
            final itemUid =
                (map['user_id'] ?? map['userId'] ?? '').toString().trim();
            if (currentUid != 'guest' &&
                itemUid.isNotEmpty &&
                itemUid != currentUid) {
              return false;
            }
            return true;
          })
          .map((map) {
            final idKey = 'id_${map['id']}';
            final tdKey = _buildTitleDateKey(
              (map['judul'] ?? map['title'] ?? '').toString(),
              (map['tanggalIso'] ?? map['date'] ?? '').toString().split('T').first,
            );
            final savedPref = userPrefsMap[idKey] ?? userPrefsMap[tdKey];
            return normalizeItem(
              map,
              savedPref: savedPref,
              currentUserId: currentUid,
            );
          })
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Load all schedules from local storage and sync with backend API strictly for current user
  static Future<List<Map<String, dynamic>>> loadSchedules() async {
    final prefs = await SharedPreferences.getInstance();
    final currentUid = await getCurrentUserId();
    final userPrefsMap = await _loadUserPrefsMap();

    // 1. Ambil data lokal milik akun pengguna yang aktif
    List<Map<String, dynamic>> items = await getLocalCachedSchedules();

    // 2. Fetch data jadwal terkini dari backend API
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

            // Filter item offline/lokal murni milik akun ini yang belum diunggah ke server
            final pendingOfflineItems = items.where((e) {
              final idStr = (e['id'] ?? '').toString();
              final isLocal = e['isOffline'] == true ||
                  e['syncStatus'] == 'pending' ||
                  idStr.startsWith('local_') ||
                  int.tryParse(idStr) == null;
              return isLocal;
            }).toList();

            final List<Map<String, dynamic>> refreshed = [];

            for (final row in apiList) {
              final rowMap = Map<String, dynamic>.from(row);
              final rowId = (rowMap['id'] ?? '').toString();
              if (isDummyScheduleId(rowId)) continue;

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
                currentUserId: currentUid,
              );

              refreshed.add(norm);
            }

            // Masukkan kembali draf offline lokal jika belum ada di server
            for (final pending in pendingOfflineItems) {
              final exists = refreshed.any((s) =>
                  s['id'].toString() == pending['id'].toString() ||
                  _buildTitleDateKey(
                        (s['judul'] ?? '').toString(),
                        (s['tanggalIso'] ?? '').toString(),
                      ) ==
                      _buildTitleDateKey(
                        (pending['judul'] ?? '').toString(),
                        (pending['tanggalIso'] ?? '').toString(),
                      ));
              if (!exists) {
                refreshed.insert(0, pending);
              }
            }

            items = refreshed;
          }
        }
      } catch (_) {}
    }

    await saveLocalSchedules(items);

    // Sinkronkan penjadwalan reminder otomatis HANYA untuk jadwal akun ini
    await NotificationService.instance.rescheduleAllFromList(items);

    return items;
  }

  /// Save list to local SharedPreferences scoped to current user
  static Future<void> saveLocalSchedules(
    List<Map<String, dynamic>> items,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final currentUid = await getCurrentUserId();
    final scopedKey = await getScopedStorageKey();

    final serializable = items
        .where((e) => !isDummyScheduleId(e['id']))
        .where((e) {
          final itemUid =
              (e['user_id'] ?? e['userId'] ?? '').toString().trim();
          if (currentUid != 'guest' &&
              itemUid.isNotEmpty &&
              itemUid != currentUid) {
            return false;
          }
          return true;
        })
        .map((e) {
      final copy = Map<String, dynamic>.from(e);
      copy.remove('date');
      copy['user_id'] = currentUid;
      copy['userId'] = currentUid;
      return copy;
    }).toList();

    await prefs.setString(scopedKey, jsonEncode(serializable));
  }

  /// Add a new schedule locally and to the server
  static Future<Map<String, dynamic>> addSchedule(
    Map<String, dynamic> raw,
  ) async {
    final currentUid = await getCurrentUserId();
    var item = normalizeItem(raw, currentUserId: currentUid);

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
          'enable_wa_notification': item['enableWaNotification'] ?? true,
          'wa_phone': item['waPhone'],
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
          if (body['data'] is Map) {
            final serverData = Map<String, dynamic>.from(body['data']);
            if (serverData['id'] != null) item['id'] = serverData['id'];
            if (serverData['whatsapp_status'] != null) {
              item['whatsapp_status'] = serverData['whatsapp_status'];
              item['whatsappStatus'] = serverData['whatsapp_status'];
            }
            if (serverData['whatsapp_error'] != null) {
              item['whatsapp_error'] = serverData['whatsapp_error'];
              item['whatsappError'] = serverData['whatsapp_error'];
            }
            if (serverData['whatsapp_sent_at'] != null) {
              item['whatsapp_sent_at'] = serverData['whatsapp_sent_at'];
              item['whatsappSentAt'] = serverData['whatsapp_sent_at'];
            }
            if (serverData['whatsapp_message_id'] != null) {
              item['whatsapp_message_id'] = serverData['whatsapp_message_id'];
              item['whatsappMessageId'] = serverData['whatsapp_message_id'];
            }
          }
        }
      } catch (_) {}
    }

    item = normalizeItem(item, savedPref: item, currentUserId: currentUid);
    await _saveUserPreferenceForItem(item);

    final prefsNow = await SharedPreferences.getInstance();
    final scopedKey = await getScopedStorageKey();
    final rawLocal = prefsNow.getString(scopedKey);
    List<Map<String, dynamic>> current = [];
    if (rawLocal != null && rawLocal.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(rawLocal);
        current = decoded
            .map((e) => normalizeItem(Map<String, dynamic>.from(e), currentUserId: currentUid))
            .where((e) => !isDummyScheduleId(e['id']))
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

    await NotificationService.instance.addScheduleCreatedNotification(item);
    await NotificationService.instance.scheduleReminderForItem(item);

    final dynamic rawWa =
        item['enableWaNotification'] ?? item['enable_wa_notification'];
    final bool enableWa = rawWa == null ||
        rawWa == true ||
        rawWa == 1 ||
        rawWa == '1' ||
        rawWa.toString().toLowerCase() == 'true';
    if (enableWa) {
      WhatsappReminderService.instance
          .scheduleAutomaticReminder(item)
          .catchError((_) => <String, dynamic>{});

      WhatsappReminderService.instance
          .sendScheduleCreatedNotification(item)
          .catchError((_) => <String, dynamic>{});
    }

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

    await NotificationService.instance.cancelReminderForScheduleId(id);

    final currentUid = await getCurrentUserId();
    var item = normalizeItem(
      {
        ...updatedRaw,
        'id': id,
        'reminderTriggered': false,
        'reminderTriggeredAt': null,
      },
      existingLocal: existingLocal,
      savedPref: updatedRaw,
      currentUserId: currentUid,
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
          'enable_wa_notification': item['enableWaNotification'] ?? true,
          'wa_phone': item['waPhone'],
          'is_completed': item['isCompleted'] ?? false,
        };

        final response = await http.put(
          Uri.parse('$baseUrl/api/schedules/$id'),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final body = jsonDecode(response.body);
          if (body['data'] is Map) {
            final serverData = Map<String, dynamic>.from(body['data']);
            if (serverData['whatsapp_status'] != null) {
              item['whatsapp_status'] = serverData['whatsapp_status'];
              item['whatsappStatus'] = serverData['whatsapp_status'];
            }
            if (serverData['whatsapp_error'] != null) {
              item['whatsapp_error'] = serverData['whatsapp_error'];
              item['whatsappError'] = serverData['whatsapp_error'];
            }
            if (serverData['whatsapp_sent_at'] != null) {
              item['whatsapp_sent_at'] = serverData['whatsapp_sent_at'];
              item['whatsappSentAt'] = serverData['whatsapp_sent_at'];
            }
            if (serverData['whatsapp_message_id'] != null) {
              item['whatsapp_message_id'] = serverData['whatsapp_message_id'];
              item['whatsappMessageId'] = serverData['whatsapp_message_id'];
            }
          }
        }
      } catch (_) {}
    }

    if (index >= 0) {
      items[index] = item;
    } else {
      items.insert(0, item);
    }

    await saveLocalSchedules(items);

    await NotificationService.instance.scheduleReminderForItem(item);

    final dynamic rawWa =
        item['enableWaNotification'] ?? item['enable_wa_notification'];
    final bool enableWa = rawWa == null ||
        rawWa == true ||
        rawWa == 1 ||
        rawWa == '1' ||
        rawWa.toString().toLowerCase() == 'true';
    if (enableWa) {
      WhatsappReminderService.instance
          .scheduleAutomaticReminder(item)
          .catchError((_) => <String, dynamic>{});

      WhatsappReminderService.instance
          .sendScheduleCreatedNotification(item)
          .catchError((_) => <String, dynamic>{});
    }

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