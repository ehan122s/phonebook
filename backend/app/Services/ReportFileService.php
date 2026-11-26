<?php

namespace App\Services;

use App\Models\Report;
use App\Models\ReportFile;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\ValidationException;

/**
 * Orkestrasi upload, download (signed URL / stream), dan delete dokumen lampiran laporan
 * menggunakan Supabase Storage.
 */
class ReportFileService
{
    public function __construct(
        private readonly SupabaseStorageService $supabaseStorage
    ) {}

    /**
     * Validasi dokumen dan unggah ke Supabase Storage pada path:
     * reports/{user_id}/{report_id}/{filename}
     *
     * @param  array{title?: string|null, description?: string|null}  $meta
     */
    public function uploadForReport(Report $report, UploadedFile $file, array $meta = []): ReportFile
    {
        $maxKb = (int) config('filesystems.report_files.max_size_kb', 20480);
        $allowedExts = config('filesystems.report_files.allowed_extensions', ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'csv', 'txt']);
        $allowedMimes = config('filesystems.report_files.allowed_mimes', []);

        $ext = strtolower($file->getClientOriginalExtension());
        if (!in_array($ext, $allowedExts, true)) {
            throw ValidationException::withMessages([
                'file' => ['Ekstensi file tidak didukung. Gunakan PDF, DOC, DOCX, XLS, XLSX, CSV, atau TXT.'],
            ]);
        }

        $size = (int) $file->getSize();
        if ($size <= 0 || $size > ($maxKb * 1024)) {
            throw ValidationException::withMessages([
                'file' => ["Ukuran dokumen maksimal {$maxKb} KB dan tidak boleh kosong."],
            ]);
        }

        $realPath = $file->getRealPath();
        $binary = $realPath && file_exists($realPath) ? file_get_contents($realPath) : false;
        if ($binary === false || $binary === '') {
            throw ValidationException::withMessages([
                'file' => ['Berkas dokumen tidak dapat dibaca.'],
            ]);
        }

        $detectedMime = $this->resolveDocumentMime($file, $binary, $ext);
        if (!empty($allowedMimes) && !in_array($detectedMime, $allowedMimes, true)) {
            throw ValidationException::withMessages([
                'file' => ['Tipe MIME berkas tidak diizinkan untuk dokumen laporan.'],
            ]);
        }

        $originalName = $file->getClientOriginalName() ?: ("dokumen_laporan.{$ext}");
        $cleanBase = pathinfo(preg_replace('/[^A-Za-z0-9._-]/', '_', $originalName), PATHINFO_FILENAME);
        $cleanBase = trim((string) $cleanBase, '._-') ?: 'dokumen';
        $uniqueName = "{$cleanBase}_" . date('YmdHis') . '_' . substr(uniqid('', false), -5) . ".{$ext}";

        $bucket = (string) config('services.supabase.storage_bucket', 'reports');
        $storagePath = "reports/{$report->user_id}/{$report->id}/{$uniqueName}";
        $fileUrl = null;

        if ($this->supabaseStorage->isConfigured()) {
            $uploaded = $this->supabaseStorage->upload($bucket, $storagePath, $binary, $detectedMime);
            $bucket = $uploaded['bucket'];
            $storagePath = $uploaded['path'];
            $fileUrl = $uploaded['public_url'];
        } elseif (app()->environment('production')) {
            throw new \RuntimeException('Layanan Supabase Storage belum dikonfigurasi pada server produksi.');
        } else {
            // Fallback non-produksi agar pengujian lokal tetap berjalan tanpa kredensial eksternal
            Storage::disk('local')->put($storagePath, $binary);
        }

        return ReportFile::create([
            'report_id' => $report->id,
            'user_id' => $report->user_id,
            'title' => !empty($meta['title']) ? trim((string) $meta['title']) : $originalName,
            'description' => isset($meta['description']) ? trim((string) $meta['description']) : null,
            'file_name' => $originalName,
            'storage_bucket' => $bucket,
            'storage_path' => $storagePath,
            'file_url' => $fileUrl,
            'mime_type' => $detectedMime,
            'file_size' => strlen($binary),
        ]);
    }

    /**
     * Buat Signed URL akses sementara untuk bucket privat.
     */
    public function createSignedUrl(ReportFile $reportFile, ?int $expiresIn = null): string
    {
        if ($this->supabaseStorage->isConfigured()) {
            return $this->supabaseStorage->createSignedUrl(
                $reportFile->storage_bucket ?: 'reports',
                $reportFile->storage_path,
                $expiresIn
            );
        }

        return $reportFile->download_url;
    }

    /**
     * Ambil konten biner dokumen untuk di-stream ke pengguna yang berwenang.
     *
     * @return array{content: string, content_type: string}
     */
    public function fetchContent(ReportFile $reportFile): array
    {
        if ($this->supabaseStorage->isConfigured()) {
            return $this->supabaseStorage->download(
                $reportFile->storage_bucket ?: 'reports',
                $reportFile->storage_path
            );
        }

        if (Storage::disk('local')->exists($reportFile->storage_path)) {
            return [
                'content' => Storage::disk('local')->get($reportFile->storage_path),
                'content_type' => $reportFile->mime_type ?: 'application/octet-stream',
            ];
        }

        throw new \RuntimeException('Berkas dokumen tidak ditemukan.');
    }

    /**
     * Hapus dokumen dari Supabase Storage dan hapus metadata dari database.
     */
    public function deleteFile(ReportFile $reportFile): void
    {
        if ($this->supabaseStorage->isConfigured()) {
            $this->supabaseStorage->delete(
                $reportFile->storage_bucket ?: 'reports',
                $reportFile->storage_path
            );
        } else {
            try {
                if (Storage::disk('local')->exists($reportFile->storage_path)) {
                    Storage::disk('local')->delete($reportFile->storage_path);
                }
            } catch (\Throwable $e) {
                // Abaikan error pembersihan disk lokal
            }
        }

        $reportFile->delete();
    }

    private function resolveDocumentMime(UploadedFile $file, string $binary, string $ext): string
    {
        $finfoMime = null;
        if (function_exists('finfo_open')) {
            $finfo = @finfo_open(FILEINFO_MIME_TYPE);
            if ($finfo !== false) {
                $detected = @finfo_buffer($finfo, $binary);
                @finfo_close($finfo);
                if (is_string($detected) && $detected !== '') {
                    $finfoMime = $detected;
                }
            }
        }

        $clientMime = $file->getMimeType() ?: $finfoMime;

        // Office OpenXML (.docx / .xlsx) sering terdeteksi finfo sebagai application/zip
        if ($ext === 'docx' && in_array($finfoMime, ['application/zip', 'application/octet-stream', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'], true)) {
            return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
        }
        if ($ext === 'xlsx' && in_array($finfoMime, ['application/zip', 'application/octet-stream', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'], true)) {
            return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
        }
        if ($ext === 'doc' && in_array($finfoMime, ['application/msword', 'application/x-ole-storage', 'application/octet-stream'], true)) {
            return 'application/msword';
        }
        if ($ext === 'xls' && in_array($finfoMime, ['application/vnd.ms-excel', 'application/x-ole-storage', 'application/octet-stream'], true)) {
            return 'application/vnd.ms-excel';
        }
        if ($ext === 'csv' && in_array($finfoMime, ['text/plain', 'text/csv', 'application/csv'], true)) {
            return 'text/csv';
        }

        return (string) ($finfoMime ?: $clientMime ?: 'application/octet-stream');
    }
}
