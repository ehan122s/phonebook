<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AppUpdate;
use App\Models\BugReport;
use App\Services\DiscordAppUpdateService;
use App\Services\DiscordTicketService;
use App\Services\TicketNotificationService;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class DiscordInteractionController extends Controller
{
    /**
     * Pencarian aman entitas BugReport yang kompatibel dengan PostgreSQL:
     * Menghindari cast string non-numerik langsung ke kolom bigint id.
     */
    public static function findTicket($idOrCode, bool $lock = false): ?BugReport
    {
        $query = BugReport::query();
        if ($lock) {
            $query->lockForUpdate();
        }

        if (is_numeric($idOrCode)) {
            $ticket = (clone $query)->find((int) $idOrCode);
            if ($ticket) return $ticket;
        }

        return (clone $query)->where('ticket_code', $idOrCode)
            ->orWhere('ticket_number', $idOrCode)
            ->first();
    }

    /**
     * Endpoint utama untuk menerima payload Discord Interactions API.
     * Menerima PING, Komponen Tombol (ACC, TOLAK, SELESAI), dan Modal Submit Penolakan.
     */
    public function handle(Request $request)
    {
        // 1. Verifikasi Signature Ed25519
        if (!DiscordTicketService::verifySignature($request)) {
            Log::warning('Discord Interaction: Signature verification failed.');
            return response()->json(['error' => 'Invalid request signature'], 401);
        }

        $payload = $request->json()->all() ?: $request->all();
        $type = (int) ($payload['type'] ?? 0);

        // TYPE 1: Discord PING (Health check dari Discord Developer Portal)
        if ($type === 1) {
            return response()->json(['type' => 1]);
        }

        // Identifikasi Pengguna / Developer Discord (bisa di payload.user atau payload.member.user)
        $user = $payload['user'] ?? ($payload['member']['user'] ?? []);
        $member = $payload['member'] ?? [];
        $devId = (string) ($user['id'] ?? ($member['user']['id'] ?? ''));
        $devUsername = $user['global_name'] ?? ($user['username'] ?? ($member['nick'] ?? 'Developer'));
        $devTag = "@{$devUsername} ({$devId})";

        // Periksa izin Developer
        if (!DiscordTicketService::isDeveloperAuthorized($devId)) {
            return response()->json([
                'type' => 4, // CHANNEL_MESSAGE_WITH_SOURCE
                'data' => [
                    'content' => '⚠️ Anda tidak memiliki izin untuk mengelola tiket laporan Phonebook.',
                    'flags' => 64, // EPHEMERAL
                ],
            ]);
        }

        // TYPE 2: APPLICATION_COMMAND (Slash command: /update, /app-update, /update-app, /publish-update)
        if ($type === 2) {
            $commandName = strtolower($payload['data']['name'] ?? '');
            if (in_array($commandName, ['update', 'app-update', 'update-app', 'publish-update', 'update-aplikasi'])) {
                return response()->json(DiscordAppUpdateService::buildUpdateModal());
            }

            if (in_array($commandName, ['panel-update', 'update-panel'])) {
                $res = DiscordAppUpdateService::sendControlPanelToChannel();
                return response()->json([
                    'type' => 4,
                    'data' => [
                        'content' => $res['success'] ? '✅ Panel kontrol pembaruan aplikasi telah dikirim ke channel.' : '❌ Gagal: ' . $res['message'],
                        'flags' => 64,
                    ],
                ]);
            }
        }

        // TYPE 3: MESSAGE_COMPONENT (Klik Tombol ACC, TOLAK, SELESAI, atau Tombol Update)
        if ($type === 3) {
            $customId = $payload['data']['custom_id'] ?? '';
            return $this->handleComponentInteraction($customId, $devTag);
        }

        // TYPE 5: MODAL_SUBMIT (Submit Alasan Penolakan, Penyelesaian, atau Pengumuman Update)
        if ($type === 5) {
            $customId = $payload['data']['custom_id'] ?? '';
            return $this->handleModalSubmitInteraction($customId, $payload['data'] ?? [], $devTag);
        }

        return response()->json([
            'type' => 4,
            'data' => [
                'content' => 'Interaction type tidak dikenali.',
                'flags' => 64,
            ],
        ]);
    }

    /**
     * Menangani interaksi klik tombol Discord (ACC, TOLAK, SELESAI).
     */
    private function handleComponentInteraction(string $customId, string $devTag)
    {
        // 1. ACC LAPORAN
        if (str_starts_with($customId, 'ticket_acc_')) {
            $ticketId = substr($customId, strlen('ticket_acc_'));
            return $this->processTicketAction($ticketId, 'acc', null, $devTag);
        }

        // 2. TOLAK LAPORAN -> Langsung buka Modal Form secara instan (0ms) untuk mencegah Discord interaction timeout
        if (str_starts_with($customId, 'ticket_tolak_')) {
            $ticketId = substr($customId, strlen('ticket_tolak_'));

            // Kembalikan Discord Modal Dialog (Type 9) langsung tanpa menunggu query database
            return response()->json([
                'type' => 9, // MODAL
                'data' => [
                    'custom_id' => "modal_tolak_{$ticketId}",
                    'title' => 'Alasan Penolakan Tiket',
                    'components' => [
                        [
                            'type' => 1, // ACTION_ROW
                            'components' => [
                                [
                                    'type' => 4, // TEXT_INPUT
                                    'custom_id' => 'rejection_reason',
                                    'label' => 'Jelaskan alasan penolakan laporan:',
                                    'style' => 2, // PARAGRAPH
                                    'min_length' => 5,
                                    'max_length' => 1000,
                                    'required' => true,
                                    'placeholder' => 'Contoh: Kendala tidak dapat direproduksi atau fitur sudah diperbarui di versi terbaru.',
                                ],
                            ],
                        ],
                    ],
                ],
            ]);
        }

        // 3. SELESAIKAN TIKET -> Langsung buka Modal Form secara instan (0ms) untuk mencegah Discord interaction timeout
        if (str_starts_with($customId, 'ticket_selesai_')) {
            $ticketId = substr($customId, strlen('ticket_selesai_'));

            // Kembalikan Discord Modal Dialog (Type 9) langsung tanpa menunggu query database
            return response()->json([
                'type' => 9, // MODAL
                'data' => [
                    'custom_id' => "modal_selesai_{$ticketId}",
                    'title' => 'Selesaikan Tiket Laporan',
                    'components' => [
                        [
                            'type' => 1, // ACTION_ROW
                            'components' => [
                                [
                                    'type' => 4, // TEXT_INPUT
                                    'custom_id' => 'resolution_reason',
                                    'label' => 'Alasan / Penjelasan Penyelesaian:',
                                    'style' => 2, // PARAGRAPH
                                    'min_length' => 5,
                                    'max_length' => 1000,
                                    'required' => true,
                                    'placeholder' => 'Contoh: Masalah gagal mengunduh laporan telah diperbaiki. Silakan perbarui aplikasi dan coba kembali.',
                                ],
                            ],
                        ],
                    ],
                ],
            ]);
        }

        // 4. BUKA MODAL FORM PENGUMUMAN UPDATE APLIKASI (0ms)
        if ($customId === 'btn_app_update_open') {
            return response()->json(DiscordAppUpdateService::buildUpdateModal());
        }

        // 5. PUBLIKASIKAN UPDATE APLIKASI
        if (str_starts_with($customId, 'app_update_publish_')) {
            $updateId = substr($customId, strlen('app_update_publish_'));
            $update = AppUpdate::find($updateId);

            if (!$update) {
                return response()->json([
                    'type' => 4,
                    'data' => [
                        'content' => '⚠️ Draft pembaruan aplikasi tidak ditemukan atau telah dihapus.',
                        'flags' => 64,
                    ],
                ]);
            }

            $update->is_published = true;
            $update->published_at = Carbon::now('Asia/Jakarta');
            $update->save();

            // Siarkan ke channel khusus update (1572971111266910289)
            DiscordAppUpdateService::broadcastPublishedUpdate($update, $devTag);

            Log::info("AppUpdate [PUBLISHED]: Versi {$update->version} dipublikasikan oleh {$devTag}");

            return response()->json([
                'type' => 7, // UPDATE_MESSAGE
                'data' => [
                    'embeds' => [DiscordAppUpdateService::buildPublishedEmbed($update, $devTag)],
                    'components' => DiscordAppUpdateService::buildPublishedComponents($update),
                ],
            ]);
        }

        // 6. BATALKAN PENGUMUMAN UPDATE APLIKASI
        if (str_starts_with($customId, 'app_update_cancel_')) {
            $updateId = substr($customId, strlen('app_update_cancel_'));
            $update = AppUpdate::find($updateId);

            if ($update) {
                $canceledUpdate = clone $update;
                $update->delete();
                return response()->json([
                    'type' => 7, // UPDATE_MESSAGE
                    'data' => [
                        'embeds' => [DiscordAppUpdateService::buildCanceledEmbed($canceledUpdate, $devTag)],
                        'components' => [],
                    ],
                ]);
            }

            return response()->json([
                'type' => 4,
                'data' => [
                    'content' => 'ℹ️ Draft pengumuman update sudah dibatalkan sebelumnya.',
                    'flags' => 64,
                ],
            ]);
        }

        return response()->json([
            'type' => 4,
            'data' => [
                'content' => 'Tombol tidak dikenali.',
                'flags' => 64,
            ],
        ]);
    }

    /**
     * Menangani modal submit alasan penolakan dan penyelesaian tiket dari Discord.
     */
    private function handleModalSubmitInteraction(string $customId, array $data, string $devTag)
    {
        if (str_starts_with($customId, 'modal_tolak_')) {
            $ticketId = substr($customId, strlen('modal_tolak_'));

            $reason = '';
            foreach ($data['components'] ?? [] as $row) {
                foreach ($row['components'] ?? [] as $field) {
                    if (($field['custom_id'] ?? '') === 'rejection_reason') {
                        $reason = trim($field['value'] ?? '');
                    }
                }
            }

            if (empty($reason)) {
                $reason = 'Laporan ditolak oleh developer.';
            }

            return $this->processTicketAction($ticketId, 'tolak', $reason, $devTag);
        }

        if (str_starts_with($customId, 'modal_selesai_')) {
            $ticketId = substr($customId, strlen('modal_selesai_'));

            $reason = '';
            foreach ($data['components'] ?? [] as $row) {
                foreach ($row['components'] ?? [] as $field) {
                    if (($field['custom_id'] ?? '') === 'resolution_reason') {
                        $reason = trim($field['value'] ?? '');
                    }
                }
            }

            if (empty($reason)) {
                return response()->json([
                    'type' => 4,
                    'data' => [
                        'content' => '⚠️ Alasan / penjelasan penyelesaian tiket wajib diisi.',
                        'flags' => 64,
                    ],
                ]);
            }

            return $this->processTicketAction($ticketId, 'selesai', $reason, $devTag);
        }

        // 3. SUBMIT PENGUMUMAN UPDATE APLIKASI
        if ($customId === 'modal_app_update') {
            $version = '';
            $title = '';
            $description = '';
            $apkUrl = '';
            $type = 'optional';

            foreach ($data['components'] ?? [] as $row) {
                foreach ($row['components'] ?? [] as $field) {
                    $cId = $field['custom_id'] ?? '';
                    $val = trim($field['value'] ?? '');
                    if ($cId === 'update_version') $version = $val;
                    elseif ($cId === 'update_title') $title = $val;
                    elseif ($cId === 'update_description') $description = $val;
                    elseif ($cId === 'update_apk_url') $apkUrl = $val;
                    elseif ($cId === 'update_type') $type = strtolower($val) === 'mandatory' ? 'mandatory' : 'optional';
                }
            }

            // Validasi format versi semver
            if (!preg_match('/^[0-9]+(\.[0-9]+)*(\+[0-9]+)?$/', $version)) {
                return response()->json([
                    'type' => 4,
                    'data' => [
                        'content' => '⚠️ Format versi tidak valid! Gunakan format semantic versioning seperti `1.2.0`.',
                        'flags' => 64,
                    ],
                ]);
            }

            // Validasi APK URL wajib HTTPS
            if (!filter_var($apkUrl, FILTER_VALIDATE_URL) || !str_starts_with(strtolower($apkUrl), 'https://')) {
                return response()->json([
                    'type' => 4,
                    'data' => [
                        'content' => '⚠️ Link download APK harus berupa URL valid dengan protokol aman HTTPS (`https://...`).',
                        'flags' => 64,
                    ],
                ]);
            }

            if (empty($title) || empty($description)) {
                return response()->json([
                    'type' => 4,
                    'data' => [
                        'content' => '⚠️ Judul pembaruan dan deskripsi / catatan perubahan wajib diisi.',
                        'flags' => 64,
                    ],
                ]);
            }

            // Simpan data draft pembaruan ke PostgreSQL Supabase
            $update = AppUpdate::create([
                'version' => $version,
                'title' => $title,
                'description' => $description,
                'apk_url' => $apkUrl,
                'type' => $type,
                'is_published' => false,
                'discord_user_id' => $devTag,
                'discord_user_name' => $devTag,
            ]);

            return response()->json([
                'type' => 4, // CHANNEL_MESSAGE_WITH_SOURCE
                'data' => [
                    'embeds' => [DiscordAppUpdateService::buildDraftEmbed($update, $devTag)],
                    'components' => DiscordAppUpdateService::buildDraftComponents($update->id),
                ],
            ]);
        }

        return response()->json([
            'type' => 4,
            'data' => ['content' => 'Modal submit tidak dikenali.', 'flags' => 64],
        ]);
    }

    /**
     * Memproses perubahan status tiket dan mengirimkan notifikasi WhatsApp secara cepat, aman & idempoten.
     */
    public function processTicketAction($ticketId, string $action, ?string $reason = null, ?string $developerName = null)
    {
        $devTag = $developerName ?: 'Developer Phonebook';

        $ticket = self::findTicket($ticketId);
        if (!$ticket) {
            return response()->json([
                'type' => 4,
                'data' => [
                    'content' => "⚠️ Tiket laporan ID {$ticketId} tidak ditemukan di sistem database.",
                    'flags' => 64,
                ],
            ], 404);
        }

        $statusUpper = strtoupper($ticket->status ?: 'MENUNGGU PERSETUJUAN');

        // 1. Aksi ACC LAPORAN
        if ($action === 'acc') {
            if ($statusUpper === 'DITERIMA') {
                return response()->json([
                    'type' => 4,
                    'data' => [
                        'content' => "ℹ️ Tiket {$ticket->ticket_code} sudah disetujui sebelumnya oleh {$ticket->handled_by}.",
                        'flags' => 64,
                    ],
                ]);
            }
            if ($statusUpper === 'SELESAI') {
                return response()->json([
                    'type' => 4,
                    'data' => [
                        'content' => "ℹ️ Tiket {$ticket->ticket_code} sudah berstatus SELESAI.",
                        'flags' => 64,
                    ],
                ]);
            }

            $ticket->status = 'DITERIMA';
            $ticket->handled_by = $devTag;
            $ticket->approved_at = Carbon::now('Asia/Jakarta');
            $ticket->accepted_at = Carbon::now('Asia/Jakarta');
            $ticket->save();

            // Catat notifikasi aplikasi user di PostgreSQL Supabase
            TicketNotificationService::createAppNotification($ticket, 'acc');

            // Kirim notifikasi WhatsApp otomatis via Fonnte (timeout 3s aman)
            TicketNotificationService::sendWhatsAppUpdate($ticket, 'acc');

            return response()->json([
                'type' => 7, // UPDATE_MESSAGE
                'data' => [
                    'embeds' => [DiscordTicketService::buildEmbed($ticket)],
                    'components' => DiscordTicketService::buildComponents($ticket),
                ],
            ]);
        }

        // 2. Aksi TOLAK LAPORAN
        if ($action === 'tolak') {
            if ($statusUpper === 'DITOLAK') {
                return response()->json([
                    'type' => 4,
                    'data' => [
                        'content' => "ℹ️ Tiket {$ticket->ticket_code} sudah ditolak sebelumnya.",
                        'flags' => 64,
                    ],
                ]);
            }

            $ticket->status = 'DITOLAK';
            $ticket->handled_by = $devTag;
            $ticket->rejection_reason = $reason ?: 'Laporan belum dapat diproses.';
            $ticket->save();

            // Catat notifikasi aplikasi user di PostgreSQL Supabase
            TicketNotificationService::createAppNotification($ticket, 'tolak', $reason);

            // Kirim notifikasi WhatsApp otomatis via Fonnte
            TicketNotificationService::sendWhatsAppUpdate($ticket, 'tolak', $reason);

            return response()->json([
                'type' => 7, // UPDATE_MESSAGE
                'data' => [
                    'embeds' => [DiscordTicketService::buildEmbed($ticket)],
                    'components' => DiscordTicketService::buildComponents($ticket),
                ],
            ]);
        }

        // 3. Aksi SELESAI DIPROSES
        if ($action === 'selesai') {
            if ($statusUpper === 'SELESAI') {
                return response()->json([
                    'type' => 4,
                    'data' => [
                        'content' => "ℹ️ Tiket {$ticket->ticket_code} sudah ditandai SELESAI sebelumnya.",
                        'flags' => 64,
                    ],
                ]);
            }

            $ticket->status = 'SELESAI';
            $ticket->handled_by = $devTag;
            $ticket->resolution_reason = $reason ?: 'Masalah telah diselesaikan oleh tim developer.';
            $ticket->resolved_at = Carbon::now('Asia/Jakarta');
            $ticket->save();

            // Catat notifikasi aplikasi user di PostgreSQL Supabase lengkap dengan reason developer
            TicketNotificationService::createAppNotification($ticket, 'selesai', $reason);

            // Kirim notifikasi WhatsApp otomatis via Fonnte
            TicketNotificationService::sendWhatsAppUpdate($ticket, 'selesai', $reason);

            return response()->json([
                'type' => 7, // UPDATE_MESSAGE
                'data' => [
                    'embeds' => [DiscordTicketService::buildEmbed($ticket)],
                    'components' => DiscordTicketService::buildComponents($ticket),
                ],
            ]);
        }

        return response()->json([
            'type' => 4,
            'data' => ['content' => 'Aksi tiket tidak dikenali.', 'flags' => 64],
        ]);
    }

    /**
     * Endpoint REST API untuk trigger aksi ACC, TOLAK, atau SELESAI langsung
     * (untuk pengujian dev / curl / integrasi eksternal).
     */
    public function triggerAction(Request $request, $id)
    {
        $ticket = self::findTicket($id);

        if (!$ticket) {
            if ($request->wantsJson()) {
                return response()->json([
                    'success' => false,
                    'message' => 'Tiket laporan tidak ditemukan.',
                ], 404);
            }
            return response('<h2>⚠️ Tiket laporan tidak ditemukan.</h2>', 404, ['Content-Type' => 'text/html']);
        }

        $action = strtolower($request->input('action') ?: ($request->query('action') ?: 'acc'));
        $reason = $request->input('reason') ?: $request->query('reason');
        $dev = $request->input('developer') ?: ($request->query('developer') ?: 'Tim Developer Phonebook');

        // Jika dibuka dari browser via GET dan aksi adalah selesai tanpa reason, tampilkan form input reason
        if ($request->isMethod('GET') && !$request->wantsJson()) {
            if ($action === 'selesai' && empty($reason)) {
                $html = <<<HTML
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Selesaikan Tiket {$ticket->ticket_code}</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #F0F5F1; margin: 0; padding: 24px; display: flex; justify-content: center; align-items: center; min-height: 100vh; }
        .card { background: #fff; border-radius: 16px; padding: 28px; max-width: 480px; width: 100%; box-shadow: 0 4px 20px rgba(0,0,0,0.08); border-top: 6px solid #245C3A; }
        h2 { color: #245C3A; margin-top: 0; font-size: 20px; }
        .info { background: #EBF3ED; padding: 12px 16px; border-radius: 8px; margin-bottom: 20px; font-size: 14px; color: #1E2923; }
        label { display: block; font-weight: 600; font-size: 13px; color: #2D3748; margin-bottom: 8px; }
        textarea { width: 100%; box-sizing: border-box; padding: 12px; border: 1px solid #CBD5E0; border-radius: 8px; font-size: 14px; min-height: 100px; resize: vertical; }
        button { background: #245C3A; color: #fff; border: none; padding: 12px 20px; border-radius: 8px; font-size: 15px; font-weight: 600; width: 100%; margin-top: 18px; cursor: pointer; transition: background 0.2s; }
        button:hover { background: #1B452B; }
    </style>
</head>
<body>
    <div class="card">
        <h2>Selesaikan Tiket #{$ticket->ticket_code}</h2>
        <div class="info">
            <strong>Pelapor:</strong> {$ticket->reporter_name}<br>
            <strong>Judul:</strong> {$ticket->title}<br>
            <strong>Status Saat Ini:</strong> {$ticket->status}
        </div>
        <form method="POST">
            <input type="hidden" name="action" value="selesai">
            <label for="reason">Alasan / Penjelasan Penyelesaian (Wajib):</label>
            <textarea name="reason" id="reason" required placeholder="Contoh: Masalah gagal mengunduh laporan telah diperbaiki. Silakan perbarui aplikasi dan coba kembali."></textarea>
            <button type="submit">✅ Simpan & Selesaikan Tiket</button>
        </form>
    </div>
</body>
</html>
HTML;
                return response($html, 200, ['Content-Type' => 'text/html']);
            }
        }

        if ($action === 'acc') {
            $ticket->status = 'DITERIMA';
            $ticket->handled_by = $dev;
            $ticket->approved_at = Carbon::now('Asia/Jakarta');
            $ticket->accepted_at = Carbon::now('Asia/Jakarta');
            $ticket->save();
            TicketNotificationService::createAppNotification($ticket, 'acc');
        } elseif ($action === 'tolak') {
            $ticket->status = 'DITOLAK';
            $ticket->handled_by = $dev;
            $ticket->rejection_reason = $reason ?: 'Laporan belum dapat diproses.';
            $ticket->save();
            TicketNotificationService::createAppNotification($ticket, 'tolak', $reason);
        } elseif ($action === 'selesai') {
            $ticket->status = 'SELESAI';
            $ticket->handled_by = $dev;
            $ticket->resolution_reason = $reason ?: 'Masalah telah diselesaikan oleh tim developer.';
            $ticket->resolved_at = Carbon::now('Asia/Jakarta');
            $ticket->save();
            TicketNotificationService::createAppNotification($ticket, 'selesai', $reason);
        }

        // Kirim WhatsApp notifikasi via Fonnte
        $waResult = TicketNotificationService::sendWhatsAppUpdate($ticket, $action, $reason);

        // Update pesan Discord jika ada message_id
        DiscordTicketService::updateDiscordMessage($ticket);

        if (!$request->wantsJson() && !$request->ajax()) {
            $statusLabel = $ticket->status;
            $html = <<<HTML
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Tiket {$ticket->ticket_code} Berhasil Diperbarui</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #F0F5F1; margin: 0; padding: 24px; display: flex; justify-content: center; align-items: center; min-height: 100vh; }
        .card { background: #fff; border-radius: 16px; padding: 32px; max-width: 440px; width: 100%; text-align: center; box-shadow: 0 4px 20px rgba(0,0,0,0.08); border-top: 6px solid #245C3A; }
        .icon { font-size: 48px; margin-bottom: 12px; }
        h2 { color: #245C3A; margin: 0 0 10px; font-size: 22px; }
        p { color: #4A5568; font-size: 14px; line-height: 1.6; }
        .badge { display: inline-block; background: #EBF3ED; color: #245C3A; font-weight: 700; padding: 6px 14px; border-radius: 20px; font-size: 13px; margin: 8px 0; }
    </style>
</head>
<body>
    <div class="card">
        <div class="icon">✅</div>
        <h2>Aksi Berhasil!</h2>
        <div class="badge">Tiket #{$ticket->ticket_code}</div>
        <p>Status berhasil diperbarui menjadi <strong>{$statusLabel}</strong>.<br>Notifikasi WhatsApp dan aplikasi pengguna telah otomatis dikirimkan.</p>
    </div>
</body>
</html>
HTML;
            return response($html, 200, ['Content-Type' => 'text/html']);
        }

        return response()->json([
            'success' => true,
            'message' => "Tiket {$ticket->ticket_code} berhasil diubah statusnya menjadi {$ticket->status}.",
            'ticket' => [
                'id' => $ticket->id,
                'ticket_code' => $ticket->ticket_code,
                'status' => $ticket->status,
                'resolution_reason' => $ticket->resolution_reason,
                'rejection_reason' => $ticket->rejection_reason,
                'handled_by' => $ticket->handled_by,
                'approved_at' => $ticket->approved_at?->toIso8601String(),
                'resolved_at' => $ticket->resolved_at?->toIso8601String(),
                'wa_sent' => $ticket->wa_sent,
                'wa_status' => $ticket->wa_status,
            ],
            'whatsapp' => $waResult,
        ]);
    }
}
