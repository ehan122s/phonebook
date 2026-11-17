<?php

namespace App\Services;

use App\Models\BugReport;
use Carbon\Carbon;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class TicketNotificationService
{
    /**
     * Mengirimkan pesan notifikasi WhatsApp kepada pelapor tiket berdasarkan status.
     * Menggunakan Fonnte WhatsApp API Gateway dengan konfigurasi services.fonnte.token.
     *
     * @param BugReport $ticket
     * @param string $action 'acc'|'tolak'|'selesai'
     * @param string|null $reason
     * @return array
     */
    public static function sendWhatsAppUpdate(BugReport $ticket, string $action, ?string $reason = null): array
    {
        $phone = $ticket->reporter_phone;
        if (empty($phone)) {
            self::logHistory($ticket, $action, false, 'Nomor WhatsApp pelapor kosong');
            return [
                'success' => false,
                'reason' => 'Nomor WhatsApp pelapor tidak tersedia pada tiket.',
            ];
        }

        $cleanPhone = WhatsappService::normalizePhone($phone);
        if (strlen($cleanPhone) < 10) {
            self::logHistory($ticket, $action, false, "Nomor WhatsApp tidak valid: {$cleanPhone}");
            return [
                'success' => false,
                'reason' => "Nomor WhatsApp pelapor tidak valid ({$cleanPhone}).",
            ];
        }

        $message = self::buildMessage($ticket, $action, $reason);

        // Ambil token Fonnte dari Laravel config
        $token = config('services.fonnte.token') ?: env('FONNTE_TOKEN');
        if (empty($token)) {
            Log::warning("TicketNotificationService: FONNTE_TOKEN belum dikonfigurasi di server.");
            self::logHistory($ticket, $action, false, 'FONNTE_TOKEN belum diatur di server .env');
            return [
                'success' => false,
                'reason' => 'FONNTE_TOKEN belum dikonfigurasi pada server.',
            ];
        }

        try {
            $payload = [
                'target' => $cleanPhone,
                'message' => $message,
                'countryCode' => '62',
            ];

            $response = Http::withHeaders([
                'Authorization' => $token,
            ])->timeout(10)->asForm()->post('https://api.fonnte.com/send', $payload);

            $json = $response->json() ?? [];
            $isSuccess = $response->successful() && (($json['status'] ?? false) === true);
            $msgId = is_array($json['id'] ?? null) ? ($json['id'][0] ?? null) : ($json['id'] ?? null);
            $process = $json['process'] ?? null;

            if ($isSuccess) {
                $ticket->wa_sent = true;
                $ticket->wa_status = 'terkirim';
                self::logHistory($ticket, $action, true, "Terkirim ke {$cleanPhone} (ID: {$msgId}, Proses: {$process})");
                $ticket->save();

                return [
                    'success' => true,
                    'message_id' => $msgId,
                    'process' => $process,
                    'target' => $cleanPhone,
                ];
            } else {
                $errorReason = $json['reason'] ?? ($json['message'] ?? 'Fonnte device disconnect / gagal kirim');
                $ticket->wa_sent = false;
                $ticket->wa_status = 'gagal';
                self::logHistory($ticket, $action, false, "Gagal via Fonnte: {$errorReason}");
                $ticket->save();

                return [
                    'success' => false,
                    'reason' => $errorReason,
                    'target' => $cleanPhone,
                ];
            }
        } catch (\Throwable $e) {
            $ticket->wa_sent = false;
            $ticket->wa_status = 'gagal';
            self::logHistory($ticket, $action, false, 'Exception: ' . mb_substr($e->getMessage(), 0, 150));
            $ticket->save();

            return [
                'success' => false,
                'reason' => $e->getMessage(),
                'target' => $cleanPhone,
            ];
        }
    }

    /**
     * Membangun teks pesan WhatsApp sesuai spesifikasi template resmi.
     */
    public static function buildMessage(BugReport $ticket, string $action, ?string $reason = null): string
    {
        $name = trim($ticket->reporter_name ?: 'Pengguna');
        $code = $ticket->ticket_code ?: "PB-" . date('Y') . "-{$ticket->id}";
        $title = $ticket->title;
        $category = $ticket->category;

        switch (strtolower($action)) {
            case 'acc':
            case 'diterima':
                return "Halo, *{$name}*.\n\n" .
                    "Laporan masalah yang Anda kirim melalui aplikasi Phonebook telah kami terima.\n\n" .
                    "Berikut informasi laporan Anda:\n\n" .
                    "ID Tiket: {$code}\n" .
                    "Judul: {$title}\n" .
                    "Kategori: {$category}\n" .
                    "Status: DITERIMA\n\n" .
                    "Tim IT akan melakukan pemeriksaan terhadap laporan tersebut.\n\n" .
                    "Terima kasih telah membantu meningkatkan kualitas aplikasi Phonebook.\n\n" .
                    "*Tim IT Phonebook*";

            case 'tolak':
            case 'ditolak':
                $reasonText = trim($reason ?: ($ticket->rejection_reason ?: 'Tidak memenuhi kriteria laporan kendala.'));
                return "Halo, *{$name}*.\n\n" .
                    "Mohon maaf, laporan masalah Anda pada aplikasi Phonebook belum dapat kami proses.\n\n" .
                    "ID Tiket: {$code}\n" .
                    "Judul: {$title}\n" .
                    "Status: DITOLAK\n\n" .
                    "Alasan:\n" .
                    "{$reasonText}\n\n" .
                    "Jika masih membutuhkan bantuan, silakan mengirim laporan kembali melalui aplikasi Phonebook.\n\n" .
                    "*Tim IT Phonebook*";

            case 'selesai':
                return "Halo, *{$name}*.\n\n" .
                    "Kami ingin menginformasikan bahwa laporan masalah Anda telah selesai ditangani.\n\n" .
                    "ID Tiket: {$code}\n" .
                    "Judul: {$title}\n" .
                    "Status: SELESAI\n\n" .
                    "Terima kasih atas laporan dan kontribusi Anda untuk aplikasi Phonebook.\n\n" .
                    "*Tim IT Phonebook*";

            default:
                return "Halo, *{$name}*.\n\n" .
                    "Pembaruan status laporan ID Tiket: {$code} ({$title})\n" .
                    "Status: {$ticket->status}\n\n" .
                    "*Tim IT Phonebook*";
        }
    }

    /**
     * Mencatat histori pengiriman WhatsApp ke kolom JSON wa_history.
     */
    private static function logHistory(BugReport $ticket, string $action, bool $success, string $detail): void
    {
        $history = is_array($ticket->wa_history) ? $ticket->wa_history : [];
        $history[] = [
            'action' => strtoupper($action),
            'success' => $success,
            'detail' => $detail,
            'timestamp' => Carbon::now('Asia/Jakarta')->toIso8601String(),
        ];
        $ticket->wa_history = $history;
    }
}
