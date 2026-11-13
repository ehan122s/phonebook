<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AppNotification;
use App\Models\Report;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Schema;

class ReportController extends Controller
{
    public function index(Request $request)
    {
        $reports = Report::with(['user', 'category', 'photos'])
            ->where('user_id', $request->user()->id)
            ->latest()
            ->get();

        return response()->json([
            'success' => true,
            'message' => 'Data laporan berhasil diambil',
            'data' => $reports,
        ]);
    }

    public function show(Request $request, $id)
    {
        $report = Report::with(['user', 'category', 'photos'])
            ->where('user_id', $request->user()->id)
            ->find($id);

        if (!$report) {
            return response()->json([
                'success' => false,
                'message' => 'Laporan tidak ditemukan',
            ], 404);
        }

        return response()->json([
            'success' => true,
            'data' => $report,
        ]);
    }

    public function store(Request $request)
    {
        $validated = $request->validate([
            'category_id' => 'nullable|exists:categories,id',
            'title' => 'required|string|max:255',
            'activity_date' => 'required|date',
            'location' => 'required|string|max:255',
            'latitude' => 'nullable|numeric',
            'longitude' => 'nullable|numeric',
            'description' => 'nullable|string',
            'status' => 'nullable|in:draft,terkirim,diperiksa,disetujui,ditolak',
        ]);

        $report = Report::create([
            'user_id' => $request->user()->id,
            'category_id' => $validated['category_id'] ?? null,
            'title' => $validated['title'],
            'activity_date' => $validated['activity_date'],
            'location' => $validated['location'],
            'latitude' => $validated['latitude'] ?? null,
            'longitude' => $validated['longitude'] ?? null,
            'description' => $validated['description'] ?? null,
            'status' => $validated['status'] ?? 'draft',
        ]);

        // Catat notifikasi laporan baru ke tabel app_notifications (tanpa mengganggu alur utama)
        try {
            if (Schema::hasTable('app_notifications')) {
                $statusLabel = ($report->status === 'draft') ? 'Disimpan sebagai Draft' : 'Berhasil Dikirim';
                AppNotification::create([
                    'user_id' => $request->user()->id,
                    'type' => 'laporan',
                    'title' => 'Laporan Baru: ' . $report->title,
                    'message' => "Laporan kegiatan \"{$report->title}\" di {$report->location} ({$statusLabel}).",
                    'reference_id' => 'report_' . $report->id,
                    'metadata' => [
                        'report_id' => $report->id,
                        'activity_date' => $validated['activity_date'],
                        'location' => $report->location,
                        'status' => $report->status,
                    ],
                    'is_read' => false,
                ]);
            }
        } catch (\Throwable $e) {
            // Abaikan jika tabel belum tersedia
        }

        return response()->json([
            'success' => true,
            'message' => 'Laporan berhasil dibuat',
            'data' => $report,
        ], 201);
    }

    public function update(Request $request, $id)
    {
        $report = Report::where('user_id', $request->user()->id)
            ->find($id);

        if (!$report) {
            return response()->json([
                'success' => false,
                'message' => 'Laporan tidak ditemukan',
            ], 404);
        }

        $validated = $request->validate([
            'category_id' => 'nullable|exists:categories,id',
            'title' => 'required|string|max:255',
            'activity_date' => 'required|date',
            'location' => 'required|string|max:255',
            'latitude' => 'nullable|numeric',
            'longitude' => 'nullable|numeric',
            'description' => 'nullable|string',
            'status' => 'nullable|in:draft,terkirim,diperiksa,disetujui,ditolak',
        ]);

        $report->update([
            'category_id' => $validated['category_id'] ?? null,
            'title' => $validated['title'],
            'activity_date' => $validated['activity_date'],
            'location' => $validated['location'],
            'latitude' => $validated['latitude'] ?? null,
            'longitude' => $validated['longitude'] ?? null,
            'description' => $validated['description'] ?? null,
            'status' => $validated['status'] ?? $report->status,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Laporan berhasil diperbarui',
            'data' => $report,
        ]);
    }

    public function destroy(Request $request, $id)
    {
        $report = Report::where('user_id', $request->user()->id)
            ->find($id);

        if (!$report) {
            return response()->json([
                'success' => false,
                'message' => 'Laporan tidak ditemukan',
            ], 404);
        }

        $report->delete();

        return response()->json([
            'success' => true,
            'message' => 'Laporan berhasil dihapus',
        ]);
    }
}