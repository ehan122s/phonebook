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
        // Pastikan laporan milik user yang sedang login atau akun admin
        $user = $request->user();
        $query = Report::query();
        if ($user && $user->role !== 'admin') {
            $query->where('user_id', $user->id);
        }
        $report = $query->find($reportId);

        if (!$report) {
            return response()->json([
                'success' => false,
                'message' => 'Laporan tidak ditemukan',
            ], 404);
        }

        $validated = $request->validate([
            'photo' => 'required|file|mimes:jpg,jpeg,png,webp,gif|max:10240',
            'latitude' => 'nullable|numeric',
            'longitude' => 'nullable|numeric',
        ]);

        $photo = $request->file('photo');

        // Pastikan direktori 'reports' tersedia di storage public
        try {
            if (!Storage::disk('public')->exists('reports')) {
                Storage::disk('public')->makeDirectory('reports');
            }
        } catch (\Throwable $e) {}

        $path = $photo->store('reports', 'public');
        $photoBytes = file_get_contents($photo->getRealPath());
        $base64 = base64_encode($photoBytes);

        $reportPhoto = ReportPhoto::create([
            'report_id' => $report->id,
            'photo' => $path,
            'photo_base64' => $base64,
            'latitude' => $validated['latitude'] ?? null,
            'longitude' => $validated['longitude'] ?? null,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Foto laporan berhasil diupload',
            'data' => $reportPhoto,
        ], 201);
    }

    /**
     * Menyajikan berkas foto laporan secara langsung ke frontend / preview.
     */
    public function file($id)
    {
        $photo = ReportPhoto::find($id);

        if (!$photo) {
            return response()->json([
                'success' => false,
                'message' => 'Foto tidak ditemukan',
            ], 404);
        }

        // 1. Coba dari penyimpanan fisik storage public
        if ($photo->photo && Storage::disk('public')->exists($photo->photo)) {
            $file = Storage::disk('public')->get($photo->photo);
            $mime = Storage::disk('public')->mimeType($photo->photo) ?: 'image/jpeg';
            return response($file, 200, [
                'Content-Type' => $mime,
                'Cache-Control' => 'public, max-age=86400',
            ]);
        }

        // 2. Fallback dari cadangan biner Base64 di database (aman untuk serverless / multi-instance)
        if (!empty($photo->photo_base64)) {
            $binary = base64_decode($photo->photo_base64);
            $ext = strtolower(pathinfo($photo->photo, PATHINFO_EXTENSION));
            $mime = match ($ext) {
                'png' => 'image/png',
                'webp' => 'image/webp',
                'gif' => 'image/gif',
                default => 'image/jpeg',
            };
            return response($binary, 200, [
                'Content-Type' => $mime,
                'Cache-Control' => 'public, max-age=86400',
            ]);
        }

        return response()->json([
            'success' => false,
            'message' => 'File fisik foto belum tersedia',
        ], 404);
    }

    public function destroy(Request $request, $id)
    {
        $photo = ReportPhoto::with('report')->find($id);
        $user = $request->user();

        if (!$photo || ($user->role !== 'admin' && $photo->report->user_id !== $user->id)) {
            return response()->json([
                'success' => false,
                'message' => 'Foto tidak ditemukan',
            ], 404);
        }

        if ($photo->photo && Storage::disk('public')->exists($photo->photo)) {
            Storage::disk('public')->delete($photo->photo);
        }

        $photo->delete();

        return response()->json([
            'success' => true,
            'message' => 'Foto laporan berhasil dihapus',
        ]);
    }
}