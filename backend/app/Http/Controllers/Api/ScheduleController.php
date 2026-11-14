<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AppNotification;
use App\Models\Schedule;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Schema;

class ScheduleController extends Controller
{
    private const TIMEZONE = 'Asia/Jakarta';

    /**
     * Normalisasi string waktu ke format HH:mm
     */
    private function normalizeTime(?string $raw): ?string
    {
        if ($raw === null || trim($raw) === '') {
            return null;
        }

        $clean = trim($raw);
        if (str_contains($clean, '-')) {
            $clean = trim(explode('-', $clean)[0]);
        }
        $clean = str_replace('.', ':', $clean);

        if (preg_match('/^(\d{1,2}):(\d{2})(?::\d{2})?$/', $clean, $matches)) {
            $h = (int) $matches[1];
            $m = (int) $matches[2];
            if ($h >= 0 && $h < 24 && $m >= 0 && $m < 60) {
                return str_pad((string) $h, 2, '0', STR_PAD_LEFT) . ':' . str_pad((string) $m, 2, '0', STR_PAD_LEFT);
            }
        }

        return null;
    }

    /**
     * Hitung waktu reminder_at akurat berdasarkan tanggal + jam jadwal - reminder_minutes
     * dalam zona waktu Asia/Jakarta.
     */
    private function calculateReminderAt(string $date, ?string $startTime, bool $reminderEnabled, int $reminderMinutes): ?Carbon
    {
        if (!$reminderEnabled) {
            return null;
        }

        $timeStr = $this->normalizeTime($startTime) ?? '08:00';
        $scheduleDateTime = Carbon::createFromFormat(
            'Y-m-d H:i',
            "{$date} {$timeStr}",
            self::TIMEZONE
        );

        return $scheduleDateTime->copy()->subMinutes($reminderMinutes);
    }

    public function index(Request $request)
    {
        $schedules = Schedule::with('user')
            ->where('user_id', $request->user()->id)
            ->orderByDesc('date')
            ->orderBy('start_time')
            ->get();

        return response()->json([
            'success' => true,
            'message' => 'Data jadwal berhasil diambil',
            'data' => $schedules,
        ]);
    }

    public function show(Request $request, $id)
    {
        $schedule = Schedule::with('user')
            ->where('user_id', $request->user()->id)
            ->find($id);

        if (!$schedule) {
            return response()->json([
                'success' => false,
                'message' => 'Jadwal tidak ditemukan',
            ], 404);
        }

        return response()->json([
            'success' => true,
            'data' => $schedule,
        ]);
    }

    public function store(Request $request)
    {
        if ($request->has('start_time')) {
            $request->merge([
                'start_time' => $this->normalizeTime($request->input('start_time')),
            ]);
        }
        if ($request->has('end_time')) {
            $request->merge([
                'end_time' => $this->normalizeTime($request->input('end_time')),
            ]);
        }

        $validated = $request->validate([
            'title' => 'required|string|max:255',
            'category' => 'nullable|string|max:100',
            'date' => 'required|date',
            'start_time' => 'nullable|date_format:H:i',
            'end_time' => 'nullable|date_format:H:i',
            'location' => 'nullable|string|max:255',
            'description' => 'nullable|string',
            'reminder_enabled' => 'nullable|boolean',
            'reminder_minutes' => 'nullable|integer|min:1|max:10080',
            'enable_wa_notification' => 'nullable|boolean',
            'wa_phone' => 'nullable|string|max:25',
            'is_completed' => 'nullable|boolean',
        ]);

        $reminderEnabled = $validated['reminder_enabled'] ?? true;
        $reminderMinutes = (int) ($validated['reminder_minutes'] ?? 30);
        $dateOnly = Carbon::parse($validated['date'], self::TIMEZONE)->format('Y-m-d');
        $startTime = $validated['start_time'] ?? null;
        $enableWaNotification = (bool) ($validated['enable_wa_notification'] ?? false);
        $waPhone = $validated['wa_phone'] ?? null;

        $data = [
            'user_id' => $request->user()->id,
            'title' => $validated['title'],
            'date' => $dateOnly,
            'start_time' => $startTime,
            'end_time' => $validated['end_time'] ?? null,
            'location' => $validated['location'] ?? null,
            'description' => $validated['description'] ?? null,
            'reminder_enabled' => $reminderEnabled,
            'reminder_at' => $this->calculateReminderAt($dateOnly, $startTime, $reminderEnabled, $reminderMinutes),
            'enable_wa_notification' => $enableWaNotification,
            'wa_phone' => $waPhone,
            'whatsapp_sent' => false,
        ];

        if (Schema::hasColumn('schedules', 'category')) {
            $data['category'] = $validated['category'] ?? 'Penyuluhan';
        }
        if (Schema::hasColumn('schedules', 'reminder_minutes')) {
            $data['reminder_minutes'] = $reminderMinutes;
        }
        if (Schema::hasColumn('schedules', 'is_completed')) {
            $data['is_completed'] = $validated['is_completed'] ?? false;
        }

        $schedule = Schedule::create($data);

        // Pastikan atribut dikembalikan pada response JSON meskipun tabel belum dimigrasi penuh
        $schedule->setAttribute('reminder_minutes', $reminderMinutes);
        $schedule->setAttribute('category', $validated['category'] ?? 'Penyuluhan');

        // Catat notifikasi jadwal baru jika tabel app_notifications tersedia
        try {
            if (Schema::hasTable('app_notifications')) {
                $jamLabel = $startTime ? "{$startTime} WIB" : 'Waktu belum ditentukan';
                AppNotification::create([
                    'user_id' => $request->user()->id,
                    'type' => 'jadwal',
                    'title' => 'Jadwal Baru Ditambahkan',
                    'message' => "Jadwal \"{$schedule->title}\" dijadwalkan pada {$dateOnly} pukul {$jamLabel} (Pengingat {$reminderMinutes} menit sebelumnya).",
                    'reference_id' => 'schedule_' . $schedule->id,
                    'metadata' => [
                        'schedule_id' => $schedule->id,
                        'date' => $dateOnly,
                        'start_time' => $startTime,
                        'reminder_minutes' => $reminderMinutes,
                        'location' => $schedule->location,
                    ],
                    'is_read' => false,
                ]);
            }
        } catch (\Throwable $e) {
            // Jangan menggagalkan pembuatan jadwal jika pencatatan notifikasi gagal
        }

        return response()->json([
            'success' => true,
            'message' => 'Jadwal berhasil dibuat',
            'data' => $schedule,
        ], 201);
    }

    public function update(Request $request, $id)
    {
        $schedule = Schedule::where('user_id', $request->user()->id)
            ->find($id);

        if (!$schedule) {
            return response()->json([
                'success' => false,
                'message' => 'Jadwal tidak ditemukan',
            ], 404);
        }

        if ($request->has('start_time')) {
            $request->merge([
                'start_time' => $this->normalizeTime($request->input('start_time')),
            ]);
        }
        if ($request->has('end_time')) {
            $request->merge([
                'end_time' => $this->normalizeTime($request->input('end_time')),
            ]);
        }

        $validated = $request->validate([
            'title' => 'sometimes|required|string|max:255',
            'category' => 'nullable|string|max:100',
            'date' => 'sometimes|required|date',
            'start_time' => 'nullable|date_format:H:i',
            'end_time' => 'nullable|date_format:H:i',
            'location' => 'nullable|string|max:255',
            'description' => 'nullable|string',
            'reminder_enabled' => 'nullable|boolean',
            'reminder_minutes' => 'nullable|integer|min:1|max:10080',
            'enable_wa_notification' => 'nullable|boolean',
            'wa_phone' => 'nullable|string|max:25',
            'is_completed' => 'nullable|boolean',
        ]);

        $title = $validated['title'] ?? $schedule->title;
        $dateOnly = isset($validated['date'])
            ? Carbon::parse($validated['date'], self::TIMEZONE)->format('Y-m-d')
            : Carbon::parse($schedule->date, self::TIMEZONE)->format('Y-m-d');
        $startTime = array_key_exists('start_time', $validated)
            ? $validated['start_time']
            : $schedule->start_time;
        $reminderEnabled = $validated['reminder_enabled'] ?? $schedule->reminder_enabled ?? true;
        $reminderMinutes = (int) ($validated['reminder_minutes'] ?? $schedule->reminder_minutes ?? 30);
        $enableWaNotification = array_key_exists('enable_wa_notification', $validated)
            ? (bool) $validated['enable_wa_notification']
            : ($schedule->enable_wa_notification ?? false);
        $waPhone = array_key_exists('wa_phone', $validated)
            ? $validated['wa_phone']
            : $schedule->wa_phone;

        $updateData = [
            'title' => $title,
            'date' => $dateOnly,
            'start_time' => $startTime,
            'end_time' => array_key_exists('end_time', $validated) ? $validated['end_time'] : $schedule->end_time,
            'location' => array_key_exists('location', $validated) ? $validated['location'] : $schedule->location,
            'description' => array_key_exists('description', $validated) ? $validated['description'] : $schedule->description,
            'reminder_enabled' => $reminderEnabled,
            'reminder_at' => $this->calculateReminderAt($dateOnly, $startTime, $reminderEnabled, $reminderMinutes),
            'enable_wa_notification' => $enableWaNotification,
            'wa_phone' => $waPhone,
            'whatsapp_sent' => false,
        ];

        if (Schema::hasColumn('schedules', 'category') && isset($validated['category'])) {
            $updateData['category'] = $validated['category'];
        }
        if (Schema::hasColumn('schedules', 'reminder_minutes')) {
            $updateData['reminder_minutes'] = $reminderMinutes;
        }
        if (Schema::hasColumn('schedules', 'is_completed') && isset($validated['is_completed'])) {
            $updateData['is_completed'] = $validated['is_completed'];
        }

        $schedule->update($updateData);
        $schedule->setAttribute('reminder_minutes', $reminderMinutes);

        return response()->json([
            'success' => true,
            'message' => 'Jadwal berhasil diperbarui',
            'data' => $schedule,
        ]);
    }

    public function destroy(Request $request, $id)
    {
        $schedule = Schedule::where('user_id', $request->user()->id)
            ->find($id);

        if (!$schedule) {
            return response()->json([
                'success' => false,
                'message' => 'Jadwal tidak ditemukan',
            ], 404);
        }

        $schedule->delete();

        return response()->json([
            'success' => true,
            'message' => 'Jadwal berhasil dihapus',
        ]);
    }

    /**
     * Kirim pengingat WhatsApp untuk jadwal tertentu.
     * Menggunakan gateway Fonnte (jika online) dan mengembalikan fallback wa_url
     * sehingga aplikasi mobile dapat membuka WhatsApp langsung tanpa gagal.
     */
    public function sendWhatsapp(Request $request, $id)
    {
        $schedule = Schedule::where('user_id', $request->user()->id)->find($id);

        if (!$schedule) {
            return response()->json([
                'success' => false,
                'message' => 'Jadwal tidak ditemukan',
            ], 404);
        }

        $targetPhone = $request->input('target_phone')
            ?: $schedule->wa_phone
            ?: $request->user()->whatsapp_number
            ?: $request->user()->phone
            ?: $request->user()->no_hp;

        if (empty($targetPhone)) {
            return response()->json([
                'success' => false,
                'message' => 'Nomor WhatsApp belum ditentukan. Silakan isi nomor WhatsApp penerima.',
            ], 422);
        }

        $title = $schedule->title;
        $category = $schedule->category ?? 'Kegiatan Dinas Kehutanan';
        $date = Carbon::parse($schedule->date)->translatedFormat('l, d F Y');
        $time = $schedule->start_time ?: '08:00';
        $location = $schedule->location ?: 'Sesuai agenda lapangan';
        $reminderMinutes = (int) ($schedule->reminder_minutes ?? 30);
        $notes = $schedule->description;

        $message = \App\Services\WhatsappService::formatReminderMessage(
            $title,
            $category,
            $date,
            $time,
            $location,
            $reminderMinutes,
            $notes
        );

        $result = \App\Services\WhatsappService::sendReminder($targetPhone, $message);

        if (!empty($result['success'])) {
            $schedule->update(['whatsapp_sent' => true]);
        }

        return response()->json([
            'success' => true,
            'server_delivered' => !empty($result['success']),
            'message' => !empty($result['success'])
                ? 'Pengingat WhatsApp berhasil dikirim dari server!'
                : 'Pengingat WhatsApp siap dikirim langsung melalui aplikasi WhatsApp.',
            'gateway_result' => $result,
            'target_phone' => $result['target'] ?? $targetPhone,
            'wa_url' => $result['wa_url'] ?? null,
            'message_text' => $message,
        ]);
    }

    /**
     * Pengiriman langsung pengingat WhatsApp (tes atau manual).
     */
    public function directSend(Request $request)
    {
        $validated = $request->validate([
            'target_phone' => 'required|string',
            'message' => 'nullable|string',
            'title' => 'nullable|string',
            'date' => 'nullable|string',
            'time' => 'nullable|string',
            'location' => 'nullable|string',
        ]);

        $message = $validated['message'] ?? null;
        if (empty($message)) {
            $title = $validated['title'] ?? 'Kegiatan Dinas CDK Wilayah V';
            $category = $request->input('category', 'Kegiatan Dinas Kehutanan');
            $date = $validated['date'] ?? Carbon::now()->translatedFormat('l, d F Y');
            $time = $validated['time'] ?? '08:00';
            $location = $validated['location'] ?? 'Wilayah Kerja CDK Wilayah V';
            $reminderMinutes = (int) $request->input('reminder_minutes', 30);
            $notes = $request->input('notes', null);

            $message = \App\Services\WhatsappService::formatReminderMessage(
                $title,
                $category,
                $date,
                $time,
                $location,
                $reminderMinutes,
                $notes
            );
        }

        $result = \App\Services\WhatsappService::sendReminder($validated['target_phone'], $message);

        return response()->json([
            'success' => true,
            'server_delivered' => !empty($result['success']),
            'message' => !empty($result['success'])
                ? 'Pesan WhatsApp berhasil dikirim dari server!'
                : 'Pesan WhatsApp siap dikirim langsung via WhatsApp.',
            'gateway_result' => $result,
            'target_phone' => $result['target'],
            'wa_url' => $result['wa_url'],
            'message_text' => $message,
        ]);
    }
}
