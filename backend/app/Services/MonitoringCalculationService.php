<?php

namespace App\Services;

/**
 * Layanan perhitungan capaian Laporan Monitoring secara deterministik dan aman.
 * Persentase capaian, sisa target, dan status pencapaian selalu dihitung di server
 * dari input target & hasil aktual pengguna (tidak pernah diketik manual).
 */
class MonitoringCalculationService
{
    public const STATUS_ACHIEVED = 'Tercapai';
    public const STATUS_NOT_ACHIEVED = 'Belum tercapai';
    public const STATUS_NEEDS_CHECK = 'Perlu diperiksa';

    /**
     * Hitung persentase capaian, sisa target, dan status pencapaian.
     *
     * @return array{
     *   achievement_percentage: float|null,
     *   remaining_target: float|null,
     *   achievement_status: string
     * }
     */
    public function calculate(?float $targetValue, ?float $actualValue): array
    {
        if (
            $targetValue === null
            || $actualValue === null
            || !is_finite($targetValue)
            || !is_finite($actualValue)
            || $targetValue <= 0
            || $actualValue < 0
        ) {
            return [
                'achievement_percentage' => null,
                'remaining_target' => ($targetValue !== null && is_finite($targetValue) && $targetValue > 0 && $actualValue !== null && is_finite($actualValue) && $actualValue >= 0)
                    ? round(max(0.0, $targetValue - $actualValue), 2)
                    : null,
                'achievement_status' => self::STATUS_NEEDS_CHECK,
            ];
        }

        $percentage = round(($actualValue / $targetValue) * 100, 2);
        $remaining = round(max(0.0, $targetValue - $actualValue), 2);
        $status = $actualValue >= $targetValue
            ? self::STATUS_ACHIEVED
            : self::STATUS_NOT_ACHIEVED;

        return [
            'achievement_percentage' => $percentage,
            'remaining_target' => $remaining,
            'achievement_status' => $status,
        ];
    }

    /**
     * Format angka desimal agar bilangan bulat tampil rapi (mis. 5.00 -> 5, 2.50 -> 2.5).
     */
    public function formatNumber(?float $value): string
    {
        if ($value === null || !is_finite($value)) {
            return '-';
        }

        $rounded = round($value, 2);
        if (abs($rounded - round($rounded)) < 0.0001) {
            return (string) (int) round($rounded);
        }

        return rtrim(rtrim(number_format($rounded, 2, '.', ''), '0'), '.');
    }

    /**
     * Susun ringkasan teks terstruktur untuk kolom description / tampilan fallback.
     *
     * @param  array<string, mixed>  $data
     */
    public function buildStructuredSummaryText(array $data): string
    {
        $activityName = trim((string) ($data['activity_name'] ?? $data['title'] ?? '-'));
        $period = trim((string) ($data['monitoring_period'] ?? '-'));
        $targetPeriod = trim((string) ($data['target_period'] ?? $period));
        $officer = trim((string) ($data['officer_name'] ?? '-'));
        $unit = trim((string) ($data['target_unit'] ?? 'unit'));

        $targetVal = isset($data['target_value']) && $data['target_value'] !== '' ? (float) $data['target_value'] : null;
        $actualVal = isset($data['actual_value']) && $data['actual_value'] !== '' ? (float) $data['actual_value'] : null;
        $calc = $this->calculate($targetVal, $actualVal);

        $targetStr = $targetVal !== null ? $this->formatNumber($targetVal) . " {$unit}" : '-';
        $actualStr = $actualVal !== null ? $this->formatNumber($actualVal) . " {$unit}" : '-';
        $pctStr = $calc['achievement_percentage'] !== null ? $this->formatNumber($calc['achievement_percentage']) . '%' : '-';
        $remStr = $calc['remaining_target'] !== null ? $this->formatNumber($calc['remaining_target']) . " {$unit}" : '-';
        $statusStr = $calc['achievement_status'];

        $facts = trim((string) ($data['field_facts'] ?? '-'));
        $obstacles = trim((string) ($data['obstacles'] ?? '-'));
        $causes = trim((string) ($data['failure_causes'] ?? '-'));
        $recommendations = trim((string) ($data['recommendations'] ?? '-'));
        $followUp = trim((string) ($data['follow_up_plan'] ?? '-'));
        $nextDate = trim((string) ($data['next_target_date'] ?? '-'));

        $lines = [
            'LAPORAN MONITORING KEGIATAN',
            'Cabang Dinas Kehutanan Wilayah V',
            '',
            "1. Nama Kegiatan          : {$activityName}",
            "2. Periode Monitoring     : {$period}",
            "3. Petugas / Pelaksana    : {$officer}",
            "4. Target Direncanakan    : {$targetStr}" . ($targetPeriod !== '' && $targetPeriod !== '-' ? " (Periode: {$targetPeriod})" : ''),
            "5. Hasil Aktual           : {$actualStr}",
            "6. Persentase Capaian     : {$pctStr}",
            "7. Sisa Target            : {$remStr}",
            "8. Status Pencapaian      : {$statusStr}",
            '',
            '9. Fakta & Kondisi Lapangan:',
            $facts !== '' ? $facts : '-',
            '',
            '10. Kendala & Penyebab Belum Tercapai:',
            'Kendala: ' . ($obstacles !== '' ? $obstacles : '-'),
            'Penyebab: ' . ($causes !== '' ? $causes : '-'),
            '',
            '11. Rekomendasi Perbaikan:',
            $recommendations !== '' ? $recommendations : '-',
            '',
            '12. Rencana Tindak Lanjut:',
            $followUp !== '' ? $followUp : '-',
            'Target Penyelesaian Berikutnya: ' . ($nextDate !== '' ? $nextDate : '-'),
        ];

        return implode("\n", $lines);
    }
}
