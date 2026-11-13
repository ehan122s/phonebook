import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/api_constants.dart';
import '../constants/jadwal_constants.dart';
import 'connectivity_service.dart';

/// Service terpusat untuk:
/// 1. Mengelola daftar Notifikasi aplikasi (Laporan baru, Jadwal baru, Reminder jadwal, Sinkronisasi).
/// 2. Menghapus notifikasi satu per satu (`deleteNotification`) dan hapus semua (`deleteAllNotifications`)
///    secara persisten (SharedPreferences + API Backend) tanpa menghapus data Laporan/Jadwal asli.
/// 3. Menjadwalkan Reminder Jadwal otomatis menggunakan timezone Asia/Jakarta (WIB / UTC+7)
///    melalui Android AlarmManager MethodChannel (tetap jalan di background, app ditutup, atau restart)
///    serta exact Timer di level aplikasi (tetap jalan saat berpindah halaman).
class NotificationService extends ChangeNotifier with WidgetsBindingObserver {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const MethodChannel _nativeChannel =
      MethodChannel('com.cdkv.phonebook/notifications');

  static const String _storagePrefix = 'phonebook_notifications_v2';
  static const String _deletedIdsPrefix = 'phonebook_deleted_notif_ids_v2';
  static const String _clearedAtPrefix = 'phonebook_notif_cleared_at_v2';
  static const String _triggeredRemindersKey =
      'phonebook_triggered_reminders_v2';
  static const String _jadwalStorageKey = 'phonebook_jadwal_items_v1';

  /// Global key agar banner/snackbar reminder tetap dapat muncul meskipun pengguna berpindah halaman
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  final List<Map<String, dynamic>> _notifications = [];
  final Set<String> _deletedNotificationIds = {};
  final Set<String> _triggeredReminderSignatures = {};
  final Map<String, Timer> _exactReminderTimers = {};

  Timer? _periodicCheckTimer;
  bool _initialized = false;
  DateTime? _lastClearedAt;

  List<Map<String, dynamic>> get notifications =>
      List.unmodifiable(_notifications);

  int get totalCount => _notifications.length;

  int get unreadCount =>
      _notifications.where((n) => n['isRead'] != true).length;

  /// Inisialisasi NotificationService saat aplikasi dimulai
  Future<void> init() async {
    if (_initialized) {
      await loadNotifications();
      await syncScheduledRemindersFromStorage();
      return;
    }
    _initialized = true;

    WidgetsBinding.instance.addObserver(this);

    await _loadTriggeredSignatures();
    await loadNotifications();
    await requestAndroidPermission();
    await syncScheduledRemindersFromStorage();

    // Cek setiap 15 detik di level global aplikasi (bukan hanya di halaman Jadwal)
    _periodicCheckTimer?.cancel();
    _periodicCheckTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => checkDueRemindersNow(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncNativeTriggeredReminders().then((_) {
        checkDueRemindersNow();
      });
    }
  }

  Future<String> _getUserScopeKey() async {
    final prefs = await SharedPreferences.getInstance();
    final email = (prefs.getString('email') ?? '').trim().toLowerCase();
    final userId = (prefs.getString('user_id') ?? '').trim();
    if (email.isNotEmpty) return email.replaceAll(RegExp(r'[^a-z0-9]'), '_');
    if (userId.isNotEmpty) return 'uid_$userId';
    return 'default_user';
  }

  /// Meminta permission notifikasi pada Android 13+ (POST_NOTIFICATIONS)
  Future<void> requestAndroidPermission() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _nativeChannel.invokeMethod('requestPermission');
    } catch (_) {}
  }

  /// Menampilkan notifikasi sistem Android (status bar / heads-up notification)
  Future<void> showSystemNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _nativeChannel.invokeMethod('showNotification', {
        'id': id,
        'title': title,
        'body': body,
      });
    } catch (_) {}
  }

  // ===========================================================================
  // MANAJEMEN DATA NOTIFIKASI (LOAD, ADD, DELETE ONE, DELETE ALL)
  // ===========================================================================

  Future<void> loadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final scope = await _getUserScopeKey();

    final deletedRaw = prefs.getStringList('${_deletedIdsPrefix}_$scope') ?? [];
    _deletedNotificationIds
      ..clear()
      ..addAll(deletedRaw);

    final clearedAtRaw = prefs.getString('${_clearedAtPrefix}_$scope');
    _lastClearedAt =
        clearedAtRaw != null ? DateTime.tryParse(clearedAtRaw) : null;

    final rawList = prefs.getString('${_storagePrefix}_$scope');
    final List<Map<String, dynamic>> loaded = [];

    if (rawList != null && rawList.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(rawList);
        for (final item in decoded) {
          final map = _normalizeNotification(Map<String, dynamic>.from(item));
          final id = map['id'].toString();
          if (!_deletedNotificationIds.contains(id)) {
            loaded.add(map);
          }
        }
      } catch (_) {}
    }

    // Sinkronisasi dari server jika online & memiliki token valid
    final token = prefs.getString('token');
    final isOnline = await ConnectivityService.instance.isOnline();
    final isValidServerToken = token != null &&
        token.isNotEmpty &&
        !token.startsWith('offline_') &&
        !token.startsWith('google_session_');

    if (isValidServerToken && isOnline) {
      try {
        final response = await http.get(
          Uri.parse(ApiConstants.notificationsUrl),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final body = jsonDecode(response.body);
          if (body['data'] is List) {
            for (final srv in body['data']) {
              final map = _normalizeNotification(Map<String, dynamic>.from(srv));
              final id = map['id'].toString();
              final refId = (map['referenceId'] ?? '').toString();

              // Jangan masukkan kembali notifikasi yang sudah pernah dihapus pengguna
              if (_deletedNotificationIds.contains(id) ||
                  (refId.isNotEmpty &&
                      _deletedNotificationIds.contains(refId))) {
                continue;
              }

              if (_lastClearedAt != null) {
                final createdAt = DateTime.tryParse(
                  (map['createdAt'] ?? '').toString(),
                );
                if (createdAt != null &&
                    !createdAt.isAfter(_lastClearedAt!)) {
                  continue;
                }
              }

              final exists = loaded.any(
                (e) =>
                    e['id'].toString() == id ||
                    (refId.isNotEmpty &&
                        e['referenceId']?.toString() == refId),
              );
              if (!exists) {
                loaded.add(map);
              }
            }
          }
        }
      } catch (_) {}
    }

    loaded.sort((a, b) {
      final dateA = DateTime.tryParse((a['createdAt'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final dateB = DateTime.tryParse((b['createdAt'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return dateB.compareTo(dateA);
    });

    _notifications
      ..clear()
      ..addAll(loaded);

    await _saveLocalNotifications();
    notifyListeners();
  }

  Map<String, dynamic> _normalizeNotification(Map<String, dynamic> raw) {
    final nowWib = JadwalDateUtils.nowWib();
    final id = (raw['id'] ??
            raw['reference_id'] ??
            'notif_${nowWib.millisecondsSinceEpoch}')
        .toString();
    final type = (raw['type'] ?? raw['tipe'] ?? 'umum').toString();
    final title = (raw['title'] ?? raw['judul'] ?? 'Notifikasi').toString();
    final message = (raw['message'] ?? raw['pesan'] ?? '').toString();
    final referenceId =
        (raw['referenceId'] ?? raw['reference_id'] ?? id).toString();
    final createdAt = (raw['createdAt'] ??
            raw['created_at'] ??
            nowWib.toIso8601String())
        .toString();
    final isRead = raw['isRead'] == true || raw['is_read'] == true;
    final metadata = raw['metadata'] is Map
        ? Map<String, dynamic>.from(raw['metadata'])
        : <String, dynamic>{};

    return {
      'id': id,
      'serverId': raw['serverId'] ?? (raw['id'] is int ? raw['id'] : null),
      'type': type,
      'title': title,
      'message': message,
      'referenceId': referenceId,
      'createdAt': createdAt,
      'isRead': isRead,
      'metadata': metadata,
    };
  }

  Future<void> _saveLocalNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final scope = await _getUserScopeKey();
    await prefs.setString(
      '${_storagePrefix}_$scope',
      jsonEncode(_notifications),
    );
    await prefs.setStringList(
      '${_deletedIdsPrefix}_$scope',
      _deletedNotificationIds.toList(),
    );
  }

  /// Menambahkan notifikasi baru ke penyimpanan lokal & backend API
  Future<Map<String, dynamic>> addNotification({
    required String type,
    required String title,
    required String message,
    String? referenceId,
    Map<String, dynamic>? metadata,
    bool triggerSystemNotification = true,
  }) async {
    final nowWib = JadwalDateUtils.nowWib();
    final id = referenceId ?? 'notif_${nowWib.microsecondsSinceEpoch}';

    // Pastikan jika referenceId baru dibuat, hapus dari daftar deleted lama agar bisa tampil
    _deletedNotificationIds.remove(id);

    final newItem = _normalizeNotification({
      'id': id,
      'type': type,
      'title': title,
      'message': message,
      'referenceId': id,
      'createdAt': nowWib.toIso8601String(),
      'isRead': false,
      'metadata': metadata ?? <String, dynamic>{},
    });

    // Hindari duplikasi dengan referenceId yang sama persis
    _notifications.removeWhere(
      (e) =>
          e['id'].toString() == id ||
          (referenceId != null && e['referenceId']?.toString() == referenceId),
    );
    _notifications.insert(0, newItem);

    await _saveLocalNotifications();
    notifyListeners();

    if (triggerSystemNotification) {
      await showSystemNotification(
        id: id.hashCode.abs() % 100000,
        title: title,
        body: message,
      );
    }

    // Kirim ke backend jika online
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final isOnline = await ConnectivityService.instance.isOnline();
    final isValidServerToken = token != null &&
        token.isNotEmpty &&
        !token.startsWith('offline_') &&
        !token.startsWith('google_session_');

    if (isValidServerToken && isOnline) {
      try {
        final response = await http
            .post(
              Uri.parse(ApiConstants.notificationsUrl),
              headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode({
                'type': type,
                'title': title,
                'message': message,
                'reference_id': id,
                'metadata': metadata ?? {},
                'is_read': false,
              }),
            )
            .timeout(const Duration(seconds: 8));

        if (response.statusCode == 200 || response.statusCode == 201) {
          final body = jsonDecode(response.body);
          final serverId = body['data']?['id'];
          if (serverId != null) {
            final idx = _notifications.indexWhere((e) => e['id'] == id);
            if (idx >= 0) {
              _notifications[idx]['serverId'] = serverId;
              await _saveLocalNotifications();
            }
          }
        }
      } catch (_) {}
    }

    return newItem;
  }

  /// Helper ketika pengguna membuat laporan baru
  Future<void> addReportCreatedNotification({
    required String title,
    required String jenisLaporan,
    required String location,
    required String status,
    dynamic reportId,
  }) async {
    final nowWib = JadwalDateUtils.nowWib();
    final statusLabel =
        status.toLowerCase() == 'draft' ? 'Draft Disimpan' : 'Berhasil Dikirim';
    final ref = reportId != null
        ? 'report_${reportId}_${nowWib.millisecondsSinceEpoch}'
        : 'report_${nowWib.millisecondsSinceEpoch}';

    await addNotification(
      type: 'laporan',
      title: 'Laporan Baru ($statusLabel)',
      message:
          '$jenisLaporan "$title" di $location telah tercatat pada ${JadwalDateUtils.formatTanggal(nowWib)}.',
      referenceId: ref,
      metadata: {
        'reportId': reportId?.toString(),
        'judul': title,
        'jenis': jenisLaporan,
        'lokasi': location,
        'status': status,
      },
      triggerSystemNotification: true,
    );
  }

  /// Helper ketika pengguna membuat jadwal baru
  Future<void> addScheduleCreatedNotification(Map<String, dynamic> item) async {
    final nowWib = JadwalDateUtils.nowWib();
    final judul = (item['judul'] ?? item['title'] ?? 'Kegiatan').toString();
    final tanggalIso = (item['tanggalIso'] ?? '').toString();
    final tanggalFormatted =
        JadwalDateUtils.formatTanggal(JadwalDateUtils.parseIsoDate(tanggalIso));
    final waktu = (item['waktu'] ?? item['time'] ?? '08:00').toString();
    final lokasi = (item['lokasi'] ?? item['location'] ?? '-').toString();
    final reminderMinutes =
        int.tryParse((item['reminderMinutes'] ?? 30).toString()) ?? 30;
    final reminderClock =
        JadwalDateUtils.calculateReminderTimeStr(waktu, reminderMinutes);

    final ref =
        'schedule_created_${item['id']}_${nowWib.millisecondsSinceEpoch}';

    await addNotification(
      type: 'jadwal',
      title: 'Jadwal Baru: $judul',
      message:
          'Dijadwalkan pada $tanggalFormatted pukul $waktu WIB di $lokasi. Pengingat otomatis aktif $reminderMinutes menit sebelumnya (pukul $reminderClock WIB).',
      referenceId: ref,
      metadata: {
        'scheduleId': item['id']?.toString(),
        'judul': judul,
        'tanggalIso': tanggalIso,
        'waktu': waktu,
        'reminderMinutes': reminderMinutes,
        'reminderTime': reminderClock,
        'lokasi': lokasi,
      },
      triggerSystemNotification: true,
    );
  }

  /// Menandai satu notifikasi sudah dibaca
  Future<void> markAsRead(String id) async {
    final index =
        _notifications.indexWhere((e) => e['id'].toString() == id.toString());
    if (index < 0) return;

    _notifications[index]['isRead'] = true;
    await _saveLocalNotifications();
    notifyListeners();

    final serverId = _notifications[index]['serverId'] ?? id;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final isOnline = await ConnectivityService.instance.isOnline();
    if (token != null &&
        token.isNotEmpty &&
        !token.startsWith('offline_') &&
        isOnline) {
      try {
        await http.patch(
          Uri.parse('${ApiConstants.notificationsUrl}/$serverId/read'),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 6));
      } catch (_) {}
    }
  }

  /// Menandai seluruh notifikasi sudah dibaca
  Future<void> markAllAsRead() async {
    for (final item in _notifications) {
      item['isRead'] = true;
    }
    await _saveLocalNotifications();
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final isOnline = await ConnectivityService.instance.isOnline();
    if (token != null &&
        token.isNotEmpty &&
        !token.startsWith('offline_') &&
        isOnline) {
      try {
        await http.patch(
          Uri.parse('${ApiConstants.notificationsUrl}/read-all'),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 6));
      } catch (_) {}
    }
  }

  /// B. Fitur Hapus Notifikasi Satu per Satu
  /// Menghapus 1 notifikasi secara permanen dari penyimpanan lokal & server
  /// tanpa memengaruhi notifikasi lain maupun data laporan/jadwal asli.
  Future<void> deleteNotification(String id) async {
    final index =
        _notifications.indexWhere((e) => e['id'].toString() == id.toString());
    Map<String, dynamic>? removed;
    if (index >= 0) {
      removed = _notifications.removeAt(index);
    }

    _deletedNotificationIds.add(id.toString());
    if (removed != null) {
      if (removed['referenceId'] != null) {
        _deletedNotificationIds.add(removed['referenceId'].toString());
      }
      if (removed['serverId'] != null) {
        _deletedNotificationIds.add(removed['serverId'].toString());
      }
    }

    await _saveLocalNotifications();
    notifyListeners();

    final serverTarget = removed?['serverId'] ?? removed?['referenceId'] ?? id;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final isOnline = await ConnectivityService.instance.isOnline();
    final isValidServerToken = token != null &&
        token.isNotEmpty &&
        !token.startsWith('offline_') &&
        !token.startsWith('google_session_');

    if (isValidServerToken && isOnline) {
      try {
        await http.delete(
          Uri.parse(ApiConstants.notificationDetailUrl(serverTarget)),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 8));
      } catch (_) {}
    }
  }

  /// A. Fitur Hapus Semua Notifikasi
  /// Menghapus seluruh notifikasi pengguna sekaligus secara permanen dari penyimpanan lokal & server
  /// tanpa menghapus laporan atau jadwal aslinya.
  Future<void> deleteAllNotifications() async {
    for (final item in _notifications) {
      _deletedNotificationIds.add(item['id'].toString());
      if (item['referenceId'] != null) {
        _deletedNotificationIds.add(item['referenceId'].toString());
      }
      if (item['serverId'] != null) {
        _deletedNotificationIds.add(item['serverId'].toString());
      }
    }

    _notifications.clear();
    _lastClearedAt = JadwalDateUtils.nowWib();

    final prefs = await SharedPreferences.getInstance();
    final scope = await _getUserScopeKey();
    await prefs.setString(
      '${_clearedAtPrefix}_$scope',
      _lastClearedAt!.toIso8601String(),
    );
    await _saveLocalNotifications();
    notifyListeners();

    final token = prefs.getString('token');
    final isOnline = await ConnectivityService.instance.isOnline();
    final isValidServerToken = token != null &&
        token.isNotEmpty &&
        !token.startsWith('offline_') &&
        !token.startsWith('google_session_');

    if (isValidServerToken && isOnline) {
      try {
        await http.delete(
          Uri.parse(ApiConstants.clearAllNotificationsUrl),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 8));
      } catch (_) {}
    }
  }

  // ===========================================================================
  // PENJADWALAN REMINDER OTOMATIS (TIMEZONE ASIA/JAKARTA - WIB)
  // ===========================================================================

  Future<void> _loadTriggeredSignatures() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_triggeredRemindersKey) ?? [];
    _triggeredReminderSignatures
      ..clear()
      ..addAll(list);
    await _syncNativeTriggeredReminders();
  }

  Future<void> _saveTriggeredSignatures() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _triggeredRemindersKey,
      _triggeredReminderSignatures.toList(),
    );
  }

  Future<void> _syncNativeTriggeredReminders() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final result =
          await _nativeChannel.invokeMethod<List<dynamic>>('getTriggeredReminders');
      if (result != null && result.isNotEmpty) {
        bool changed = false;
        for (final sig in result) {
          final str = sig?.toString() ?? '';
          if (str.isNotEmpty && _triggeredReminderSignatures.add(str)) {
            changed = true;
          }
        }
        if (changed) {
          await _saveTriggeredSignatures();
        }
      }
    } catch (_) {}
  }

  /// Membuat signature unik untuk suatu versi jadwal (id + tanggal + waktu + reminderMinutes)
  /// sehingga tidak pernah ada notifikasi ganda untuk jadwal yang sama, namun jika jadwal diedit
  /// (jam/tanggal/reminder berubah), reminder baru tetap akan dijadwalkan ulang.
  String buildReminderSignature(Map<String, dynamic> item) {
    final id = (item['id'] ?? '').toString();
    final tanggalIso = (item['tanggalIso'] ?? '').toString();
    final waktu = (item['waktu'] ?? item['time'] ?? '08:00').toString();
    final reminderMinutes =
        int.tryParse((item['reminderMinutes'] ?? 30).toString()) ?? 30;
    return '${id}_${tanggalIso}_${waktu}_$reminderMinutes';
  }

  bool isReminderTriggered(Map<String, dynamic> item) {
    if (item['reminderTriggered'] == true) return true;
    final sig = buildReminderSignature(item);
    return _triggeredReminderSignatures.contains(sig);
  }

  /// Membaca semua jadwal dari penyimpanan lokal dan menjadwalkan ulang seluruh reminder aktif
  Future<void> syncScheduledRemindersFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_jadwalStorageKey);
    if (raw == null || raw.isEmpty) return;

    try {
      final List<dynamic> decoded = jsonDecode(raw);
      final items =
          decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      await rescheduleAllFromList(items);
    } catch (_) {}
  }

  /// Menjadwalkan ulang semua jadwal dalam list
  Future<void> rescheduleAllFromList(List<Map<String, dynamic>> items) async {
    for (final timer in _exactReminderTimers.values) {
      timer.cancel();
    }
    _exactReminderTimers.clear();

    for (final item in items) {
      if (item['isCompleted'] == true || item['reminderEnabled'] == false) {
        await cancelReminderForScheduleId(item['id'], removeTriggeredHistory: false);
      } else {
        await scheduleReminderForItem(item);
      }
    }
  }

  /// Menjadwalkan reminder otomatis untuk satu item jadwal berdasarkan waktu jadwal - reminderMinutes
  /// dalam zona waktu Asia/Jakarta (WIB).
  Future<void> scheduleReminderForItem(Map<String, dynamic> item) async {
    final id = (item['id'] ?? '').toString();
    if (id.isEmpty) return;

    // Batalkan timer lama untuk ID ini terlebih dahulu
    _exactReminderTimers[id]?.cancel();
    _exactReminderTimers.remove(id);

    if (item['isCompleted'] == true || item['reminderEnabled'] == false) {
      await cancelReminderForScheduleId(id, removeTriggeredHistory: false);
      return;
    }

    final signature = buildReminderSignature(item);
    if (_triggeredReminderSignatures.contains(signature)) {
      return;
    }

    final tanggalIso = (item['tanggalIso'] ?? '').toString();
    final date = JadwalDateUtils.parseIsoDate(tanggalIso);
    final timeStr = (item['waktu'] ?? item['time'] ?? '08:00').toString();
    final parts = timeStr.split(':');
    final hour = parts.isNotEmpty ? (int.tryParse(parts[0]) ?? 8) : 8;
    final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;

    final reminderMinutes =
        int.tryParse((item['reminderMinutes'] ?? 30).toString()) ?? 30;

    final scheduleWib = DateTime(date.year, date.month, date.day, hour, minute);
    final reminderTriggerWib =
        scheduleWib.subtract(Duration(minutes: reminderMinutes));
    final nowWib = JadwalDateUtils.nowWib();

    // Jika jadwal utamanya sudah lewat lebih dari 5 menit yang lalu, jangan jadwalkan alarm baru
    if (nowWib.isAfter(scheduleWib.add(const Duration(minutes: 5)))) {
      return;
    }

    final title = (item['judul'] ?? item['title'] ?? 'Kegiatan').toString();
    final location = (item['lokasi'] ?? item['location'] ?? '-').toString();
    final reminderTimeStr =
        JadwalDateUtils.calculateReminderTimeStr(timeStr, reminderMinutes);

    final notifTitle = 'Pengingat Jadwal: $title';
    final notifBody =
        'Kegiatan "$title" akan dimulai pukul $timeStr WIB ($reminderMinutes menit lagi) di $location.';

    // Hitung epoch millis dalam Asia/Jakarta (WIB) untuk AlarmManager Android
    final triggerEpochMillis = JadwalDateUtils.wibToEpochMillis(
      reminderTriggerWib.year,
      reminderTriggerWib.month,
      reminderTriggerWib.day,
      reminderTriggerWib.hour,
      reminderTriggerWib.minute,
      0,
    );
    final nowEpochMillis = DateTime.now().toUtc().millisecondsSinceEpoch;
    final effectiveTriggerMillis = triggerEpochMillis <= nowEpochMillis
        ? nowEpochMillis + 1500
        : triggerEpochMillis;

    // 1. Jadwalkan di Native Android AlarmManager (agar tetap berjalan di background/app ditutup/restart)
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _nativeChannel.invokeMethod('scheduleReminder', {
          'scheduleKey': id,
          'notificationId': (id.hashCode.abs() % 90000) + 10000,
          'triggerAtMillis': effectiveTriggerMillis,
          'title': notifTitle,
          'body': notifBody,
          'signature': signature,
        });
      } catch (_) {}
    }

    // 2. Jadwalkan Exact Timer di Flutter (agar tepat pada detiknya memicu update state & banner saat app aktif/pindah halaman)
    final delay = reminderTriggerWib.difference(nowWib);
    if (delay <= Duration.zero) {
      // Sudah memasuki rentang waktu reminder (antara reminderTriggerWib s/d scheduleWib)
      _exactReminderTimers[id] = Timer(
        const Duration(milliseconds: 800),
        () => _triggerReminderNow(item, reminderTimeStr),
      );
    } else {
      _exactReminderTimers[id] = Timer(
        delay,
        () => _triggerReminderNow(item, reminderTimeStr),
      );
    }
  }

  /// Mengecek seluruh jadwal di penyimpanan apakah ada yang sudah memasuki waktu reminder
  Future<void> checkDueRemindersNow() async {
    await _syncNativeTriggeredReminders();

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_jadwalStorageKey);
    if (raw == null || raw.isEmpty) return;

    List<Map<String, dynamic>> items = [];
    try {
      final List<dynamic> decoded = jsonDecode(raw);
      items = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return;
    }

    final nowWib = JadwalDateUtils.nowWib();
    bool storageUpdated = false;

    for (final item in items) {
      if (item['isCompleted'] == true || item['reminderEnabled'] == false) {
        continue;
      }

      final sig = buildReminderSignature(item);
      if (_triggeredReminderSignatures.contains(sig)) {
        if (item['reminderTriggered'] != true) {
          item['reminderTriggered'] = true;
          storageUpdated = true;
        }
        continue;
      }

      final tanggalIso = (item['tanggalIso'] ?? '').toString();
      final date = JadwalDateUtils.parseIsoDate(tanggalIso);
      final timeStr = (item['waktu'] ?? item['time'] ?? '08:00').toString();
      final parts = timeStr.split(':');
      final hour = parts.isNotEmpty ? (int.tryParse(parts[0]) ?? 8) : 8;
      final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
      final reminderMinutes =
          int.tryParse((item['reminderMinutes'] ?? 30).toString()) ?? 30;

      final scheduleWib =
          DateTime(date.year, date.month, date.day, hour, minute);
      final reminderTriggerWib =
          scheduleWib.subtract(Duration(minutes: reminderMinutes));

      if (!nowWib.isBefore(reminderTriggerWib) &&
          !nowWib.isAfter(scheduleWib.add(const Duration(minutes: 5)))) {
        final reminderTimeStr =
            JadwalDateUtils.calculateReminderTimeStr(timeStr, reminderMinutes);
        await _triggerReminderNow(item, reminderTimeStr);
        item['reminderTriggered'] = true;
        item['reminderTriggeredAt'] = nowWib.toIso8601String();
        storageUpdated = true;
      }
    }

    if (storageUpdated) {
      await prefs.setString(_jadwalStorageKey, jsonEncode(items));
      notifyListeners();
    }
  }

  Future<void> _triggerReminderNow(
    Map<String, dynamic> item,
    String reminderTimeStr,
  ) async {
    final sig = buildReminderSignature(item);
    if (_triggeredReminderSignatures.contains(sig)) return;

    _triggeredReminderSignatures.add(sig);
    await _saveTriggeredSignatures();

    final id = (item['id'] ?? '').toString();
    _exactReminderTimers[id]?.cancel();
    _exactReminderTimers.remove(id);

    final title = (item['judul'] ?? item['title'] ?? 'Kegiatan').toString();
    final timeStr = (item['waktu'] ?? item['time'] ?? '08:00').toString();
    final location = (item['lokasi'] ?? item['location'] ?? '-').toString();
    final reminderMinutes =
        int.tryParse((item['reminderMinutes'] ?? 30).toString()) ?? 30;
    final nowWib = JadwalDateUtils.nowWib();

    // Update status reminderTriggered pada penyimpanan jadwal lokal
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_jadwalStorageKey);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(raw);
        final list =
            decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        final idx = list.indexWhere((e) => e['id'].toString() == id);
        if (idx >= 0) {
          list[idx]['reminderTriggered'] = true;
          list[idx]['reminderTriggeredAt'] = nowWib.toIso8601String();
          await prefs.setString(_jadwalStorageKey, jsonEncode(list));
        }
      }
    } catch (_) {}

    // Tambahkan ke daftar Notifikasi aplikasi & tampilkan notifikasi sistem
    await addNotification(
      type: 'reminder',
      title: 'Pengingat Jadwal: $title',
      message:
          'Kegiatan "$title" dijadwalkan pukul $timeStr WIB ($reminderMinutes menit lagi, pengingat pukul $reminderTimeStr WIB) di $location.',
      referenceId: 'reminder_trig_$sig',
      metadata: {
        'scheduleId': id,
        'judul': title,
        'waktu': timeStr,
        'reminderMinutes': reminderMinutes,
        'reminderTime': reminderTimeStr,
        'lokasi': location,
      },
      triggerSystemNotification: true,
    );

    // Tampilkan notifikasi in-app melalui global ScaffoldMessenger (muncul di halaman mana pun)
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger != null) {
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          backgroundColor: const Color(0xFF245C3A),
          behavior: SnackBarBehavior.floating,
          content: Row(
            children: [
              const Icon(
                Icons.notifications_active_rounded,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Pengingat Jadwal ($reminderTimeStr WIB): "$title" akan dimulai pukul $timeStr WIB ($reminderMinutes menit lagi) di $location.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    notifyListeners();
  }

  /// Membatalkan reminder terkait ketika jadwal diedit atau dihapus
  Future<void> cancelReminderForScheduleId(
    dynamic scheduleId, {
    bool removeTriggeredHistory = true,
  }) async {
    final id = (scheduleId ?? '').toString();
    if (id.isEmpty) return;

    _exactReminderTimers[id]?.cancel();
    _exactReminderTimers.remove(id);

    if (removeTriggeredHistory) {
      _triggeredReminderSignatures.removeWhere((sig) => sig.startsWith('${id}_'));
      await _saveTriggeredSignatures();
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _nativeChannel.invokeMethod('cancelReminder', {
          'scheduleKey': id,
          'notificationId': (id.hashCode.abs() % 90000) + 10000,
        });
      } catch (_) {}
    }
  }
}
