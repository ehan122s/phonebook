<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;

class WhatsappService
{
    public static function sendReminder(string $targetPhone, string $message): bool
    {
        $response = Http::withHeaders([
            'Authorization' => env('FONNTE_TOKEN'), // Isi token dari dashboard Fonnte di .env
        ])->post('https://api.fonnte.com/send', [
            'target' => $targetPhone,
            'message' => $message,
            'countryCode' => '62',
        ]);

        return $response->successful();
    }
}