// ============================================================================
// [WIDGET, MANAJER TEMPLATE & EKSPORTIR PDF LAPORAN - REPORT_TEMPLATES.DART]
// Simpan file ini di: lib/widgets/laporan/report_templates.dart
//
// Perbaikan Penting Unduh PDF di Flutter Web (Chrome/Edge) & Mobile:
// - Mengganti skema `data:application/pdf;base64,...` (yang diblokir oleh Chrome
//   menjadi halaman kosong `Untitled`) dengan `XFile.fromData(...).saveTo(...)`
//   berbasis Blob Object URL (`blob:http://...`).
// - Kini saat tombol Unduh PDF diklik di Chrome/Web, file `.pdf` langsung
//   ter-download otomatis ke folder Downloads komputer/HP, dan dapat dibuka
//   di tab PDF Viewer Chrome untuk langsung di-print tanpa layar abu-abu kosong.
// ============================================================================

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/api_constants.dart';
import '../../constants/laporan_constants.dart';
import '../../services/device_file_storage_service.dart';
import '../../services/monitoring_calculator.dart';
import '../../services/offline_database.dart';

/// Manager untuk mengelola penyimpanan, ekstraksi file contoh, & format Template Laporan.
class ReportTemplateManager {
  static const String storageKey = 'phonebook_report_templates_v1';

  /// Daftar template laporan bawaan (Default) — otomatis aktif meskipun Admin
  /// belum mengubah atau mengunggah template baru.
  static List<Map<String, dynamic>> defaultTemplates() {
    return [
      {
        'id': 'tpl_penyuluhan',
        'title': 'Laporan Penyuluhan',
        'category': 'Penyuluhan',
        'iconKey': 'groups',
        'description':
            'Template laporan kegiatan penyuluhan kehutanan dan pendampingan Kelompok Tani Hutan (KTH).',
        'defaultTitle': 'Penyuluhan Kehutanan & Pendampingan KTH',
        'requirePhoto': true,
        'requireLocation': true,
        'sampleFileName': '',
        'fields': <String>[
          'Kelompok Tani Hutan (KTH) / Sasaran',
          'Materi Penyuluhan',
          'Jumlah Peserta (Orang)',
          'Hasil & Tindak Lanjut',
        ],
        'templateBody':
            'LAPORAN KEGIATAN PENYULUHAN KEHUTANAN\n'
            'Cabang Dinas Kehutanan Wilayah V\n\n'
            '1. Kelompok Sasaran / KTH : {{Kelompok Tani Hutan (KTH) / Sasaran}}\n'
            '2. Materi Penyuluhan      : {{Materi Penyuluhan}}\n'
            '3. Jumlah Peserta         : {{Jumlah Peserta (Orang)}}\n'
            '4. Hasil & Tindak Lanjut  :\n{{Hasil & Tindak Lanjut}}',
        'updatedBy': 'Administrator',
      },
      {
        'id': 'tpl_trk',
        'title': 'Laporan TRK',
        'category': 'TRK & Rehabilitasi',
        'iconKey': 'park',
        'description':
            'Template laporan kegiatan Tenaga Rimbawan Kehutanan (TRK), rehabilitasi lahan kritis, dan penanaman.',
        'defaultTitle': 'Pelaksanaan Kegiatan TRK & Rehabilitasi Lahan',
        'requirePhoto': true,
        'requireLocation': true,
        'sampleFileName': '',
        'fields': <String>[
          'Blok / Petak Kawasan Rehabilitasi',
          'Jenis & Jumlah Bibit Tanaman',
          'Luas Area Penanaman (Ha)',
          'Kondisi Tanaman & Evaluasi Lapangan',
        ],
        'templateBody':
            'LAPORAN PELAKSANAAN TRK & REHABILITASI HUTAN\n'
            'Cabang Dinas Kehutanan Wilayah V\n\n'
            '1. Blok / Petak Kawasan : {{Blok / Petak Kawasan Rehabilitasi}}\n'
            '2. Jenis & Jumlah Bibit : {{Jenis & Jumlah Bibit Tanaman}}\n'
            '3. Luas Area (Ha)       : {{Luas Area Penanaman (Ha)}}\n'
            '4. Kondisi & Evaluasi   :\n{{Kondisi Tanaman & Evaluasi Lapangan}}',
        'updatedBy': 'Administrator',
      },
      {
        'id': 'tpl_monitoring',
        'title': 'Laporan Monitoring',
        'category': 'Monitoring & Evaluasi',
        'iconKey': 'forest',
        'description':
            'Laporan monitoring berbasis perbandingan target kegiatan, hasil aktual lapangan, persentase capaian, sisa target, kendala, serta rencana tindak lanjut.',
        'defaultTitle': 'Laporan Monitoring Kegiatan',
        'requirePhoto': false,
        'requireLocation': true,
        'sampleFileName': '',
        'fields': <String>[
          'Nama Kegiatan yang Dimonitor',
          'Periode Monitoring',
          'Target Kegiatan & Satuan',
          'Hasil Aktual & Fakta Lapangan',
          'Kendala, Rekomendasi & Tindak Lanjut',
        ],
        'templateBody':
            'LAPORAN MONITORING KEGIATAN\n'
            'Cabang Dinas Kehutanan Wilayah V\n\n'
            '1. Kegiatan yang Dimonitor : {{Nama Kegiatan yang Dimonitor}}\n'
            '2. Periode Monitoring      : {{Periode Monitoring}}\n'
            '3. Target Kegiatan         : {{Target Kegiatan & Satuan}}\n'
            '4. Hasil Aktual & Fakta    : {{Hasil Aktual & Fakta Lapangan}}\n'
            '5. Kendala & Tindak Lanjut :\n{{Kendala, Rekomendasi & Tindak Lanjut}}',
        'updatedBy': 'Administrator',
      },
      {
        'id': 'tpl_kegiatan',
        'title': 'Laporan Kegiatan',
        'category': 'Kegiatan Lapangan',
        'iconKey': 'event_note',
        'description':
            'Template laporan kegiatan teknis, sosialisasi masyarakat, dan koordinasi lapangan lainnya.',
        'defaultTitle': 'Laporan Kegiatan Operasional Lapangan',
        'requirePhoto': false,
        'requireLocation': true,
        'sampleFileName': '',
        'fields': <String>[
          'Nama Kegiatan & Instansi Terkait',
          'Tujuan Pelaksanaan Kegiatan',
          'Ringkasan Hasil Kegiatan',
        ],
        'templateBody':
            'LAPORAN KEGIATAN LAPANGAN\n'
            'Cabang Dinas Kehutanan Wilayah V\n\n'
            '1. Kegiatan & Pihak Terkait : {{Nama Kegiatan & Instansi Terkait}}\n'
            '2. Tujuan Kegiatan          : {{Tujuan Pelaksanaan Kegiatan}}\n'
            '3. Ringkasan Hasil          :\n{{Ringkasan Hasil Kegiatan}}',
        'updatedBy': 'Administrator',
      },
      {
        'id': 'tpl_kejadian',
        'title': 'Laporan Kejadian',
        'category': 'Kejadian Khusus',
        'iconKey': 'warning',
        'description':
            'Template laporan kejadian darurat, kebakaran hutan, bencana alam, atau kondisi khusus di lapangan.',
        'defaultTitle': 'Laporan Kejadian Khusus / Darurat Kehutanan',
        'requirePhoto': true,
        'requireLocation': true,
        'sampleFileName': '',
        'fields': <String>[
          'Jenis Kejadian (Kebakaran / Longsor / Gangguan)',
          'Perkiraan Dampak / Luas Terdampak',
          'Tindakan Penanganan Awal',
        ],
        'templateBody':
            'LAPORAN KEJADIAN KHUSUS KEHUTANAN\n'
            'Cabang Dinas Kehutanan Wilayah V\n\n'
            '1. Jenis Kejadian        : {{Jenis Kejadian (Kebakaran / Longsor / Gangguan)}}\n'
            '2. Dampak / Luas         : {{Perkiraan Dampak / Luas Terdampak}}\n'
            '3. Penanganan Awal       :\n{{Tindakan Penanganan Awal}}',
        'updatedBy': 'Administrator',
      },
    ];
  }

  /// Konversi kode ikon string menjadi [IconData].
  static IconData iconFromKey(String? key) {
    return switch (key) {
      'groups' => Icons.groups_outlined,
      'park' => Icons.park_outlined,
      'forest' => Icons.forest_outlined,
      'event_note' => Icons.event_note_outlined,
      'warning' => Icons.warning_amber_rounded,
      'assignment' => Icons.assignment_outlined,
      'eco' => Icons.eco_outlined,
      _ => Icons.description_outlined,
    };
  }

  /// Mendeteksi apakah suatu teks mengandung byte biner / ZIP (.docx) mentah
  /// yang rusak seperti `PK!TF-.xml` atau `word/document.xml`.
  static bool isCorruptedBinaryText(String? text) {
    if (text == null) return false;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;

    final lower = trimmed.toLowerCase();
    if (trimmed.contains('PK!') ||
        trimmed.contains('PK\x03') ||
        lower.contains('word/document.xml') ||
        lower.contains('[content_types]') ||
        lower.contains('_rels/.rels') ||
        lower.contains('docprops/') ||
        lower.contains('theme/theme') ||
        lower.contains('fonttable.xml') ||
        lower.contains('websettings.xml') ||
        lower.contains('endstream')) {
      return true;
    }

    int weirdSymbolCount = 0;
    int printableCount = 0;
    for (int i = 0; i < trimmed.length; i++) {
      final code = trimmed.codeUnitAt(i);
      if (code >= 32 && code <= 126) {
        printableCount++;
        const noisyChars = '~\$`^|\\@#%*<>[]{}';
        if (noisyChars.contains(String.fromCharCode(code))) {
          weirdSymbolCount++;
        }
      }
    }
    if (printableCount > 24 && (weirdSymbolCount / printableCount) > 0.10) {
      return true;
    }
    return false;
  }

  /// Memvalidasi apakah nama field/kolom form layak dibaca manusia (bukan byte biner).
  static bool _isValidHumanFieldName(String? field) {
    if (field == null) return false;
    final f = field.trim();
    if (f.length < 3 || f.length > 55) return false;
    if (isCorruptedBinaryText(f)) return false;
    if (!RegExp(r'^[A-Za-z0-9 .,/()&-]+$').hasMatch(f)) return false;
    final letters = RegExp(r'[A-Za-z]').allMatches(f).length;
    if (letters < 3) return false;
    if (!RegExp(r'[aiueoAIUEO]').hasMatch(f)) return false;
    return true;
  }

  /// Memvalidasi apakah satu baris teks hasil ekstraksi layak masuk ke template.
  static bool _isValidHumanReadableLine(String line) {
    final l = line.trim();
    if (l.isEmpty) return false;
    if (isCorruptedBinaryText(l)) return false;
    final cleaned = l.replaceAll(RegExp(r'\{\{[^}]+\}\}'), '');
    if (RegExp(r'[~^`|\\\$@#%*<>]').hasMatch(cleaned)) return false;
    final letters = RegExp(r'[A-Za-z]').allMatches(l).length;
    if (letters < 2) return false;
    return true;
  }

  /// Mengembalikan daftar field standar yang bersih sesuai kategori/judul laporan.
  static List<String> defaultFieldsForCategory(String categoryOrTitle) {
    final hint = categoryOrTitle.toLowerCase();
    if (hint.contains('trk') ||
        hint.contains('rehab') ||
        hint.contains('tanam') ||
        hint.contains('bibit')) {
      return <String>[
        'Blok / Petak Kawasan Rehabilitasi',
        'Jenis & Jumlah Bibit Tanaman',
        'Luas Area Penanaman (Ha)',
        'Kondisi Tanaman & Evaluasi Lapangan',
      ];
    } else if (hint.contains('monitor') ||
        hint.contains('patroli') ||
        hint.contains('batas')) {
      return <String>[
        'Kawasan / Titik Pantau Hutan',
        'Kondisi Tegakan & Patok Batas',
        'Temuan Lapangan / Kerawanan',
        'Rekomendasi Tindakan',
      ];
    } else if (hint.contains('kejadian') ||
        hint.contains('kebakaran') ||
        hint.contains('bencana') ||
        hint.contains('darurat')) {
      return <String>[
        'Jenis Kejadian (Kebakaran / Longsor / Gangguan)',
        'Perkiraan Dampak / Luas Terdampak',
        'Tindakan Penanganan Awal',
      ];
    } else if (hint.contains('kegiatan')) {
      return <String>[
        'Nama Kegiatan & Instansi Terkait',
        'Tujuan Pelaksanaan Kegiatan',
        'Ringkasan Hasil Kegiatan',
      ];
    }
    return <String>[
      'Kelompok Tani Hutan (KTH) / Sasaran',
      'Materi Penyuluhan',
      'Jumlah Peserta (Orang)',
      'Hasil & Tindak Lanjut',
    ];
  }

  /// Membangun kerangka template standar yang bersih dari judul dan daftar field.
  static String buildCleanDefaultTemplateBody(
    String title,
    List<String> fields,
  ) {
    final cleanTitle =
        title.trim().isEmpty ? 'LAPORAN KEGIATAN LAPANGAN' : title.trim().toUpperCase();
    final buffer = StringBuffer();
    buffer.writeln(cleanTitle);
    buffer.writeln('Cabang Dinas Kehutanan Wilayah V\n');
    for (int i = 0; i < fields.length; i++) {
      final f = fields[i];
      buffer.writeln('${i + 1}. $f : {{$f}}');
    }
    return buffer.toString().trim();
  }

  /// Normalisasi map template agar tipe datanya selalu konsisten dan bebas dari korupsi biner.
  static Map<String, dynamic> normalizeTemplate(Map<String, dynamic> raw) {
    final title = (raw['title'] ?? raw['name'] ?? 'Laporan Kegiatan').toString().trim();
    final category = (raw['category'] ?? 'Penyuluhan').toString().trim();

    final rawFieldsConfig = raw['fields_config'];
    final List<Map<String, dynamic>> fieldsConfig = [];

    if (rawFieldsConfig is List && rawFieldsConfig.isNotEmpty) {
      for (final item in rawFieldsConfig) {
        if (item is Map) {
          final label = (item['label'] ?? item['name'] ?? '').toString().trim();
          if (label.isNotEmpty && _isValidHumanFieldName(label)) {
            final opts = (item['options'] is List)
                ? (item['options'] as List)
                    .map((o) => o.toString().trim())
                    .where((s) => s.isNotEmpty)
                    .toList()
                : <String>[];
            fieldsConfig.add({
              'id': (item['id'] ?? 'f_${label.replaceAll(RegExp(r'\W+'), '_').toLowerCase()}').toString(),
              'label': label,
              'type': (item['type'] ?? 'text').toString(),
              'placeholder': (item['placeholder'] ?? 'Isi $label...').toString(),
              'description': (item['description'] ?? '').toString(),
              'required': item['required'] != false,
              'options': opts,
            });
          }
        } else if (item is String) {
          final s = item.trim();
          if (_isValidHumanFieldName(s)) {
            final isLong = s.toLowerCase().contains('hasil') ||
                s.toLowerCase().contains('uraian') ||
                s.toLowerCase().contains('kondisi') ||
                s.toLowerCase().contains('temuan') ||
                s.toLowerCase().contains('tindak') ||
                s.toLowerCase().contains('rekomendasi');
            final isNum = s.toLowerCase().contains('jumlah') ||
                s.toLowerCase().contains('luas') ||
                s.toLowerCase().contains('hektar');
            fieldsConfig.add({
              'id': 'f_${s.replaceAll(RegExp(r'\W+'), '_').toLowerCase()}',
              'label': s,
              'type': isLong ? 'textarea' : (isNum ? 'number' : 'text'),
              'placeholder': 'Isi $s...',
              'description': '',
              'required': true,
              'options': <String>[],
            });
          }
        }
      }
    }

    if (fieldsConfig.isEmpty) {
      final rawFields = raw['fields'] ?? raw['placeholders'];
      List<String> stringFields = rawFields is List
          ? rawFields
              .map((e) => e.toString().trim())
              .where(_isValidHumanFieldName)
              .toList()
          : <String>[];
      if (stringFields.isEmpty) {
        stringFields = defaultFieldsForCategory('$title $category');
      }
      for (final s in stringFields) {
        final isLong = s.toLowerCase().contains('hasil') ||
            s.toLowerCase().contains('uraian') ||
            s.toLowerCase().contains('kondisi') ||
            s.toLowerCase().contains('temuan') ||
            s.toLowerCase().contains('tindak') ||
            s.toLowerCase().contains('rekomendasi');
        final isNum = s.toLowerCase().contains('jumlah') ||
            s.toLowerCase().contains('luas') ||
            s.toLowerCase().contains('hektar');
        fieldsConfig.add({
          'id': 'f_${s.replaceAll(RegExp(r'\W+'), '_').toLowerCase()}',
          'label': s,
          'type': isLong ? 'textarea' : (isNum ? 'number' : 'text'),
          'placeholder': 'Isi $s...',
          'description': '',
          'required': true,
          'options': <String>[],
        });
      }
    }

    final List<String> fields = fieldsConfig.map((f) => f['label'] as String).toList();

    String templateBody = (raw['templateBody'] ?? raw['template_body'] ?? '').toString().trim();
    if (templateBody.isEmpty || isCorruptedBinaryText(templateBody)) {
      templateBody = buildCleanDefaultTemplateBody(title, fields);
    }

    return {
      'id': (raw['id'] ?? 'tpl_${DateTime.now().millisecondsSinceEpoch}').toString(),
      'title': title.isEmpty ? 'Laporan Kegiatan' : title,
      'name': title.isEmpty ? 'Laporan Kegiatan' : title,
      'category': category.isEmpty ? 'Penyuluhan' : category,
      'iconKey': (raw['iconKey'] ?? raw['icon_key'] ?? 'description').toString(),
      'description': (raw['description'] ?? 'Template laporan kegiatan lapangan penyuluh kehutanan.').toString(),
      'defaultTitle': (raw['defaultTitle'] ?? raw['default_title'] ?? '').toString(),
      'requirePhoto': raw['requirePhoto'] ?? raw['require_photo'] ?? true,
      'requireLocation': raw['requireLocation'] ?? raw['require_location'] ?? true,
      'sampleFileName': (raw['sampleFileName'] ?? raw['file_name'] ?? '').toString(),
      'fields': fields,
      'fields_config': fieldsConfig,
      'templateBody': templateBody,
      'updatedBy': (raw['updatedBy'] ?? 'Administrator').toString(),
    };
  }

  static List<Map<String, dynamic>>? _memoryCache;
  static Future<List<Map<String, dynamic>>>? _activeFetch;
  static DateTime? _lastFetchTime;

  /// Memuat seluruh template laporan:
  /// - Menggunakan deduplikasi request agar tidak terjadi request ganda/berulang.
  /// - Online: Mengambil template terbaru dari Supabase melalui Laravel API dan menyimpannya ke SQLite & SharedPreferences.
  /// - Offline/Lambat: Menggunakan template terakhir yang tersimpan di SQLite (atau SharedPreferences).
  /// - Menggunakan timeout wajar (8 detik) dan retry terbatas (1x) agar UI tidak terblokir.
  static Future<List<Map<String, dynamic>>> loadTemplates({bool forceRefresh = false}) async {
    // 1. Jika dalam 15 detik terakhir sudah diambil dan tidak dipaksa refresh, kembalikan dari memori
    if (!forceRefresh && _memoryCache != null && _memoryCache!.isNotEmpty && _lastFetchTime != null) {
      if (DateTime.now().difference(_lastFetchTime!).inSeconds < 15) {
        return _memoryCache!;
      }
    }

    // 2. Hindari request berulang bersamaan: jika sedang ada fetch aktif, gunakan Future yang sama
    if (_activeFetch != null) {
      return _activeFetch!;
    }

    _activeFetch = _executeLoadTemplates(forceRefresh: forceRefresh);
    try {
      final result = await _activeFetch!;
      return result;
    } finally {
      _activeFetch = null;
    }
  }

  static Future<List<Map<String, dynamic>>> _executeLoadTemplates({bool forceRefresh = false}) async {
    // 1. Baca cache SQLite terlebih dahulu jika memori belum ada
    if (_memoryCache == null || _memoryCache!.isEmpty) {
      try {
        final sqliteTemplates = await OfflineDatabase.instance.getCachedTemplates();
        if (sqliteTemplates.isNotEmpty) {
          _memoryCache = sqliteTemplates.map(normalizeTemplate).toList();
        }
      } catch (_) {}
    }

    // 2. Fallback baca SharedPreferences jika SQLite belum terisi
    final prefs = await SharedPreferences.getInstance();
    if (_memoryCache == null || _memoryCache!.isEmpty) {
      final raw = prefs.getString(storageKey);
      if (raw != null && raw.isNotEmpty) {
        try {
          final List<dynamic> decoded = jsonDecode(raw);
          if (decoded.isNotEmpty) {
            _memoryCache = decoded.map((e) => normalizeTemplate(Map<String, dynamic>.from(e))).toList();
          }
        } catch (_) {}
      }
    }

    // 3. Ambil data terbaru dari backend Laravel / Supabase (dengan timeout 8 detik & max 1 retry)
    List<Map<String, dynamic>>? liveTemplates;
    int attempts = 0;
    while (attempts < 2 && liveTemplates == null) {
      attempts++;
      try {
        final response = await http
            .get(
              Uri.parse(ApiConstants.reportTemplatesUrl),
              headers: {'Accept': 'application/json'},
            )
            .timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          if (decoded['success'] == true && decoded['data'] is List) {
            final List<dynamic> list = decoded['data'];
            if (list.isNotEmpty) {
              liveTemplates = list.map((item) => normalizeTemplate(Map<String, dynamic>.from(item))).toList();
            }
          }
        }
      } catch (e) {
        if (attempts < 2) {
          await Future.delayed(const Duration(milliseconds: 1500));
        } else {
          debugPrint('ReportTemplateManager fetch info (offline/fallback mode): $e');
        }
      }
    }

    if (liveTemplates != null && liveTemplates.isNotEmpty) {
      _memoryCache = liveTemplates;
      _lastFetchTime = DateTime.now();

      // Sinkronkan ke SQLite untuk penggunaan offline
      try {
        await OfflineDatabase.instance.cacheTemplates(liveTemplates);
      } catch (_) {}

      // Simpan juga ke SharedPreferences
      await prefs.setString(storageKey, jsonEncode(liveTemplates));
      return liveTemplates;
    }

    // 4. Jika fetch live gagal, kembalikan dari cache (SQLite / SharedPreferences)
    if (_memoryCache != null && _memoryCache!.isNotEmpty) {
      return _memoryCache!;
    }

    // 5. Fallback terakhir jika instalasi baru dan offline: gunakan default templates
    final defaults = defaultTemplates();
    _memoryCache = defaults;
    try {
      await OfflineDatabase.instance.cacheTemplates(defaults);
    } catch (_) {}
    await prefs.setString(storageKey, jsonEncode(defaults));
    return defaults;
  }

  /// Menyimpan daftar template ke SQLite, SharedPreferences & menyinkronkannya ke PostgreSQL Supabase.
  static Future<void> saveTemplates(
    List<Map<String, dynamic>> templates,
  ) async {
    final normalized = templates.map(normalizeTemplate).toList();
    _memoryCache = normalized;
    _lastFetchTime = DateTime.now();

    // Simpan ke SQLite
    try {
      await OfflineDatabase.instance.cacheTemplates(normalized);
    } catch (_) {}

    // Simpan ke SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(normalized));
  }

  /// Menyimpan 1 template tertentu dan menyinkronkan langsung ke PostgreSQL Supabase via API.
  static Future<Map<String, dynamic>> saveTemplate(
    Map<String, dynamic> template,
  ) async {
    final clean = normalizeTemplate(template);
    final all = await loadTemplates();
    final idx = all.indexWhere(
      (t) =>
          t['id']?.toString() == clean['id']?.toString() ||
          t['title']?.toString().toLowerCase() == clean['title']?.toString().toLowerCase(),
    );

    if (idx != -1) {
      all[idx] = clean;
    } else {
      all.add(clean);
    }
    await saveTemplates(all);

    // Sinkronkan ke database PostgreSQL Supabase
    try {
      final idStr = clean['id']?.toString() ?? '';
      final isServerNumericId = int.tryParse(idStr) != null;
      final uri = isServerNumericId
          ? Uri.parse(ApiConstants.reportTemplateDetailUrl(idStr))
          : Uri.parse(ApiConstants.reportTemplatesUrl);

      final payload = jsonEncode({
        'name': clean['title'],
        'title': clean['title'],
        'category': clean['category'],
        'description': clean['description'],
        'fields_config': clean['fields_config'],
        'placeholders': clean['fields'],
        'template_body': clean['templateBody'],
        'icon_key': clean['iconKey'],
        'default_title': clean['defaultTitle'],
        'require_photo': clean['requirePhoto'],
        'require_location': clean['requireLocation'],
      });

      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

      if (isServerNumericId) {
        await http.put(uri, headers: headers, body: payload).timeout(const Duration(seconds: 8));
      } else {
        final res = await http.post(uri, headers: headers, body: payload).timeout(const Duration(seconds: 8));
        if (res.statusCode == 200 || res.statusCode == 201) {
          final resJson = jsonDecode(res.body);
          if (resJson['data']?['id'] != null) {
            clean['id'] = resJson['data']['id'].toString();
            clean['serverId'] = resJson['data']['id'];
            await saveTemplates(all);
          }
        }
      }
    } catch (e) {
      debugPrint('Sync template to Supabase offline info: $e');
    }

    return clean;
  }

  /// Mencari template berdasarkan nama jenis laporan.
  static Future<Map<String, dynamic>> findByTitle(String jenisLaporan) async {
    final templates = await loadTemplates();
    final lower = jenisLaporan.trim().toLowerCase();
    for (final t in templates) {
      if (t['title'].toString().trim().toLowerCase() == lower) {
        return t;
      }
    }
    for (final t in templates) {
      if (lower.contains(t['title'].toString().trim().toLowerCase()) ||
          t['title'].toString().trim().toLowerCase().contains(lower)) {
        return t;
      }
    }
    return templates.first;
  }

  /// Merangkai naskah isi laporan berdasarkan template Admin dan isian bagian user.
  static String buildFormattedBody({
    required Map<String, dynamic> template,
    required Map<String, String> fieldValues,
    String additionalNotes = '',
  }) {
    final cleanTemplate = normalizeTemplate(template);
    String body = (cleanTemplate['templateBody'] ?? '').toString().trim();
    final List<String> fields =
        (cleanTemplate['fields'] as List?)?.map((e) => e.toString()).toList() ??
        [];

    if (body.isEmpty || isCorruptedBinaryText(body)) {
      final buffer = StringBuffer();
      buffer.writeln(cleanTemplate['title'].toString().toUpperCase());
      buffer.writeln('Cabang Dinas Kehutanan Wilayah V\n');
      for (int i = 0; i < fields.length; i++) {
        final f = fields[i];
        final val = (fieldValues[f] ?? '').trim();
        buffer.writeln('${i + 1}. $f : ${val.isEmpty ? '-' : val}');
      }
      body = buffer.toString().trim();
    } else {
      for (final f in fields) {
        final val = (fieldValues[f] ?? '').trim();
        body = body.replaceAll('{{$f}}', val.isEmpty ? '-' : val);
      }
      // Bersihkan sisa placeholder {{...}} yang belum terisi agar rapi saat dicetak
      body = body.replaceAllMapped(
        RegExp(r'\{\{([^}]+)\}\}'),
        (m) {
          final key = (m.group(1) ?? '').trim();
          final val = (fieldValues[key] ?? '').trim();
          return val.isNotEmpty ? val : '-';
        },
      );
    }

    if (additionalNotes.trim().isNotEmpty) {
      body = '$body\n\nCatatan Tambahan:\n${additionalNotes.trim()}';
    }

    return body;
  }

  /// Menyaring dan memperbaiki isi laporan (`isi`) jika terdeteksi korup (`PK!...`)
  /// atau kosong sehingga baik tampilan di aplikasi maupun unduhan PDF/Word selalu bersih.
  static String sanitizeReportIsi({
    required String rawIsi,
    required String jenis,
    required String judul,
    required String lokasi,
    Map<String, dynamic>? template,
  }) {
    final trimmed = rawIsi.trim();
    if (trimmed.isNotEmpty && !isCorruptedBinaryText(trimmed)) {
      return trimmed.replaceAll(RegExp(r'\{\{[^}]+\}\}'), '-');
    }

    final List<String> fields = template != null && template['fields'] is List
        ? (template['fields'] as List).map((e) => e.toString()).toList()
        : defaultFieldsForCategory(jenis);

    final Map<String, String> fallbackValues = {};
    for (int i = 0; i < fields.length; i++) {
      final f = fields[i];
      final fl = f.toLowerCase();
      if (fl.contains('lokasi') || fl.contains('kawasan') || fl.contains('blok') || fl.contains('kth') || i == 0) {
        fallbackValues[f] = lokasi.trim().isNotEmpty ? lokasi.trim() : 'Kawasan Hutan CDK Wilayah V Garut';
      } else if (fl.contains('materi') || fl.contains('kegiatan') || fl.contains('jenis') || i == 1) {
        fallbackValues[f] = judul.trim().isNotEmpty ? judul.trim() : jenis;
      } else if (fl.contains('jumlah') || fl.contains('luas')) {
        fallbackValues[f] = 'Terlampir sesuai daftar hadir / pengukuran lapangan';
      } else {
        fallbackValues[f] =
            'Kegiatan $judul di $lokasi telah dilaksanakan dengan baik dan lancar sesuai prosedur lapangan.';
      }
    }

    final cleanTpl = template != null
        ? normalizeTemplate(template)
        : <String, dynamic>{
            'title': jenis.trim().isEmpty ? 'Laporan Kegiatan' : jenis,
            'fields': fields,
            'templateBody': buildCleanDefaultTemplateBody(jenis, fields),
          };

    return buildFormattedBody(
      template: cleanTpl,
      fieldValues: fallbackValues,
    );
  }

  // ---------------------------------------------------------------------------
  // EKSTRAKSI OTOMATIS DARI FILE CONTOH LAPORAN (.DOCX / .DOC / .PDF / .TXT)
  // ---------------------------------------------------------------------------

  static Map<String, dynamic> extractTemplateFromSampleFile({
    required String fileName,
    Uint8List? bytes,
  }) {
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';
    final cleanBaseName = fileName
        .replaceAll(RegExp(r'\.[^.]+$'), '')
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .trim();

    String extractedRawText = '';

    if (bytes != null && bytes.isNotEmpty) {
      if (ext == 'docx' ||
          (bytes.length >= 4 &&
              bytes[0] == 0x50 &&
              bytes[1] == 0x4B &&
              bytes[2] == 0x03 &&
              bytes[3] == 0x04)) {
        extractedRawText = _extractTextFromDocxBytes(bytes);
      } else if (ext == 'pdf' ||
          (bytes.length >= 4 &&
              bytes[0] == 0x25 &&
              bytes[1] == 0x50 &&
              bytes[2] == 0x44 &&
              bytes[3] == 0x46)) {
        extractedRawText = _extractTextFromPdfBytes(bytes);
      } else {
        extractedRawText = _extractPlainText(bytes);
      }
    }

    if (isCorruptedBinaryText(extractedRawText)) {
      extractedRawText = '';
    }

    final List<String> detectedFields = [];
    final List<String> templateLines = [];

    final combinedHint = '$cleanBaseName $extractedRawText'.toLowerCase();
    String inferredCategory = 'Penyuluhan';
    String inferredIcon = 'groups';
    String inferredTitle = cleanBaseName.isNotEmpty
        ? _toTitleCase(cleanBaseName)
        : 'Laporan Kegiatan';
    if (!inferredTitle.toLowerCase().startsWith('laporan')) {
      inferredTitle = 'Laporan $inferredTitle';
    }

    if (combinedHint.contains('trk') ||
        combinedHint.contains('rehab') ||
        combinedHint.contains('tanam') ||
        combinedHint.contains('bibit')) {
      inferredCategory = 'TRK & Rehabilitasi';
      inferredIcon = 'park';
    } else if (combinedHint.contains('monitor') ||
        combinedHint.contains('patroli') ||
        combinedHint.contains('batas')) {
      inferredCategory = 'Monitoring & Patroli';
      inferredIcon = 'forest';
    } else if (combinedHint.contains('kejadian') ||
        combinedHint.contains('kebakaran') ||
        combinedHint.contains('bencana') ||
        combinedHint.contains('darurat')) {
      inferredCategory = 'Kejadian Khusus';
      inferredIcon = 'warning';
    } else if (combinedHint.contains('kegiatan')) {
      inferredCategory = 'Kegiatan Lapangan';
      inferredIcon = 'event_note';
    }

    final rawLines = extractedRawText
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where(_isValidHumanReadableLine)
        .toList();

    final placeholderRegex = RegExp(r'\{\{([^}]+)\}\}|\[([^\]]+)\]');
    final colonLineRegex = RegExp(
      r'^(?:[0-9]+[.)]\s*|-?\s*)?([A-Za-z0-9 /()&-]{3,42})\s*:\s*(.*)$',
    );

    const ignoredStandardLabels = {
      'judul',
      'judul laporan',
      'tanggal',
      'tanggal laporan',
      'hari / tanggal',
      'hari/tanggal',
      'lokasi',
      'lokasi kegiatan',
      'koordinat',
      'latitude',
      'longitude',
      'foto',
      'dokumentasi',
      'nama pegawai',
      'nama penyuluh',
      'status',
    };

    for (final line in rawLines) {
      final matches = placeholderRegex.allMatches(line);
      if (matches.isNotEmpty) {
        String updatedLine = line;
        bool hasValidMatch = false;
        for (final m in matches) {
          final fieldName = (m.group(1) ?? m.group(2) ?? '').trim();
          if (_isValidHumanFieldName(fieldName) &&
              !ignoredStandardLabels.contains(fieldName.toLowerCase())) {
            hasValidMatch = true;
            if (!detectedFields.contains(fieldName)) {
              detectedFields.add(fieldName);
            }
            updatedLine = updatedLine.replaceAll(
              m.group(0)!,
              '{{$fieldName}}',
            );
          }
        }
        if (hasValidMatch && _isValidHumanReadableLine(updatedLine)) {
          templateLines.add(updatedLine);
          continue;
        }
      }

      final colonMatch = colonLineRegex.firstMatch(line);
      if (colonMatch != null) {
        final rawLabel = colonMatch.group(1)!.trim();
        final lowerLabel = rawLabel.toLowerCase();
        if (_isValidHumanFieldName(rawLabel) &&
            !ignoredStandardLabels.contains(lowerLabel) &&
            !lowerLabel.contains('http')) {
          if (!detectedFields.contains(rawLabel)) {
            detectedFields.add(rawLabel);
          }
          final prefix = line.substring(0, line.indexOf(':'));
          templateLines.add('$prefix: {{$rawLabel}}');
          continue;
        }
      }

      if (_isValidHumanReadableLine(line)) {
        templateLines.add(line);
      }
    }

    if (detectedFields.isEmpty) {
      detectedFields.addAll(defaultFieldsForCategory(inferredCategory));
    }

    String finalTemplateBody;
    final candidateBody = templateLines.join('\n').trim();
    if (templateLines.length >= 2 &&
        candidateBody.contains('{{') &&
        !isCorruptedBinaryText(candidateBody)) {
      finalTemplateBody = candidateBody;
    } else {
      finalTemplateBody =
          buildCleanDefaultTemplateBody(inferredTitle, detectedFields);
    }

    return {
      'title': inferredTitle,
      'category': inferredCategory,
      'iconKey': inferredIcon,
      'defaultTitle': 'Pelaksanaan $inferredTitle',
      'description':
          'Template hasil konversi otomatis dari file contoh "$fileName".',
      'sampleFileName': fileName,
      'fields': detectedFields,
      'templateBody': finalTemplateBody,
    };
  }

  /// Mengekstrak teks paragraf dari file `.docx` (ZIP XML) secara lintas platform
  /// (mendukung Android, iOS, Desktop, maupun Flutter Web tanpa menghasilkan byte `PK!`).
  static String _extractTextFromDocxBytes(Uint8List bytes) {
    try {
      const targetName = 'word/document.xml';
      final targetBytes = ascii.encode(targetName);

      // 1. Cari ukuran & offset akurat dari Central Directory ZIP (PK\x01\x02) jika tersedia
      int? cdCompSize;
      int? cdLocalOffset;
      for (int j = bytes.length - 46; j >= 0; j--) {
        if (bytes[j] == 0x50 &&
            bytes[j + 1] == 0x4B &&
            bytes[j + 2] == 0x01 &&
            bytes[j + 3] == 0x02) {
          final fnLen = bytes[j + 28] | (bytes[j + 29] << 8);
          final namePos = j + 46;
          if (fnLen == targetBytes.length &&
              namePos + fnLen <= bytes.length) {
            bool match = true;
            for (int k = 0; k < targetBytes.length; k++) {
              if (bytes[namePos + k] != targetBytes[k]) {
                match = false;
                break;
              }
            }
            if (match) {
              cdCompSize =
                  bytes[j + 20] |
                  (bytes[j + 21] << 8) |
                  (bytes[j + 22] << 16) |
                  (bytes[j + 23] << 24);
              cdLocalOffset =
                  bytes[j + 42] |
                  (bytes[j + 43] << 8) |
                  (bytes[j + 44] << 16) |
                  (bytes[j + 45] << 24);
              break;
            }
          }
        }
      }

      // 2. Telusuri Local File Header (PK\x03\x04) untuk word/document.xml
      int i = cdLocalOffset ?? 0;
      while (i <= bytes.length - 30) {
        if (bytes[i] == 0x50 &&
            bytes[i + 1] == 0x4B &&
            bytes[i + 2] == 0x03 &&
            bytes[i + 3] == 0x04) {
          final compressionMethod = bytes[i + 8] | (bytes[i + 9] << 8);
          final localCompSize =
              bytes[i + 18] |
              (bytes[i + 19] << 8) |
              (bytes[i + 20] << 16) |
              (bytes[i + 21] << 24);
          final compressedSize =
              (localCompSize > 0) ? localCompSize : (cdCompSize ?? 0);
          final fileNameLength = bytes[i + 26] | (bytes[i + 27] << 8);
          final extraFieldLength = bytes[i + 28] | (bytes[i + 29] << 8);

          final nameStart = i + 30;
          if (nameStart + fileNameLength <= bytes.length) {
            bool isTarget = fileNameLength == targetBytes.length;
            if (isTarget) {
              for (int k = 0; k < targetBytes.length; k++) {
                if (bytes[nameStart + k] != targetBytes[k]) {
                  isTarget = false;
                  break;
                }
              }
            }

            final dataStart = nameStart + fileNameLength + extraFieldLength;
            if (isTarget && dataStart < bytes.length) {
              final endIndex =
                  (compressedSize > 0 &&
                      dataStart + compressedSize <= bytes.length)
                  ? dataStart + compressedSize
                  : bytes.length;
              final slice = Uint8List.sublistView(bytes, dataStart, endIndex);

              List<int>? xmlBytes;
              if (compressionMethod == 0) {
                xmlBytes = slice;
              } else if (compressionMethod == 8) {
                // Dekompresi DEFLATE murni lintas platform (berfungsi di Web & Mobile)
                try {
                  xmlBytes = _PureDartDeflate.inflate(slice);
                } catch (_) {}

                // Fallback native RawZLibFilter jika diperlukan di non-Web
                if ((xmlBytes == null || xmlBytes.isEmpty) && !kIsWeb) {
                  try {
                    final filter = RawZLibFilter.inflateFilter(raw: true);
                    filter.process(slice, 0, slice.length);
                    final out = <int>[];
                    List<int>? chunk;
                    while ((chunk = filter.processed()) != null) {
                      out.addAll(chunk!);
                    }
                    xmlBytes = out;
                  } catch (_) {}
                }
              }

              if (xmlBytes != null && xmlBytes.isNotEmpty) {
                final xmlString = utf8.decode(xmlBytes, allowMalformed: true);
                final stripped = _stripXmlToParagraphs(xmlString);
                if (stripped.isNotEmpty && !isCorruptedBinaryText(stripped)) {
                  return stripped;
                }
              }
              break;
            }
          }
        }
        i++;
      }
    } catch (_) {}
    // Jangan pernah mengembalikan byte ZIP mentah (PK!...) jika dekompresi gagal
    return '';
  }

  static String _stripXmlToParagraphs(String xml) {
    final withLineBreaks = xml
        .replaceAll('</w:p>', '\n')
        .replaceAll('</w:tr>', '\n')
        .replaceAll('</w:tc>', '  ')
        .replaceAll('<w:br/>', '\n')
        .replaceAll('<w:br />', '\n')
        .replaceAll('<w:tab/>', ' ');
    final withoutTags = withLineBreaks.replaceAll(RegExp(r'<[^>]+>'), '');
    return withoutTags
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .trim();
  }

  static String _extractTextFromPdfBytes(Uint8List bytes) {
    try {
      final raw = latin1.decode(bytes, allowInvalid: true);
      final matches = RegExp(r'\(([^()\\]{3,120})\)').allMatches(raw);
      final buffer = StringBuffer();
      for (final m in matches) {
        final txt = m.group(1)!.trim();
        if (_isValidHumanReadableLine(txt) &&
            RegExp(r'^[A-Za-z0-9 .,:/()&-]+$').hasMatch(txt)) {
          buffer.writeln(txt);
        }
      }
      final res = buffer.toString().trim();
      if (res.isNotEmpty && !isCorruptedBinaryText(res)) return res;
    } catch (_) {}
    return '';
  }

  static String _extractPlainText(Uint8List bytes) {
    try {
      // Cegah file biner ZIP (.docx) atau PDF dibaca mentah sebagai teks UTF-8
      if (bytes.length >= 4) {
        if ((bytes[0] == 0x50 && bytes[1] == 0x4B) ||
            (bytes[0] == 0x25 &&
                bytes[1] == 0x50 &&
                bytes[2] == 0x44 &&
                bytes[3] == 0x46)) {
          return '';
        }
      }
      final decoded = utf8.decode(bytes, allowMalformed: true);
      if (isCorruptedBinaryText(decoded)) return '';
      final lines = decoded
          .split(RegExp(r'\r?\n'))
          .map(
            (l) =>
                l.replaceAll(RegExp(r'[^\x20-\x7E\u00A0-\u00FF]'), '').trim(),
          )
          .where((l) => l.length >= 3 && _isValidHumanReadableLine(l))
          .toList();
      return lines.take(40).join('\n');
    } catch (_) {
      return '';
    }
  }

  static String _toTitleCase(String input) {
    return input
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) {
          if (w.toUpperCase() == 'TRK' || w.toUpperCase() == 'KTH') {
            return w.toUpperCase();
          }
          return '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';
        })
        .join(' ');
  }
}

// ============================================================================
// GENERATOR & EKSPORTIR DOKUMEN LAPORAN (PDF SIAP CETAK & WORD)
// ============================================================================

class ReportExportResult {
  final bool success;
  final String fileName;
  final String? filePath;
  final String? webBlobUrl;
  final String message;

  const ReportExportResult({
    required this.success,
    required this.fileName,
    this.filePath,
    this.webBlobUrl,
    required this.message,
  });
}

class ReportProcessedPhoto {
  final Uint8List jpegBytes;
  final int width;
  final int height;

  const ReportProcessedPhoto({
    required this.jpegBytes,
    required this.width,
    required this.height,
  });
}

class ReportDocumentExporter {
  static String _formatCurrentDateTime() {
    final now = DateTime.now();
    final List<String> months = [
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
      'Desember'
    ];
    final day = now.day.toString();
    final month = months[now.month - 1];
    final year = now.year.toString();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final second = now.second.toString().padLeft(2, '0');
    return '$day $month $year, Pukul $hour:$minute:$second WIB';
  }

  /// Helper untuk menormalisasi URL foto dari database atau API,
  /// mencegah loopback 'localhost' / '127.0.0.1' yang membuat perangkat mobile hang/stuck.
  static String normalizePhotoUrl(String rawUrl) {
    var url = rawUrl.trim();
    if (url.isEmpty) return '';

    // Ganti localhost / 127.0.0.1 dengan baseUrl server produksi resmi
    if (url.contains('localhost') || url.contains('127.0.0.1')) {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        final path = uri.path;
        final query = uri.hasQuery ? '?${uri.query}' : '';
        return '${ApiConstants.baseUrl}$path$query';
      }
    }

    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      if (url.startsWith('/')) {
        return '${ApiConstants.baseUrl}$url';
      } else {
        return '${ApiConstants.baseUrl}/storage/$url';
      }
    }
    return url;
  }

  /// Mengekstrak data biner satu kandidat foto (Base64, file lokal, atau network URL).
  static Future<Uint8List?> _resolveSinglePhoto(dynamic photoItem) async {
    try {
      if (photoItem == null) return null;
      if (photoItem is Uint8List) return photoItem;

      String? b64;
      String? targetPathOrUrl;

      if (photoItem is Map) {
        if (photoItem['photo_base64'] != null) {
          b64 = photoItem['photo_base64'].toString().trim();
        } else if (photoItem['base64'] != null) {
          b64 = photoItem['base64'].toString().trim();
        }

        if (photoItem['localPhotoPath'] != null) {
          final lp = photoItem['localPhotoPath'].toString().trim();
          if (lp.isNotEmpty && !kIsWeb) {
            final f = File(lp);
            if (await f.exists()) {
              final b = await f.readAsBytes();
              if (b.isNotEmpty) return b;
            }
          }
        }

        targetPathOrUrl = (photoItem['url'] ??
                photoItem['photo'] ??
                photoItem['photo_url'] ??
                photoItem['file_path'])
            ?.toString()
            .trim();
      } else if (photoItem is String) {
        final str = photoItem.trim();
        if (str.startsWith('data:image')) {
          b64 = str;
        } else if (str.length > 200 && !str.startsWith('http') && !str.startsWith('/')) {
          b64 = str;
        } else {
          targetPathOrUrl = str;
        }
      }

      // 1. Ekstrak data Base64 instan (0 ms, tidak memerlukan koneksi internet)
      if (b64 != null && b64.isNotEmpty) {
        final cleanB64 = b64.contains(',') ? b64.split(',').last.trim() : b64;
        try {
          final decoded = base64Decode(cleanB64);
          if (decoded.isNotEmpty) return decoded;
        } catch (_) {}
      }

      if (targetPathOrUrl == null || targetPathOrUrl.isEmpty) return null;

      // 2. Data URI
      if (targetPathOrUrl.startsWith('data:image')) {
        final comma = targetPathOrUrl.indexOf(',');
        if (comma != -1) {
          try {
            return base64Decode(targetPathOrUrl.substring(comma + 1));
          } catch (_) {}
        }
      }

      // 3. File lokal disk (Android / Desktop)
      if (!kIsWeb) {
        try {
          final file = File(targetPathOrUrl);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            if (bytes.isNotEmpty) return bytes;
          }
        } catch (_) {}
      }

      // 4. Unduh dari Server dengan timeout ketat (5s) agar proses download tidak stuck
      final finalUrl = normalizePhotoUrl(targetPathOrUrl);
      if (finalUrl.isNotEmpty) {
        final response = await http
            .get(Uri.parse(finalUrl))
            .timeout(const Duration(seconds: 5));
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          return response.bodyBytes;
        }
      }
    } catch (e) {
      debugPrint('_resolveSinglePhoto warning: $e');
    }
    return null;
  }

  /// Mengambil SELURUH data biner foto lampiran kegiatan yang tercatat pada laporan.
  /// Diproses secara paralel menggunakan [Future.wait] dengan timeout ketat 5 detik.
  static Future<List<Uint8List>> resolveAllPhotoBytes(
    Map<String, dynamic> laporan,
  ) async {
    final List<dynamic> candidates = [];

    // 1. Laporan offline / file lokal
    if (laporan['localPhotoPath'] != null) {
      candidates.add(laporan['localPhotoPath']);
    }
    if (laporan['photo_base64'] != null) {
      candidates.add(laporan['photo_base64']);
    }

    // 2. Relasi 'photos' dari server backend
    if (laporan['photos'] is List && (laporan['photos'] as List).isNotEmpty) {
      for (final item in (laporan['photos'] as List)) {
        if (item != null) candidates.add(item);
      }
    }

    // 3. Field legacy 'foto'
    if (laporan['foto'] != null && laporan['foto'].toString().trim().isNotEmpty) {
      candidates.add(laporan['foto']);
    }

    if (candidates.isEmpty) return [];

    // Unduh seluruh foto secara paralel
    final results = await Future.wait(candidates.map(_resolveSinglePhoto));

    final List<Uint8List> validBytes = [];
    for (final b in results) {
      if (b != null && b.isNotEmpty) {
        final isDup = validBytes.any((exist) =>
            exist.length == b.length &&
            exist.take(16).toList().toString() == b.take(16).toList().toString());
        if (!isDup) {
          validBytes.add(b);
        }
      }
    }

    return validBytes;
  }

  /// Mengambil data biner foto pertama (untuk backwards-compatibility).
  static Future<Uint8List?> resolvePhotoBytes(Map<String, dynamic> laporan) async {
    final all = await resolveAllPhotoBytes(laporan);
    return all.isNotEmpty ? all.first : null;
  }

  static ReportProcessedPhoto? _processImage(Uint8List rawBytes) {
    try {
      final decoded = img.decodeImage(rawBytes);
      if (decoded == null) return null;

      // Koreksi orientasi EXIF otomatis
      final oriented = img.bakeOrientation(decoded);

      // Batasi resolusi maksimum 1024px agar pemrosesan dan ukuran dokumen lebih ringan.
      img.Image toEncode = oriented;
      if (oriented.width > 1024 || oriented.height > 1024) {
        if (oriented.width >= oriented.height) {
          toEncode = img.copyResize(oriented, width: 1024);
        } else {
          toEncode = img.copyResize(oriented, height: 1024);
        }
      }

      final jpeg = Uint8List.fromList(img.encodeJpg(toEncode, quality: 80));
      return ReportProcessedPhoto(
        jpegBytes: jpeg,
        width: toEncode.width,
        height: toEncode.height,
      );
    } catch (e) {
      debugPrint('Error processing image for export: $e');
      return null;
    }
  }

  /// Mengekspor laporan menjadi file PDF (.pdf) atau Word (.doc).
  /// - Di Flutter Web (Chrome/Edge): Menggunakan `XFile.fromData(...).saveTo(...)`
  ///   yang membuat `Blob` Object URL (`blob:http://...`) dan memicu `<a download>`
  ///   secara langsung sehingga TIDAK diblokir Chrome (tidak muncul tab Untitled abu-abu).
  /// - Di Android/Desktop: Menyimpan langsung ke folder Download perangkat.
  static Future<ReportExportResult> exportReport(
    Map<String, dynamic> laporan, {
    String format = 'pdf',
    bool openInNewTabOnWeb = false,
    void Function(String status)? onProgress,
  }) async {
    final isPdf = format.toLowerCase() == 'pdf';
    final rawTitle = (laporan['judul'] ?? 'Laporan_Kegiatan').toString();
    final safeTitle = rawTitle
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
    final ext = isPdf ? 'pdf' : 'doc';
    final fileName = '${safeTitle.isEmpty ? 'Laporan' : safeTitle}.$ext';

    onProgress?.call('Menyiapkan naskah laporan...');
    final enrichedLaporan = await _ensureFormattedReportContent(laporan);

    onProgress?.call('Memeriksa lampiran foto dokumentasi...');
    final rawPhotoBytesList = await resolveAllPhotoBytes(laporan);

    final List<ReportProcessedPhoto> processedPhotos = [];
    if (rawPhotoBytesList.isNotEmpty) {
      onProgress?.call('Mengoptimalkan ${rawPhotoBytesList.length} foto lampiran...');
      for (final rawBytes in rawPhotoBytesList) {
        try {
          final processed = await compute(_processImage, rawBytes);
          if (processed != null) {
            processedPhotos.add(processed);
          }
        } catch (_) {}
      }
    }

    final String waktuUnduh = _formatCurrentDateTime();

    onProgress?.call('Menyusun format dokumen ${isPdf ? 'PDF' : 'Word'}...');
    final Uint8List fileBytes = isPdf
        ? generatePdfBytes(
            enrichedLaporan,
            photo: processedPhotos.isNotEmpty ? processedPhotos.first : null,
            photos: processedPhotos,
            waktuUnduh: waktuUnduh,
          )
        : generateWordDocBytes(
            enrichedLaporan,
            photo: processedPhotos.isNotEmpty ? processedPhotos.first : null,
            photos: processedPhotos,
            waktuUnduh: waktuUnduh,
          );

    onProgress?.call('Menyimpan berkas ke perangkat...');

    // 1. Penanganan khusus Flutter Web (Chrome / Edge / Firefox)
    if (kIsWeb) {
      try {
        final mime = isPdf ? 'application/pdf' : 'application/msword';
        final xfile = XFile.fromData(
          fileBytes,
          mimeType: mime,
          name: fileName,
        );

        // xfile.path di Flutter Web adalah Blob Object URL (`blob:http://...`)
        final blobUrl = xfile.path;

        if (openInNewTabOnWeb && blobUrl.startsWith('blob:')) {
          // Buka Blob URL di tab baru (Chrome mengizinkan blob: URL dan
          // menampilkan PDF Viewer bawaan lengkap dengan tombol Print!)
          await launchUrl(
            Uri.parse(blobUrl),
            webOnlyWindowName: '_blank',
          );
          return ReportExportResult(
            success: true,
            fileName: fileName,
            webBlobUrl: blobUrl,
            message:
                'PDF dibuka di tab baru. Silakan gunakan tombol Print / Download di pojok kanan atas.',
          );
        }

        // Memicu unduhan langsung (<a href="blob:..." download="fileName">.click())
        await xfile.saveTo(fileName);

        return ReportExportResult(
          success: true,
          fileName: fileName,
          webBlobUrl: blobUrl,
          message:
              'File "$fileName" berhasil diunduh ke folder Downloads browser Anda.',
        );
      } catch (e) {
        return ReportExportResult(
          success: false,
          fileName: fileName,
          message: 'Gagal mengunduh dokumen di browser: $e',
        );
      }
    }

    // 2. Penanganan Android, Windows, Linux, macOS: simpan langsung ke folder Download publik HP
    try {
      final saveRes = await DeviceFileStorageService.instance.saveToDownloads(
        bytes: fileBytes,
        fileName: fileName,
        mimeType: isPdf ? 'application/pdf' : 'application/msword',
        subfolder: 'Phonebook_Laporan',
      );

      return ReportExportResult(
        success: saveRes.success,
        fileName: saveRes.fileName,
        filePath: saveRes.filePath,
        message: saveRes.success
            ? 'Laporan berhasil diunduh dan tersimpan di folder ${saveRes.displayPath}'
            : saveRes.message,
      );
    } catch (e) {
      return ReportExportResult(
        success: false,
        fileName: fileName,
        message: 'Gagal menyimpan file laporan ke folder Download: $e',
      );
    }
  }

  /// Mengunduh hanya file foto lampiran ke folder Download HP.
  static Future<ReportExportResult> exportPhotoOnly(
    Map<String, dynamic> laporan,
  ) async {
    final rawTitle = (laporan['judul'] ?? 'Foto_Laporan').toString();
    final safeTitle = rawTitle
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
    final fileName = 'Foto_${safeTitle.isEmpty ? 'Laporan' : safeTitle}.jpg';

    final rawPhotoBytes = await resolvePhotoBytes(laporan);
    if (rawPhotoBytes == null || rawPhotoBytes.isEmpty) {
      return ReportExportResult(
        success: false,
        fileName: fileName,
        message: 'Laporan ini tidak memiliki berkas foto lampiran.',
      );
    }

    final processedPhoto = await compute(_processImage, rawPhotoBytes);
    final bytesToSave = processedPhoto?.jpegBytes ?? rawPhotoBytes;

    if (kIsWeb) {
      try {
        final xfile = XFile.fromData(
          bytesToSave,
          mimeType: 'image/jpeg',
          name: fileName,
        );
        await xfile.saveTo(fileName);
        return ReportExportResult(
          success: true,
          fileName: fileName,
          webBlobUrl: xfile.path,
          message: 'Foto berhasil diunduh ke folder Downloads browser Anda.',
        );
      } catch (e) {
        return ReportExportResult(
          success: false,
          fileName: fileName,
          message: 'Gagal mengunduh foto di browser: $e',
        );
      }
    }

    try {
      final saveRes = await DeviceFileStorageService.instance.saveToDownloads(
        bytes: bytesToSave,
        fileName: fileName,
        mimeType: 'image/jpeg',
        subfolder: 'Phonebook_Laporan',
      );

      return ReportExportResult(
        success: saveRes.success,
        fileName: saveRes.fileName,
        filePath: saveRes.filePath,
        message: saveRes.success
            ? 'Foto lampiran berhasil diunduh ke folder ${saveRes.displayPath}'
            : saveRes.message,
      );
    } catch (e) {
      return ReportExportResult(
        success: false,
        fileName: fileName,
        message: 'Gagal menyimpan foto lampiran: $e',
      );
    }
  }

  /// Membuka file yang sudah diunduh (baik di Native maupun Blob URL di Web).
  static Future<void> openExportedFile(ReportExportResult result) async {
    try {
      if (kIsWeb &&
          result.webBlobUrl != null &&
          result.webBlobUrl!.isNotEmpty) {
        await launchUrl(
          Uri.parse(result.webBlobUrl!),
          webOnlyWindowName: '_blank',
        );
        return;
      }
      if (result.filePath != null && result.filePath!.isNotEmpty) {
        final String mime;
        if (result.fileName.endsWith('.pdf')) {
          mime = 'application/pdf';
        } else if (result.fileName.endsWith('.doc')) {
          mime = 'application/msword';
        } else if (result.fileName.endsWith('.jpg') ||
            result.fileName.endsWith('.jpeg')) {
          mime = 'image/jpeg';
        } else {
          mime = 'application/octet-stream';
        }
        await DeviceFileStorageService.instance.openFile(
          result.filePath!,
          mimeType: mime,
        );
      }
    } catch (_) {}
  }

  /// Memastikan laporan selalu memiliki isi naskah terstruktur sesuai template
  /// meskipun template belum diedit manual oleh Admin.
  static Future<Map<String, dynamic>> _ensureFormattedReportContent(
    Map<String, dynamic> laporan,
  ) async {
    final copy = Map<String, dynamic>.from(laporan);
    final rawIsi = (copy['isi'] ?? '').toString().trim();
    final jenis = (copy['jenis'] ?? 'Laporan Penyuluhan').toString();
    final judul = (copy['judul'] ?? 'Kegiatan Lapangan').toString();
    final lokasi = (copy['lokasi'] ?? 'Kawasan Hutan Garut').toString();

    final isCorrupted = ReportTemplateManager.isCorruptedBinaryText(rawIsi);
    if (rawIsi.isEmpty || !rawIsi.contains('\n') || isCorrupted) {
      final template = await ReportTemplateManager.findByTitle(jenis);
      copy['isi'] = ReportTemplateManager.sanitizeReportIsi(
        rawIsi: isCorrupted ? '' : rawIsi,
        jenis: jenis,
        judul: judul,
        lokasi: lokasi,
        template: template,
      );
    } else {
      copy['isi'] = rawIsi.replaceAll(RegExp(r'\{\{[^}]+\}\}'), '-');
    }
    return copy;
  }

  /// Menghasilkan file PDF 1.4 standar (biner valid) siap print.
  /// Jika laporan memiliki foto lampiran, dokumen otomatis disusun 2 halaman
  /// dengan Halaman 2 sebagai Lampiran Foto Dokumentasi resmi.
  static Uint8List generatePdfBytes(
    Map<String, dynamic> laporan, {
    ReportProcessedPhoto? photo,
    List<ReportProcessedPhoto> photos = const [],
    String? waktuUnduh,
  }) {
    final List<ReportProcessedPhoto> allPhotos = [
      ?photo,
      ...photos,
    ];
    final uniquePhotos = <ReportProcessedPhoto>[];
    for (final p in allPhotos) {
      if (!uniquePhotos.contains(p)) uniquePhotos.add(p);
    }
    final photoToUse = uniquePhotos.isNotEmpty ? uniquePhotos.first : null;

    final judul = _cleanPdfText(
      (laporan['judul'] ?? 'Laporan Kegiatan Lapangan').toString(),
    );
    final jenis = _cleanPdfText(
      (laporan['jenis'] ?? 'Laporan Penyuluhan').toString(),
    );
    final pelapor = _cleanPdfText(
      (laporan['pelapor'] ??
              laporan['userName'] ??
              'Penyuluh Kehutanan CDK Wilayah V')
          .toString(),
    );
    final tanggal = _cleanPdfText((laporan['tanggal'] ?? '-').toString());
    final lokasi = _cleanPdfText((laporan['lokasi'] ?? '-').toString());
    final status = _cleanPdfText((laporan['status'] ?? 'Selesai').toString());
    final lat = _cleanPdfText((laporan['latitude'] ?? '').toString());
    final lng = _cleanPdfText((laporan['longitude'] ?? '').toString());
    final koordinat = (lat.isNotEmpty && lng.isNotEmpty)
        ? '$lat, $lng'
        : 'Terlampir pada sistem';
    final rawIsiCandidate = (laporan['isi'] ?? '').toString().trim();
    final bool isMonitoring = MonitoringCalculator.isMonitoringReportType(
      laporan['jenis']?.toString(),
      laporan['report_type']?.toString(),
    );
    final Map<String, dynamic> monitoringMap = isMonitoring
        ? MonitoringCalculator.extractMonitoringMap(laporan)
        : const <String, dynamic>{};
    final bool hasStructuredMonitoring =
        isMonitoring &&
        (monitoringMap['activity_name'] != null ||
            monitoringMap['target_value'] != null ||
            monitoringMap['actual_value'] != null);

    final isiRaw = hasStructuredMonitoring
        ? MonitoringCalculator.buildFormattedMonitoringBody({
            ...laporan,
            ...monitoringMap,
            'title': judul,
            'location': lokasi,
            'activity_date': tanggal,
          })
        : (ReportTemplateManager.isCorruptedBinaryText(rawIsiCandidate)
              ? ReportTemplateManager.sanitizeReportIsi(
                  rawIsi: '',
                  jenis: (laporan['jenis'] ?? 'Laporan Penyuluhan').toString(),
                  judul: (laporan['judul'] ?? 'Kegiatan Lapangan').toString(),
                  lokasi: (laporan['lokasi'] ?? 'Kawasan Hutan Garut').toString(),
                )
              : rawIsiCandidate);

    final bool hasAttachedPhoto = photoToUse != null;

    // Susun Halaman 1 (Header + Metadata) dan aliran baris isi laporan (mendukung halaman lanjutan).
    final page1Header = StringBuffer();

    void writeTextTo(
      StringBuffer target,
      String text,
      double x,
      double y, {
      bool bold = false,
      int fontSize = 11,
    }) {
      final fontKey = bold ? '/F2' : '/F1';
      final escaped = _escapePdfLiteral(_cleanPdfText(text));
      target.writeln('BT $fontKey $fontSize Tf $x $y Td ($escaped) Tj ET');
    }

    // Garis Atas Kop Surat
    page1Header.writeln('0.14 0.36 0.23 rg');
    page1Header.writeln('50 792 495 3 re f');
    page1Header.writeln('0 0 0 rg');

    // Header Kop Instansi
    writeTextTo(
      page1Header,
      'PEMERINTAH DAERAH PROVINSI JAWA BARAT',
      155,
      772,
      bold: true,
      fontSize: 12,
    );
    writeTextTo(page1Header, 'DINAS KEHUTANAN', 238, 756, bold: true, fontSize: 13);
    writeTextTo(
      page1Header,
      'CABANG DINAS KEHUTANAN WILAYAH V GARUT',
      150,
      740,
      bold: true,
      fontSize: 12,
    );
    writeTextTo(
      page1Header,
      'Dokumen Laporan Resmi Kegiatan Penyuluhan & Pengelolaan Kehutanan',
      128,
      725,
      fontSize: 9,
    );

    // Garis pembatas kop
    page1Header.writeln('0.14 0.36 0.23 rg');
    page1Header.writeln('50 714 495 1.5 re f');
    page1Header.writeln('0 0 0 rg');

    // Judul Dokumen
    writeTextTo(page1Header, jenis.toUpperCase(), 50, 690, bold: true, fontSize: 13);
    writeTextTo(page1Header, judul, 50, 673, bold: true, fontSize: 11);

    // Kotak Metadata Laporan
    final double metaBoxHeight = hasAttachedPhoto ? 104 : 92;
    final double metaBoxY = hasAttachedPhoto ? 556 : 568;
    page1Header.writeln('0.95 0.97 0.95 rg');
    page1Header.writeln('50 $metaBoxY 495 $metaBoxHeight re f');
    page1Header.writeln('0 0 0 rg');

    writeTextTo(page1Header, 'Nama Pegawai / Penyuluh', 62, 642, bold: true, fontSize: 10);
    writeTextTo(page1Header, ':  $pelapor', 205, 642, fontSize: 10);

    writeTextTo(page1Header, 'Jenis Laporan', 62, 626, bold: true, fontSize: 10);
    writeTextTo(page1Header, ':  $jenis', 205, 626, fontSize: 10);

    writeTextTo(page1Header, 'Tanggal Laporan', 62, 610, bold: true, fontSize: 10);
    writeTextTo(page1Header, ':  $tanggal', 205, 610, fontSize: 10);

    writeTextTo(page1Header, 'Lokasi Kegiatan', 62, 594, bold: true, fontSize: 10);
    writeTextTo(page1Header, ':  $lokasi', 205, 594, fontSize: 10);

    writeTextTo(page1Header, 'Titik Koordinat', 62, 578, bold: true, fontSize: 10);
    writeTextTo(page1Header, ':  $koordinat  (Status: $status)', 150, 578, fontSize: 10);

    if (hasAttachedPhoto) {
      writeTextTo(page1Header, 'Foto Dokumentasi', 62, 562, bold: true, fontSize: 10);
      writeTextTo(
        page1Header,
        ':  Terlampir Resmi pada Halaman Lampiran Dokumen',
        205,
        562,
        fontSize: 10,
      );
    }

    // Bagian Isi Laporan
    final double sectionTitleY = hasAttachedPhoto ? 532 : 544;
    writeTextTo(
      page1Header,
      isMonitoring
          ? 'RINGKASAN & EVALUASI LAPORAN MONITORING:'
          : 'URAIAN & HASIL KEGIATAN LAPANGAN:',
      50,
      sectionTitleY,
      bold: true,
      fontSize: 11,
    );
    page1Header.writeln('0.80 0.85 0.80 rg');
    page1Header.writeln('50 ${sectionTitleY - 7} 495 0.8 re f');
    page1Header.writeln('0 0 0 rg');

    final bodyLines = _wrapTextLines(
      isiRaw.isNotEmpty
          ? isiRaw
          : 'Laporan kegiatan telah dilaksanakan sesuai jadwal dan prosedur lapangan.',
      maxCharsPerLine: 78,
    );

    final double lineStep = isMonitoring ? 13.5 : 15.0;
    final List<StringBuffer> textPageBuffers = <StringBuffer>[page1Header];

    // Kapasitas Halaman 1 jika hanya 1 halaman teks vs multi halaman
    final int page1MaxAboveSign = ((sectionTitleY - 24 - 165) / lineStep).floor() + 1;
    final bool needsOverflowPages = bodyLines.length > page1MaxAboveSign;

    int lineCursor = 0;
    double currentY = sectionTitleY - 24;
    final double page1MinY = needsOverflowPages ? 68 : 165;
    while (lineCursor < bodyLines.length && currentY >= page1MinY) {
      final line = bodyLines[lineCursor++];
      final isSectionLine =
          RegExp(r'^[0-9]+\.').hasMatch(line) ||
          (line == line.toUpperCase() && line.length > 5);
      writeTextTo(
        textPageBuffers.first,
        _cleanPdfText(line),
        50,
        currentY,
        bold: isSectionLine,
        fontSize: isMonitoring ? 9 : 10,
      );
      currentY -= lineStep;
    }

    while (lineCursor < bodyLines.length) {
      final contBuf = StringBuffer();
      contBuf.writeln('0.14 0.36 0.23 rg');
      contBuf.writeln('50 792 495 2 re f');
      contBuf.writeln('0 0 0 rg');
      writeTextTo(
        contBuf,
        'LANJUTAN: ${jenis.toUpperCase()} - $judul',
        50,
        772,
        bold: true,
        fontSize: 10,
      );
      contBuf.writeln('0.80 0.85 0.80 rg');
      contBuf.writeln('50 762 495 0.8 re f');
      contBuf.writeln('0 0 0 rg');

      double contY = 742;
      final remainingAfterThis = bodyLines.length - lineCursor;
      final maxFitWithSign = ((742 - 165) / lineStep).floor() + 1;
      final double minYForThisPage =
          remainingAfterThis <= maxFitWithSign ? 165 : 68;
      while (lineCursor < bodyLines.length && contY >= minYForThisPage) {
        final line = bodyLines[lineCursor++];
        final isSectionLine =
            RegExp(r'^[0-9]+\.').hasMatch(line) ||
            (line == line.toUpperCase() && line.length > 5);
        writeTextTo(
          contBuf,
          _cleanPdfText(line),
          50,
          contY,
          bold: isSectionLine,
          fontSize: isMonitoring ? 9 : 10,
        );
        contY -= lineStep;
      }
      textPageBuffers.add(contBuf);
    }

    final int photoPageCount = hasAttachedPhoto ? 1 : 0;
    final int totalPages = textPageBuffers.length + photoPageCount;

    // Blok Tanda Tangan diletakkan pada halaman teks terakhir
    final lastTextBuf = textPageBuffers.last;
    lastTextBuf.writeln('0.80 0.85 0.80 rg');
    lastTextBuf.writeln('50 145 495 0.8 re f');
    lastTextBuf.writeln('0 0 0 rg');

    writeTextTo(lastTextBuf, 'Garut, $tanggal', 360, 125, fontSize: 10);
    writeTextTo(
      lastTextBuf,
      'Penyuluh / Petugas Pelaksana,',
      360,
      111,
      bold: true,
      fontSize: 10,
    );
    writeTextTo(lastTextBuf, pelapor, 360, 62, bold: true, fontSize: 10);

    for (int pageIdx = 0; pageIdx < textPageBuffers.length; pageIdx++) {
      final buf = textPageBuffers[pageIdx];
      final String footerText = totalPages > 1
          ? 'Aplikasi Phonebook CDK Wilayah V  •  Halaman ${pageIdx + 1} dari $totalPages'
          : 'Dicetak otomatis melalui Aplikasi Phonebook CDK Wilayah V';
      writeTextTo(buf, footerText, 50, 42, fontSize: 8);
      if (waktuUnduh != null && waktuUnduh.isNotEmpty) {
        writeTextTo(buf, 'Waktu Unduh: $waktuUnduh', 290, 42, fontSize: 8);
      }
    }

    // Pembuatan Halaman Lampiran Foto jika foto tersedia
    final pagePhotoBuffer = StringBuffer();
    if (hasAttachedPhoto) {
      void drawPhotoPageText(
        String text,
        double x,
        double y, {
        bool bold = false,
        int fontSize = 11,
      }) {
        final fontKey = bold ? '/F2' : '/F1';
        final escaped = _escapePdfLiteral(_cleanPdfText(text));
        pagePhotoBuffer.writeln('BT $fontKey $fontSize Tf $x $y Td ($escaped) Tj ET');
      }

      // Garis Atas Hijau Kop Surat
      pagePhotoBuffer.writeln('0.14 0.36 0.23 rg');
      pagePhotoBuffer.writeln('50 792 495 3 re f');
      pagePhotoBuffer.writeln('0 0 0 rg');

      // Header Kop Instansi Halaman Foto
      drawPhotoPageText(
        'PEMERINTAH DAERAH PROVINSI JAWA BARAT',
        155,
        772,
        bold: true,
        fontSize: 12,
      );
      drawPhotoPageText('DINAS KEHUTANAN', 238, 756, bold: true, fontSize: 13);
      drawPhotoPageText(
        'CABANG DINAS KEHUTANAN WILAYAH V GARUT',
        150,
        740,
        bold: true,
        fontSize: 12,
      );
      drawPhotoPageText(
        'LAMPIRAN DOKUMENTASI FOTO KEGIATAN LAPANGAN',
        135,
        724,
        bold: true,
        fontSize: 11,
      );

      // Garis pembatas kop
      pagePhotoBuffer.writeln('0.14 0.36 0.23 rg');
      pagePhotoBuffer.writeln('50 714 495 1.5 re f');
      pagePhotoBuffer.writeln('0 0 0 rg');

      // Kotak Metadata Halaman Foto
      pagePhotoBuffer.writeln('0.95 0.97 0.95 rg');
      pagePhotoBuffer.writeln('50 638 495 68 re f');
      pagePhotoBuffer.writeln('0 0 0 rg');

      drawPhotoPageText('Judul Laporan', 62, 688, bold: true, fontSize: 10);
      drawPhotoPageText(':  $judul', 180, 688, fontSize: 10);

      drawPhotoPageText('Pelapor / Petugas', 62, 672, bold: true, fontSize: 10);
      drawPhotoPageText(':  $pelapor   ($jenis)', 180, 672, fontSize: 10);

      drawPhotoPageText('Waktu Pelaksanaan', 62, 656, bold: true, fontSize: 10);
      drawPhotoPageText(':  $tanggal   (Status: $status)', 180, 656, fontSize: 10);

      drawPhotoPageText('Lokasi & Koordinat', 62, 642, bold: true, fontSize: 10);
      drawPhotoPageText(':  $lokasi  [$koordinat]', 180, 642, fontSize: 10);

      // Hitung posisi dan ukuran gambar agar aspect ratio foto selalu presisi
      const double maxPhotoW = 475;
      const double maxPhotoH = 370;
      final double aspect = photoToUse.width / photoToUse.height;
      double drawW;
      double drawH;
      if (aspect > (maxPhotoW / maxPhotoH)) {
        drawW = maxPhotoW;
        drawH = maxPhotoW / aspect;
      } else {
        drawH = maxPhotoH;
        drawW = maxPhotoH * aspect;
      }

      final double drawX = 50 + (495 - drawW) / 2;
      final double drawY = 225 + (395 - drawH) / 2;

      // Bingkai Latar dan Garis Tepi Foto
      pagePhotoBuffer.writeln('0.92 0.94 0.92 rg');
      pagePhotoBuffer.writeln('${(drawX - 3).toStringAsFixed(1)} ${(drawY - 3).toStringAsFixed(1)} ${(drawW + 6).toStringAsFixed(1)} ${(drawH + 6).toStringAsFixed(1)} re f');
      pagePhotoBuffer.writeln('0.75 0.82 0.75 RG');
      pagePhotoBuffer.writeln('1.2 w');
      pagePhotoBuffer.writeln('${(drawX - 3).toStringAsFixed(1)} ${(drawY - 3).toStringAsFixed(1)} ${(drawW + 6).toStringAsFixed(1)} ${(drawH + 6).toStringAsFixed(1)} re S');
      pagePhotoBuffer.writeln('0 0 0 rg');

      // Gambar Image XObject
      pagePhotoBuffer.writeln('q ${drawW.toStringAsFixed(1)} 0 0 ${drawH.toStringAsFixed(1)} ${drawX.toStringAsFixed(1)} ${drawY.toStringAsFixed(1)} cm /Im1 Do Q');

      // Keterangan di bawah foto
      final double captionY = drawY - 20;
      drawPhotoPageText(
        'Dokumentasi Resmi Kegiatan: $judul',
        50,
        captionY,
        bold: true,
        fontSize: 10,
      );
      drawPhotoPageText(
        'Lokasi: $lokasi | Titik Koordinat: $koordinat',
        50,
        captionY - 14,
        fontSize: 9,
      );
      if (waktuUnduh != null && waktuUnduh.isNotEmpty) {
        drawPhotoPageText(
          'Waktu Diunduh & Dicetak: $waktuUnduh',
          50,
          captionY - 28,
          fontSize: 9,
        );
      }

      // Garis Pemisah Footer
      pagePhotoBuffer.writeln('0.80 0.85 0.80 rg');
      pagePhotoBuffer.writeln('50 135 495 0.8 re f');
      pagePhotoBuffer.writeln('0 0 0 rg');

      // Tanda Tangan Ringkas di Halaman Lampiran Foto
      drawPhotoPageText('Garut, $tanggal', 360, 115, fontSize: 10);
      drawPhotoPageText(
        'Petugas Pelaksana,',
        360,
        101,
        bold: true,
        fontSize: 10,
      );
      drawPhotoPageText(pelapor, 360, 56, bold: true, fontSize: 10);

      drawPhotoPageText(
        'Aplikasi Phonebook CDK Wilayah V  •  Halaman $totalPages dari $totalPages (Lampiran Foto Dokumentasi)',
        50,
        42,
        fontSize: 8,
      );
    }

    final textStreamBytesList = textPageBuffers
        .map((buf) => latin1.encode(buf.toString()))
        .toList();
    final photoStreamBytes = hasAttachedPhoto
        ? latin1.encode(pagePhotoBuffer.toString())
        : null;

    final pdfBuffer = BytesBuilder();
    final offsets = <int>[0];

    void writeAscii(String s) {
      pdfBuffer.add(latin1.encode(s));
    }

    writeAscii('%PDF-1.4\n');

    final List<int> kidPageObjIds = <int>[
      for (int i = 0; i < textStreamBytesList.length; i++) 5 + (i * 2),
      if (hasAttachedPhoto) 5 + (textStreamBytesList.length * 2),
    ];

    // 1 0 obj: Catalog
    offsets.add(pdfBuffer.length);
    writeAscii('1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n');

    // 2 0 obj: Pages
    offsets.add(pdfBuffer.length);
    final kidsStr = kidPageObjIds.map((id) => '$id 0 R').join(' ');
    writeAscii('2 0 obj\n<< /Type /Pages /Kids [$kidsStr] /Count $totalPages >>\nendobj\n');

    // 3 0 obj: Font F1
    offsets.add(pdfBuffer.length);
    writeAscii(
      '3 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>\nendobj\n',
    );

    // 4 0 obj: Font F2
    offsets.add(pdfBuffer.length);
    writeAscii(
      '4 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>\nendobj\n',
    );

    // Text pages (pairs of Page + Contents Stream starting at obj 5)
    for (int i = 0; i < textStreamBytesList.length; i++) {
      final pageObjId = 5 + (i * 2);
      final streamObjId = pageObjId + 1;
      final streamBytes = textStreamBytesList[i];

      offsets.add(pdfBuffer.length);
      writeAscii(
        '$pageObjId 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] '
        '/Resources << /Font << /F1 3 0 R /F2 4 0 R >> >> '
        '/Contents $streamObjId 0 R >>\nendobj\n',
      );

      offsets.add(pdfBuffer.length);
      writeAscii('$streamObjId 0 obj\n<< /Length ${streamBytes.length} >>\nstream\n');
      pdfBuffer.add(streamBytes);
      writeAscii('\nendstream\nendobj\n');
    }

    if (hasAttachedPhoto && photoStreamBytes != null) {
      final photoPageObjId = 5 + (textStreamBytesList.length * 2);
      final photoStreamObjId = photoPageObjId + 1;
      final imageObjId = photoPageObjId + 2;

      offsets.add(pdfBuffer.length);
      writeAscii(
        '$photoPageObjId 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] '
        '/Resources << /Font << /F1 3 0 R /F2 4 0 R >> /XObject << /Im1 $imageObjId 0 R >> >> '
        '/Contents $photoStreamObjId 0 R >>\nendobj\n',
      );

      offsets.add(pdfBuffer.length);
      writeAscii('$photoStreamObjId 0 obj\n<< /Length ${photoStreamBytes.length} >>\nstream\n');
      pdfBuffer.add(photoStreamBytes);
      writeAscii('\nendstream\nendobj\n');

      offsets.add(pdfBuffer.length);
      writeAscii(
        '$imageObjId 0 obj\n<< /Type /XObject /Subtype /Image '
        '/Width ${photoToUse.width} /Height ${photoToUse.height} '
        '/ColorSpace /DeviceRGB /BitsPerComponent 8 '
        '/Filter /DCTDecode /Length ${photoToUse.jpegBytes.length} >>\nstream\n',
      );
      pdfBuffer.add(photoToUse.jpegBytes);
      writeAscii('\nendstream\nendobj\n');
    }

    final int objectCount = offsets.length - 1;
    final xrefOffset = pdfBuffer.length;
    writeAscii('xref\n0 ${objectCount + 1}\n0000000000 65535 f \n');
    for (int idx = 1; idx <= objectCount; idx++) {
      final offStr = offsets[idx].toString().padLeft(10, '0');
      writeAscii('$offStr 00000 n \n');
    }

    writeAscii(
      'trailer\n<< /Size ${objectCount + 1} /Root 1 0 R >>\nstartxref\n$xrefOffset\n%%EOF\n',
    );

    return pdfBuffer.toBytes();
  }

  /// Menghasilkan dokumen Word (.doc) yang dapat dibuka di Microsoft Word.
  /// Foto lampiran otomatis disertakan dalam dokumen secara inline (Base64).
  static Uint8List generateWordDocBytes(
    Map<String, dynamic> laporan, {
    ReportProcessedPhoto? photo,
    List<ReportProcessedPhoto> photos = const [],
    String? waktuUnduh,
  }) {
    final List<ReportProcessedPhoto> allPhotos = [
      ?photo,
      ...photos,
    ];
    final uniquePhotos = <ReportProcessedPhoto>[];
    for (final p in allPhotos) {
      if (!uniquePhotos.contains(p)) uniquePhotos.add(p);
    }

    final judul = (laporan['judul'] ?? 'Laporan Kegiatan').toString();
    final jenis = (laporan['jenis'] ?? 'Laporan Penyuluhan').toString();
    final pelapor =
        (laporan['pelapor'] ??
                laporan['userName'] ??
                'Penyuluh Kehutanan CDK Wilayah V')
            .toString();
    final tanggal = (laporan['tanggal'] ?? '-').toString();
    final lokasi = (laporan['lokasi'] ?? '-').toString();
    final status = (laporan['status'] ?? 'Selesai').toString();
    final lat = (laporan['latitude'] ?? '').toString();
    final lng = (laporan['longitude'] ?? '').toString();
    final rawWordIsi = (laporan['isi'] ?? '').toString().trim();
    final bool isMonitoring = MonitoringCalculator.isMonitoringReportType(
      laporan['jenis']?.toString(),
      laporan['report_type']?.toString(),
    );
    final Map<String, dynamic> monitoringMap = isMonitoring
        ? MonitoringCalculator.extractMonitoringMap(laporan)
        : const <String, dynamic>{};
    final bool hasStructuredMonitoring =
        isMonitoring &&
        (monitoringMap['activity_name'] != null ||
            monitoringMap['target_value'] != null ||
            monitoringMap['actual_value'] != null);

    final cleanWordIsi = hasStructuredMonitoring
        ? MonitoringCalculator.buildFormattedMonitoringBody({
            ...laporan,
            ...monitoringMap,
            'title': judul,
            'location': lokasi,
            'activity_date': tanggal,
          })
        : (ReportTemplateManager.isCorruptedBinaryText(rawWordIsi)
              ? ReportTemplateManager.sanitizeReportIsi(
                  rawIsi: '',
                  jenis: jenis,
                  judul: judul,
                  lokasi: lokasi,
                )
              : rawWordIsi);
    final isi = cleanWordIsi.replaceAll('\n', '<br/>');

    String monitoringHtmlSection = '';
    if (isMonitoring) {
      String pickMon(String key, [String fallback = '-']) {
        final v = laporan[key] ?? monitoringMap[key];
        return (v != null && v.toString().trim().isNotEmpty)
            ? v.toString().trim()
            : fallback;
      }

      final monCalc = MonitoringCalculator.calculate(
        target: laporan['target_value'] ?? monitoringMap['target_value'],
        actual: laporan['actual_value'] ?? monitoringMap['actual_value'],
        unit: pickMon('target_unit', 'satuan'),
      );
      monitoringHtmlSection = '''
  <div class="section-title">RINGKASAN TARGET &amp; CAPAIAN MONITORING:</div>
  <table class="meta">
    <tr><td width="32%"><b>Kegiatan yang Dimonitor</b></td><td>${pickMon('activity_name', judul)}</td></tr>
    <tr><td><b>Periode Monitoring</b></td><td>${pickMon('monitoring_period')}</td></tr>
    <tr><td><b>Petugas / Pelaksana</b></td><td>${pickMon('officer_name', pelapor)}</td></tr>
    <tr><td><b>Periode Target</b></td><td>${pickMon('target_period')}</td></tr>
    <tr><td><b>Target Direncanakan</b></td><td>${monCalc.formattedTarget}</td></tr>
    <tr><td><b>Hasil Aktual</b></td><td>${monCalc.formattedActual}</td></tr>
    <tr><td><b>Persentase Capaian</b></td><td><b>${monCalc.formattedPercentage}</b></td></tr>
    <tr><td><b>Sisa Target</b></td><td>${monCalc.formattedRemaining}</td></tr>
    <tr><td><b>Status Pencapaian</b></td><td><b>${monCalc.status}</b></td></tr>
  </table>
''';
    }

    String photoHtmlSection = '';
    if (uniquePhotos.isNotEmpty) {
      final buffer = StringBuffer();
      buffer.writeln('  <div class="section-title">LAMPIRAN FOTO DOKUMENTASI KEGIATAN:</div>');
      for (int i = 0; i < uniquePhotos.length; i++) {
        final currentPhoto = uniquePhotos[i];
        final b64 = base64Encode(currentPhoto.jpegBytes);
        final label = uniquePhotos.length > 1
            ? 'Dokumentasi Foto ${i + 1} Resmi'
            : 'Dokumentasi Resmi';
        buffer.writeln('''
  <div class="photo-box" style="text-align: center; border: 1px solid #DCE6DC; padding: 14px; background: #FFFFFF; margin-bottom: 20px; border-radius: 6px;">
    <img src="data:image/jpeg;base64,$b64" style="max-width: 520px; max-height: 400px; border-radius: 6px; border: 1px solid #B0C4B5;" /><br/>
    <p style="font-size: 9.5pt; color: #4A5568; margin-top: 8px; line-height: 1.4;">
      <b>$label:</b> $judul<br/>
      <b>Lokasi:</b> $lokasi &nbsp;|&nbsp; <b>Titik Koordinat:</b> ${lat.isNotEmpty ? '$lat, $lng' : '-'}<br/>
      ${waktuUnduh != null && waktuUnduh.isNotEmpty ? '<b>Waktu Diunduh & Dicetak:</b> $waktuUnduh' : ''}
    </p>
  </div>
''');
      }
      photoHtmlSection = buffer.toString();
    }

    final htmlDoc = '''
<html xmlns:o="urn:schemas-microsoft-com:office:office"
      xmlns:w="urn:schemas-microsoft-com:office:word"
      xmlns="http://www.w3.org/TR/REC-html40">
<head>
  <meta charset="utf-8">
  <title>$judul</title>
  <style>
    body { font-family: Arial, sans-serif; font-size: 11pt; color: #1E2923; line-height: 1.5; }
    .kop { text-align: center; border-bottom: 3px solid #245C3A; padding-bottom: 10px; margin-bottom: 20px; }
    .kop h2, .kop h3, .kop p { margin: 2px 0; }
    table.meta { width: 100%; border-collapse: collapse; margin-bottom: 18px; background: #F2F7F0; }
    table.meta td { padding: 6px 10px; border: 1px solid #DCE6DC; }
    .section-title { font-weight: bold; color: #245C3A; margin-top: 14px; margin-bottom: 6px; }
    .content-box { border: 1px solid #DCE6DC; padding: 14px; background: #FFFFFF; margin-bottom: 18px; }
    .sign { margin-top: 40px; text-align: right; }
  </style>
</head>
<body>
  <div class="kop">
    <h3>PEMERINTAH DAERAH PROVINSI JAWA BARAT</h3>
    <h2>DINAS KEHUTANAN</h2>
    <h3>CABANG DINAS KEHUTANAN WILAYAH V GARUT</h3>
    <p>Laporan Resmi Kegiatan Lapangan &amp; Penyuluhan Kehutanan</p>
  </div>
  <h3 style="color:#245C3A; margin-bottom:6px;">$jenis</h3>
  <h2 style="margin-top:0;">$judul</h2>
  <table class="meta">
    <tr><td width="32%"><b>Nama Pegawai / Penyuluh</b></td><td>$pelapor</td></tr>
    <tr><td><b>Tanggal Laporan</b></td><td>$tanggal</td></tr>
    <tr><td><b>Lokasi Kegiatan</b></td><td>$lokasi</td></tr>
    <tr><td><b>Titik Koordinat</b></td><td>${lat.isNotEmpty ? '$lat, $lng' : '-'}</td></tr>
    <tr><td><b>Status Laporan</b></td><td>$status</td></tr>
    <tr><td><b>Lampiran Foto</b></td><td>${photo != null ? 'Tersedia (Terlampir pada bagian bawah naskah)' : 'Tidak terlampir'}</td></tr>
    ${waktuUnduh != null && waktuUnduh.isNotEmpty ? '<tr><td><b>Waktu Cetak/Unduh</b></td><td>$waktuUnduh</td></tr>' : ''}
  </table>
  $monitoringHtmlSection
  <div class="section-title">${isMonitoring ? 'EVALUASI &amp; TINDAK LANJUT MONITORING (12 BAGIAN):' : 'URAIAN &amp; HASIL KEGIATAN:'}</div>
  <div class="content-box">$isi</div>
  $photoHtmlSection
  <div class="sign">
    <p>Garut, $tanggal<br/><b>Penyuluh / Petugas Pelaksana,</b></p>
    <br/><br/>
    <p><b><u>$pelapor</u></b></p>
  </div>
</body>
</html>
''';
    return Uint8List.fromList(utf8.encode(htmlDoc));
  }

  static List<String> _wrapTextLines(String text, {int maxCharsPerLine = 78}) {
    final result = <String>[];
    final paragraphs = text.split(RegExp(r'\r?\n'));
    for (final para in paragraphs) {
      final cleanPara = para.trimRight();
      if (cleanPara.isEmpty) {
        result.add('');
        continue;
      }
      final words = cleanPara.split(RegExp(r'\s+'));
      var currentLine = StringBuffer();
      for (final word in words) {
        if (currentLine.isEmpty) {
          currentLine.write(word);
        } else if (currentLine.length + 1 + word.length <= maxCharsPerLine) {
          currentLine.write(' $word');
        } else {
          result.add(currentLine.toString());
          currentLine = StringBuffer(word);
        }
      }
      if (currentLine.isNotEmpty) {
        result.add(currentLine.toString());
      }
    }
    return result;
  }

  static String _cleanPdfText(String input) {
    return input
        .replaceAll('•', '-')
        .replaceAll('—', '-')
        .replaceAll('–', '-')
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('’', "'")
        .replaceAll(RegExp(r'[^\x20-\x7E]'), '');
  }

  static String _escapePdfLiteral(String input) {
    return input
        .replaceAll(r'\', r'\\')
        .replaceAll('(', r'\(')
        .replaceAll(')', r'\)');
  }
}

// ============================================================================
// WIDGET DAFTAR TEMPLATE LAPORAN (RAPI, LEGA & RESPONSIF)
// ============================================================================

class ReportTemplates extends StatefulWidget {
  const ReportTemplates({
    super.key,
    required this.onSelectTemplate,
    this.isAdmin = false,
    this.templates,
    this.onEditTemplate,
    this.onPreviewTemplate,
    this.onDeleteTemplate,
  });

  final ValueChanged<String> onSelectTemplate;
  final bool isAdmin;
  final List<Map<String, dynamic>>? templates;
  final ValueChanged<Map<String, dynamic>>? onEditTemplate;
  final ValueChanged<Map<String, dynamic>>? onPreviewTemplate;
  final ValueChanged<Map<String, dynamic>>? onDeleteTemplate;

  @override
  State<ReportTemplates> createState() => _ReportTemplatesState();
}

class _ReportTemplatesState extends State<ReportTemplates> {
  List<Map<String, dynamic>> _loadedTemplates = [];

  @override
  void initState() {
    super.initState();
    if (widget.templates == null) {
      _loadFromStorage();
    }
  }

  Future<void> _loadFromStorage() async {
    final list = await ReportTemplateManager.loadTemplates();
    if (mounted) {
      setState(() => _loadedTemplates = list);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = widget.templates ?? _loadedTemplates;
    if (list.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: list.map((t) => _buildTemplateCard(context, t)).toList(),
    );
  }

  Widget _buildTemplateCard(
    BuildContext context,
    Map<String, dynamic> template,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark
        ? const Color(0xFF1E2822)
        : LaporanColors.cardBackground;
    final cardBorder = isDark
        ? const Color(0xFF2E3D34)
        : LaporanColors.borderTemplate;
    final iconBg = isDark
        ? const Color(0xFF26352B)
        : LaporanColors.greenBackground;
    final softBg = isDark
        ? const Color(0xFF18221B)
        : const Color(0xFFF2F7F0);
    final primaryGreen = isDark
        ? const Color(0xFF81C784)
        : const Color(0xFF245C3A);
    final titleColor = isDark ? Colors.white : const Color(0xFF24352A);
    final subColor = isDark ? Colors.white70 : const Color(0xFF758278);

    final String title = (template['title'] ?? 'Laporan Kegiatan').toString();
    final String category = (template['category'] ?? 'Penyuluhan').toString();
    final String description = (template['description'] ?? '').toString();
    final String sampleFileName = (template['sampleFileName'] ?? '').toString();
    final IconData iconData = template['icon'] is IconData
        ? template['icon'] as IconData
        : ReportTemplateManager.iconFromKey(template['iconKey']?.toString());
    final List<String> fields =
        (template['fields'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final bool requirePhoto = template['requirePhoto'] != false;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.035),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            if (widget.isAdmin && widget.onEditTemplate != null) {
              widget.onEditTemplate!(template);
            } else {
              widget.onSelectTemplate(title);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        iconData,
                        color: primaryGreen,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: titleColor,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: iconBg,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  category,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: primaryGreen,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            description,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: subColor,
                              height: 1.4,
                            ),
                          ),
                          if (sampleFileName.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.attach_file_rounded,
                                  size: 14,
                                  color: primaryGreen,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Sumber File Contoh: $sampleFileName',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: primaryGreen,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (!widget.isAdmin) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: primaryGreen,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: softBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isAdmin
                            ? 'Bagian Form yang Diisi Pegawai (${fields.length + 3} kolom):'
                            : 'Bagian yang Perlu Diisi:',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          const _FieldBadge(
                            label: 'Judul',
                            icon: Icons.title_rounded,
                            isStandard: true,
                          ),
                          const _FieldBadge(
                            label: 'Tanggal',
                            icon: Icons.calendar_today_outlined,
                            isStandard: true,
                          ),
                          const _FieldBadge(
                            label: 'Lokasi & GPS',
                            icon: Icons.location_on_outlined,
                            isStandard: true,
                          ),
                          if (requirePhoto)
                            const _FieldBadge(
                              label: 'Foto',
                              icon: Icons.camera_alt_outlined,
                              isStandard: true,
                            ),
                          ...fields.map(
                            (f) => _FieldBadge(
                              label: f,
                              icon: Icons.edit_note_rounded,
                              isStandard: false,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (widget.isAdmin) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => widget.onEditTemplate?.call(template),
                        icon: const Icon(Icons.edit_document, size: 17),
                        label: const Text(
                          'Atur Template / Upload Contoh',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF245C3A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () {
                              if (widget.onPreviewTemplate != null) {
                                widget.onPreviewTemplate!(template);
                              } else {
                                widget.onSelectTemplate(title);
                              }
                            },
                            icon: Icon(
                              Icons.visibility_outlined,
                              size: 16,
                              color: primaryGreen,
                            ),
                            label: Text(
                              'Pratinjau Form',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: primaryGreen,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: cardBorder),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 11,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          if (widget.onDeleteTemplate != null) ...[
                            const SizedBox(width: 4),
                            IconButton(
                              tooltip: 'Hapus Template',
                              onPressed: () =>
                                  widget.onDeleteTemplate!(template),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 19,
                                color: Color(0xFFD32F2F),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isStandard;

  const _FieldBadge({
    required this.label,
    required this.icon,
    required this.isStandard,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isStandard
        ? (isDark ? const Color(0xFF233829) : const Color(0xFFE8F2E8))
        : (isDark ? const Color(0xFF26332D) : Colors.white);
    final fg = isStandard
        ? (isDark ? const Color(0xFF81C784) : const Color(0xFF245C3A))
        : (isDark ? Colors.white70 : const Color(0xFF37473B));
    final border = isDark ? const Color(0xFF2E3D34) : const Color(0xFFDCE6DC);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.5, color: fg),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isStandard ? FontWeight.w700 : FontWeight.w600,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
// ============================================================================
// DEKOMPRESOR DEFLATE (RFC 1951) MURNI LINTAS PLATFORM (WEB & MOBILE)
// ============================================================================

class _PureDartDeflate {
  static const List<int> _lenBase = [
    3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31,
    35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258
  ];
  static const List<int> _lenExtra = [
    0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2,
    3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0
  ];
  static const List<int> _distBase = [
    1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193,
    257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145,
    8193, 12289, 16385, 24577
  ];
  static const List<int> _distExtra = [
    0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6,
    7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13
  ];
  static const List<int> _clOrder = [
    16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15
  ];

  static Uint8List inflate(Uint8List src) {
    final out = <int>[];
    int bytePos = 0;
    int bitBuf = 0;
    int bitCount = 0;

    int readBits(int n) {
      while (bitCount < n) {
        if (bytePos >= src.length) {
          throw const FormatException('Unexpected EOF in DEFLATE stream');
        }
        bitBuf |= src[bytePos++] << bitCount;
        bitCount += 8;
      }
      final val = bitBuf & ((1 << n) - 1);
      bitBuf >>= n;
      bitCount -= n;
      return val;
    }

    Map<int, int> buildTree(List<int> lengths) {
      int maxBits = 0;
      for (final l in lengths) {
        if (l > maxBits) maxBits = l;
      }
      if (maxBits == 0) return {};

      final blCount = List<int>.filled(maxBits + 1, 0);
      for (final l in lengths) {
        if (l > 0) blCount[l]++;
      }

      final nextCode = List<int>.filled(maxBits + 1, 0);
      int code = 0;
      for (int bits = 1; bits <= maxBits; bits++) {
        code = (code + blCount[bits - 1]) << 1;
        nextCode[bits] = code;
      }

      final table = <int, int>{};
      for (int n = 0; n < lengths.length; n++) {
        final len = lengths[n];
        if (len != 0) {
          final c = nextCode[len]++;
          table[(len << 16) | c] = n;
        }
      }
      return table;
    }

    int decodeSymbol(Map<int, int> tree) {
      int code = 0;
      for (int len = 1; len <= 15; len++) {
        code = (code << 1) | readBits(1);
        final sym = tree[(len << 16) | code];
        if (sym != null) return sym;
      }
      throw const FormatException('Invalid Huffman code in DEFLATE stream');
    }

    int bfinal = 0;
    while (bfinal == 0) {
      bfinal = readBits(1);
      final btype = readBits(2);

      if (btype == 0) {
        bitBuf = 0;
        bitCount = 0;
        if (bytePos + 4 > src.length) break;
        final len = src[bytePos] | (src[bytePos + 1] << 8);
        bytePos += 4;
        for (int k = 0; k < len && bytePos < src.length; k++) {
          out.add(src[bytePos++]);
        }
      } else if (btype == 1 || btype == 2) {
        Map<int, int> litLenTree;
        Map<int, int> distTree;

        if (btype == 1) {
          final llLengths = List<int>.filled(288, 0);
          for (int i = 0; i <= 143; i++) {
            llLengths[i] = 8;
          }
          for (int i = 144; i <= 255; i++) {
            llLengths[i] = 9;
          }
          for (int i = 256; i <= 279; i++) {
            llLengths[i] = 7;
          }
          for (int i = 280; i <= 287; i++) {
            llLengths[i] = 8;
          }
          litLenTree = buildTree(llLengths);
          distTree = buildTree(List<int>.filled(32, 5));
        } else {
          final hlit = readBits(5) + 257;
          final hdist = readBits(5) + 1;
          final hclen = readBits(4) + 4;

          final clLengths = List<int>.filled(19, 0);
          for (int i = 0; i < hclen; i++) {
            clLengths[_clOrder[i]] = readBits(3);
          }
          final clTree = buildTree(clLengths);

          final allLengths = <int>[];
          while (allLengths.length < hlit + hdist) {
            final sym = decodeSymbol(clTree);
            if (sym < 16) {
              allLengths.add(sym);
            } else if (sym == 16) {
              final prev = allLengths.isNotEmpty ? allLengths.last : 0;
              final repeat = readBits(2) + 3;
              for (int r = 0; r < repeat; r++) {
                allLengths.add(prev);
              }
            } else if (sym == 17) {
              final repeat = readBits(3) + 3;
              for (int r = 0; r < repeat; r++) {
                allLengths.add(0);
              }
            } else if (sym == 18) {
              final repeat = readBits(7) + 11;
              for (int r = 0; r < repeat; r++) {
                allLengths.add(0);
              }
            }
          }

          litLenTree = buildTree(allLengths.sublist(0, hlit));
          distTree = buildTree(allLengths.sublist(hlit, hlit + hdist));
        }

        while (true) {
          final sym = decodeSymbol(litLenTree);
          if (sym < 256) {
            out.add(sym);
          } else if (sym == 256) {
            break;
          } else {
            final lenIdx = sym - 257;
            final length = _lenBase[lenIdx] + readBits(_lenExtra[lenIdx]);
            final dSym = decodeSymbol(distTree);
            final dist = _distBase[dSym] + readBits(_distExtra[dSym]);
            final start = out.length - dist;
            for (int k = 0; k < length; k++) {
              out.add(out[start + k]);
            }
          }
        }
      } else {
        throw const FormatException('Invalid DEFLATE block type');
      }
    }

    return Uint8List.fromList(out);
  }
}