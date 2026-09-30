<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Schedule;
use Illuminate\Http\Request;

class ScheduleController extends Controller
{
    public function index()
    {
        $schedules = Schedule::with('user')
            ->orderBy('date')
            ->orderBy('start_time')
            ->get();

        return response()->json([
            'success' => true,
            'message' => 'Data jadwal berhasil diambil',
            'data' => $schedules,
        ]);
    }

    public function show($id)
    {
        $schedule = Schedule::with('user')->find($id);

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
            'user_id' => 'required|exists:users,id',
            'title' => 'required|string|max:255',
            'date' => 'required|date',
            'start_time' => 'nullable|date_format:H:i',
            'end_time' => 'nullable|date_format:H:i',
            'location' => 'nullable|string|max:255',
            'description' => 'nullable|string',
            'reminder_enabled' => 'nullable|boolean',
            'reminder_at' => 'nullable|date',
        ]);

        $schedule = Schedule::create([
            'user_id' => $validated['user_id'],
            'title' => $validated['title'],
            'date' => $validated['date'],
            'start_time' => $validated['start_time'] ?? null,
            'end_time' => $validated['end_time'] ?? null,
            'location' => $validated['location'] ?? null,
            'description' => $validated['description'] ?? null,
            'reminder_enabled' => $validated['reminder_enabled'] ?? true,
            'reminder_at' => $validated['reminder_at'] ?? null,
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
        $schedule = Schedule::find($id);

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
            'reminder_at' => 'nullable|date',
        ]);

        $schedule->update([
            'title' => $validated['title'],
            'date' => $validated['date'],
            'start_time' => $validated['start_time'] ?? null,
            'end_time' => $validated['end_time'] ?? null,
            'location' => $validated['location'] ?? null,
            'description' => $validated['description'] ?? null,
            'reminder_enabled' => $validated['reminder_enabled'] ?? true,
            'reminder_at' => $validated['reminder_at'] ?? null,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Jadwal berhasil diperbarui',
            'data' => $schedule,
        ]);
    }

    public function destroy($id)
    {
        $schedule = Schedule::find($id);

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