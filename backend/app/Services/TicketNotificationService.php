<?php

namespace App\Services;

use App\Models\AppNotification;
use App\Models\BugReport;
use Carbon\Carbon;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Schema;

class TicketNotificationService
{
    /**
     * Membuat notifikasi dalam aplikasi (AppNotification) untuk pengguna pemilik tiket.
     * Tersimpan di PostgreSQL Supabase sehingga tetap tersedia saat user online/offline.
     */
    public static function createAppNotification(BugReport $ticket, string $action, ?string $reason = null): ?AppNotification
    {
        if (empty($ticket->user_id)) {
            return null;
        }

        try {
            $code = $ticket->ticket_code ?: "PB-{$ticket->id}";
            $devName = $ticket->handled_by ?: 'Tim Developer Phonebook';
            $refId = 'ticket_' . strtolower($action) . '_' . $ticket->id;

            $title = '';
            $message = '';
            $statusStr = '';

            switch (strtolower($action)) {
                case 'acc':
                case 'in_progress':
                    $statusStr = 'in_progress';
                    $title = 'Laporan Masalah Sedang Ditangani';
                    $message = "Laporan masalah Anda (#{$code}: \"{$ticket->title}\") telah disetujui dan sedang ditangani oleh {$devName}.";
                    break;

                case 'selesai':
                case 'resolved':
                    $statusStr = 'resolved';
                    $title = 'Laporan Masalah Telah Diselesaikan';
                    $reasonText = trim($reason ?: ($ticket->resolution_reason ?: 'Masalah telah berhasil diperbaiki oleh tim developer.'));
                    $message = "Laporan masalah Anda (#{$code}) telah diselesaikan oleh tim developer.\n\nKeterangan Developer:\n{$reasonText}";
                    break;

                case 'tolak':
                case 'rejected':
                    $statusStr = 'rejected';
                    $title = 'Laporan Masalah Belum Dapat Diproses';
                    $reasonText = trim($reason ?: ($ticket->rejection_reason ?: 'Laporan belum dapat ditindaklanjuti.'));
                    $message = "Laporan masalah Anda (#{$code}) belum dapat diproses.\n\nAlasan:\n{$reasonText}";
                    break;

                default:
                    $statusStr = $action;
                    $title = 'Pembaruan Status Laporan Masalah';
                    $message = "Status laporan tiket #{$code} diperbarui: {$ticket->status}";
            }

            return AppNotification::updateOrCreate(
                [
                    'user_id' => $ticket->user_id,
                    'reference_id' => $refId,
                ],
                [
                    'type' => 'laporan_masalah',
                    'title' => $title,
                    'message' => $message,
                    'metadata' => [
                        'ticket_id' => $ticket->id,
                        'ticket_code' => $code,
                        'category' => $ticket->category,
                        'title' => $ticket->title,
                        'status' => $statusStr,
                        'developer' => $devName,
                        'reason' => $reason ?: ($ticket->resolution_reason ?: $ticket->rejection_reason),
                        'action' => $action,
                        'resolved_at' => $ticket->resolved_at?->toIso8601String(),
                        'approved_at' => $ticket->approved_at?->toIso8601String(),
                    ],
                    'is_read' => false,
                ]
            );
        } catch (\Throwable $e) {
            Log::warning("TicketNotificationService: Gagal mencatat AppNotification untuk tiket #{$ticket->id}: " . $e->getMessage());
            return null;
        }
    }
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
            ])->timeout(3)->asForm()->post('https://api.fonnte.com/send', $payload);

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
            case 'resolved':
                $reasonText = trim($reason ?: ($ticket->resolution_reason ?: 'Masalah telah diselesaikan oleh tim developer.'));
                return "PHONEBOOK - INFORMASI PENYELESAIAN TIKET\n\n" .
                    "Halo, *{$name}*. Laporan masalah Anda telah diselesaikan.\n\n" .
                    "Ticket ID: {$code}\n" .
                    "Status: RESOLVED\n\n" .
                    "Keterangan Developer:\n" .
                    "{$reasonText}\n\n" .
                    "Terima kasih telah membantu meningkatkan aplikasi Phonebook.\n" .
                    "- Tim Developer Phonebook";

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
