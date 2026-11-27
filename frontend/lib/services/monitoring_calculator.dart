import 'dart:convert';

class MonitoringCalculationResult {
  final double? targetValue;
  final double? actualValue;
  final String unit;
  final double? achievementPercentage;
  final double? remainingTarget;
  final String status;

  const MonitoringCalculationResult({
    required this.targetValue,
    required this.actualValue,
    required this.unit,
    required this.achievementPercentage,
    required this.remainingTarget,
    required this.status,
  });

  bool get isAchieved => status == MonitoringCalculator.statusAchieved;
  bool get isNotAchieved => status == MonitoringCalculator.statusNotAchieved;
  bool get needsCheck => status == MonitoringCalculator.statusNeedsCheck;

  String get formattedTarget {
    if (targetValue == null) return '-';
    final numStr = MonitoringCalculator.formatNumber(targetValue);
    return unit.isNotEmpty ? '$numStr $unit' : numStr;
  }

  String get formattedActual {
    if (actualValue == null) return '-';
    final numStr = MonitoringCalculator.formatNumber(actualValue);
    return unit.isNotEmpty ? '$numStr $unit' : numStr;
  }

  String get formattedPercentage {
    if (achievementPercentage == null) return '-';
    return '${MonitoringCalculator.formatNumber(achievementPercentage)}%';
  }

  String get formattedRemaining {
    if (remainingTarget == null) return '-';
    final numStr = MonitoringCalculator.formatNumber(remainingTarget);
    return unit.isNotEmpty ? '$numStr $unit' : numStr;
  }

  double get progressFraction {
    if (achievementPercentage == null ||
        achievementPercentage!.isNaN ||
        achievementPercentage!.isInfinite) {
      return 0.0;
    }
    return (achievementPercentage! / 100.0).clamp(0.0, 1.0);
  }
}

class MonitoringCalculator {
  MonitoringCalculator._();

  static const String statusAchieved = 'Tercapai';
  static const String statusNotAchieved = 'Belum tercapai';
  static const String statusNeedsCheck = 'Perlu diperiksa';

  static const List<String> defaultUnits = <String>[
    'kelompok',
    'kegiatan',
    'peserta',
    'lokasi',
    'dokumen',
    'batang',
    'ha',
    'Lainnya',
  ];

  static bool isMonitoringReportType(String? jenisLaporan, [String? reportType]) {
    final normalizedType = (reportType ?? '').trim().toLowerCase();
    if (normalizedType == 'monitoring') {
      return true;
    }
    final normalizedJenis = (jenisLaporan ?? '').trim().toLowerCase();
    return normalizedJenis.contains('monitoring');
  }

  static double? parseNumber(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) {
      final value = raw.toDouble();
      if (value.isNaN || value.isInfinite) return null;
      return value;
    }
    final cleaned = raw.toString().trim().replaceAll(',', '.');
    if (cleaned.isEmpty) return null;
    final parsed = double.tryParse(cleaned);
    if (parsed == null || parsed.isNaN || parsed.isInfinite) {
      return null;
    }
    return parsed;
  }

  static String formatNumber(double? value) {
    if (value == null || value.isNaN || value.isInfinite) {
      return '-';
    }
    final rounded = (value * 100).roundToDouble() / 100;
    if ((rounded - rounded.roundToDouble()).abs() < 0.0001) {
      return rounded.round().toString();
    }
    var text = rounded.toStringAsFixed(2);
    text = text.replaceFirst(RegExp(r'0+$'), '');
    text = text.replaceFirst(RegExp(r'\.$'), '');
    return text;
  }

  static MonitoringCalculationResult calculate({
    required dynamic target,
    required dynamic actual,
    String? unit,
  }) {
    final resolvedUnit =
        (unit != null && unit.trim().isNotEmpty) ? unit.trim() : 'satuan';
    final targetValue = parseNumber(target);
    final actualValue = parseNumber(actual);

    if (targetValue == null ||
        actualValue == null ||
        targetValue <= 0 ||
        actualValue < 0) {
      return MonitoringCalculationResult(
        targetValue: targetValue,
        actualValue: actualValue,
        unit: resolvedUnit,
        achievementPercentage: null,
        remainingTarget: null,
        status: statusNeedsCheck,
      );
    }

    final rawPercentage = (actualValue / targetValue) * 100.0;
    final percentage = (rawPercentage * 100).roundToDouble() / 100;
    final rawRemaining =
        targetValue > actualValue ? (targetValue - actualValue) : 0.0;
    final remaining = (rawRemaining * 100).roundToDouble() / 100;
    final status =
        actualValue >= targetValue ? statusAchieved : statusNotAchieved;

    return MonitoringCalculationResult(
      targetValue: targetValue,
      actualValue: actualValue,
      unit: resolvedUnit,
      achievementPercentage: percentage,
      remainingTarget: remaining,
      status: status,
    );
  }

  static String buildComparisonSummary(MonitoringCalculationResult calc) {
    if (calc.needsCheck) {
      return 'Data target atau hasil aktual belum valid (${calc.status}). '
          'Target: ${calc.formattedTarget}, Hasil aktual: ${calc.formattedActual}.';
    }
    if (calc.isAchieved) {
      return 'Target tercapai: realisasi ${calc.formattedActual} dari target '
          '${calc.formattedTarget} (${calc.formattedPercentage}). Sisa target: ${calc.formattedRemaining}.';
    }
    return 'Realisasi ${calc.formattedActual} dari target ${calc.formattedTarget} '
        '(${calc.formattedPercentage}). Sisa target belum tercapai: ${calc.formattedRemaining}.';
  }

  static Map<String, dynamic> extractMonitoringMap(Map<String, dynamic> report) {
    final Map<String, dynamic> merged = <String, dynamic>{};

    final rawMonitoringData = report['monitoring_data'];
    if (rawMonitoringData is Map) {
      for (final entry in rawMonitoringData.entries) {
        merged[entry.key.toString()] = entry.value;
      }
    } else if (rawMonitoringData is String &&
        rawMonitoringData.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawMonitoringData);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            merged[entry.key.toString()] = entry.value;
          }
        }
      } catch (_) {}
    }

    const keys = <String>[
      'report_type',
      'activity_name',
      'monitoring_period',
      'officer_name',
      'target_value',
      'target_unit',
      'target_period',
      'actual_value',
      'achievement_percentage',
      'remaining_target',
      'achievement_status',
      'field_facts',
      'obstacles',
      'failure_causes',
      'recommendations',
      'follow_up_plan',
      'next_target_date',
    ];

    for (final key in keys) {
      final direct = report[key];
      if (direct != null && direct.toString().trim().isNotEmpty) {
        merged[key] = direct;
      }
    }

    return merged;
  }

  static String buildFormattedMonitoringBody(Map<String, dynamic> data) {
    final extracted = extractMonitoringMap(data);
    String pick(List<String> keys, [String fallback = '-']) {
      for (final key in keys) {
        final value = data[key] ?? extracted[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString().trim();
        }
      }
      return fallback;
    }

    final title = pick(['title', 'judul']);
    final activityName = pick(['activity_name'], title);
    final location = pick(['location', 'lokasi']);
    final activityDate = pick(['activity_date', 'tanggal', 'tanggalApi']);
    final monitoringPeriod = pick(['monitoring_period']);
    final officerName = pick(['officer_name', 'pelapor']);
    final targetPeriod = pick(['target_period']);
    final targetUnit = pick(['target_unit'], 'satuan');

    final calc = calculate(
      target: data['target_value'] ?? extracted['target_value'],
      actual: data['actual_value'] ?? extracted['actual_value'],
      unit: targetUnit,
    );

    final fieldFacts = pick(['field_facts']);
    final obstacles = pick(['obstacles']);
    final failureCauses = pick(['failure_causes']);
    final recommendations = pick(['recommendations']);
    final followUpPlan = pick(['follow_up_plan']);
    final nextTargetDate = pick(['next_target_date']);

    final hasPhoto = (data['foto'] ?? '').toString().trim().isNotEmpty ||
        (data['localPhotoPath'] ?? '').toString().trim().isNotEmpty ||
        (data['photo_base64'] ?? '').toString().trim().isNotEmpty ||
        (data['photos'] is List && (data['photos'] as List).isNotEmpty);
    final fileCount = (data['files'] is List) ? (data['files'] as List).length : 0;

    final docLines = <String>[
      hasPhoto
          ? '- Foto dokumentasi lapangan terlampir.'
          : '- Belum ada foto dokumentasi lapangan.',
      if (fileCount > 0) '- $fileCount dokumen lampiran pendukung tersedia.',
    ];

    final kendalaLines = <String>[
      'Kendala ditemukan: $obstacles',
      if (failureCauses != '-') 'Penyebab belum tercapai: $failureCauses',
    ].join('\n');

    final tindakLanjutLines = <String>[
      'Rencana tindak lanjut: $followUpPlan',
      'Target penyelesaian berikutnya: $nextTargetDate',
    ].join('\n');

    return <String>[
      '1. Identitas Kegiatan\n'
          '- Judul Monitoring: $title\n'
          '- Kegiatan Dimonitor: $activityName\n'
          '- Lokasi: $location\n'
          '- Tanggal Monitoring: $activityDate\n'
          '- Petugas / Pelaksana: $officerName',
      '2. Periode Monitoring\n'
          '- Periode Monitoring: $monitoringPeriod\n'
          '- Periode Target: $targetPeriod',
      '3. Target Direncanakan\n${calc.formattedTarget}',
      '4. Hasil Aktual\n${calc.formattedActual}',
      '5. Perbandingan Target & Hasil\n${buildComparisonSummary(calc)}',
      '6. Persentase Capaian\n${calc.formattedPercentage} (${calc.status})',
      '7. Sisa Target\n${calc.formattedRemaining}',
      '8. Fakta & Kondisi Lapangan\n$fieldFacts',
      '9. Kendala\n$kendalaLines',
      '10. Rekomendasi\n$recommendations',
      '11. Rencana Tindak Lanjut\n$tindakLanjutLines',
      '12. Dokumentasi\n${docLines.join('\n')}',
    ].join('\n\n');
  }
}
