<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\BugReport;
use App\Services\DiscordTicketService;
use App\Services\TicketNotificationService;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class DiscordInteractionController extends Controller
{
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

        $payload = $request->all();
        $type = (int) ($payload['type'] ?? 0);

        // TYPE 1: Discord PING (Health check dari Discord Developer Portal)
        if ($type === 1) {
            return response()->json(['type' => 1]);
        }

        // Identifikasi Pengguna / Developer Discord
        $member = $payload['member'] ?? null;
        $user = $member['user'] ?? ($payload['user'] ?? []);
        $devId = $user['id'] ?? null;
        $devUsername = $user['username'] ?? ($member['nick'] ?? 'Developer');
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

        // TYPE 3: MESSAGE_COMPONENT (Klik Tombol ACC, TOLAK, SELESAI)
        if ($type === 3) {
            $customId = $payload['data']['custom_id'] ?? '';
            return $this->handleComponentInteraction($customId, $devTag);
        }

        // TYPE 5: MODAL_SUBMIT (Submit Alasan Penolakan dari Modal Dialog)
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

        // 2. TOLAK LAPORAN -> Tampilkan Modal Form untuk Alasan Penolakan
        if (str_starts_with($customId, 'ticket_tolak_')) {
            $ticketId = substr($customId, strlen('ticket_tolak_'));

            $ticket = BugReport::find($ticketId);
            if (!$ticket) {
                return response()->json([
                    'type' => 4,
                    'data' => [
                        'content' => "⚠️ Tiket #{$ticketId} tidak ditemukan.",
                        'flags' => 64,
                    ],
                ]);
            }

            if (strtoupper($ticket->status) === 'DITOLAK' || strtoupper($ticket->status) === 'SELESAI') {
                return response()->json([
                    'type' => 4,
                    'data' => [
                        'content' => "⚠️ Tiket {$ticket->ticket_code} sudah berstatus {$ticket->status} dan tidak dapat ditolak lagi.",
                        'flags' => 64,
                    ],
                ]);
            }

            // Kembalikan Discord Modal Dialog (Type 9)
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

        // 3. SELESAI DIPROSES
        if (str_starts_with($customId, 'ticket_selesai_')) {
            $ticketId = substr($customId, strlen('ticket_selesai_'));
            return $this->processTicketAction($ticketId, 'selesai', null, $devTag);
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
     * Menangani modal submit alasan penolakan tiket dari Discord.
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

        return response()->json([
            'type' => 4,
            'data' => ['content' => 'Modal submit tidak dikenali.', 'flags' => 64],
        ]);
    }

    /**
     * Memproses perubahan status tiket dan mengirimkan notifikasi WhatsApp secara aman & idempoten.
     */
    public function processTicketAction($ticketId, string $action, ?string $reason = null, ?string $developerName = null)
    {
        $devTag = $developerName ?: 'Developer Phonebook';

        return DB::transaction(function () use ($ticketId, $action, $reason, $devTag) {
            $ticket = BugReport::lockForUpdate()->find($ticketId);
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
                $ticket->save();

                // Kirim notifikasi WhatsApp otomatis
                $waResult = TicketNotificationService::sendWhatsAppUpdate($ticket, 'acc');

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

                // Kirim notifikasi WhatsApp otomatis
                $waResult = TicketNotificationService::sendWhatsAppUpdate($ticket, 'tolak', $reason);

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
                $ticket->resolved_at = Carbon::now('Asia/Jakarta');
                $ticket->save();

                // Kirim notifikasi WhatsApp otomatis
                $waResult = TicketNotificationService::sendWhatsAppUpdate($ticket, 'selesai');

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
        });
    }

    /**
     * Endpoint REST API untuk trigger aksi ACC, TOLAK, atau SELESAI langsung
     * (untuk pengujian dev / curl / integrasi eksternal).
     */
    public function triggerAction(Request $request, $id)
    {
        $validated = $request->validate([
            'action' => 'required|in:acc,tolak,selesai',
            'reason' => 'nullable|string|max:1000',
            'developer' => 'nullable|string|max:128',
        ]);

        $ticket = BugReport::find($id);
        if (!$ticket) {
            $ticket = BugReport::where('ticket_code', $id)->first();
        }

        if (!$ticket) {
            return response()->json([
                'success' => false,
                'message' => 'Tiket laporan tidak ditemukan.',
            ], 404);
        }

        $action = strtolower($validated['action']);
        $reason = $validated['reason'] ?? null;
        $dev = $validated['developer'] ?? 'Tim Developer Phonebook';

        if ($action === 'acc') {
            $ticket->status = 'DITERIMA';
            $ticket->handled_by = $dev;
            $ticket->approved_at = Carbon::now('Asia/Jakarta');
            $ticket->save();
        } elseif ($action === 'tolak') {
            $ticket->status = 'DITOLAK';
            $ticket->handled_by = $dev;
            $ticket->rejection_reason = $reason ?: 'Laporan belum dapat diproses.';
            $ticket->save();
        } elseif ($action === 'selesai') {
            $ticket->status = 'SELESAI';
            $ticket->handled_by = $dev;
            $ticket->resolved_at = Carbon::now('Asia/Jakarta');
            $ticket->save();
        }

        // Kirim WhatsApp notifikasi via Fonnte
        $waResult = TicketNotificationService::sendWhatsAppUpdate($ticket, $action, $reason);

        // Update pesan Discord jika ada message_id
        DiscordTicketService::updateDiscordMessage($ticket);

        return response()->json([
            'success' => true,
            'message' => "Tiket {$ticket->ticket_code} berhasil diubah statusnya menjadi {$ticket->status}.",
            'ticket' => [
                'id' => $ticket->id,
                'ticket_code' => $ticket->ticket_code,
                'status' => $ticket->status,
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
