<?php

namespace App\Services;

use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use RuntimeException;

/**
 * Service komunikasi dengan Groq API (OpenAI-compatible Chat Completions).
 * API Key hanya dibaca dari backend config/env dan tidak pernah diekspos ke log atau client.
 */
class GroqService
{
    public function isConfigured(): bool
    {
        return !empty(config('services.groq.api_key'))
            && !empty(config('services.groq.base_url'));
    }

    public function getModel(): string
    {
        return (string) (config('services.groq.model') ?: 'openai/gpt-oss-120b');
    }

    public function getFallbackModel(): string
    {
        return (string) (config('services.groq.fallback_model') ?: 'llama-3.1-8b-instant');
    }

    /**
     * Mengirim permintaan chat completions ke Groq API.
     * Otomatis mencoba retry singkat atau model fallback jika terkena rate limit (429).
     *
     * @param array<int, array<string, mixed>> $messages
     * @param array<int, array<string, mixed>> $tools
     * @return array<string, mixed>
     */
    public function chatCompletions(
        array $messages,
        array $tools = [],
        float $temperature = 0.4,
        int $maxTokens = 1024
    ): array {
        $apiKey = (string) config('services.groq.api_key');
        $baseUrl = rtrim((string) config('services.groq.base_url', 'https://api.groq.com/openai/v1'), '/');
        $model = $this->getModel();
        $timeout = max(5, (int) config('services.groq.timeout', 30));

        if ($apiKey === '') {
            throw new RuntimeException('Layanan AI belum dikonfigurasi oleh administrator.');
        }

        $response = $this->sendRequest($apiKey, $baseUrl, $model, $timeout, $messages, $tools, $temperature, $maxTokens);

        if ($response->status() === 429) {
            $retryAfter = (int) ($response->header('Retry-After') ?? 0);
            if ($retryAfter > 0 && $retryAfter <= 2) {
                sleep($retryAfter);
                $response = $this->sendRequest($apiKey, $baseUrl, $model, $timeout, $messages, $tools, $temperature, $maxTokens);
            }
        }

        if ($response->status() === 429) {
            $fallback = $this->getFallbackModel();
            if ($fallback !== '' && $fallback !== $model) {
                Log::info('Groq API switching to fallback model after 429', [
                    'primary_model' => $model,
                    'fallback_model' => $fallback,
                ]);
                $model = $fallback;
                $response = $this->sendRequest($apiKey, $baseUrl, $fallback, $timeout, $messages, $tools, $temperature, $maxTokens);
            }
        }

        $status = $response->status();

        if ($status === 429) {
            Log::warning('Groq API rate limit reached', ['model' => $model]);
            throw new RuntimeException('Layanan AI sedang sibuk (batas permintaan tercapai). Tunggu sebentar lalu coba lagi.');
        }

        if ($status === 401 || $status === 403) {
            Log::error('Groq API authentication failure', ['status' => $status, 'model' => $model]);
            throw new RuntimeException('Otorisasi layanan AI gagal. Hubungi administrator sistem.');
        }

        if (!$response->successful()) {
            Log::warning('Groq API non-200 response', [
                'status' => $status,
                'model' => $model,
            ]);
            throw new RuntimeException('Layanan AI gagal memproses permintaan saat ini. Silakan coba lagi.');
        }

        $json = $response->json();
        if (!is_array($json) || empty($json['choices'][0]['message'])) {
            Log::warning('Groq API malformed response', ['model' => $model]);
            throw new RuntimeException('Format balasan layanan AI tidak valid. Silakan coba lagi.');
        }

        return $json;
    }

    /**
     * @param array<int, array<string, mixed>> $messages
     * @param array<int, array<string, mixed>> $tools
     */
    private function sendRequest(
        string $apiKey,
        string $baseUrl,
        string $model,
        int $timeout,
        array $messages,
        array $tools,
        float $temperature,
        int $maxTokens
    ): \Illuminate\Http\Client\Response {
        $payload = [
            'model' => $model,
            'messages' => $messages,
            'temperature' => $temperature,
            'max_tokens' => $maxTokens,
        ];

        if (!empty($tools)) {
            $payload['tools'] = $tools;
            $payload['tool_choice'] = 'auto';
        }

        try {
            return Http::withToken($apiKey)
                ->acceptJson()
                ->timeout($timeout)
                ->post("{$baseUrl}/chat/completions", $payload);
        } catch (ConnectionException $e) {
            Log::warning('Groq API connection timeout/failure', [
                'model' => $model,
                'type' => 'connection_exception',
            ]);
            throw new RuntimeException('Koneksi ke layanan AI memakan waktu terlalu lama. Silakan coba lagi.');
        } catch (\Throwable $e) {
            Log::error('Groq API unexpected client error', [
                'model' => $model,
                'type' => get_class($e),
            ]);
            throw new RuntimeException('Terjadi gangguan koneksi ke layanan AI. Silakan coba beberapa saat lagi.');
        }
    }
}
