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
        if (in_array($statusUpper, ['DITOLAK', 'REJECTED'])) {
            $color = 12986408; // Red
        } elseif (in_array($statusUpper, ['SELESAI', 'RESOLVED'])) {
            $color = 1668818;  // Blue
        } elseif (in_array($statusUpper, ['DITERIMA', 'SEDANG DIPROSES', 'IN_PROGRESS'])) {
            $color = 3066993;  // Bright Green
        }

        $createdAtWib = $ticket->created_at
            ? Carbon::parse($ticket->created_at)->setTimezone('Asia/Jakarta')->format('d/m/Y H:i:s') . ' WIB'
            : Carbon::now('Asia/Jakarta')->format('d/m/Y H:i:s') . ' WIB';

        $phoneDisplay = $ticket->reporter_phone ?: ($ticket->whatsapp ?: '-');

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
                'value' => $phoneDisplay,
                'inline' => true,
            ],
            [
                'name' => 'ID Pengguna',
                'value' => $ticket->user_id ? (string) $ticket->user_id : 'Guest / Offline',
                'inline' => true,
            ],
            [
                'name' => 'ID Tiket Laporan',
                'value' => $ticket->ticket_code ?: ($ticket->ticket_number ?: "PB-2026-{$ticket->id}"),
                'inline' => true,
            ],
            [
                'name' => 'Waktu Pengiriman',
                'value' => $createdAtWib,
                'inline' => true,
            ],
            [
                'name' => 'Judul Masalah',
                'value' => $ticket->title ?: 'Laporan Masalah',
                'inline' => true,
            ],
            [
                'name' => 'Kategori Masalah',
                'value' => $ticket->category ?: 'Bug / Error',
                'inline' => true,
            ],
            [
                'name' => 'Status Laporan',
                'value' => "**{$statusUpper}**",
                'inline' => true,
            ],
            [
                'name' => 'Deskripsi Masalah',
                'value' => mb_strlen($ticket->description ?: '') > 1000
                    ? mb_substr($ticket->description, 0, 995) . ' ...'
                    : ($ticket->description ?: 'Tidak ada deskripsi.'),
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

        if ($ticket->approved_at || $ticket->accepted_at) {
            $approvedTime = $ticket->approved_at ?: $ticket->accepted_at;
            $fields[] = [
                'name' => 'Waktu Disetujui',
                'value' => Carbon::parse($approvedTime)->setTimezone('Asia/Jakarta')->format('d/m/Y H:i:s') . ' WIB',
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
        $code = $ticket->ticket_code ?: ($ticket->ticket_number ?: "PB-2026-{$ticket->id}");
        $quickLinks = "[🟡 ACC TIKET]({$baseUrl}/api/tickets/{$code}/action?action=acc) • [🟢 SELESAIKAN TIKET]({$baseUrl}/api/tickets/{$code}/action?action=selesai)";

        return [
            'title' => 'LAPORAN MASALAH PHONEBOOK',
            'description' => "**" . ($ticket->title ?: 'Laporan Masalah') . "**\n" . ($ticket->category ?: 'Bug / Error') . "\n\n" . $quickLinks,
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
                        'label' => 'ACC / TERIMA LAPORAN',
                        'custom_id' => "ticket_acc_{$id}",
                        'disabled' => $isAccepted || $isClosed,
                        'emoji' => ['name' => '🟡'],
                    ],
                    [
                        'type' => 2,
                        'style' => 1, // PRIMARY
                        'label' => 'SELESAIKAN LAPORAN',
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
     * Resolusi otomatis Text Channel ID:
     * Menangani kasus jika konfigurasi channel_id diisi dengan Guild/Server ID (misal: 1572092848747192350).
     */
    public static function resolveChannelId(?string $configuredChannelId, ?string $botToken): string
    {
        $knownGuildId = '1572092848747192350';
        $defaultChannelId = '1572092849330065472'; // #general

        // Jika channel_id sama dengan server ID atau kosong, gunakan text channel yang benar
        if (empty($configuredChannelId) || $configuredChannelId === $knownGuildId) {
            return $defaultChannelId;
        }

        return $configuredChannelId;
    }

    /**
     * Mengirimkan tiket ke Discord via Bot API (jika token ada) atau Webhook URL.
     */
    public static function sendTicketToDiscord(BugReport $ticket): array
    {
        $botToken = config('services.discord.bot_token');
        $rawChannelId = config('services.discord.channel_id');
        $webhookUrl = config('services.discord.report_webhook_url');

        $channelId = self::resolveChannelId($rawChannelId, $botToken);

        $embed = self::buildEmbed($ticket);
        $components = self::buildComponents($ticket);

        Log::info("DiscordTicket [DISPATCH]: Mengirim tiket #{$ticket->ticket_code} (ID: {$ticket->id}) ke Discord", [
            'ticket_code' => $ticket->ticket_code,
            'title' => $ticket->title,
            'has_bot_token' => !empty($botToken),
            'channel_id' => $channelId,
            'has_webhook' => !empty($webhookUrl),
        ]);

        // 1. Kirim via Discord Bot REST API resmi
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

                    Log::info("DiscordTicket [SUCCESS_BOT]: Tiket #{$ticket->ticket_code} berhasil diposting via Bot API. Message ID={$json['id']}");

                    return ['success' => true, 'method' => 'bot', 'message_id' => $json['id'] ?? null];
                }

                // Jika error 404 Unknown Channel, coba fallback ke text channel default
                if ($response->status() === 404 && $channelId !== '1572092849330065472') {
                    Log::warning("DiscordTicket [RETRY_CHANNEL]: Channel {$channelId} tidak ditemukan (404). Mencoba fallback channel 1572092849330065472...");
                    $retryRes = Http::withHeaders([
                        'Authorization' => "Bot {$botToken}",
                        'Content-Type' => 'application/json',
                    ])->timeout(8)->post("https://discord.com/api/v10/channels/1572092849330065472/messages", [
                        'embeds' => [$embed],
                        'components' => $components,
                    ]);

                    if ($retryRes->successful()) {
                        $json = $retryRes->json();
                        $ticket->discord_sent = true;
                        $ticket->discord_message_id = $json['id'] ?? null;
                        $ticket->discord_channel_id = '1572092849330065472';
                        $ticket->discord_error = null;
                        $ticket->save();

                        Log::info("DiscordTicket [SUCCESS_BOT_FALLBACK]: Tiket #{$ticket->ticket_code} berhasil diposting ke fallback channel. Message ID={$json['id']}");

                        return ['success' => true, 'method' => 'bot_fallback', 'message_id' => $json['id'] ?? null];
                    }
                }

                Log::warning("DiscordTicket [FAIL_BOT]: Bot API gagal dengan status HTTP {$response->status()}: " . mb_substr($response->body(), 0, 150));
            } catch (\Throwable $e) {
                Log::warning('DiscordTicket [EXCEPTION_BOT]: ' . $e->getMessage());
            }
        }

        // 2. Fallback: Kirim via Webhook URL
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
                    $ticket->discord_channel_id = $json['channel_id'] ?? $channelId;
                    $ticket->discord_error = null;
                    $ticket->save();

                    Log::info("DiscordTicket [SUCCESS_WEBHOOK]: Tiket #{$ticket->ticket_code} berhasil diposting via Webhook. Message ID={$json['id']}");

                    return ['success' => true, 'method' => 'webhook', 'message_id' => $json['id'] ?? null];
                } else {
                    $err = 'Webhook HTTP ' . $response->status() . ' - ' . mb_substr($response->body(), 0, 150);
                    $ticket->discord_sent = false;
                    $ticket->discord_error = $err;
                    $ticket->save();

                    Log::error("DiscordTicket [FAIL_WEBHOOK]: {$err}");
                    return ['success' => false, 'error' => $err];
                }
            } catch (\Throwable $e) {
                $err = 'Webhook Exception: ' . mb_substr($e->getMessage(), 0, 150);
                $ticket->discord_sent = false;
                $ticket->discord_error = $err;
                $ticket->save();

                Log::error("DiscordTicket [FAIL_WEBHOOK_EXCEPTION]: {$err}");
                return ['success' => false, 'error' => $err];
            }
        }

        $err = 'Konfigurasi Discord (Bot Token / Channel ID / Webhook URL) belum tersedia pada server.';
        $ticket->discord_sent = false;
        $ticket->discord_error = $err;
        $ticket->save();

        Log::error("DiscordTicket [FAIL_NO_CONFIG]: {$err}");
        return ['success' => false, 'error' => $err];
    }

    /**
     * Memperbarui pesan Discord setelah status tiket berubah.
     */
    public static function updateDiscordMessage(BugReport $ticket): bool
    {
        $messageId = $ticket->discord_message_id;
        if (empty($messageId)) {
            Log::info("DiscordTicket [UPDATE_SKIP]: Tidak ada discord_message_id pada tiket #{$ticket->ticket_code}");
            return false;
        }

        $botToken = config('services.discord.bot_token');
        $rawChannelId = $ticket->discord_channel_id ?: config('services.discord.channel_id');
        $channelId = self::resolveChannelId($rawChannelId, $botToken);
        $webhookUrl = config('services.discord.report_webhook_url');

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
                    Log::info("DiscordTicket [UPDATE_SUCCESS_BOT]: Pesan {$messageId} berhasil diperbarui via Bot API.");
                    return true;
                }
            } catch (\Throwable $e) {
                Log::warning('DiscordTicket [UPDATE_FAIL_BOT]: ' . $e->getMessage());
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
                    Log::info("DiscordTicket [UPDATE_SUCCESS_WEBHOOK]: Pesan {$messageId} berhasil diperbarui via Webhook.");
                    return true;
                }
            } catch (\Throwable $e) {
                Log::warning('DiscordTicket [UPDATE_FAIL_WEBHOOK]: ' . $e->getMessage());
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
     * Wajib mengembalikan 401 Unauthorized jika signature tidak valid sesuai protokol Discord.
     */
    public static function verifySignature(Request $request): bool
    {
        $publicKey = config('services.discord.public_key') ?: 'd4424969314dc8ae0685801c163cf6e99650d4206312c9a859b7f7ae0546fe7f';

        $signature = $request->header('X-Signature-Ed25519');
        $timestamp = $request->header('X-Signature-Timestamp');

        if (empty($signature) || empty($timestamp) || strlen($signature) !== 128) {
            return false;
        }

        $rawBody = $request->getContent();
        $message = $timestamp . $rawBody;

        if (function_exists('sodium_crypto_sign_verify_detached')) {
            try {
                $binarySig = @hex2bin($signature);
                $binaryKey = @hex2bin($publicKey);
                if ($binarySig === false || $binaryKey === false) {
                    return false;
                }
                return sodium_crypto_sign_verify_detached($binarySig, $message, $binaryKey);
            } catch (\Throwable $e) {
                return false;
            }
        }

        return false;
    }
}
