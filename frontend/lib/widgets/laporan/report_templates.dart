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

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/laporan_constants.dart';

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
        'category': 'Monitoring & Patroli',
        'iconKey': 'forest',
        'description':
            'Template laporan hasil monitoring kawasan hutan, pemeriksaan patok batas, dan pengamanan hutan.',
        'defaultTitle': 'Monitoring & Patroli Kawasan Hutan',
        'requirePhoto': true,
        'requireLocation': true,
        'sampleFileName': '',
        'fields': <String>[
          'Kawasan / Titik Pantau Hutan',
          'Kondisi Tegakan & Patok Batas',
          'Temuan Lapangan / Kerawanan',
          'Rekomendasi Tindakan',
        ],
        'templateBody':
            'LAPORAN MONITORING KAWASAN HUTAN\n'
            'Cabang Dinas Kehutanan Wilayah V\n\n'
            '1. Kawasan / Titik Pantau    : {{Kawasan / Titik Pantau Hutan}}\n'
            '2. Kondisi Tegakan & Patok   : {{Kondisi Tegakan & Patok Batas}}\n'
            '3. Temuan Lapangan           : {{Temuan Lapangan / Kerawanan}}\n'
            '4. Rekomendasi Tindakan      :\n{{Rekomendasi Tindakan}}',
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

  /// Normalisasi map template agar tipe datanya selalu konsisten.
  static Map<String, dynamic> normalizeTemplate(Map<String, dynamic> raw) {
    final rawFields = raw['fields'];
    final List<String> fields = rawFields is List
        ? rawFields
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList()
        : <String>[];

    return {
      'id': (raw['id'] ?? 'tpl_${DateTime.now().millisecondsSinceEpoch}')
          .toString(),
      'title': (raw['title'] ?? 'Laporan Kegiatan').toString(),
      'category': (raw['category'] ?? 'Penyuluhan').toString(),
      'iconKey': (raw['iconKey'] ?? 'description').toString(),
      'description':
          (raw['description'] ??
                  'Template laporan kegiatan lapangan penyuluh kehutanan.')
              .toString(),
      'defaultTitle': (raw['defaultTitle'] ?? '').toString(),
      'requirePhoto': raw['requirePhoto'] != false,
      'requireLocation': raw['requireLocation'] != false,
      'sampleFileName': (raw['sampleFileName'] ?? '').toString(),
      'fields': fields,
      'templateBody': (raw['templateBody'] ?? '').toString(),
      'updatedBy': (raw['updatedBy'] ?? 'Administrator').toString(),
    };
  }

  /// Memuat seluruh template dari SharedPreferences.
  static Future<List<Map<String, dynamic>>> loadTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);

    if (raw != null && raw.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(raw);
        final list = decoded
            .map(
              (item) => normalizeTemplate(Map<String, dynamic>.from(item)),
            )
            .toList();
        if (list.isNotEmpty) {
          final hasTrk = list.any(
            (t) =>
                t['title'].toString().toLowerCase().contains('trk') ||
                t['id'] == 'tpl_trk',
          );
          if (!hasTrk) {
            final trkDefault = defaultTemplates().firstWhere(
              (t) => t['id'] == 'tpl_trk',
            );
            list.insert(1, trkDefault);
            await saveTemplates(list);
          }
          return list;
        }
      } catch (_) {}
    }

    final defaults = defaultTemplates();
    await saveTemplates(defaults);
    return defaults;
  }

  /// Menyimpan daftar template ke SharedPreferences.
  static Future<void> saveTemplates(
    List<Map<String, dynamic>> templates,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = templates.map(normalizeTemplate).toList();
    await prefs.setString(storageKey, jsonEncode(normalized));
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
    String body = (template['templateBody'] ?? '').toString().trim();
    final List<String> fields =
        (template['fields'] as List?)?.map((e) => e.toString()).toList() ?? [];

    if (body.isEmpty) {
      final buffer = StringBuffer();
      buffer.writeln(template['title'].toString().toUpperCase());
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
    }

    if (additionalNotes.trim().isNotEmpty) {
      body = '$body\n\nCatatan Tambahan:\n${additionalNotes.trim()}';
    }

    return body;
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
      if (ext == 'docx') {
        extractedRawText = _extractTextFromDocxBytes(bytes);
      } else if (ext == 'pdf') {
        extractedRawText = _extractTextFromPdfBytes(bytes);
      } else {
        extractedRawText = _extractPlainText(bytes);
      }
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
        .where((l) => l.isNotEmpty)
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
    };

    for (final line in rawLines) {
      final matches = placeholderRegex.allMatches(line);
      if (matches.isNotEmpty) {
        String updatedLine = line;
        for (final m in matches) {
          final fieldName = (m.group(1) ?? m.group(2) ?? '').trim();
          if (fieldName.length >= 3 &&
              fieldName.length <= 45 &&
              !ignoredStandardLabels.contains(fieldName.toLowerCase())) {
            if (!detectedFields.contains(fieldName)) {
              detectedFields.add(fieldName);
            }
            updatedLine = updatedLine.replaceAll(
              m.group(0)!,
              '{{$fieldName}}',
            );
          }
        }
        templateLines.add(updatedLine);
        continue;
      }

      final colonMatch = colonLineRegex.firstMatch(line);
      if (colonMatch != null) {
        final rawLabel = colonMatch.group(1)!.trim();
        final lowerLabel = rawLabel.toLowerCase();
        if (!ignoredStandardLabels.contains(lowerLabel) &&
            !lowerLabel.contains('http') &&
            rawLabel.length >= 3) {
          if (!detectedFields.contains(rawLabel)) {
            detectedFields.add(rawLabel);
          }
          final prefix = line.substring(0, line.indexOf(':'));
          templateLines.add('$prefix: {{$rawLabel}}');
          continue;
        }
      }

      templateLines.add(line);
    }

    if (detectedFields.isEmpty) {
      if (inferredCategory == 'TRK & Rehabilitasi') {
        detectedFields.addAll([
          'Blok / Petak Kawasan Rehabilitasi',
          'Jenis & Jumlah Bibit Tanaman',
          'Luas Area Penanaman (Ha)',
          'Kondisi Tanaman & Evaluasi Lapangan',
        ]);
      } else if (inferredCategory == 'Monitoring & Patroli') {
        detectedFields.addAll([
          'Kawasan / Titik Pantau Hutan',
          'Kondisi Tegakan & Patok Batas',
          'Temuan Lapangan / Kerawanan',
          'Rekomendasi Tindakan',
        ]);
      } else if (inferredCategory == 'Kejadian Khusus') {
        detectedFields.addAll([
          'Jenis Kejadian Lapangan',
          'Perkiraan Dampak / Luas Terdampak',
          'Tindakan Penanganan Awal',
        ]);
      } else {
        detectedFields.addAll([
          'Kelompok Tani Hutan (KTH) / Sasaran',
          'Materi / Pokok Kegiatan',
          'Jumlah Peserta Hadir (Orang)',
          'Hasil Kegiatan & Tindak Lanjut',
        ]);
      }
    }

    String finalTemplateBody;
    if (templateLines.length >= 3 &&
        templateLines.join('\n').contains('{{')) {
      finalTemplateBody = templateLines.join('\n');
    } else {
      final buffer = StringBuffer();
      buffer.writeln(inferredTitle.toUpperCase());
      buffer.writeln('Cabang Dinas Kehutanan Wilayah V\n');
      for (int i = 0; i < detectedFields.length; i++) {
        final f = detectedFields[i];
        buffer.writeln('${i + 1}. $f : {{$f}}');
      }
      finalTemplateBody = buffer.toString().trim();
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

  static String _extractTextFromDocxBytes(Uint8List bytes) {
    try {
      const targetName = 'word/document.xml';
      final targetBytes = ascii.encode(targetName);

      int i = 0;
      while (i <= bytes.length - 30) {
        if (bytes[i] == 0x50 &&
            bytes[i + 1] == 0x4B &&
            bytes[i + 2] == 0x03 &&
            bytes[i + 3] == 0x04) {
          final compressionMethod = bytes[i + 8] | (bytes[i + 9] << 8);
          final compressedSize =
              bytes[i + 18] |
              (bytes[i + 19] << 8) |
              (bytes[i + 20] << 16) |
              (bytes[i + 21] << 24);
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
                  (dataStart + compressedSize <= bytes.length &&
                      compressedSize > 0)
                  ? dataStart + compressedSize
                  : bytes.length;
              final slice = bytes.sublist(dataStart, endIndex);

              List<int>? xmlBytes;
              if (compressionMethod == 0) {
                xmlBytes = slice;
              } else if (!kIsWeb && compressionMethod == 8) {
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

              if (xmlBytes != null && xmlBytes.isNotEmpty) {
                final xmlString = utf8.decode(xmlBytes, allowMalformed: true);
                return _stripXmlToParagraphs(xmlString);
              }
            }
          }
        }
        i++;
      }
    } catch (_) {}
    return _extractPlainText(bytes);
  }

  static String _stripXmlToParagraphs(String xml) {
    final withLineBreaks = xml
        .replaceAll('</w:p>', '\n')
        .replaceAll('<w:br/>', '\n')
        .replaceAll('<w:tab/>', ' ');
    final withoutTags = withLineBreaks.replaceAll(RegExp(r'<[^>]+>'), '');
    return withoutTags
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .trim();
  }

  static String _extractTextFromPdfBytes(Uint8List bytes) {
    try {
      final raw = latin1.decode(bytes, allowInvalid: true);
      final matches = RegExp(r'\(([^()\\]{3,120})\)').allMatches(raw);
      final buffer = StringBuffer();
      for (final m in matches) {
        final txt = m.group(1)!.trim();
        if (RegExp(r'^[A-Za-z0-9 .,:/()&-]+$').hasMatch(txt)) {
          buffer.writeln(txt);
        }
      }
      final res = buffer.toString().trim();
      if (res.isNotEmpty) return res;
    } catch (_) {}
    return '';
  }

  static String _extractPlainText(Uint8List bytes) {
    try {
      final decoded = utf8.decode(bytes, allowMalformed: true);
      final lines = decoded
          .split(RegExp(r'\r?\n'))
          .map(
            (l) =>
                l.replaceAll(RegExp(r'[^\x20-\x7E\u00A0-\u00FF]'), '').trim(),
          )
          .where((l) => l.length >= 3)
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

class ReportDocumentExporter {
  /// Mengekspor laporan menjadi file PDF (.pdf) atau Word (.doc).
  /// - Di Flutter Web (Chrome/Edge): Menggunakan `XFile.fromData(...).saveTo(...)`
  ///   yang membuat `Blob` Object URL (`blob:http://...`) dan memicu `<a download>`
  ///   secara langsung sehingga TIDAK diblokir Chrome (tidak muncul tab Untitled abu-abu).
  /// - Di Android/Desktop: Menyimpan langsung ke folder Download perangkat.
  static Future<ReportExportResult> exportReport(
    Map<String, dynamic> laporan, {
    String format = 'pdf',
    bool openInNewTabOnWeb = false,
  }) async {
    final isPdf = format.toLowerCase() == 'pdf';
    final rawTitle = (laporan['judul'] ?? 'Laporan_Kegiatan').toString();
    final safeTitle = rawTitle
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
    final ext = isPdf ? 'pdf' : 'doc';
    final fileName = '${safeTitle.isEmpty ? 'Laporan' : safeTitle}.$ext';

    // Pastikan isi laporan selalu terformat rapi dengan template meskipun
    // laporan lama belum memiliki teks panjang.
    final enrichedLaporan = await _ensureFormattedReportContent(laporan);

    final Uint8List fileBytes = isPdf
        ? generatePdfBytes(enrichedLaporan)
        : generateWordDocBytes(enrichedLaporan);

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

    // 2. Penanganan Android, Windows, Linux, macOS: simpan ke folder Download
    try {
      final dir = await _getReportDownloadDirectory();
      final targetFile = _getUniqueFile(dir, fileName);
      await targetFile.writeAsBytes(fileBytes, flush: true);

      return ReportExportResult(
        success: true,
        fileName: targetFile.uri.pathSegments.last,
        filePath: targetFile.path,
        message: 'Dokumen berhasil disimpan di: ${targetFile.path}',
      );
    } catch (e) {
      return ReportExportResult(
        success: false,
        fileName: fileName,
        message: 'Gagal menyimpan file laporan: $e',
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
        await OpenFilex.open(result.filePath!);
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

    if (rawIsi.isEmpty || !rawIsi.contains('\n')) {
      final template = await ReportTemplateManager.findByTitle(jenis);
      final List<String> fields =
          (template['fields'] as List?)?.map((e) => e.toString()).toList() ??
          [];
      final Map<String, String> defaultValues = {};
      for (int i = 0; i < fields.length; i++) {
        final f = fields[i];
        if (i == 0) {
          defaultValues[f] = lokasi;
        } else if (i == 1) {
          defaultValues[f] = judul;
        } else if (i == fields.length - 1 && rawIsi.isNotEmpty) {
          defaultValues[f] = rawIsi;
        } else {
          defaultValues[f] = rawIsi.isNotEmpty
              ? rawIsi
              : 'Telah dilaksanakan sesuai jadwal dan prosedur lapangan.';
        }
      }
      copy['isi'] = ReportTemplateManager.buildFormattedBody(
        template: template,
        fieldValues: defaultValues,
      );
    }
    return copy;
  }

  /// Menghasilkan file PDF 1.4 standar (biner valid) siap print.
  static Uint8List generatePdfBytes(Map<String, dynamic> laporan) {
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
    final isiRaw = (laporan['isi'] ?? '').toString().trim();

    final content = StringBuffer();

    // Garis Atas Kop Surat
    content.writeln('0.14 0.36 0.23 rg');
    content.writeln('50 792 495 3 re f');
    content.writeln('0 0 0 rg');

    void drawText(
      String text,
      double x,
      double y, {
      bool bold = false,
      int fontSize = 11,
    }) {
      final fontKey = bold ? '/F2' : '/F1';
      final escaped = _escapePdfLiteral(text);
      content.writeln('BT $fontKey $fontSize Tf $x $y Td ($escaped) Tj ET');
    }

    // Header Kop Instansi
    drawText(
      'PEMERINTAH DAERAH PROVINSI JAWA BARAT',
      155,
      772,
      bold: true,
      fontSize: 12,
    );
    drawText('DINAS KEHUTANAN', 238, 756, bold: true, fontSize: 13);
    drawText(
      'CABANG DINAS KEHUTANAN WILAYAH V GARUT',
      150,
      740,
      bold: true,
      fontSize: 12,
    );
    drawText(
      'Dokumen Laporan Resmi Kegiatan Penyuluhan & Pengelolaan Kehutanan',
      128,
      725,
      fontSize: 9,
    );

    // Garis pembatas kop
    content.writeln('0.14 0.36 0.23 rg');
    content.writeln('50 714 495 1.5 re f');
    content.writeln('0 0 0 rg');

    // Judul Dokumen
    drawText(jenis.toUpperCase(), 50, 690, bold: true, fontSize: 13);
    drawText(judul, 50, 673, bold: true, fontSize: 11);

    // Kotak Metadata Laporan
    content.writeln('0.95 0.97 0.95 rg');
    content.writeln('50 568 495 92 re f');
    content.writeln('0 0 0 rg');

    drawText('Nama Pegawai / Penyuluh', 62, 642, bold: true, fontSize: 10);
    drawText(':  $pelapor', 205, 642, fontSize: 10);

    drawText('Jenis Laporan', 62, 626, bold: true, fontSize: 10);
    drawText(':  $jenis', 205, 626, fontSize: 10);

    drawText('Tanggal Laporan', 62, 610, bold: true, fontSize: 10);
    drawText(':  $tanggal', 205, 610, fontSize: 10);

    drawText('Lokasi Kegiatan', 62, 594, bold: true, fontSize: 10);
    drawText(':  $lokasi', 205, 594, fontSize: 10);

    drawText('Titik Koordinat & Status', 62, 578, bold: true, fontSize: 10);
    drawText(':  $koordinat  ($status)', 205, 578, fontSize: 10);

    // Bagian Isi Laporan
    drawText(
      'URAIAN & HASIL KEGIATAN LAPANGAN:',
      50,
      544,
      bold: true,
      fontSize: 11,
    );
    content.writeln('0.80 0.85 0.80 rg');
    content.writeln('50 537 495 0.8 re f');
    content.writeln('0 0 0 rg');

    final bodyLines = _wrapTextLines(
      isiRaw.isNotEmpty
          ? isiRaw
          : 'Laporan kegiatan telah dilaksanakan sesuai jadwal dan prosedur lapangan.',
      maxCharsPerLine: 78,
    );

    double currentY = 518;
    for (final line in bodyLines) {
      if (currentY < 165) break;
      final isSectionLine =
          RegExp(r'^[0-9]+\.').hasMatch(line) ||
          (line == line.toUpperCase() && line.length > 5);
      drawText(
        _cleanPdfText(line),
        50,
        currentY,
        bold: isSectionLine,
        fontSize: 10,
      );
      currentY -= 15;
    }

    // Blok Tanda Tangan
    content.writeln('0.80 0.85 0.80 rg');
    content.writeln('50 145 495 0.8 re f');
    content.writeln('0 0 0 rg');

    drawText('Garut, $tanggal', 360, 125, fontSize: 10);
    drawText(
      'Penyuluh / Petugas Pelaksana,',
      360,
      111,
      bold: true,
      fontSize: 10,
    );
    drawText(pelapor, 360, 62, bold: true, fontSize: 10);
    drawText(
      'Dicetak otomatis melalui Aplikasi Phonebook CDK Wilayah V',
      50,
      42,
      fontSize: 8,
    );

    final streamContent = content.toString();
    final streamBytes = latin1.encode(streamContent);

    final pdfBuffer = BytesBuilder();
    final offsets = <int>[0];

    void writeAscii(String s) {
      pdfBuffer.add(latin1.encode(s));
    }

    writeAscii('%PDF-1.4\n');

    offsets.add(pdfBuffer.length);
    writeAscii('1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n');

    offsets.add(pdfBuffer.length);
    writeAscii(
      '2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n',
    );

    offsets.add(pdfBuffer.length);
    writeAscii(
      '3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] '
      '/Resources << /Font << /F1 4 0 R /F2 5 0 R >> >> '
      '/Contents 6 0 R >>\nendobj\n',
    );

    offsets.add(pdfBuffer.length);
    writeAscii(
      '4 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>\nendobj\n',
    );

    offsets.add(pdfBuffer.length);
    writeAscii(
      '5 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>\nendobj\n',
    );

    offsets.add(pdfBuffer.length);
    writeAscii('6 0 obj\n<< /Length ${streamBytes.length} >>\nstream\n');
    pdfBuffer.add(streamBytes);
    writeAscii('\nendstream\nendobj\n');

    final xrefOffset = pdfBuffer.length;
    writeAscii('xref\n0 7\n0000000000 65535 f \n');
    for (int idx = 1; idx <= 6; idx++) {
      final offStr = offsets[idx].toString().padLeft(10, '0');
      writeAscii('$offStr 00000 n \n');
    }

    writeAscii(
      'trailer\n<< /Size 7 /Root 1 0 R >>\nstartxref\n$xrefOffset\n%%EOF\n',
    );

    return pdfBuffer.toBytes();
  }

  /// Menghasilkan dokumen Word (.doc) yang dapat dibuka di Microsoft Word.
  static Uint8List generateWordDocBytes(Map<String, dynamic> laporan) {
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
    final isi = (laporan['isi'] ?? '')
        .toString()
        .replaceAll('\n', '<br/>');

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
    .content-box { border: 1px solid #DCE6DC; padding: 14px; background: #FFFFFF; }
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
  </table>
  <div class="section-title">URAIAN &amp; HASIL KEGIATAN:</div>
  <div class="content-box">$isi</div>
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

  static Future<Directory> _getReportDownloadDirectory() async {
    if (!kIsWeb && Platform.isAndroid) {
      final publicDownload = Directory('/storage/emulated/0/Download');
      if (publicDownload.existsSync()) {
        final subDir = Directory('${publicDownload.path}/Phonebook_Laporan');
        try {
          if (!subDir.existsSync()) {
            subDir.createSync(recursive: true);
          }
          return subDir;
        } catch (_) {
          return publicDownload;
        }
      }
    }
    try {
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null) return downloadsDir;
    } catch (_) {}
    return await getApplicationDocumentsDirectory();
  }

  static File _getUniqueFile(Directory dir, String baseFileName) {
    File candidate = File('${dir.path}/$baseFileName');
    if (!candidate.existsSync()) return candidate;

    final dotIndex = baseFileName.lastIndexOf('.');
    final nameWithoutExt = dotIndex != -1
        ? baseFileName.substring(0, dotIndex)
        : baseFileName;
    final ext = dotIndex != -1 ? baseFileName.substring(dotIndex) : '';

    int counter = 1;
    while (candidate.existsSync()) {
      candidate = File('${dir.path}/$nameWithoutExt ($counter)$ext');
      counter++;
    }
    return candidate;
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