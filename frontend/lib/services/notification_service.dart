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
///    serta exact Timer & pengecekan berkala 5 detik di level aplikasi (tetap jalan saat berpindah halaman).
class NotificationService extends ChangeNotifier with WidgetsBindingObserver {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const MethodChannel _nativeChannel =
      MethodChannel('com.cdkv.phonebook/notifications');

  static const String _storagePrefix = 'phonebook_notifications_v2';
  static const String _deletedIdsPrefix = 'phonebook_deleted_notif_ids_v2';
  static const String _clearedAtPrefix = 'phonebook_notif_cleared_at_v2';
  static const String _triggeredRemindersKey =
      'phonebook_triggered_reminders_v3';
  static const String _jadwalStorageKey = 'phonebook_jadwal_items_v1';

  /// Global key agar banner/snackbar reminder tetap dapat muncul meskipun pengguna berpindah halaman
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  final List<Map<String, dynamic>> _notifications = [];
  final Set<String> _deletedNotificationIds = {};
  final Set<String> _triggeredReminderSignatures = {};
  final Map<String, Timer> _exactReminderTimers = {};
  final Map<String, String> _scheduledSignaturesById = {};

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

    // Cek setiap 5 detik di level global aplikasi agar reminder selalu muncul tepat waktu
    // walaupun pengguna sedang di halaman Dashboard, Laporan, Materi, atau Profil
    _periodicCheckTimer?.cancel();
    _periodicCheckTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => checkDueRemindersNow(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      checkDueRemindersNow();
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
    final nowWib = DateTime.now();
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
    bool triggerSystemNotification = false,
  }) async {
    final now = DateTime.now();
    final id = referenceId ?? 'notif_${now.microsecondsSinceEpoch}';

    _deletedNotificationIds.remove(id);

    final newItem = _normalizeNotification({
      'id': id,
      'type': type,
      'title': title,
      'message': message,
      'referenceId': id,
      'createdAt': now.toIso8601String(),
      'isRead': false,
      'metadata': metadata ?? <String, dynamic>{},
    });

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
    final now = DateTime.now();
    final statusLabel =
        status.toLowerCase() == 'draft' ? 'Draft Disimpan' : 'Berhasil Dikirim';
    final ref = reportId != null
        ? 'report_${reportId}_${now.millisecondsSinceEpoch}'
        : 'report_${now.millisecondsSinceEpoch}';

    await addNotification(
      type: 'laporan',
      title: 'Laporan Baru ($statusLabel)',
      message:
          '$jenisLaporan "$title" di $location telah tercatat pada ${JadwalDateUtils.formatTanggal(now)}.',
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

  /// Helper ketika pengguna membuat jadwal baru:
  /// Mencatat ke halaman Notifikasi dalam aplikasi TANPA memicu notifikasi reminder sistem prematur
  /// (notifikasi reminder sistem baru akan berbunyi otomatis tepat pada waktu `waktu_jadwal - reminderMinutes`).
  Future<void> addScheduleCreatedNotification(Map<String, dynamic> item) async {
    final now = DateTime.now();
    final judul = (item['judul'] ?? item['title'] ?? 'Kegiatan').toString();
    final tanggalIso = (item['tanggalIso'] ?? '').toString();
    final tanggalFormatted =
        JadwalDateUtils.formatTanggal(JadwalDateUtils.parseIsoDate(tanggalIso));
    final waktu = (item['waktu'] ?? item['time'] ?? '08:00').toString();
    final lokasi = (item['lokasi'] ?? item['location'] ?? '-').toString();
    final reminderMinutes =
        int.tryParse((item['reminderMinutes'] ?? 10).toString()) ?? 10;
    final reminderClock =
        JadwalDateUtils.calculateReminderTimeStr(waktu, reminderMinutes);

    final ref =
        'schedule_created_${item['id']}_${now.millisecondsSinceEpoch}';

    await addNotification(
      type: 'jadwal',
      title: 'Jadwal Baru: $judul',
      message:
          'Dijadwalkan pada $tanggalFormatted pukul $waktu WIB di $lokasi. Pengingat otomatis akan muncul $reminderMinutes menit sebelumnya (pukul $reminderClock WIB).',
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
      // JANGAN memunculkan notifikasi sistem saat menekan tombol Tambah Jadwal;
      // biarkan notifikasi sistem muncul tepat pada waktu reminder (misal 12:55 atau 12:50)!
      triggerSystemNotification: false,
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
    _lastClearedAt = DateTime.now();

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
  // PENJADWALAN REMINDER OTOMATIS (TIMEZONE LOKAL PERANGKAT / ASIA/JAKARTA)
  // ===========================================================================

  Future<void> _loadTriggeredSignatures() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_triggeredRemindersKey) ?? [];
    _triggeredReminderSignatures
      ..clear()
      ..addAll(list);
  }

  Future<void> _saveTriggeredSignatures() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _triggeredRemindersKey,
      _triggeredReminderSignatures.toList(),
    );
  }

  /// Membuat signature unik untuk suatu versi jadwal (id + tanggal + waktu + reminderMinutes)
  String buildReminderSignature(Map<String, dynamic> item) {
    final id = (item['id'] ?? '').toString();
    final tanggalIso = (item['tanggalIso'] ?? '').toString();
    final waktu = (item['waktu'] ?? item['time'] ?? '08:00').toString();
    final reminderMinutes =
        int.tryParse((item['reminderMinutes'] ?? 10).toString()) ?? 10;
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

  /// Menjadwalkan ulang semua jadwal dalam list tanpa membatalkan timer aktif yang signature-nya sama
  Future<void> rescheduleAllFromList(List<Map<String, dynamic>> items) async {
    final activeIds = <String>{};

    for (final item in items) {
      final id = (item['id'] ?? '').toString();
      if (id.isEmpty) continue;
      activeIds.add(id);

      if (item['isCompleted'] == true || item['reminderEnabled'] == false) {
        await cancelReminderForScheduleId(id, removeTriggeredHistory: false);
      } else {
        final sig = buildReminderSignature(item);
        // Jika timer untuk signature yang sama persis sudah aktif, jangan di-reset
        if (_scheduledSignaturesById[id] == sig &&
            (_exactReminderTimers[id]?.isActive ?? false)) {
          continue;
        }
        await scheduleReminderForItem(item);
      }
    }

    // Bersihkan timer untuk jadwal yang sudah tidak ada di daftar
    final removedIds = _exactReminderTimers.keys
        .where((k) => !activeIds.contains(k))
        .toList();
    for (final remId in removedIds) {
      _exactReminderTimers[remId]?.cancel();
      _exactReminderTimers.remove(remId);
      _scheduledSignaturesById.remove(remId);
    }
  }

  /// Menjadwalkan reminder otomatis untuk satu item jadwal berdasarkan waktu jadwal - reminderMinutes
  Future<void> scheduleReminderForItem(Map<String, dynamic> item) async {
    final id = (item['id'] ?? '').toString();
    if (id.isEmpty) return;

    _exactReminderTimers[id]?.cancel();
    _exactReminderTimers.remove(id);
    _scheduledSignaturesById.remove(id);

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
        int.tryParse((item['reminderMinutes'] ?? 10).toString()) ?? 10;

    // Gunakan waktu lokal perangkat (Asia/Jakarta) sehingga 100% sinkron dengan jam sistem & TimePicker
    final scheduleLocal = DateTime(
      date.year,
      date.month,
      date.day,
      hour,
      minute,
    );
    final reminderTriggerLocal =
        scheduleLocal.subtract(Duration(minutes: reminderMinutes));
    final nowLocal = DateTime.now();

    // Jika jadwal utamanya sudah lewat lebih dari 2 menit yang lalu, jangan jadwalkan alarm
    if (nowLocal.isAfter(scheduleLocal.add(const Duration(minutes: 2)))) {
      return;
    }

    _scheduledSignaturesById[id] = signature;

    final title = (item['judul'] ?? item['title'] ?? 'Kegiatan').toString();
    final location = (item['lokasi'] ?? item['location'] ?? '-').toString();
    final reminderTimeStr =
        JadwalDateUtils.calculateReminderTimeStr(timeStr, reminderMinutes);

    final notifTitle = 'Pengingat Jadwal: $title';
    final notifBody =
        'Kegiatan "$title" akan dimulai pukul $timeStr WIB ($reminderMinutes menit lagi) di $location.';

    final triggerEpochMillis = reminderTriggerLocal.millisecondsSinceEpoch;
    final nowEpochMillis = nowLocal.millisecondsSinceEpoch;

    final delay = reminderTriggerLocal.difference(nowLocal);

    if (delay > Duration.zero) {
      // Waktu reminder masih di masa depan -> jadwalkan tepat pada reminderTriggerLocal!
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        try {
          await _nativeChannel.invokeMethod('scheduleReminder', {
            'scheduleKey': id,
            'notificationId': (id.hashCode.abs() % 90000) + 10000,
            'triggerAtMillis': triggerEpochMillis,
            'title': notifTitle,
            'body': notifBody,
            'signature': signature,
          });
        } catch (_) {}
      }

      _exactReminderTimers[id] = Timer(
        delay,
        () => _triggerReminderNow(
          item,
          reminderTimeStr,
          triggeredByNativeAlready: false,
        ),
      );
    } else {
      // Apabila waktu sekarang sudah berada pada atau melewati titik reminderTriggerLocal
      // namun jadwal utama (scheduleLocal) masih belum lewat:
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        try {
          await _nativeChannel.invokeMethod('scheduleReminder', {
            'scheduleKey': id,
            'notificationId': (id.hashCode.abs() % 90000) + 10000,
            'triggerAtMillis': nowEpochMillis + 1500,
            'title': notifTitle,
            'body': notifBody,
            'signature': signature,
          });
        } catch (_) {}
      }

      _exactReminderTimers[id] = Timer(
        const Duration(milliseconds: 1500),
        () => _triggerReminderNow(
          item,
          reminderTimeStr,
          triggeredByNativeAlready: false,
        ),
      );
    }
  }

  /// Mengecek seluruh jadwal di penyimpanan apakah ada yang sudah memasuki waktu reminder
  Future<void> checkDueRemindersNow() async {
    Set<String> nativeTriggeredSigs = {};
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final result = await _nativeChannel
            .invokeMethod<List<dynamic>>('getTriggeredReminders');
        if (result != null) {
          nativeTriggeredSigs =
              result.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toSet();
        }
      } catch (_) {}
    }

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

    final nowLocal = DateTime.now();
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
          int.tryParse((item['reminderMinutes'] ?? 10).toString()) ?? 10;

      final scheduleLocal =
          DateTime(date.year, date.month, date.day, hour, minute);
      final reminderTriggerLocal =
          scheduleLocal.subtract(Duration(minutes: reminderMinutes));

      final bool firedInNative = nativeTriggeredSigs.contains(sig);
      final bool isTimeReached = !nowLocal.isBefore(reminderTriggerLocal) &&
          !nowLocal.isAfter(scheduleLocal.add(const Duration(minutes: 5)));

      if (firedInNative || isTimeReached) {
        final reminderTimeStr =
            JadwalDateUtils.calculateReminderTimeStr(timeStr, reminderMinutes);
        await _triggerReminderNow(
          item,
          reminderTimeStr,
          triggeredByNativeAlready: firedInNative,
        );
        item['reminderTriggered'] = true;
        item['reminderTriggeredAt'] = nowLocal.toIso8601String();
        storageUpdated = true;
      } else {
        // Pastikan timer aktif untuk jadwal yang belum tiba waktunya
        final id = (item['id'] ?? '').toString();
        if (id.isNotEmpty &&
            nowLocal.isBefore(reminderTriggerLocal) &&
            !(_exactReminderTimers[id]?.isActive ?? false)) {
          await scheduleReminderForItem(item);
        }
      }
    }

    if (storageUpdated) {
      await prefs.setString(_jadwalStorageKey, jsonEncode(items));
      notifyListeners();
    }
  }

  Future<void> _triggerReminderNow(
    Map<String, dynamic> item,
    String reminderTimeStr, {
    required bool triggeredByNativeAlready,
  }) async {
    final sig = buildReminderSignature(item);
    if (_triggeredReminderSignatures.contains(sig)) return;

    _triggeredReminderSignatures.add(sig);
    await _saveTriggeredSignatures();

    final id = (item['id'] ?? '').toString();
    _exactReminderTimers[id]?.cancel();
    _exactReminderTimers.remove(id);
    _scheduledSignaturesById.remove(id);

    final title = (item['judul'] ?? item['title'] ?? 'Kegiatan').toString();
    final timeStr = (item['waktu'] ?? item['time'] ?? '08:00').toString();
    final location = (item['lokasi'] ?? item['location'] ?? '-').toString();
    final reminderMinutes =
        int.tryParse((item['reminderMinutes'] ?? 10).toString()) ?? 10;
    final nowLocal = DateTime.now();

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
          list[idx]['reminderTriggeredAt'] = nowLocal.toIso8601String();
          await prefs.setString(_jadwalStorageKey, jsonEncode(list));
        }
      }
    } catch (_) {}

    // Tambahkan ke daftar Notifikasi aplikasi & tampilkan notifikasi sistem Android
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
      triggerSystemNotification: !triggeredByNativeAlready,
    );

    // Tampilkan MaterialBanner & SnackBar in-app melalui global ScaffoldMessenger
    // sehingga muncul jelas di halaman mana pun pengguna berada
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger != null) {
      messenger.clearMaterialBanners();
      messenger.showMaterialBanner(
        MaterialBanner(
          backgroundColor: const Color(0xFFE8F2E8),
          leading: const CircleAvatar(
            backgroundColor: Color(0xFF245C3A),
            child: Icon(
              Icons.notifications_active_rounded,
              color: Colors.white,
            ),
          ),
          content: Text(
            'Pengingat Jadwal ($reminderTimeStr WIB): "$title" akan dimulai pukul $timeStr WIB ($reminderMinutes menit lagi) di $location.',
            style: const TextStyle(
              color: Color(0xFF24352A),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => messenger.hideCurrentMaterialBanner(),
              child: const Text(
                'Tutup',
                style: TextStyle(
                  color: Color(0xFF245C3A),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );

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
                  'Pengingat Jadwal ($reminderTimeStr WIB): "$title" dimulai pukul $timeStr WIB ($reminderMinutes menit lagi) di $location.',
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
    _scheduledSignaturesById.remove(id);

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
