import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/api_constants.dart';
import '../constants/jadwal_constants.dart';
import 'connectivity_service.dart';

class JadwalService {
  static const String storageKey = 'phonebook_jadwal_items_v1';
  static String get baseUrl => ApiConstants.baseUrl;

  /// Formats time string ensuring HH:mm format for backend validation
  static String formatTimeString(String raw) {
    final clean = raw.trim();
    if (clean.isEmpty) return '08:00';

    // If given range like "08:00 - 10:00", take the first part
    final first = clean.contains('-') ? clean.split('-').first.trim() : clean;

    // Check HH:mm with regex
    final regex = RegExp(r'^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$');
    if (regex.hasMatch(first)) {
      final parts = first.split(':');
      final h = parts[0].padLeft(2, '0');
      final m = parts[1].padLeft(2, '0');
      return '$h:$m';
    }

    // Try dot separator e.g. 08.00
    if (first.contains('.')) {
      final parts = first.split('.');
      if (parts.length == 2) {
        final h = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (h != null && m != null && h >= 0 && h < 24 && m >= 0 && m < 60) {
          return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
        }
      }
    }

    return '08:00';
  }

  /// Normalizes schedule item map so all pages (jadwal, kategori, admin_folder) can read it without type crashes
  static Map<String, dynamic> normalizeItem(Map<String, dynamic> raw) {
    final id = raw['id'] ?? 'jadwal_${DateTime.now().millisecondsSinceEpoch}';
    final judul = (raw['judul'] ?? raw['title'] ?? 'Kegiatan Lapangan').toString();
    final kategori = (raw['kategori'] ?? 'Penyuluhan').toString();

    String tanggalIso = '';
    if (raw['tanggalIso'] != null && raw['tanggalIso'].toString().isNotEmpty) {
      tanggalIso = raw['tanggalIso'].toString();
    } else if (raw['date'] is String && raw['date'].toString().isNotEmpty) {
      tanggalIso = raw['date'].toString().split('T').first;
    } else if (raw['date'] is DateTime) {
      final d = raw['date'] as DateTime;
      tanggalIso =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    } else {
      final now = DateTime.now();
      tanggalIso =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    }

    final waktu = formatTimeString((raw['waktu'] ?? raw['start_time'] ?? raw['time'] ?? '08:00').toString());
    final lokasi = (raw['lokasi'] ?? raw['location'] ?? 'Lokasi belum ditentukan').toString();
    final catatan = (raw['catatan'] ?? raw['description'] ?? '').toString();
    final isCompleted = raw['isCompleted'] == true;

    return {
      'id': id,
      'judul': judul,
      'title': judul,
      'kategori': kategori,
      'tanggalIso': tanggalIso,
      'date': JadwalDateUtils.parseIsoDate(tanggalIso),
      'waktu': waktu,
      'time': waktu,
      'lokasi': lokasi,
      'location': lokasi,
      'catatan': catatan,
      'description': catatan,
      'isCompleted': isCompleted,
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
        items = decoded.map((e) => normalizeItem(Map<String, dynamic>.from(e))).toList();
      } catch (_) {}
    }

    // Try fetching from backend if token exists and online
    final token = prefs.getString('token');
    final isOnline = await ConnectivityService.instance.isOnline();

    if (token != null && token.isNotEmpty && isOnline) {
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
              final norm = normalizeItem(Map<String, dynamic>.from(row));
              final existingIndex = items.indexWhere((e) => e['id'].toString() == norm['id'].toString());
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
      items = buildDefaultJadwalList().map(normalizeItem).toList();
      await saveLocalSchedules(items);
    } else {
      await saveLocalSchedules(items);
    }

    return items;
  }

  /// Save list to local SharedPreferences
  static Future<void> saveLocalSchedules(List<Map<String, dynamic>> items) async {
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
  static Future<Map<String, dynamic>> addSchedule(Map<String, dynamic> raw) async {
    final item = normalizeItem(raw);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final isOnline = await ConnectivityService.instance.isOnline();

    if (token != null && token.isNotEmpty && isOnline) {
      try {
        final payload = {
          'title': item['judul'],
          'date': item['tanggalIso'],
          'start_time': formatTimeString(item['waktu']),
          'location': item['lokasi'],
          'description': item['catatan'],
          'reminder_enabled': true,
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

    final current = await loadSchedules();
    current.insert(0, item);
    await saveLocalSchedules(current);
    return item;
  }

  /// Toggle completed status
  static Future<void> toggleComplete(dynamic id) async {
    final items = await loadSchedules();
    final index = items.indexWhere((e) => e['id'].toString() == id.toString());
    if (index >= 0) {
      items[index]['isCompleted'] = !(items[index]['isCompleted'] == true);
      await saveLocalSchedules(items);
    }
  }

  /// Delete schedule
  static Future<void> deleteSchedule(dynamic id) async {
    final items = await loadSchedules();
    items.removeWhere((e) => e['id'].toString() == id.toString());
    await saveLocalSchedules(items);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final isOnline = await ConnectivityService.instance.isOnline();

    if (token != null && token.isNotEmpty && isOnline && int.tryParse(id.toString()) != null) {
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
