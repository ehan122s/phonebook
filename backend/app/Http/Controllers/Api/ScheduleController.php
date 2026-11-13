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
            'is_completed' => 'nullable|boolean',
        ]);

        $reminderEnabled = $validated['reminder_enabled'] ?? true;
        $reminderMinutes = (int) ($validated['reminder_minutes'] ?? 30);
        $dateOnly = Carbon::parse($validated['date'], self::TIMEZONE)->format('Y-m-d');
        $startTime = $validated['start_time'] ?? null;

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

        $updateData = [
            'title' => $title,
            'date' => $dateOnly,
            'start_time' => $startTime,
            'end_time' => array_key_exists('end_time', $validated) ? $validated['end_time'] : $schedule->end_time,
            'location' => array_key_exists('location', $validated) ? $validated['location'] : $schedule->location,
            'description' => array_key_exists('description', $validated) ? $validated['description'] : $schedule->description,
            'reminder_enabled' => $reminderEnabled,
            'reminder_at' => $this->calculateReminderAt($dateOnly, $startTime, $reminderEnabled, $reminderMinutes),
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
}
