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

        // Buat Kode Tiket Resmi Phonebook (e.g. PB-2026-0001)
        $ticketCode = BugReport::generateTicketCode();

        // Status awal tiket
        $initialStatus = 'MENUNGGU PERSETUJUAN';

        // Simpan terlebih dahulu ke database
        $bugReport = BugReport::create([
            'ticket_code' => $ticketCode,
            'user_id' => $user ? $user->id : null,
            'reporter_name' => $userName,
            'reporter_email' => $userEmail !== '-' ? $userEmail : null,
            'reporter_phone' => $userPhone,
            'category' => $category,
            'priority' => $priority,
            'title' => $title,
            'description' => $description,
            'app_version' => $appVersion,
            'device_info' => $deviceInfo,
            'discord_sent' => false,
            'status' => $initialStatus,
        ]);

        // Kirim ke Discord dengan Embed lengkap & Komponen Tombol ACC/TOLAK/SELESAI
        $discordRes = DiscordTicketService::sendTicketToDiscord($bugReport);

        return response()->json([
            'success' => true,
            'message' => $discordRes['success']
                ? 'Laporan masalah berhasil dikirim dan didaftarkan ke sistem tiket Tim IT Discord.'
                : 'Laporan masalah berhasil disimpan ke sistem Phonebook.',
            'data' => [
                'id' => $bugReport->id,
                'ticket_code' => $bugReport->ticket_code,
                'title' => $bugReport->title,
                'category' => $bugReport->category,
                'status' => $bugReport->status,
                'reporter_name' => $bugReport->reporter_name,
                'reporter_phone' => $bugReport->reporter_phone,
                'discord_sent' => $bugReport->discord_sent,
                'created_at' => $bugReport->created_at?->toIso8601String(),
            ],
        ], 201);
    }

    /**
     * Melihat riwayat laporan kendala (untuk pengguna terautentikasi / admin).
     */
    public function index(Request $request)
    {
        $user = $request->user() ?: auth('sanctum')->user();

        $query = BugReport::query()->latest();

        // Jika bukan admin, filter laporan milik dirinya sendiri berdasarkan user_id atau email
        if (!$user || $user->role !== 'admin') {
            $query->where(function ($q) use ($user, $request) {
                if ($user) {
                    $q->where('user_id', $user->id)
                      ->orWhere('reporter_email', $user->email);
                    if (!empty($user->whatsapp_number)) {
                        $q->orWhere('reporter_phone', $user->whatsapp_number);
                    }
                } else {
                    // Jika diakses tanpa auth tapi mengirim email atau phone via query param
                    $email = $request->query('email');
                    $phone = $request->query('phone');
                    if (!empty($email) || !empty($phone)) {
                        if (!empty($email)) $q->where('reporter_email', $email);
                        if (!empty($phone)) $q->orWhere('reporter_phone', $phone);
                    } else {
                        $q->whereRaw('1 = 0');
                    }
                }
            });
        }

        $reports = $query->paginate(30);

        return response()->json([
            'success' => true,
            'data' => $reports,
        ]);
    }
}
