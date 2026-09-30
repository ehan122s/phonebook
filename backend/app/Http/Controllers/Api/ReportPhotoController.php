<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Report;
use App\Models\ReportPhoto;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class ReportPhotoController extends Controller
{
    public function store(Request $request, $reportId)
    {
        // Pastikan laporan milik user yang sedang login
        $report = Report::where('user_id', $request->user()->id)
            ->find($reportId);

        if (!$report) {
            return response()->json([
                'success' => false,
                'message' => 'Laporan tidak ditemukan',
            ], 404);
        }

        $validated = $request->validate([
            'photo' => 'required|image|mimes:jpg,jpeg,png,webp|max:10240',
            'latitude' => 'nullable|numeric',
            'longitude' => 'nullable|numeric',
        ]);

        $photo = $request->file('photo');

        $path = $photo->store('reports', 'public');

        $reportPhoto = ReportPhoto::create([
            'report_id' => $report->id,
            'photo' => $path,
            'latitude' => $validated['latitude'] ?? null,
            'longitude' => $validated['longitude'] ?? null,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Foto laporan berhasil diupload',
            'data' => $reportPhoto,
        ], 201);
    }

    public function destroy(Request $request, $id)
    {
        $photo = ReportPhoto::with('report')->find($id);

        if (!$photo || $photo->report->user_id !== $request->user()->id) {
            return response()->json([
                'success' => false,
                'message' => 'Foto tidak ditemukan',
            ], 404);
        }

        if ($photo->photo) {
            Storage::disk('public')->delete($photo->photo);
        }

        $photo->delete();

        return response()->json([
            'success' => true,
            'message' => 'Foto laporan berhasil dihapus',
        ]);
    }
}