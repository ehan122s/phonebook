import 'package:flutter/material.dart';

import '../../constants/laporan_constants.dart';
import '../../services/monitoring_calculator.dart';

class MonitoringStatusBadge extends StatelessWidget {
  final String status;
  final bool compact;

  const MonitoringStatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  Color _backgroundColor() {
    switch (status) {
      case MonitoringCalculator.statusAchieved:
        return const Color(0xFFE8F5E9);
      case MonitoringCalculator.statusNotAchieved:
        return const Color(0xFFFFF3E0);
      default:
        return const Color(0xFFFFEBEE);
    }
  }

  Color _foregroundColor() {
    switch (status) {
      case MonitoringCalculator.statusAchieved:
        return const Color(0xFF2E7D32);
      case MonitoringCalculator.statusNotAchieved:
        return const Color(0xFFE65100);
      default:
        return const Color(0xFFC62828);
    }
  }

  IconData _icon() {
    switch (status) {
      case MonitoringCalculator.statusAchieved:
        return Icons.check_circle_outline_rounded;
      case MonitoringCalculator.statusNotAchieved:
        return Icons.timelapse_rounded;
      default:
        return Icons.warning_amber_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = _backgroundColor();
    final fg = _foregroundColor();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon(), size: compact ? 13 : 15, color: fg),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class MonitoringReportFormSections extends StatelessWidget {
  final TextEditingController activityNameController;
  final TextEditingController monitoringPeriodController;
  final TextEditingController officerNameController;
  final TextEditingController targetValueController;
  final TextEditingController targetPeriodController;
  final TextEditingController customUnitController;
  final TextEditingController actualValueController;
  final TextEditingController fieldFactsController;
  final TextEditingController obstaclesController;
  final TextEditingController failureCausesController;
  final TextEditingController recommendationsController;
  final TextEditingController followUpPlanController;
  final String selectedUnit;
  final DateTime? nextTargetDate;
  final ValueChanged<String> onUnitChanged;
  final VoidCallback onPickNextTargetDate;
  final VoidCallback onClearNextTargetDate;
  final VoidCallback onValuesChanged;
  final Widget Function({
    required TextEditingController controller,
    required String label,
    required String hint,
    IconData? icon,
    int maxLines,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) fieldBuilder;

  const MonitoringReportFormSections({
    super.key,
    required this.activityNameController,
    required this.monitoringPeriodController,
    required this.officerNameController,
    required this.targetValueController,
    required this.targetPeriodController,
    required this.customUnitController,
    required this.actualValueController,
    required this.fieldFactsController,
    required this.obstaclesController,
    required this.failureCausesController,
    required this.recommendationsController,
    required this.followUpPlanController,
    required this.selectedUnit,
    required this.nextTargetDate,
    required this.onUnitChanged,
    required this.onPickNextTargetDate,
    required this.onClearNextTargetDate,
    required this.onValuesChanged,
    required this.fieldBuilder,
  });

  String get _effectiveUnit {
    if (selectedUnit == 'Lainnya') {
      final custom = customUnitController.text.trim();
      return custom.isEmpty ? 'satuan' : custom;
    }
    return selectedUnit.trim().isEmpty ? 'satuan' : selectedUnit.trim();
  }

  String _formatDateLabel(DateTime? date) {
    if (date == null) return 'Pilih target tanggal penyelesaian';
    const months = [
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
      'Desember',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final calc = MonitoringCalculator.calculate(
      target: targetValueController.text,
      actual: actualValueController.text,
      unit: _effectiveUnit,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SubSectionHeader(
          badge: 'A',
          title: 'Identitas Kegiatan Monitoring',
          subtitle: 'Detail kegiatan yang dimonitor dan pelaksana lapangan.',
        ),
        const SizedBox(height: 10),
        fieldBuilder(
          controller: activityNameController,
          label: 'Nama Kegiatan yang Dimonitor *',
          hint: 'Contoh: Pembinaan Kelompok Tani Hutan',
          icon: Icons.assignment_outlined,
          validator: (val) => (val == null || val.trim().isEmpty)
              ? 'Nama kegiatan wajib diisi'
              : null,
        ),
        const SizedBox(height: 12),
        fieldBuilder(
          controller: monitoringPeriodController,
          label: 'Periode Monitoring *',
          hint: 'Contoh: Triwulan II 2026 / Bulan November',
          icon: Icons.date_range_outlined,
          validator: (val) => (val == null || val.trim().isEmpty)
              ? 'Periode monitoring wajib diisi'
              : null,
        ),
        const SizedBox(height: 12),
        fieldBuilder(
          controller: officerNameController,
          label: 'Nama Petugas / Pelaksana *',
          hint: 'Nama penyuluh atau tim monitoring lapangan',
          icon: Icons.badge_outlined,
          validator: (val) => (val == null || val.trim().isEmpty)
              ? 'Nama petugas wajib diisi'
              : null,
        ),
        const SizedBox(height: 18),
        _SubSectionHeader(
          badge: 'B',
          title: 'Target Kegiatan Direncanakan',
          subtitle: 'Isi target numerik beserta periode dan satuan kegiatan.',
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: fieldBuilder(
                controller: targetValueController,
                label: 'Angka Target *',
                hint: 'Contoh: 5',
                icon: Icons.flag_outlined,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => onValuesChanged(),
                validator: (val) {
                  final parsed = MonitoringCalculator.parseNumber(val);
                  if (parsed == null || parsed <= 0) {
                    return 'Target > 0';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: fieldBuilder(
                controller: targetPeriodController,
                label: 'Periode Target *',
                hint: 'Contoh: 2 bulan',
                icon: Icons.schedule_outlined,
                validator: (val) => (val == null || val.trim().isEmpty)
                    ? 'Periode wajib'
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Satuan Target *',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: MonitoringCalculator.defaultUnits.map((unit) {
            final bool isSelected = selectedUnit == unit;
            return ChoiceChip(
              label: Text(unit),
              selected: isSelected,
              onSelected: (_) => onUnitChanged(unit),
              selectedColor: LaporanColors.primary.withValues(alpha: 0.16),
              backgroundColor: LaporanColors.fieldFill,
              side: BorderSide(
                color: isSelected
                    ? LaporanColors.primary
                    : LaporanColors.borderCard,
              ),
              labelStyle: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? LaporanColors.primary
                    : const Color(0xFF374151),
              ),
            );
          }).toList(),
        ),
        if (selectedUnit == 'Lainnya') ...[
          const SizedBox(height: 10),
          fieldBuilder(
            controller: customUnitController,
            label: 'Satuan Kustom *',
            hint: 'Contoh: paket, bibit, unit, desa',
            icon: Icons.edit_outlined,
            onChanged: (_) => onValuesChanged(),
            validator: (val) {
              if (selectedUnit == 'Lainnya' &&
                  (val == null || val.trim().isEmpty)) {
                return 'Masukkan satuan kustom';
              }
              return null;
            },
          ),
        ],
        const SizedBox(height: 18),
        _SubSectionHeader(
          badge: 'C',
          title: 'Hasil Aktual & Fakta Lapangan',
          subtitle: 'Isi manual capaian nyata di lapangan (tidak terisi otomatis).',
        ),
        const SizedBox(height: 10),
        fieldBuilder(
          controller: actualValueController,
          label: 'Hasil Aktual Dicapai ($_effectiveUnit) *',
          hint: 'Masukkan angka hasil nyata yang dicapai',
          icon: Icons.analytics_outlined,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => onValuesChanged(),
          validator: (val) {
            final parsed = MonitoringCalculator.parseNumber(val);
            if (parsed == null || parsed < 0) {
              return 'Hasil aktual minimal 0';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        _LiveCalculationPanel(calc: calc),
        const SizedBox(height: 12),
        fieldBuilder(
          controller: fieldFactsController,
          label: 'Fakta / Kondisi Nyata di Lapangan *',
          hint:
              'Jelaskan kondisi objektif yang ditemukan di lapangan selama monitoring...',
          maxLines: 3,
          validator: (val) => (val == null || val.trim().isEmpty)
              ? 'Fakta lapangan wajib diisi'
              : null,
        ),
        const SizedBox(height: 18),
        _SubSectionHeader(
          badge: 'D',
          title: 'Kendala & Rencana Tindak Lanjut',
          subtitle: 'Catat hambatan, rekomendasi, dan langkah penyelesaian.',
        ),
        const SizedBox(height: 10),
        fieldBuilder(
          controller: obstaclesController,
          label: 'Kendala yang Ditemukan *',
          hint: 'Contoh: Akses jalan rusak akibat hujan / keterbatasan pendamping...',
          maxLines: 3,
          validator: (val) => (val == null || val.trim().isEmpty)
              ? 'Kendala wajib diisi'
              : null,
        ),
        const SizedBox(height: 12),
        fieldBuilder(
          controller: failureCausesController,
          label: 'Penyebab Target Belum Tercapai',
          hint: 'Uraikan faktor penyebab jika target belum tercapai 100% (opsional jika tercapai)',
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        fieldBuilder(
          controller: recommendationsController,
          label: 'Rekomendasi Perbaikan *',
          hint: 'Saran atau solusi teknis untuk mengatasi kendala di lapangan...',
          maxLines: 3,
          validator: (val) => (val == null || val.trim().isEmpty)
              ? 'Rekomendasi perbaikan wajib diisi'
              : null,
        ),
        const SizedBox(height: 12),
        fieldBuilder(
          controller: followUpPlanController,
          label: 'Rencana Tindak Lanjut *',
          hint: 'Langkah konkret, PIC, atau jadwal kunjungan lanjutan...',
          maxLines: 3,
          validator: (val) => (val == null || val.trim().isEmpty)
              ? 'Rencana tindak lanjut wajib diisi'
              : null,
        ),
        const SizedBox(height: 12),
        const Text(
          'Target Penyelesaian Berikutnya',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onPickNextTargetDate,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            decoration: BoxDecoration(
              color: LaporanColors.fieldFill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: LaporanColors.borderCard),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.event_available_outlined,
                  size: 19,
                  color: LaporanColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _formatDateLabel(nextTargetDate),
                    style: TextStyle(
                      fontSize: 13.5,
                      color: nextTargetDate != null
                          ? const Color(0xFF111827)
                          : const Color(0xFF6B7280),
                    ),
                  ),
                ),
                if (nextTargetDate != null)
                  GestureDetector(
                    onTap: onClearNextTargetDate,
                    child: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Color(0xFF6B7280),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SubSectionHeader extends StatelessWidget {
  final String badge;
  final String title;
  final String subtitle;

  const _SubSectionHeader({
    required this.badge,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: LaporanColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: LaporanColors.primary,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badge,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1B5E20),
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF4B5563),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveCalculationPanel extends StatelessWidget {
  final MonitoringCalculationResult calc;

  const _LiveCalculationPanel({required this.calc});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6FAF7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: LaporanColors.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Perhitungan Capaian Otomatis',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
              MonitoringStatusBadge(status: calc.status, compact: true),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: calc.progressFraction,
              minHeight: 8,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: AlwaysStoppedAnimation<Color>(
                calc.isAchieved
                    ? LaporanColors.primary
                    : calc.isNotAchieved
                        ? const Color(0xFFEF6C00)
                        : const Color(0xFFC62828),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MetricCell(
                label: 'Target',
                value: calc.formattedTarget,
              ),
              _MetricCell(
                label: 'Hasil Aktual',
                value: calc.formattedActual,
              ),
              _MetricCell(
                label: 'Capaian',
                value: calc.formattedPercentage,
                highlight: true,
              ),
              _MetricCell(
                label: 'Sisa Target',
                value: calc.formattedRemaining,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            MonitoringCalculator.buildComparisonSummary(calc),
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF4B5563),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCell extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _MetricCell({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: highlight
                  ? LaporanColors.primary
                  : const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}

class MonitoringSummaryCard extends StatelessWidget {
  final Map<String, dynamic> laporan;

  const MonitoringSummaryCard({super.key, required this.laporan});

  String _pick(Map<String, dynamic> merged, String key, [String fallback = '-']) {
    final direct = laporan[key];
    if (direct != null && direct.toString().trim().isNotEmpty) {
      return direct.toString().trim();
    }
    final nested = merged[key];
    if (nested != null && nested.toString().trim().isNotEmpty) {
      return nested.toString().trim();
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final merged = MonitoringCalculator.extractMonitoringMap(laporan);
    final unit = _pick(merged, 'target_unit', 'satuan');
    final calc = MonitoringCalculator.calculate(
      target: laporan['target_value'] ?? merged['target_value'],
      actual: laporan['actual_value'] ?? merged['actual_value'],
      unit: unit,
    );

    final activityName = _pick(merged, 'activity_name');
    final monitoringPeriod = _pick(merged, 'monitoring_period');
    final officerName = _pick(merged, 'officer_name');
    final targetPeriod = _pick(merged, 'target_period');
    final fieldFacts = _pick(merged, 'field_facts');
    final obstacles = _pick(merged, 'obstacles');
    final failureCauses = _pick(merged, 'failure_causes');
    final recommendations = _pick(merged, 'recommendations');
    final followUpPlan = _pick(merged, 'follow_up_plan');
    final nextTargetDate = _pick(merged, 'next_target_date');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LiveCalculationPanel(calc: calc),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: LaporanColors.borderCard),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ringkasan Laporan Monitoring',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 10),
              _SummaryRow(label: 'Kegiatan Dimonitor', value: activityName),
              _SummaryRow(label: 'Periode Monitoring', value: monitoringPeriod),
              _SummaryRow(label: 'Periode Target', value: targetPeriod),
              _SummaryRow(label: 'Petugas / Pelaksana', value: officerName),
              const Divider(height: 18),
              _SummaryRow(label: 'Fakta Lapangan', value: fieldFacts),
              _SummaryRow(label: 'Kendala', value: obstacles),
              if (failureCauses != '-')
                _SummaryRow(label: 'Penyebab Belum Tercapai', value: failureCauses),
              _SummaryRow(label: 'Rekomendasi', value: recommendations),
              _SummaryRow(label: 'Rencana Tindak Lanjut', value: followUpPlan),
              _SummaryRow(
                label: 'Target Penyelesaian Berikutnya',
                value: nextTargetDate,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF111827),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
