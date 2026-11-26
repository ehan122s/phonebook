<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use RuntimeException;

/**
 * Service wrapper untuk Supabase Storage REST API (Upload, Signed URL, Download, Delete).
 * Service role key hanya dibaca dari environment backend dan tidak pernah diekspos ke frontend.
 */
class SupabaseStorageService
{
    public function isConfigured(): bool
    {
        return !empty(config('services.supabase.url'))
            && !empty(config('services.supabase.service_role_key'));
    }

    /**
     * Unggah file dokumen ke Supabase Storage bucket.
     *
     * @return array{bucket: string, path: string, public_url: string|null}
     */
    public function upload(string $bucket, string $path, string $binaryContent, string $mimeType, bool $upsert = true): array
    {
        $baseUrl = $this->baseUrl();
        $serviceKey = $this->serviceRoleKey();
        $cleanBucket = $this->sanitizeBucket($bucket);
        $cleanPath = $this->sanitizePath($path);
        $encodedPath = $this->encodePath($cleanPath);

        $url = "{$baseUrl}/storage/v1/object/{$cleanBucket}/{$encodedPath}";

        try {
            $response = Http::withHeaders([
                'Authorization' => "Bearer {$serviceKey}",
                'apikey' => $serviceKey,
                'x-upsert' => $upsert ? 'true' : 'false',
            ])
                ->timeout(30)
                ->withBody($binaryContent, $mimeType)
                ->post($url);

            // Jika bucket belum dibuat di Supabase Storage, coba buat bucket privat lalu ulangi sekali
            if ($response->status() === 404 || ($response->status() === 400 && str_contains(strtolower($response->body()), 'bucket'))) {
                $isPublic = (bool) config('services.supabase.storage_public', false);
                $this->ensureBucketExists($cleanBucket, $isPublic);

                $response = Http::withHeaders([
                    'Authorization' => "Bearer {$serviceKey}",
                    'apikey' => $serviceKey,
                    'x-upsert' => $upsert ? 'true' : 'false',
                ])
                    ->timeout(30)
                    ->withBody($binaryContent, $mimeType)
                    ->post($url);
            }
        } catch (\Throwable $e) {
            Log::error('Supabase Storage upload connection error', [
                'bucket' => $cleanBucket,
                'path' => $cleanPath,
                'error' => $e->getMessage(),
            ]);
            throw new RuntimeException('Gagal menghubungi layanan Supabase Storage.');
        }

        if (!$response->successful()) {
            Log::error('Supabase Storage upload rejected', [
                'status' => $response->status(),
                'bucket' => $cleanBucket,
                'path' => $cleanPath,
                'body' => mb_substr($response->body(), 0, 300),
            ]);
            throw new RuntimeException('Gagal mengunggah dokumen ke Supabase Storage (HTTP ' . $response->status() . ').');
        }

        $isPublic = (bool) config('services.supabase.storage_public', false);
        $publicUrl = $isPublic
            ? "{$baseUrl}/storage/v1/object/public/{$cleanBucket}/{$encodedPath}"
            : null;

        return [
            'bucket' => $cleanBucket,
            'path' => $cleanPath,
            'public_url' => $publicUrl,
        ];
    }

    /**
     * Buat Signed URL sementara untuk mengakses berkas di private bucket.
     */
    public function createSignedUrl(string $bucket, string $path, ?int $expiresIn = null): string
    {
        $baseUrl = $this->baseUrl();
        $serviceKey = $this->serviceRoleKey();
        $cleanBucket = $this->sanitizeBucket($bucket);
        $encodedPath = $this->encodePath($this->sanitizePath($path));
        $ttl = max(30, $expiresIn ?? (int) config('services.supabase.signed_url_expires', 300));

        try {
            $response = Http::withHeaders([
                'Authorization' => "Bearer {$serviceKey}",
                'apikey' => $serviceKey,
            ])
                ->timeout(15)
                ->post("{$baseUrl}/storage/v1/object/sign/{$cleanBucket}/{$encodedPath}", [
                    'expiresIn' => $ttl,
                ]);
        } catch (\Throwable $e) {
            throw new RuntimeException('Gagal membuat tautan unduhan sementara dari Supabase Storage.');
        }

        if (!$response->successful()) {
            Log::warning('Supabase Storage sign URL failed', [
                'status' => $response->status(),
                'bucket' => $cleanBucket,
                'path' => $path,
            ]);
            throw new RuntimeException('Dokumen tidak ditemukan atau tidak dapat diakses.');
        }

        $signedPath = (string) ($response->json('signedURL') ?? $response->json('signedUrl') ?? '');
        if ($signedPath === '') {
            throw new RuntimeException('Respon signed URL Supabase Storage tidak valid.');
        }

        if (str_starts_with($signedPath, 'http')) {
            return $signedPath;
        }
        if (str_starts_with($signedPath, '/storage/v1')) {
            return $baseUrl . $signedPath;
        }

        return $baseUrl . '/storage/v1/' . ltrim($signedPath, '/');
    }

    /**
     * Unduh isi biner dokumen secara langsung melalui service role key backend.
     *
     * @return array{content: string, content_type: string}
     */
    public function download(string $bucket, string $path): array
    {
        $baseUrl = $this->baseUrl();
        $serviceKey = $this->serviceRoleKey();
        $cleanBucket = $this->sanitizeBucket($bucket);
        $encodedPath = $this->encodePath($this->sanitizePath($path));

        try {
            $response = Http::withHeaders([
                'Authorization' => "Bearer {$serviceKey}",
                'apikey' => $serviceKey,
            ])
                ->timeout(30)
                ->get("{$baseUrl}/storage/v1/object/{$cleanBucket}/{$encodedPath}");
        } catch (\Throwable $e) {
            throw new RuntimeException('Gagal mengunduh dokumen dari Supabase Storage.');
        }

        if (!$response->successful()) {
            throw new RuntimeException('Dokumen tidak ditemukan di penyimpanan (HTTP ' . $response->status() . ').');
        }

        return [
            'content' => $response->body(),
            'content_type' => $response->header('Content-Type') ?: 'application/octet-stream',
        ];
    }

    /**
     * Hapus dokumen dari Supabase Storage bucket.
     */
    public function delete(string $bucket, string $path): bool
    {
        $baseUrl = $this->baseUrl();
        $serviceKey = $this->serviceRoleKey();
        $cleanBucket = $this->sanitizeBucket($bucket);
        $cleanPath = $this->sanitizePath($path);

        if ($cleanPath === '') {
            return false;
        }

        try {
            $response = Http::withHeaders([
                'Authorization' => "Bearer {$serviceKey}",
                'apikey' => $serviceKey,
            ])
                ->timeout(15)
                ->delete("{$baseUrl}/storage/v1/object/{$cleanBucket}", [
                    'prefixes' => [$cleanPath],
                ]);

            if ($response->successful() || $response->status() === 404) {
                return true;
            }

            Log::warning('Supabase Storage delete failed', [
                'status' => $response->status(),
                'bucket' => $cleanBucket,
                'path' => $cleanPath,
            ]);
            return false;
        } catch (\Throwable $e) {
            Log::warning('Supabase Storage delete exception', [
                'bucket' => $cleanBucket,
                'path' => $cleanPath,
                'error' => $e->getMessage(),
            ]);
            return false;
        }
    }

    public function ensureBucketExists(string $bucket, bool $public = false): void
    {
        $baseUrl = $this->baseUrl();
        $serviceKey = $this->serviceRoleKey();
        $cleanBucket = $this->sanitizeBucket($bucket);

        try {
            Http::withHeaders([
                'Authorization' => "Bearer {$serviceKey}",
                'apikey' => $serviceKey,
            ])
                ->timeout(10)
                ->post("{$baseUrl}/storage/v1/bucket", [
                    'id' => $cleanBucket,
                    'name' => $cleanBucket,
                    'public' => $public,
                ]);
        } catch (\Throwable $e) {
            // Abaikan jika bucket sudah ada atau tidak memiliki izin create bucket
        }
    }

    private function baseUrl(): string
    {
        $url = rtrim((string) config('services.supabase.url'), '/');
        if ($url === '') {
            throw new RuntimeException('SUPABASE_URL belum dikonfigurasi di environment server.');
        }
        return $url;
    }

    private function serviceRoleKey(): string
    {
        $key = (string) config('services.supabase.service_role_key');
        if ($key === '') {
            throw new RuntimeException('SUPABASE_SERVICE_ROLE_KEY belum dikonfigurasi di environment server.');
        }
        return $key;
    }

    private function sanitizeBucket(string $bucket): string
    {
        $clean = preg_replace('/[^A-Za-z0-9._-]/', '', trim($bucket)) ?: 'reports';
        return $clean;
    }

    private function sanitizePath(string $path): string
    {
        $clean = str_replace(['..', '\\'], ['', '/'], trim($path));
        $clean = preg_replace('#/+#', '/', $clean) ?: '';
        return ltrim($clean, '/');
    }

    private function encodePath(string $path): string
    {
        $segments = array_filter(explode('/', $path), static fn ($s) => $s !== '');
        return implode('/', array_map('rawurlencode', $segments));
    }
}
