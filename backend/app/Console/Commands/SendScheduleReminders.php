<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Schedule;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

class ScheduleController extends Controller
{
    public function index(Request $request)
    {
        $schedules = Schedule::with('user')
            ->where('user_id', $request->user()->id)
            ->orderBy('date')
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
        $validated = $request->validate([
            'title' => 'required|string|max:255',
            'date' => 'required|date',
            'start_time' => 'nullable|date_format:H:i',
            'end_time' => 'nullable|date_format:H:i',
            'location' => 'nullable|string|max:255',
            'description' => 'nullable|string',
            'reminder_enabled' => 'nullable|boolean',
        ]);

        $reminderEnabled = $validated['reminder_enabled'] ?? true;

        $schedule = Schedule::create([
            'user_id' => $request->user()->id,
            'title' => $validated['title'],
            'date' => $validated['date'],
            'start_time' => $validated['start_time'] ?? null,
            'end_time' => $validated['end_time'] ?? null,
            'location' => $validated['location'] ?? null,
            'description' => $validated['description'] ?? null,
            'reminder_enabled' => $reminderEnabled,

            // Otomatis reminder pukul 00:00 pada tanggal kegiatan
            'reminder_at' => $reminderEnabled
                ? Carbon::parse($validated['date'])->startOfDay()
                : null,

            'whatsapp_sent' => false,
        ]);

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

        $validated = $request->validate([
            'title' => 'required|string|max:255',
            'date' => 'required|date',
            'start_time' => 'nullable|date_format:H:i',
            'end_time' => 'nullable|date_format:H:i',
            'location' => 'nullable|string|max:255',
            'description' => 'nullable|string',
            'reminder_enabled' => 'nullable|boolean',
        ]);

        $reminderEnabled = $validated['reminder_enabled'] ?? true;

        $schedule->update([
            'title' => $validated['title'],
            'date' => $validated['date'],
            'start_time' => $validated['start_time'] ?? null,
            'end_time' => $validated['end_time'] ?? null,
            'location' => $validated['location'] ?? null,
            'description' => $validated['description'] ?? null,
            'reminder_enabled' => $reminderEnabled,

            // Reset reminder mengikuti tanggal baru
            'reminder_at' => $reminderEnabled
                ? Carbon::parse($validated['date'])->startOfDay()
                : null,

            // Jadwal berubah, maka reminder bisa dikirim kembali
            'whatsapp_sent' => false,
        ]);

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