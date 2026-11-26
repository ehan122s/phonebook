<?php

namespace App\Services;

use App\Models\Report;
use App\Models\ReportPhoto;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\ValidationException;

/**
 * Orkestrasi unggah, validasi, dan penghapusan foto laporan melalui ImageKit
 * dengan fallback aman untuk foto lama dan lingkungan pengujian.
 */
class ReportPhotoService
{
    public function __construct(
        private readonly ImageKitService $imageKit
    ) {}

    /**
     * Validasi dan simpan foto laporan ke ImageKit, lalu catat metadata ke PostgreSQL.
     *
     * @param  array{latitude?: float|string|null, longitude?: float|string|null, address?: string|null}  $meta
     */
    public function storeForReport(
        Report $report,
        ?UploadedFile $file = null,
        ?string $base64Input = null,
        array $meta = []
    ): ReportPhoto {
        $resolved = $this->extractAndValidateImage($report, $file, $base64Input);

        $binary = $resolved['binary'];
        $fileName = $resolved['file_name'];
        $mimeType = $resolved['mime_type'];
        $fileSize = strlen($binary);

        $photoPath = 'reports/' . $fileName;
        $imagekitUrl = null;
        $imagekitFileId = null;
        $storageProvider = 'local';

        if ($this->imageKit->isConfigured()) {
            $baseFolder = rtrim((string) config('services.imagekit.folder', '/phonebook/reports'), '/');
            $folder = "{$baseFolder}/{$report->user_id}/{$report->id}";

            $uploaded = $this->imageKit->upload($binary, $fileName, $folder);
            $imagekitUrl = $uploaded['url'];
            $imagekitFileId = $uploaded['file_id'];
            $photoPath = $imagekitUrl;
            $fileName = $uploaded['name'] ?: $fileName;
            $fileSize = $uploaded['size'] ?: $fileSize;
            $storageProvider = 'imagekit';
        } elseif (app()->environment('production')) {
            throw new \RuntimeException('Layanan ImageKit belum dikonfigurasi pada server produksi.');
        } else {
            // Lingkungan dev/testing tanpa kredensial ImageKit: simpan ke disk public (bukan ke kolom DB)
            try {
                if (!Storage::disk('public')->exists('reports')) {
                    Storage::disk('public')->makeDirectory('reports');
                }
                $storedPath = "reports/{$fileName}";
                Storage::disk('public')->put($storedPath, $binary);
                $photoPath = $storedPath;
            } catch (\Throwable $e) {
                $photoPath = "reports/{$fileName}";
            }
        }

        $photoData = [
            'report_id' => $report->id,
            'photo' => $photoPath,
            'latitude' => $meta['latitude'] ?? $report->latitude,
            'longitude' => $meta['longitude'] ?? $report->longitude,
        ];

        $columns = $this->getPhotoColumns();

        if (in_array('address', $columns, true)) {
            $photoData['address'] = $meta['address'] ?? $report->location;
        }
        if (in_array('imagekit_file_id', $columns, true)) {
            $photoData['imagekit_file_id'] = $imagekitFileId;
        }
        if (in_array('imagekit_url', $columns, true)) {
            $photoData['imagekit_url'] = $imagekitUrl;
        }
        if (in_array('file_name', $columns, true)) {
            $photoData['file_name'] = $fileName;
        }
        if (in_array('mime_type', $columns, true)) {
            $photoData['mime_type'] = $mimeType;
        }
        if (in_array('file_size', $columns, true)) {
            $photoData['file_size'] = $fileSize;
        }
        if (in_array('storage_provider', $columns, true)) {
            $photoData['storage_provider'] = $storageProvider;
        }
        // Jangan pernah simpan binary base64 baru ke database jika sudah berhasil diupload ke ImageKit
        if (in_array('photo_base64', $columns, true)) {
            $photoData['photo_base64'] = null;
        }

        $reportPhoto = ReportPhoto::create($photoData);

        if (($report->latitude === null || $report->longitude === null)
            && !empty($meta['latitude'])
            && !empty($meta['longitude'])
        ) {
            $report->update([
                'latitude' => $meta['latitude'],
                'longitude' => $meta['longitude'],
            ]);
        }

        return $reportPhoto;
    }

    /**
     * Hapus foto dari ImageKit / storage lokal dan hapus metadata di database.
     */
    public function deletePhoto(ReportPhoto $photo): void
    {
        if (!empty($photo->imagekit_file_id) && $this->imageKit->isConfigured()) {
            $this->imageKit->delete($photo->imagekit_file_id);
        }

        try {
            if ($photo->photo
                && !filter_var($photo->photo, FILTER_VALIDATE_URL)
                && Storage::disk('public')->exists($photo->photo)
            ) {
                Storage::disk('public')->delete($photo->photo);
            }
        } catch (\Throwable $e) {
            // Abaikan kegagalan pembersihan disk lokal
        }

        $photo->delete();
    }

    /**
     * @return array{binary: string, file_name: string, mime_type: string}
     */
    private function extractAndValidateImage(Report $report, ?UploadedFile $file, ?string $base64Input): array
    {
        $maxKb = (int) config('filesystems.report_photos.max_size_kb', 10240);
        $maxBytes = $maxKb * 1024;
        $allowedMimes = config('filesystems.report_photos.allowed_mimes', ['image/jpeg', 'image/png', 'image/webp', 'image/gif']);

        $binary = null;
        $ext = 'jpg';
        $originalName = null;

        if ($file !== null) {
            $realPath = $file->getRealPath();
            if ($realPath && file_exists($realPath)) {
                $content = file_get_contents($realPath);
                if ($content !== false) {
                    $binary = $content;
                }
            }
            $originalName = $file->getClientOriginalName();
            $ext = strtolower($file->getClientOriginalExtension() ?: 'jpg');
        }

        if ($binary === null && $base64Input !== null && trim($base64Input) !== '') {
            $rawB64 = trim($base64Input);
            if (preg_match('/^data:image\/([a-zA-Z0-9+.-]+);base64,/', $rawB64, $matches)) {
                $ext = strtolower($matches[1] === 'jpeg' ? 'jpg' : $matches[1]);
                $rawB64 = substr($rawB64, strpos($rawB64, ',') + 1);
            }
            $decoded = base64_decode($rawB64, true);
            if ($decoded === false || $decoded === '') {
                throw ValidationException::withMessages([
                    'photo_base64' => ['Data foto Base64 tidak valid.'],
                ]);
            }
            $binary = $decoded;
        }

        if ($binary === null || $binary === '') {
            throw ValidationException::withMessages([
                'photo' => ['Berkas foto atau data foto wajib disertakan.'],
            ]);
        }

        if (strlen($binary) > $maxBytes) {
            throw ValidationException::withMessages([
                'photo' => ["Ukuran foto melebihi batas maksimal {$maxKb} KB."],
            ]);
        }

        $detectedMime = $this->detectImageMime($binary);
        if ($detectedMime === null || !in_array($detectedMime, $allowedMimes, true)) {
            throw ValidationException::withMessages([
                'photo' => ['Format file tidak valid. Hanya gambar JPG, PNG, WEBP, atau GIF yang diizinkan.'],
            ]);
        }

        $extFromMime = match ($detectedMime) {
            'image/png' => 'png',
            'image/webp' => 'webp',
            'image/gif' => 'gif',
            default => 'jpg',
        };
        if (!in_array($ext, ['jpg', 'jpeg', 'png', 'webp', 'gif'], true)) {
            $ext = $extFromMime;
        }

        $baseName = $originalName
            ? pathinfo(preg_replace('/[^A-Za-z0-9._-]/', '_', $originalName), PATHINFO_FILENAME)
            : 'report_' . $report->id . '_' . time();
        $cleanBase = trim((string) $baseName, '._-') ?: 'report_' . $report->id;
        $fileName = "{$cleanBase}_" . uniqid('', false) . ".{$ext}";

        return [
            'binary' => $binary,
            'file_name' => $fileName,
            'mime_type' => $detectedMime,
        ];
    }

    private function detectImageMime(string $binary): ?string
    {
        if (function_exists('finfo_open')) {
            $finfo = @finfo_open(FILEINFO_MIME_TYPE);
            if ($finfo !== false) {
                $mime = @finfo_buffer($finfo, $binary);
                @finfo_close($finfo);
                if (is_string($mime) && str_starts_with($mime, 'image/')) {
                    return $mime;
                }
            }
        }

        $info = @getimagesizefromstring($binary);
        if (is_array($info) && !empty($info['mime'])) {
            return (string) $info['mime'];
        }

        return null;
    }

    /**
     * @return array<int, string>
     */
    private function getPhotoColumns(): array
    {
        try {
            return Cache::remember('schema_report_photos_columns_v2', 300, static function () {
                return Schema::connection('db_foto')->getColumnListing('report_photos');
            });
        } catch (\Throwable $e) {
            return ['id', 'report_id', 'photo', 'latitude', 'longitude'];
        }
    }
}
