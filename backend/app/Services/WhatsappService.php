<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class WhatsappService
{
    /**
     * Send WhatsApp reminder via Fonnte API Gateway.
     * Returns an array with status, message, and fallback wa.me URL.
     */
    public static function sendReminder(string $targetPhone, string $message): array
    {
        $cleanPhone = self::normalizePhone($targetPhone);
        $token = env('FONNTE_TOKEN') ?: config('services.fonnte.token');

        $encodedText = rawurlencode($message);
        $directWaUrl = "https://wa.me/{$cleanPhone}?text={$encodedText}";

        if (empty($token)) {
            Log::warning("WhatsappService: FONNTE_TOKEN belum dikonfigurasi.");
            return [
                'success' => false,
                'gateway' => 'fonnte',
                'reason' => 'FONNTE_TOKEN belum diatur di server .env',
                'target' => $cleanPhone,
                'wa_url' => $directWaUrl,
            ];
        }

        try {
            $response = Http::withHeaders([
                'Authorization' => $token,
            ])->timeout(10)->asForm()->post('https://api.fonnte.com/send', [
                'target' => $cleanPhone,
                'message' => $message,
                'countryCode' => '62',
            ]);

            $json = $response->json();
            $status = $response->successful() && ($json['status'] ?? false) === true;

            if ($status) {
                Log::info("WhatsappService: Berhasil mengirim WhatsApp ke {$cleanPhone} via Fonnte.");
                return [
                    'success' => true,
                    'gateway' => 'fonnte',
                    'message' => 'Pengingat WhatsApp berhasil dikirim ke nomor penerima',
                    'target' => $cleanPhone,
                    'wa_url' => $directWaUrl,
                    'response' => $json,
                ];
            } else {
                $reason = $json['reason'] ?? ($json['message'] ?? 'Fonnte device disconnect atau tidak aktif');
                Log::warning("WhatsappService: Gagal via Fonnte ke {$cleanPhone}: {$reason}");
                return [
                    'success' => false,
                    'gateway' => 'fonnte',
                    'reason' => $reason,
                    'target' => $cleanPhone,
                    'wa_url' => $directWaUrl,
                ];
            }
        } catch (\Throwable $e) {
            Log::error("WhatsappService exception: " . $e->getMessage());
            return [
                'success' => false,
                'gateway' => 'fonnte',
                'reason' => $e->getMessage(),
                'target' => $cleanPhone,
                'wa_url' => $directWaUrl,
            ];
        }
    }

    /**
     * Normalizes phone number into international format without leading '+' or '0' (e.g. 6281234567890).
     */
    public static function normalizePhone(string $phone): string
    {
        $clean = preg_replace('/[^0-9]/', '', $phone);
        if (str_starts_with($clean, '0')) {
            $clean = '62' . substr($clean, 1);
        } elseif (str_starts_with($clean, '8')) {
            $clean = '62' . $clean;
        }
        return $clean;
    }

    /**
     * Format official reminder message.
     */
    public static function formatReminderMessage(string $title, string $category, string $date, string $time, string $location, int $reminderMinutes, ?string $notes = null): string
    {
        $msg = "*PENGINGAT JADWAL KEGIATAN CDK WILAYAH V GARUT*\n";
        $msg .= "--------------------------------------------------\n";
        $msg .= "Halo Rekan Kehutanan, ini adalah pengingat untuk kegiatan Anda:\n\n";
        $msg .= "📌 *Kegiatan:* {$title}\n";
        $msg .= "🏷️ *Kategori:* {$category}\n";
        $msg .= "📅 *Tanggal :* {$date}\n";
        $msg .= "⏰ *Waktu   :* {$time} WIB (Pengingat {$reminderMinutes} menit sebelumnya)\n";
        $msg .= "📍 *Lokasi  :* {$location}\n";
        if (!empty($notes)) {
            $msg .= "📝 *Catatan :* {$notes}\n";
        }
        $msg .= "\nMohon persiapkan perlengkapan lapangan Anda.\n";
        $msg .= "_Aplikasi Phonebook CDK Wilayah V - Dinas Kehutanan Jabar_";

        return $msg;
    }
}
