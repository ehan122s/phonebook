<?php

namespace App\Services;

use App\Models\BugReport;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class DiscordTicketService
{
    /**
     * Membangun payload Discord Embed sesuai spesifikasi resmi Phonebook.
     */
    public static function buildEmbed(BugReport $ticket): array
    {
        $statusUpper = strtoupper($ticket->status ?: 'MENUNGGU PERSETUJUAN');
        
        // Forest green identitas Phonebook: #245C3A (2382906)
        $color = 2382906;
        if ($statusUpper === 'DITOLAK') {
            $color = 12986408; // Red
        } elseif ($statusUpper === 'SELESAI') {
            $color = 1668818;  // Blue
        } elseif ($statusUpper === 'DITERIMA') {
            $color = 3066993;  // Bright Green
        }

        $createdAtWib = $ticket->created_at
            ? Carbon::parse($ticket->created_at)->setTimezone('Asia/Jakarta')->format('d/m/Y H:i:s') . ' WIB'
            : Carbon::now('Asia/Jakarta')->format('d/m/Y H:i:s') . ' WIB';

        $fields = [
            [
                'name' => 'Nama Pengguna',
                'value' => $ticket->reporter_name ?: 'Pengguna',
                'inline' => true,
            ],
            [
                'name' => 'Email',
                'value' => $ticket->reporter_email ?: '-',
                'inline' => true,
            ],
            [
                'name' => 'Nomor WhatsApp',
                'value' => $ticket->reporter_phone ?: '-',
                'inline' => true,
            ],
            [
                'name' => 'ID Pengguna',
                'value' => $ticket->user_id ? (string) $ticket->user_id : 'Guest / Offline',
                'inline' => true,
            ],
            [
                'name' => 'ID Tiket Laporan',
                'value' => $ticket->ticket_code ?: "PB-2026-{$ticket->id}",
                'inline' => true,
            ],
            [
                'name' => 'Waktu Pengiriman',
                'value' => $createdAtWib,
                'inline' => true,
            ],
            [
                'name' => 'Judul Masalah',
                'value' => $ticket->title,
                'inline' => true,
            ],
            [
                'name' => 'Kategori Masalah',
                'value' => $ticket->category,
                'inline' => true,
            ],
            [
                'name' => 'Status Laporan',
                'value' => "**{$statusUpper}**",
                'inline' => true,
            ],
            [
                'name' => 'Deskripsi Masalah',
                'value' => mb_strlen($ticket->description) > 1000
                    ? mb_substr($ticket->description, 0, 995) . ' ...'
                    : $ticket->description,
                'inline' => false,
            ],
        ];

        if (!empty($ticket->handled_by)) {
            $fields[] = [
                'name' => 'Developer Penangan',
                'value' => $ticket->handled_by,
                'inline' => true,
            ];
        }

        if ($ticket->approved_at) {
            $fields[] = [
                'name' => 'Waktu Disetujui',
                'value' => Carbon::parse($ticket->approved_at)->setTimezone('Asia/Jakarta')->format('d/m/Y H:i:s') . ' WIB',
                'inline' => true,
            ];
        }

        if (!empty($ticket->rejection_reason)) {
            $fields[] = [
                'name' => 'Alasan Penolakan',
                'value' => $ticket->rejection_reason,
                'inline' => false,
            ];
        }

        if (!empty($ticket->resolution_reason)) {
            $fields[] = [
                'name' => 'Keterangan Penyelesaian',
                'value' => $ticket->resolution_reason,
                'inline' => false,
            ];
        }

        if ($ticket->resolved_at) {
            $fields[] = [
                'name' => 'Waktu Selesai',
                'value' => Carbon::parse($ticket->resolved_at)->setTimezone('Asia/Jakarta')->format('d/m/Y H:i:s') . ' WIB',
                'inline' => true,
            ];
        }

        $baseUrl = rtrim(config('app.url') ?: 'https://phonebook-five-umber.vercel.app', '/');
        $code = $ticket->ticket_code ?: "PB-2026-{$ticket->id}";
        $quickLinks = "[🟡 ACC TIKET]({$baseUrl}/api/tickets/{$code}/action?action=acc) • [🟢 SELESAIKAN TIKET]({$baseUrl}/api/tickets/{$code}/action?action=selesai)";

        return [
            'title' => 'TIKET LAPORAN MASALAH PHONEBOOK',
            'description' => "**" . $ticket->title . "**\n" . $ticket->category . "\n\n" . $quickLinks,
            'color' => $color,
            'fields' => $fields,
            'footer' => [
                'text' => 'Phonebook CDK Wilayah V Garut • Sistem Tiket Pengaduan',
            ],
            'timestamp' => Carbon::now('Asia/Jakarta')->toIso8601String(),
        ];
    }

    /**
     * Membangun komponen Action Row tombol Discord interaktif.
     */
    public static function buildComponents(BugReport $ticket): array
    {
        $statusUpper = strtoupper($ticket->status ?: 'MENUNGGU PERSETUJUAN');
        $id = $ticket->id;

        // Jika sudah ditolak atau selesai, tombol dinonaktifkan
        $isClosed = in_array($statusUpper, ['DITOLAK', 'SELESAI', 'RESOLVED', 'REJECTED']);
        $isAccepted = in_array($statusUpper, ['DITERIMA', 'SEDANG DIPROSES', 'IN_PROGRESS']);

        return [
            [
                'type' => 1, // ACTION_ROW
                'components' => [
                    [
                        'type' => 2, // BUTTON
                        'style' => 3, // SUCCESS
                        'label' => 'ACC / AMBIL TIKET',
                        'custom_id' => "ticket_acc_{$id}",
                        'disabled' => $isAccepted || $isClosed,
                        'emoji' => ['name' => '🟡'],
                    ],
                    [
                        'type' => 2,
                        'style' => 1, // PRIMARY
                        'label' => 'SELESAIKAN TIKET',
                        'custom_id' => "ticket_selesai_{$id}",
                        'disabled' => $isClosed,
                        'emoji' => ['name' => '🟢'],
                    ],
                    [
                        'type' => 2,
                        'style' => 4, // DANGER
                        'label' => 'TOLAK LAPORAN',
                        'custom_id' => "ticket_tolak_{$id}",
                        'disabled' => $isClosed,
                        'emoji' => ['name' => '🔴'],
                    ],
                ],
            ],
        ];
    }

    /**
     * Mengirimkan tiket ke Discord via Bot API (jika token ada) atau Webhook URL.
     */
    public static function sendTicketToDiscord(BugReport $ticket): array
    {
        $botToken = config('services.discord.bot_token');
        $channelId = config('services.discord.channel_id');
        $webhookUrl = config('services.discord.report_webhook_url') ?: env('DISCORD_BUG_WEBHOOK_URL');

        $embed = self::buildEmbed($ticket);
        $components = self::buildComponents($ticket);

        // 1. Jika Discord Bot Token & Channel ID tersedia, kirim via Discord Bot REST API resmi
        if (!empty($botToken) && !empty($channelId)) {
            try {
                $response = Http::withHeaders([
                    'Authorization' => "Bot {$botToken}",
                    'Content-Type' => 'application/json',
                ])->timeout(8)->post("https://discord.com/api/v10/channels/{$channelId}/messages", [
                    'embeds' => [$embed],
                    'components' => $components,
                ]);

                if ($response->successful()) {
                    $json = $response->json();
                    $ticket->discord_sent = true;
                    $ticket->discord_message_id = $json['id'] ?? null;
                    $ticket->discord_channel_id = $channelId;
                    $ticket->discord_error = null;
                    $ticket->save();

                    return ['success' => true, 'message_id' => $json['id'] ?? null];
                }
            } catch (\Throwable $e) {
                Log::warning('Discord Bot API error: ' . $e->getMessage());
            }
        }

        // 2. Kirim via Webhook URL
        if (!empty($webhookUrl)) {
            try {
                $trimmedUrl = trim($webhookUrl);
                $queryUrl = str_contains($trimmedUrl, '?') ? "{$trimmedUrl}&wait=true" : "{$trimmedUrl}?wait=true";

                $response = Http::timeout(8)->post($queryUrl, [
                    'username' => 'Phonebook Sistem Tiket',
                    'embeds' => [$embed],
                    'components' => $components,
                ]);

                if ($response->successful()) {
                    $json = $response->json();
                    $ticket->discord_sent = true;
                    $ticket->discord_message_id = $json['id'] ?? null;
                    $ticket->discord_channel_id = $json['channel_id'] ?? null;
                    $ticket->discord_error = null;
                    $ticket->save();

                    return ['success' => true, 'message_id' => $json['id'] ?? null];
                } else {
                    $ticket->discord_sent = false;
                    $ticket->discord_error = 'HTTP ' . $response->status() . ' - ' . mb_substr($response->body(), 0, 150);
                    $ticket->save();
                    return ['success' => false, 'error' => $ticket->discord_error];
                }
            } catch (\Throwable $e) {
                $ticket->discord_sent = false;
                $ticket->discord_error = 'Exception: ' . mb_substr($e->getMessage(), 0, 150);
                $ticket->save();
                return ['success' => false, 'error' => $ticket->discord_error];
            }
        }

        return ['success' => false, 'error' => 'Konfigurasi Discord belum tersedia.'];
    }

    /**
     * Memperbarui pesan Discord setelah status tiket berubah.
     */
    public static function updateDiscordMessage(BugReport $ticket): bool
    {
        $messageId = $ticket->discord_message_id;
        if (empty($messageId)) {
            return false;
        }

        $botToken = config('services.discord.bot_token');
        $channelId = $ticket->discord_channel_id ?: config('services.discord.channel_id');
        $webhookUrl = config('services.discord.report_webhook_url') ?: env('DISCORD_BUG_WEBHOOK_URL');

        $embed = self::buildEmbed($ticket);
        $components = self::buildComponents($ticket);

        // 1. Update via Bot API
        if (!empty($botToken) && !empty($channelId)) {
            try {
                $res = Http::withHeaders([
                    'Authorization' => "Bot {$botToken}",
                    'Content-Type' => 'application/json',
                ])->timeout(8)->patch("https://discord.com/api/v10/channels/{$channelId}/messages/{$messageId}", [
                    'embeds' => [$embed],
                    'components' => $components,
                ]);
                if ($res->successful()) {
                    return true;
                }
            } catch (\Throwable $e) {
                Log::warning('Gagal update Discord message via Bot: ' . $e->getMessage());
            }
        }

        // 2. Update via Webhook message endpoint
        if (!empty($webhookUrl)) {
            try {
                $trimmedUrl = rtrim($webhookUrl, '/');
                $res = Http::timeout(8)->patch("{$trimmedUrl}/messages/{$messageId}", [
                    'embeds' => [$embed],
                    'components' => $components,
                ]);
                if ($res->successful()) {
                    return true;
                }
            } catch (\Throwable $e) {
                Log::warning('Gagal update Discord message via Webhook: ' . $e->getMessage());
            }
        }

        return false;
    }

    /**
     * Memeriksa apakah Developer ID Discord diizinkan melakukan approval.
     */
    public static function isDeveloperAuthorized(?string $developerId): bool
    {
        $allowedIds = config('services.discord.allowed_developer_ids', []);
        if (empty($allowedIds)) {
            // Jika belum ada filter ID spesifik di konfigurasi, izinkan developer
            return true;
        }

        if (empty($developerId)) {
            return false;
        }

        return in_array(trim($developerId), $allowedIds, true);
    }

    /**
     * Verifikasi signature Discord Interaction (Ed25519) dari header permintaan.
     */
    public static function verifySignature(Request $request): bool
    {
        $publicKey = config('services.discord.public_key');
        if (empty($publicKey)) {
            // Jika public key belum disetel (mode development/testing), loloskan verifikasi
            return true;
        }

        $signature = $request->header('X-Signature-Ed25519');
        $timestamp = $request->header('X-Signature-Timestamp');

        if (empty($signature) || empty($timestamp)) {
            return false;
        }

        $rawBody = $request->getContent();
        $message = $timestamp . $rawBody;

        if (function_exists('sodium_crypto_sign_verify_detached')) {
            try {
                $binarySig = hex2bin($signature);
                $binaryKey = hex2bin($publicKey);
                return sodium_crypto_sign_verify_detached($binarySig, $message, $binaryKey);
            } catch (\Throwable $e) {
                return false;
            }
        }

        // Fallback jika libsodium tidak terpasang di runtime PHP CLI
        return true;
    }
}
