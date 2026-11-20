<?php

namespace App\Services;

use App\Models\AppUpdate;
use Carbon\Carbon;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class DiscordAppUpdateService
{
    /**
     * Membangun payload modal form pengumuman update aplikasi untuk Discord (Type 9).
     */
    public static function buildUpdateModal(): array
    {
        return [
            'type' => 9, // MODAL
            'data' => [
                'custom_id' => 'modal_app_update',
                'title' => 'Pengumuman Update Phonebook',
                'components' => [
                    [
                        'type' => 1, // ACTION_ROW
                        'components' => [
                            [
                                'type' => 4, // TEXT_INPUT
                                'custom_id' => 'update_version',
                                'label' => 'Versi Terbaru (Contoh: 1.2.0)',
                                'style' => 1, // SHORT
                                'min_length' => 3,
                                'max_length' => 20,
                                'required' => true,
                                'placeholder' => 'Contoh: 1.2.0',
                            ],
                        ],
                    ],
                    [
                        'type' => 1,
                        'components' => [
                            [
                                'type' => 4,
                                'custom_id' => 'update_title',
                                'label' => 'Judul Pembaruan',
                                'style' => 1,
                                'min_length' => 3,
                                'max_length' => 100,
                                'required' => true,
                                'placeholder' => 'Contoh: Pembaruan Phonebook v1.2.0',
                            ],
                        ],
                    ],
                    [
                        'type' => 1,
                        'components' => [
                            [
                                'type' => 4,
                                'custom_id' => 'update_description',
                                'label' => 'Deskripsi Update / Catatan Perubahan',
                                'style' => 2, // PARAGRAPH
                                'min_length' => 5,
                                'max_length' => 1500,
                                'required' => true,
                                'placeholder' => 'Penjelasan mengenai fitur baru, perbaikan bug, atau perubahan aplikasi...',
                            ],
                        ],
                    ],
                    [
                        'type' => 1,
                        'components' => [
                            [
                                'type' => 4,
                                'custom_id' => 'update_apk_url',
                                'label' => 'Link Download APK (Wajib HTTPS)',
                                'style' => 1,
                                'min_length' => 8,
                                'max_length' => 500,
                                'required' => true,
                                'placeholder' => 'https://example.com/phonebook-v1.2.0.apk',
                            ],
                        ],
                    ],
                    [
                        'type' => 1,
                        'components' => [
                            [
                                'type' => 4,
                                'custom_id' => 'update_type',
                                'label' => 'Jenis Update (optional / mandatory)',
                                'style' => 1,
                                'min_length' => 6,
                                'max_length' => 10,
                                'required' => false,
                                'placeholder' => 'Ketik "optional" (biasa) atau "mandatory" (wajib)',
                            ],
                        ],
                    ],
                ],
            ],
        ];
    }

    /**
     * Membangun Embed konfirmasi pratinjau (Draft) update sebelum dipublikasikan.
     */
    public static function buildDraftEmbed(AppUpdate $update, string $devTag): array
    {
        $isMandatory = $update->isMandatory();

        return [
            'title' => '🚀 DRAFT PENGUMUMAN UPDATE APLIKASI PHONEBOOK',
            'description' => "Pengumuman pembaruan aplikasi telah disiapkan.\nPeriksa kembali detail di bawah ini, lalu klik **Publikasikan Update** agar pop-up notifikasi otomatis muncul di aplikasi seluruh pengguna Phonebook.",
            'color' => 2382906, // Forest green #245C3A
            'fields' => [
                [
                    'name' => '📱 Versi Aplikasi',
                    'value' => "**v{$update->version}**",
                    'inline' => true,
                ],
                [
                    'name' => '⚙️ Jenis Pembaruan',
                    'value' => $isMandatory ? '🚨 **Wajib (Mandatory)**' : '✨ **Biasa (Opsional)**',
                    'inline' => true,
                ],
                [
                    'name' => '📌 Judul Pembaruan',
                    'value' => $update->title,
                    'inline' => false,
                ],
                [
                    'name' => '🔗 Link Download APK',
                    'value' => "[Unduh File APK]({$update->apk_url})\n`{$update->apk_url}`",
                    'inline' => false,
                ],
                [
                    'name' => '📝 Deskripsi / Catatan Perubahan',
                    'value' => mb_strlen($update->description) > 1000
                        ? mb_substr($update->description, 0, 995) . ' ...'
                        : $update->description,
                    'inline' => false,
                ],
                [
                    'name' => '👤 Dibuat Oleh',
                    'value' => $devTag,
                    'inline' => true,
                ],
                [
                    'name' => '📊 Status',
                    'value' => '🟡 **Draft (Menunggu Publikasi)**',
                    'inline' => true,
                ],
            ],
            'footer' => [
                'text' => 'Phonebook CDK Wilayah V Garut • Sistem Pembaruan Aplikasi',
            ],
            'timestamp' => Carbon::now('Asia/Jakarta')->toIso8601String(),
        ];
    }

    /**
     * Membangun tombol konfirmasi publikasi atau pembatalan draft.
     */
    public static function buildDraftComponents(int $updateId): array
    {
        return [
            [
                'type' => 1, // ACTION_ROW
                'components' => [
                    [
                        'type' => 2, // BUTTON
                        'style' => 3, // SUCCESS
                        'label' => 'Publikasikan Update',
                        'custom_id' => "app_update_publish_{$updateId}",
                        'emoji' => ['name' => '📢'],
                    ],
                    [
                        'type' => 2, // BUTTON
                        'style' => 4, // DANGER
                        'label' => 'Batalkan',
                        'custom_id' => "app_update_cancel_{$updateId}",
                        'emoji' => ['name' => '❌'],
                    ],
                ],
            ],
        ];
    }

    /**
     * Membangun Embed pengumuman update yang telah resmi dipublikasikan.
     */
    public static function buildPublishedEmbed(AppUpdate $update, string $devTag): array
    {
        $isMandatory = $update->isMandatory();
        $publishedAtWib = $update->published_at
            ? Carbon::parse($update->published_at)->setTimezone('Asia/Jakarta')->format('d/m/Y H:i:s') . ' WIB'
            : Carbon::now('Asia/Jakarta')->format('d/m/Y H:i:s') . ' WIB';

        return [
            'title' => '📢 PEMBARUAN APLIKASI PHONEBOOK RESMI DIPUBLIKASIKAN',
            'description' => "Pembaruan versi **v{$update->version}** telah aktif di server.\nSeluruh pengguna aplikasi Phonebook akan menerima notifikasi pop-up pembaruan secara otomatis saat membuka aplikasi.",
            'color' => 3066993, // Bright Green
            'fields' => [
                [
                    'name' => '📱 Versi Aplikasi',
                    'value' => "**v{$update->version}**",
                    'inline' => true,
                ],
                [
                    'name' => '⚙️ Jenis Pembaruan',
                    'value' => $isMandatory ? '🚨 **Wajib (Mandatory)**' : '✨ **Biasa (Opsional)**',
                    'inline' => true,
                ],
                [
                    'name' => '📌 Judul Pembaruan',
                    'value' => $update->title,
                    'inline' => false,
                ],
                [
                    'name' => '🔗 Link Unduh APK',
                    'value' => "[Klik untuk Unduh APK]({$update->apk_url})\n`{$update->apk_url}`",
                    'inline' => false,
                ],
                [
                    'name' => '📝 Catatan Perubahan (Changelog)',
                    'value' => mb_strlen($update->description) > 1000
                        ? mb_substr($update->description, 0, 995) . ' ...'
                        : $update->description,
                    'inline' => false,
                ],
                [
                    'name' => '🕒 Waktu Publikasi',
                    'value' => $publishedAtWib,
                    'inline' => true,
                ],
                [
                    'name' => '👤 Dipublikasikan Oleh',
                    'value' => $devTag,
                    'inline' => true,
                ],
                [
                    'name' => '📊 Status',
                    'value' => '🟢 **AKTIF / DIPUBLIKASIKAN**',
                    'inline' => true,
                ],
            ],
            'footer' => [
                'text' => 'Phonebook CDK Wilayah V Garut • Sistem Pembaruan Aplikasi',
            ],
            'timestamp' => Carbon::now('Asia/Jakarta')->toIso8601String(),
        ];
    }

    /**
     * Membangun komponen tombol untuk pengumuman yang sudah dipublikasikan.
     */
    public static function buildPublishedComponents(AppUpdate $update): array
    {
        return [
            [
                'type' => 1,
                'components' => [
                    [
                        'type' => 2,
                        'style' => 3, // SUCCESS
                        'label' => 'Pembaruan Aktif',
                        'custom_id' => 'btn_app_update_active',
                        'disabled' => true,
                        'emoji' => ['name' => '✅'],
                    ],
                    [
                        'type' => 2,
                        'style' => 5, // LINK
                        'label' => 'Unduh File APK',
                        'url' => $update->apk_url,
                        'emoji' => ['name' => '📥'],
                    ],
                ],
            ],
        ];
    }

    /**
     * Membangun Embed untuk pengumuman yang dibatalkan.
     */
    public static function buildCanceledEmbed(AppUpdate $update, string $devTag): array
    {
        return [
            'title' => '❌ PENGUMUMAN PEMBARUAN DIBATALKAN',
            'description' => "Pengumuman pembaruan versi **v{$update->version}** telah dibatalkan oleh developer.",
            'color' => 12986408, // Red
            'fields' => [
                [
                    'name' => '📱 Versi Aplikasi',
                    'value' => "v{$update->version}",
                    'inline' => true,
                ],
                [
                    'name' => '👤 Dibatalkan Oleh',
                    'value' => $devTag,
                    'inline' => true,
                ],
                [
                    'name' => '🕒 Waktu Pembatalan',
                    'value' => Carbon::now('Asia/Jakarta')->format('d/m/Y H:i:s') . ' WIB',
                    'inline' => true,
                ],
            ],
            'footer' => [
                'text' => 'Phonebook CDK Wilayah V Garut • Sistem Pembaruan Aplikasi',
            ],
            'timestamp' => Carbon::now('Asia/Jakarta')->toIso8601String(),
        ];
    }

    /**
     * Mengirimkan pesan Panel Kontrol Pembaruan ke Text Channel Discord.
     */
    public static function sendControlPanelToChannel(): array
    {
        $botToken = config('services.discord.bot_token');
        $rawChannelId = config('services.discord.channel_id');
        $channelId = DiscordTicketService::resolveChannelId($rawChannelId, $botToken);

        $embed = [
            'title' => '📲 PANEL KONTROL PEMBARUAN PHONEBOOK',
            'description' => "Gunakan tombol di bawah ini untuk membuat pengumuman rilis versi terbaru aplikasi **Phonebook**.\n\n" .
                "• **Versi Terbaru**: Masukkan nomor versi semver (contoh: 1.2.0)\n" .
                "• **Judul & Deskripsi**: Tuliskan catatan perubahan / fitur baru\n" .
                "• **Link APK**: Tautan download aman HTTPS\n" .
                "• **Jenis Update**: Pilih update biasa (opsional) atau update wajib (mandatory)\n\n" .
                "Setiap pengumuman yang dipublikasikan akan memicu dialog pop-up otomatis di aplikasi pengguna.",
            'color' => 2382906, // Forest green
            'footer' => [
                'text' => 'Phonebook Developer Panel • Discord Automation',
            ],
            'timestamp' => Carbon::now('Asia/Jakarta')->toIso8601String(),
        ];

        $components = [
            [
                'type' => 1,
                'components' => [
                    [
                        'type' => 2,
                        'style' => 1, // PRIMARY (Blurple)
                        'label' => 'Buat Pengumuman Update',
                        'custom_id' => 'btn_app_update_open',
                        'emoji' => ['name' => '🚀'],
                    ],
                ],
            ],
        ];

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
                    return ['success' => true, 'message' => 'Panel pengumuman berhasil dikirim ke channel Discord.'];
                }

                return ['success' => false, 'message' => 'Gagal mengirim panel ke Discord: ' . $response->body()];
            } catch (\Throwable $e) {
                return ['success' => false, 'message' => 'Exception: ' . $e->getMessage()];
            }
        }

        return ['success' => false, 'message' => 'Bot Token atau Channel ID belum terkonfigurasi.'];
    }
}
