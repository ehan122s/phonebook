<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use RuntimeException;

/**
 * Service wrapper untuk ImageKit REST API (Upload, Delete, & Verifikasi).
 * Private key hanya dibaca dari environment backend dan tidak pernah diekspos keluar.
 */
class ImageKitService
{
    public function isConfigured(): bool
    {
        return !empty(config('services.imagekit.private_key'))
            && !empty(config('services.imagekit.url_endpoint'));
    }

    /**
     * Unggah berkas gambar biner ke ImageKit.
     *
     * @return array{file_id: string, url: string, name: string, size: int|null, file_path: string|null}
     */
    public function upload(string $binaryContent, string $fileName, ?string $folder = null): array
    {
        $privateKey = (string) config('services.imagekit.private_key');
        $uploadEndpoint = (string) config('services.imagekit.upload_endpoint', 'https://upload.imagekit.io/api/v1/files/upload');
        $defaultFolder = (string) config('services.imagekit.folder', '/phonebook/reports');

        if (empty($privateKey) || empty(config('services.imagekit.url_endpoint'))) {
            throw new RuntimeException('Konfigurasi ImageKit belum lengkap di environment server.');
        }

        $safeFolder = $this->normalizeFolder($folder ?: $defaultFolder);
        $safeFileName = $this->sanitizeFileName($fileName);

        try {
            $response = Http::withBasicAuth($privateKey, '')
                ->timeout(25)
                ->attach('file', $binaryContent, $safeFileName)
                ->post($uploadEndpoint, [
                    'fileName' => $safeFileName,
                    'folder' => $safeFolder,
                    'useUniqueFileName' => 'true',
                ]);
        } catch (\Throwable $e) {
            Log::error('ImageKit upload connection error', [
                'file_name' => $safeFileName,
                'folder' => $safeFolder,
                'error' => $e->getMessage(),
            ]);
            throw new RuntimeException('Gagal menghubungi layanan penyimpanan foto ImageKit.');
        }

        if (!$response->successful()) {
            Log::error('ImageKit upload rejected', [
                'status' => $response->status(),
                'file_name' => $safeFileName,
                'folder' => $safeFolder,
                'body' => mb_substr($response->body(), 0, 300),
            ]);
            throw new RuntimeException('Gagal mengunggah foto ke layanan penyimpanan (HTTP ' . $response->status() . ').');
        }

        $data = $response->json();
        if (!is_array($data) || empty($data['fileId']) || empty($data['url'])) {
            Log::error('ImageKit upload invalid response', ['file_name' => $safeFileName]);
            throw new RuntimeException('Respon ImageKit tidak valid saat mengunggah foto.');
        }

        return [
            'file_id' => (string) $data['fileId'],
            'url' => (string) $data['url'],
            'name' => (string) ($data['name'] ?? $safeFileName),
            'size' => isset($data['size']) ? (int) $data['size'] : strlen($binaryContent),
            'file_path' => isset($data['filePath']) ? (string) $data['filePath'] : null,
        ];
    }

    /**
     * Hapus berkas di ImageKit berdasarkan fileId.
     */
    public function delete(string $fileId): bool
    {
        $privateKey = (string) config('services.imagekit.private_key');
        $apiEndpoint = rtrim((string) config('services.imagekit.api_endpoint', 'https://api.imagekit.io/v1'), '/');

        $cleanId = trim($fileId);
        if ($cleanId === '' || empty($privateKey)) {
            return false;
        }

        try {
            $response = Http::withBasicAuth($privateKey, '')
                ->timeout(15)
                ->delete("{$apiEndpoint}/files/" . rawurlencode($cleanId));

            if ($response->successful() || $response->status() === 404) {
                return true;
            }

            Log::warning('ImageKit delete returned non-success', [
                'file_id' => $cleanId,
                'status' => $response->status(),
            ]);
            return false;
        } catch (\Throwable $e) {
            Log::warning('ImageKit delete exception', [
                'file_id' => $cleanId,
                'error' => $e->getMessage(),
            ]);
            return false;
        }
    }

    /**
     * Verifikasi bahwa URL ImageKit dapat diakses publik via HTTP.
     */
    public function verifyUrlAccessible(string $url): bool
    {
        if (!filter_var($url, FILTER_VALIDATE_URL)) {
            return false;
        }

        try {
            $response = Http::timeout(10)->head($url);
            if ($response->successful()) {
                return true;
            }

            $getRes = Http::timeout(10)->get($url);
            return $getRes->successful();
        } catch (\Throwable $e) {
            return false;
        }
    }

    private function normalizeFolder(string $folder): string
    {
        $clean = str_replace(['..', '\\'], ['', '/'], trim($folder));
        $clean = preg_replace('#/+#', '/', $clean) ?: '/phonebook/reports';
        return '/' . ltrim($clean, '/');
    }

    private function sanitizeFileName(string $fileName): string
    {
        $base = basename(str_replace('\\', '/', $fileName));
        $clean = preg_replace('/[^A-Za-z0-9._-]/', '_', $base) ?: 'photo.jpg';
        return ltrim($clean, '.');
    }
}
