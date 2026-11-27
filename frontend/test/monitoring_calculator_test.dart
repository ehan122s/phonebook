import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/monitoring_calculator.dart';
import 'package:frontend/widgets/laporan/report_templates.dart';

void main() {
  group('MonitoringCalculator Tests', () {
    test('calculates percentage, remaining target, and Belum tercapai accurately', () {
      final result = MonitoringCalculator.calculate(
        target: 5,
        actual: 3,
        unit: 'kelompok',
      );

      expect(result.targetValue, 5);
      expect(result.actualValue, 3);
      expect(result.achievementPercentage, 60);
      expect(result.remainingTarget, 2);
      expect(result.status, MonitoringCalculator.statusNotAchieved);
      expect(result.formattedTarget, '5 kelompok');
      expect(result.formattedActual, '3 kelompok');
      expect(result.formattedPercentage, '60%');
      expect(result.formattedRemaining, '2 kelompok');
    });

    test('supports custom units and marks Tercapai when actual >= target', () {
      final exact = MonitoringCalculator.calculate(
        target: 20,
        actual: 20,
        unit: 'peserta',
      );
      expect(exact.status, MonitoringCalculator.statusAchieved);
      expect(exact.remainingTarget, 0);
      expect(exact.achievementPercentage, 100);

      final exceeded = MonitoringCalculator.calculate(
        target: 10,
        actual: 12,
        unit: 'lokasi',
      );
      expect(exceeded.status, MonitoringCalculator.statusAchieved);
      expect(exceeded.remainingTarget, 0);
      expect(exceeded.achievementPercentage, 120);
      expect(exceeded.formattedRemaining, '0 lokasi');
    });

    test('prevents division by zero and returns Perlu diperiksa on invalid inputs', () {
      final zeroTarget = MonitoringCalculator.calculate(
        target: 0,
        actual: 3,
        unit: 'dokumen',
      );
      expect(zeroTarget.status, MonitoringCalculator.statusNeedsCheck);
      expect(zeroTarget.achievementPercentage, isNull);
      expect(zeroTarget.remainingTarget, isNull);
      expect(zeroTarget.formattedPercentage, '-');

      final missingActual = MonitoringCalculator.calculate(
        target: 5,
        actual: '',
        unit: 'kelompok',
      );
      expect(missingActual.status, MonitoringCalculator.statusNeedsCheck);
    });
  });

  group('Monitoring 12-Section Export Tests', () {
    final monitoringSample = <String, dynamic>{
      'judul': 'Monitoring Pembinaan KTH Semester II',
      'jenis': 'Laporan Monitoring',
      'report_type': 'monitoring',
      'pelapor': 'Rudi Hartono',
      'tanggal': '27 November 2026',
      'lokasi': 'Kecamatan Cisurupan, Garut',
      'status': 'Selesai',
      'activity_name': 'Pembinaan Kelompok Tani Hutan',
      'monitoring_period': 'Oktober - November 2026',
      'officer_name': 'Rudi Hartono',
      'target_value': 5,
      'target_unit': 'kelompok',
      'target_period': '2 bulan',
      'actual_value': 3,
      'field_facts': '3 kelompok aktif melakukan pembibitan.',
      'obstacles': 'Akses jalan menuju 2 kelompok rusak akibat hujan.',
      'failure_causes': 'Cuaca ekstrem menunda kunjungan lapangan.',
      'recommendations': 'Penjadwalan kunjungan saat cuaca cerah dengan koordinasi desa.',
      'follow_up_plan': 'Pendampingan 2 kelompok tersisa pada pekan pertama Desember.',
      'next_target_date': '2026-12-07',
    };

    test('buildFormattedMonitoringBody contains all 12 numbered sections', () {
      final body = MonitoringCalculator.buildFormattedMonitoringBody(monitoringSample);

      for (int i = 1; i <= 12; i++) {
        expect(body.contains('$i. '), isTrue);
      }
      expect(body.contains('5 kelompok'), isTrue);
      expect(body.contains('3 kelompok'), isTrue);
      expect(body.contains('60%'), isTrue);
      expect(body.contains('2 kelompok'), isTrue);
    });

    test('generateWordDocBytes includes monitoring summary table and 12 sections', () {
      final docBytes = ReportDocumentExporter.generateWordDocBytes(monitoringSample);
      final html = utf8.decode(docBytes);

      expect(html.contains('RINGKASAN TARGET &amp; CAPAIAN MONITORING'), isTrue);
      expect(html.contains('60%'), isTrue);
      expect(html.contains('2 kelompok'), isTrue);
      expect(html.contains('12. Dokumentasi'), isTrue);
    });

    test('generatePdfBytes generates multi-page or valid PDF for Monitoring report without truncation crash', () {
      final pdfBytes = ReportDocumentExporter.generatePdfBytes(monitoringSample);
      expect(pdfBytes.isNotEmpty, isTrue);
      expect(String.fromCharCodes(pdfBytes.sublist(0, 8)), '%PDF-1.4');
      final ascii = String.fromCharCodes(pdfBytes);
      expect(ascii.contains('12. Dokumentasi'), isTrue);
    });
  });
}
