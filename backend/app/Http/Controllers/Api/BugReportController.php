<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\BugReport;
use App\Services\DiscordTicketService;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

class BugReportController extends Controller
{
    /**
     * Menyimpan tiket laporan masalah baru dari pengguna Phonebook
     * dan meneruskannya ke Discord via Bot API / Webhook dengan embed & tombol interaktif.
     */
    public function store(Request $request)
    {
        Log::info("BugReport [RECEIVE]: Permintaan laporan masalah baru dari IP {$request->ip()}", [
            'title' => $request->input('title'),
            'category' => $request->input('category'),
            'phone' => $request->input('reporter_phone') ? 'PROVIDED' : 'EMPTY',
        ]);

        $validated = $request->validate([
            'title' => 'required|string|max:255',
            'category' => 'required|string|max:100',
            'description' => 'required|string|max:5000',
            'priority' => 'nullable|string|max:50',
            'reporter_name' => 'nullable|string|max:255',
            'reporter_email' => 'nullable|string|max:255',
            'reporter_phone' => 'nullable|string|max:32',
            'app_version' => 'nullable|string|max:50',
            'device_info' => 'nullable|string|max:500',
        ]);

        $user = $request->user() ?: auth('sanctum')->user();

        // Nama, email, dan nomor WhatsApp
        $userName = $user ? ($user->name ?: 'Pengguna') : ($validated['reporter_name'] ?? 'Pengguna');
        $userEmail = $user ? ($user->email ?: '-') : ($validated['reporter_email'] ?? '-');
        $userPhone = !empty($validated['reporter_phone'])
            ? $validated['reporter_phone']
            : ($user?->whatsapp_number ?: ($user?->phone ?: null));

        $appVersion = $validated['app_version'] ?? 'Phonebook v1.0.0';
        $category = $validated['category'];
        $priority = $validated['priority'] ?? 'Sedang';
        $title = $validated['title'];
        $description = $validated['description'];
        $deviceInfo = $validated['device_info'] ?? ($request->header('User-Agent') ?: 'Android / Flutter');

        Log::info("BugReport [VALIDATE]: Validasi input berhasil.", [
            'user' => $userName,
            'category' => $category,
            'priority' => $priority,
        ]);

        // Pencegahan Duplikasi: Jika tiket dengan judul, deskripsi, dan pelapor yang sama
        // baru saja dibuat dalam 45 detik terakhir (misal user menekan Kirim berulang kali)
        $duplicateQuery = BugReport::where('title', $title)
            ->where('created_at', '>=', Carbon::now()->subSeconds(45));

        if ($user) {
            $duplicateQuery->where('user_id', $user->id);
        } elseif (!empty($userPhone)) {
            $duplicateQuery->where('reporter_phone', $userPhone);
        }

        $existingRecent = $duplicateQuery->first();
        if ($existingRecent) {
            Log::info("BugReport [DEDUPLICATION]: Mendeteksi tiket kembar baru saja dibuat (#{$existingRecent->ticket_code}). Menggunakan tiket yang sudah ada.");
            
            // Jika tiket sebelumnya belum terkirim ke Discord, coba kirim ulang sekarang
            if (!$existingRecent->discord_sent) {
                Log::info("BugReport [DEDUPLICATION_RETRY]: Tiket sebelumnya belum terkirim ke Discord. Melakukan pengiriman ulang...");
                DiscordTicketService::sendTicketToDiscord($existingRecent);
            }

            return response()->json([
                'success' => true,
                'message' => 'Laporan masalah sudah terdaftar sebelumnya.',
                'data' => [
                    'id' => $existingRecent->id,
                    'ticket_code' => $existingRecent->ticket_code,
                    'title' => $existingRecent->title,
                    'category' => $existingRecent->category,
                    'status' => $existingRecent->status,
                    'reporter_name' => $existingRecent->reporter_name,
                    'reporter_phone' => $existingRecent->reporter_phone,
                    'discord_sent' => $existingRecent->discord_sent,
                    'created_at' => $existingRecent->created_at?->toIso8601String(),
                ],
            ], 200);
        }

        // Buat Kode Tiket Resmi Phonebook (e.g. PB-2026-0001)
        $ticketCode = BugReport::generateTicketCode();

        // Status awal tiket
        $initialStatus = 'MENUNGGU PERSETUJUAN';

        // Simpan terlebih dahulu ke PostgreSQL Supabase
        $bugReport = BugReport::create([
            'ticket_code' => $ticketCode,
            'ticket_number' => $ticketCode,
            'user_id' => $user ? $user->id : null,
            'reporter_name' => $userName,
            'reporter_email' => $userEmail !== '-' ? $userEmail : null,
            'reporter_phone' => $userPhone,
            'whatsapp' => $userPhone,
            'category' => $category,
            'priority' => $priority,
            'title' => $title,
            'description' => $description,
            'app_version' => $appVersion,
            'device_info' => $deviceInfo,
            'discord_sent' => false,
            'status' => $initialStatus,
        ]);

        Log::info("BugReport [DATABASE]: Tiket baru tersimpan di PostgreSQL Supabase dengan ID={$bugReport->id}, Kode={$bugReport->ticket_code}");

        // Kirim ke Discord dengan Embed lengkap & Komponen Tombol ACC/TOLAK/SELESAI
        $discordRes = DiscordTicketService::sendTicketToDiscord($bugReport);

        Log::info("BugReport [RESULT]: Hasil pengiriman ke Discord: " . ($discordRes['success'] ? 'SUKSES' : 'GAGAL'), [
            'method' => $discordRes['method'] ?? 'none',
            'error' => $discordRes['error'] ?? null,
        ]);

        return response()->json([
            'success' => true,
            'message' => $discordRes['success']
                ? 'Laporan masalah berhasil dikirim dan didaftarkan ke saluran Discord developer.'
                : 'Laporan masalah berhasil disimpan ke sistem Phonebook (antrean pengiriman Discord aktif).',
            'data' => [
                'id' => $bugReport->id,
                'ticket_code' => $bugReport->ticket_code,
                'title' => $bugReport->title,
                'category' => $bugReport->category,
                'status' => $bugReport->status,
                'reporter_name' => $bugReport->reporter_name,
                'reporter_phone' => $bugReport->reporter_phone,
                'discord_sent' => $bugReport->discord_sent,
                'discord_error' => $bugReport->discord_error,
                'created_at' => $bugReport->created_at?->toIso8601String(),
            ],
        ], 201);
    }

    /**
     * Endpoint untuk mencoba ulang (retry) pengiriman tiket ke Discord tanpa membuat record duplikat.
     */
    public function retryDiscord(Request $request, $id)
    {
        $ticket = DiscordInteractionController::findTicket($id);
        if (!$ticket) {
            return response()->json([
                'success' => false,
                'message' => "Tiket #{$id} tidak ditemukan.",
            ], 404);
        }

        if ($ticket->discord_sent && !empty($ticket->discord_message_id)) {
            return response()->json([
                'success' => true,
                'message' => "Tiket #{$ticket->ticket_code} sudah berhasil terkirim ke Discord sebelumnya.",
                'data' => [
                    'ticket_code' => $ticket->ticket_code,
                    'discord_sent' => true,
                    'discord_message_id' => $ticket->discord_message_id,
                ],
            ]);
        }

        Log::info("BugReport [MANUAL_RETRY]: Meminta pengiriman ulang tiket #{$ticket->ticket_code} ke Discord...");
        $discordRes = DiscordTicketService::sendTicketToDiscord($ticket);

        return response()->json([
            'success' => $discordRes['success'],
            'message' => $discordRes['success']
                ? "Tiket #{$ticket->ticket_code} berhasil diteruskan ke Discord developer."
                : "Pengiriman ulang gagal: " . ($discordRes['error'] ?? 'Koneksi error'),
            'data' => [
                'ticket_code' => $ticket->ticket_code,
                'discord_sent' => $ticket->discord_sent,
                'discord_message_id' => $ticket->discord_message_id,
                'discord_error' => $ticket->discord_error,
            ],
        ], $discordRes['success'] ? 200 : 502);
    }

    /**
     * Melihat riwayat laporan kendala (untuk pengguna terautentikasi / admin).
     */
    public function index(Request $request)
    {
        $user = $request->user() ?: auth('sanctum')->user();

        $query = BugReport::query()->latest();

        // Jika bukan admin, filter laporan milik dirinya sendiri berdasarkan user_id atau email/phone
        if (!$user || $user->role !== 'admin') {
            $query->where(function ($q) use ($user, $request) {
                if ($user) {
                    $q->where('user_id', $user->id)
                      ->orWhere('reporter_email', $user->email);
                    if (!empty($user->whatsapp_number)) {
                        $q->orWhere('reporter_phone', $user->whatsapp_number)
                          ->orWhere('whatsapp', $user->whatsapp_number);
                    }
                } else {
                    // Jika diakses tanpa auth tapi mengirim email atau phone via query param
                    $email = $request->query('email');
                    $phone = $request->query('phone');
                    if (!empty($email) || !empty($phone)) {
                        if (!empty($email)) {
                            $q->where('reporter_email', $email);
                        }
                        if (!empty($phone)) {
                            $cleanPhone = preg_replace('/[^0-9]/', '', $phone);
                            $q->orWhere('reporter_phone', $phone)
                              ->orWhere('whatsapp', $phone)
                              ->orWhere('reporter_phone', $cleanPhone)
                              ->orWhere('whatsapp', $cleanPhone);
                        }
                    } else {
                        // Tolak jika tidak ada pengenal pengguna sama sekali
                        $q->whereRaw('1 = 0');
                    }
                }
            });
        }

        $perPage = min((int) ($request->query('per_page', 30)), 100);
        $reports = $query->paginate($perPage);

        return response()->json([
            'success' => true,
            'data' => $reports,
        ]);
    }

    /**
     * Detail satu tiket laporan masalah.
     */
    public function show(Request $request, $id)
    {
        $ticket = DiscordInteractionController::findTicket($id);
        if (!$ticket) {
            return response()->json([
                'success' => false,
                'message' => 'Tiket tidak ditemukan',
            ], 404);
        }

        return response()->json([
            'success' => true,
            'data' => $ticket,
        ]);
    }
}
