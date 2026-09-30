<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use RuntimeException;

class FonnteService
{
    public function sendMessage(string $target, string $message): array
    {
        $token = config('services.fonnte.token');

        if (!$token) {
            throw new RuntimeException('FONNTE_TOKEN belum diatur.');
        }

        $response = Http::withHeaders([
            'Authorization' => $token,
        ])->asMultipart()->post('https://api.fonnte.com/send', [
            [
                'name' => 'target',
                'contents' => $target,
            ],
            [
                'name' => 'message',
                'contents' => $message,
            ],
            [
                'name' => 'countryCode',
                'contents' => '62',
            ],
        ]);

        if ($response->failed()) {
            throw new RuntimeException(
                'Fonnte API gagal: ' . $response->body()
            );
        }

        return $response->json();
    }
}
