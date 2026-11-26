<?php

namespace App\Console\Commands;

use App\Models\ReportPhoto;
use App\Services\ImageKitService;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Storage;

class MigrateReportPhotosToImageKit extends Command
{
    protected $signature = 'photos:migrate-imagekit
        {--dry-run : Hitung dan inventarisasi foto lama tanpa mengunggah ke ImageKit}
        {--limit=0 : Batasi jumlah foto yang dimigrasi per eksekusi (0 = semua)}
        {--retry-failed : Hanya coba ulang foto yang tercatat gagal sebelumnya}
        {--skip-verify : Lewati pemeriksaan HTTP aksesibilitas URL setelah upload}';

    protected $description = 'Migrasi foto laporan lama (storage lokal / photo_base64) ke ImageKit secara aman tanpa menghapus data lama.';

    public function handle(ImageKitService $imageKit): int
    {
        $dryRun = (bool) $this->option('dry-run');
        $limit = max(0, (int) $this->option('limit'));
        $retryFailed = (bool) $this->option('retry-failed');
        $skipVerify = (bool) $this->option('skip-verify');

        if (!$dryRun && !$imageKit->isConfigured()) {
            $this->error('Konfigurasi ImageKit (IMAGEKIT_PUBLIC_KEY, IMAGEKIT_PRIVATE_KEY, IMAGEKIT_URL_ENDPOINT) belum diisi di .env.');
            return self::FAILURE;
        }

        $backupDir = storage_path('app/backups');
        if (!is_dir($backupDir)) {
            @mkdir($backupDir, 0755, true);
        }
        $failedFilePath = $backupDir . '/report_photos_failed.json';

        $query = ReportPhoto::with('report')
            ->where(function ($q) {
                $q->whereNull('imagekit_url')
                    ->orWhere('imagekit_url', '')
                    ->orWhere('storage_provider', '!=', 'imagekit');
            })
            ->orderBy('id');

        if ($retryFailed) {
            if (!file_exists($failedFilePath)) {
                $this->info('Tidak ada daftar foto gagal yang perlu dicoba ulang.');
                return self::SUCCESS;
            }
            $failedRows = json_decode((string) file_get_contents($failedFilePath), true);
            $failedIds = is_array($failedRows) ? array_values(array_filter(array_column($failedRows, 'id'))) : [];
            if (empty($failedIds)) {
                $this->info('Daftar foto gagal kosong.');
                return self::SUCCESS;
            }
            $query->whereIn('id', $failedIds);
        }

        if ($limit > 0) {
            $query->limit($limit);
        }

        $photos = $query->get();
        $totalCandidates = $photos->count();

        // Inventarisasi lokasi sumber
        $fromLocal = 0;
        $fromBase64 = 0;
        $alreadyUrl = 0;
        $unreadable = 0;
        $backupPayload = [];

        foreach ($photos as $photo) {
            $source = $this->detectSourceType($photo);
            match ($source) {
                'local_disk' => $fromLocal++,
                'base64' => $fromBase64++,
                'external_url' => $alreadyUrl++,
                default => $unreadable++,
            };

            $backupPayload[] = [
                'id' => $photo->id,
                'report_id' => $photo->report_id,
                'photo' => $photo->photo,
                'storage_provider' => $photo->storage_provider,
                'latitude' => $photo->latitude,
                'longitude' => $photo->longitude,
                'address' => $photo->address,
                'has_base64' => !empty($photo->photo_base64),
                'base64_length' => $photo->photo_base64 ? strlen($photo->photo_base64) : 0,
                'detected_source' => $source,
                'created_at' => optional($photo->created_at)->toIso8601String(),
            ];
        }

        $this->info("=== Inventarisasi Foto Laporan Lama ===");
        $this->line("Total foto kandidat migrasi : {$totalCandidates}");
        $this->line(" - Sumber disk lokal        : {$fromLocal}");
        $this->line(" - Sumber kolom Base64      : {$fromBase64}");
        $this->line(" - Sudah berupa URL         : {$alreadyUrl}");
        $this->line(" - Tidak ditemukan fisiknya : {$unreadable}");

        if ($totalCandidates === 0) {
            $this->info('Seluruh foto sudah termigrasi atau tidak ada foto lama yang perlu dipindahkan.');
            return self::SUCCESS;
        }

        $backupFile = $backupDir . '/report_photos_backup_' . date('Ymd_His') . '.json';
        file_put_contents($backupFile, json_encode($backupPayload, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES));
        $this->info("Backup metadata tersimpan di: {$backupFile}");

        if ($dryRun) {
            $this->warn('Mode --dry-run aktif: tidak ada perubahan database atau upload yang dijalankan.');
            return self::SUCCESS;
        }

        $migrated = 0;
        $skipped = 0;
        $failed = [];

        foreach ($photos as $photo) {
            // Jika ternyata sudah URL eksternal non-ImageKit namun bukan lokal/base64, catat sebagai skip agar tidak menimpa tanpa sengaja
            if (!empty($photo->imagekit_url) && $photo->storage_provider === 'imagekit') {
                $skipped++;
                continue;
            }

            try {
                $resolved = $this->extractBinary($photo);
                if ($resolved === null) {
                    $failed[] = [
                        'id' => $photo->id,
                        'report_id' => $photo->report_id,
                        'reason' => 'File fisik di disk maupun data base64 tidak tersedia.',
                    ];
                    continue;
                }

                $userId = $photo->report?->user_id ?? 'unknown';
                $baseFolder = rtrim((string) config('services.imagekit.folder', '/phonebook/reports'), '/');
                $folder = "{$baseFolder}/{$userId}/{$photo->report_id}";

                $uploaded = $imageKit->upload($resolved['binary'], $resolved['file_name'], $folder);

                if (!$skipVerify && !$imageKit->verifyUrlAccessible($uploaded['url'])) {
                    $failed[] = [
                        'id' => $photo->id,
                        'report_id' => $photo->report_id,
                        'reason' => 'Upload berhasil tetapi URL ImageKit belum dapat diakses saat verifikasi.',
                    ];
                    continue;
                }

                // Perbarui metadata ImageKit TANPA menghapus photo_base64 atau file lama sampai terverifikasi manual
                $photo->update([
                    'photo' => $uploaded['url'],
                    'imagekit_url' => $uploaded['url'],
                    'imagekit_file_id' => $uploaded['file_id'],
                    'file_name' => $uploaded['name'] ?: $resolved['file_name'],
                    'mime_type' => $resolved['mime_type'],
                    'file_size' => $uploaded['size'] ?: strlen($resolved['binary']),
                    'storage_provider' => 'imagekit',
                ]);

                $migrated++;
                $this->line("[OK] Foto #{$photo->id} (Laporan #{$photo->report_id}) -> {$uploaded['url']}");
            } catch (\Throwable $e) {
                $failed[] = [
                    'id' => $photo->id,
                    'report_id' => $photo->report_id,
                    'reason' => $e->getMessage(),
                ];
                $this->error("[GAGAL] Foto #{$photo->id}: {$e->getMessage()}");
            }
        }

        if (!empty($failed)) {
            file_put_contents($failedFilePath, json_encode($failed, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES));
        } elseif (file_exists($failedFilePath)) {
            @unlink($failedFilePath);
        }

        $this->newLine();
        $this->info("=== Ringkasan Hasil Migrasi Foto ===");
        $this->line("Berhasil dimigrasi : {$migrated}");
        $this->line("Dilewati           : {$skipped}");
        $this->line("Gagal              : " . count($failed));
        if (!empty($failed)) {
            $this->warn("Detail kegagalan disimpan di {$failedFilePath}. Jalankan ulang dengan --retry-failed.");
        }
        $this->line('Catatan: Foto lama dan kolom photo_base64 TIDAK dihapus otomatis.');

        return count($failed) > 0 ? self::FAILURE : self::SUCCESS;
    }

    private function detectSourceType(ReportPhoto $photo): string
    {
        if (!empty($photo->photo) && !filter_var($photo->photo, FILTER_VALIDATE_URL) && !str_starts_with($photo->photo, 'data:image')) {
            try {
                if (Storage::disk('public')->exists($photo->photo)) {
                    return 'local_disk';
                }
            } catch (\Throwable $e) {
                // Abaikan
            }
        }

        if (!empty($photo->photo_base64) || (!empty($photo->photo) && str_starts_with($photo->photo, 'data:image'))) {
            return 'base64';
        }

        if (!empty($photo->photo) && filter_var($photo->photo, FILTER_VALIDATE_URL)) {
            return 'external_url';
        }

        return 'missing';
    }

    /**
     * @return array{binary: string, file_name: string, mime_type: string}|null
     */
    private function extractBinary(ReportPhoto $photo): ?array
    {
        // 1. Coba dari disk public
        if (!empty($photo->photo) && !filter_var($photo->photo, FILTER_VALIDATE_URL) && !str_starts_with($photo->photo, 'data:image')) {
            try {
                if (Storage::disk('public')->exists($photo->photo)) {
                    $binary = Storage::disk('public')->get($photo->photo);
                    if ($binary !== '') {
                        $mime = Storage::disk('public')->mimeType($photo->photo) ?: 'image/jpeg';
                        $name = basename($photo->photo) ?: "legacy_photo_{$photo->id}.jpg";
                        return [
                            'binary' => $binary,
                            'file_name' => $name,
                            'mime_type' => $mime,
                        ];
                    }
                }
            } catch (\Throwable $e) {
                // Lanjutkan ke fallback base64
            }
        }

        // 2. Coba dari photo_base64 atau data URI di kolom photo
        $rawB64 = $photo->photo_base64 ?: (str_starts_with((string) $photo->photo, 'data:image') ? $photo->photo : null);
        if (!empty($rawB64)) {
            $ext = 'jpg';
            $mime = 'image/jpeg';
            if (preg_match('/^data:(image\/[a-zA-Z0-9+.-]+);base64,/', $rawB64, $matches)) {
                $mime = strtolower($matches[1]);
                $ext = match ($mime) {
                    'image/png' => 'png',
                    'image/webp' => 'webp',
                    'image/gif' => 'gif',
                    default => 'jpg',
                };
                $rawB64 = substr($rawB64, strpos($rawB64, ',') + 1);
            }
            $binary = base64_decode(trim($rawB64), true);
            if ($binary !== false && $binary !== '') {
                return [
                    'binary' => $binary,
                    'file_name' => $photo->file_name ?: "legacy_photo_{$photo->id}.{$ext}",
                    'mime_type' => $mime,
                ];
            }
        }

        return null;
    }
}
