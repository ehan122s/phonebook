<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Report;
use App\Models\ReportPhoto;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Schema;
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
            'photo' => 'nullable|file|mimes:jpg,jpeg,png,webp,gif|max:10240',
            'photo_base64' => 'nullable|string',
            'latitude' => 'nullable|numeric',
            'longitude' => 'nullable|numeric',
            'address' => 'nullable|string|max:500',
        ]);

        if (!$request->hasFile('photo') && empty($validated['photo_base64'])) {
            return response()->json([
                'success' => false,
                'message' => 'Berkas foto atau data foto wajib disertakan',
            ], 422);
        }

        $path = 'reports/photo_' . $report->id . '_' . time() . '.jpg';
        $base64 = null;

        if ($request->hasFile('photo')) {
            $photo = $request->file('photo');
            try {
                $realPath = $photo->getRealPath();
                if ($realPath && file_exists($realPath)) {
                    $photoBytes = file_get_contents($realPath);
                    if ($photoBytes !== false) {
                        $base64 = base64_encode($photoBytes);
                    }
                }
            } catch (\Throwable $e) {}

            // Coba simpan ke disk public; jika di serverless read-only, tetap lanjutkan dengan photo_base64
            try {
                if (!Storage::disk('public')->exists('reports')) {
                    Storage::disk('public')->makeDirectory('reports');
                }
                $storedPath = $photo->store('reports', 'public');
                if ($storedPath) {
                    $path = $storedPath;
                }
            } catch (\Throwable $e) {
                $ext = strtolower($photo->getClientOriginalExtension() ?: 'jpg');
                $path = 'reports/photo_' . $report->id . '_' . time() . '.' . $ext;
            }
        }

        if (empty($base64) && !empty($validated['photo_base64'])) {
            $rawB64 = trim($validated['photo_base64']);
            if (str_contains($rawB64, ',')) {
                $rawB64 = substr($rawB64, strpos($rawB64, ',') + 1);
            }
            $base64 = $rawB64;
        }

        $photoData = [
            'report_id' => $report->id,
            'photo' => $path,
            'latitude' => $validated['latitude'] ?? $report->latitude,
            'longitude' => $validated['longitude'] ?? $report->longitude,
        ];

        try {
            if (Schema::hasColumn('report_photos', 'photo_base64')) {
                $photoData['photo_base64'] = $base64;
            }
            if (Schema::hasColumn('report_photos', 'address')) {
                $photoData['address'] = $validated['address'] ?? $report->location;
            }
        } catch (\Throwable $e) {
            $photoData['photo_base64'] = $base64;
        }

        $reportPhoto = ReportPhoto::create($photoData);

        // Sinkronkan juga koordinat pada laporan induk apabila laporan belum memiliki koordinat
        if (($report->latitude === null || $report->longitude === null) &&
            (!empty($validated['latitude']) && !empty($validated['longitude']))) {
            $report->update([
                'latitude' => $validated['latitude'],
                'longitude' => $validated['longitude'],
            ]);
        }

        return response()->json([
            'success' => true,
            'message' => 'Foto laporan dan titik geolokasi berhasil diupload',
            'data' => $reportPhoto,
        ], 201);
    }

    /**
     * Menyajikan berkas foto laporan secara langsung ke frontend / preview.
     * Mendukung rute /report-photos/{id}/file maupun /reports/{reportId}/photos/{photoId}/file.
     */
    public function file($id, $photoId = null)
    {
        $targetPhotoId = $photoId ?? $id;
        $photo = ReportPhoto::find($targetPhotoId);

        if (!$photo && $photoId !== null) {
            $photo = ReportPhoto::where('report_id', $id)->first();
        }

        if (!$photo) {
            return response()->json([
                'success' => false,
                'message' => 'Foto tidak ditemukan',
            ], 404);
        }

        // 1. Coba dari penyimpanan fisik storage public
        try {
            if ($photo->photo && Storage::disk('public')->exists($photo->photo)) {
                $file = Storage::disk('public')->get($photo->photo);
                $mime = Storage::disk('public')->mimeType($photo->photo) ?: 'image/jpeg';
                return response($file, 200, [
                    'Content-Type' => $mime,
                    'Cache-Control' => 'public, max-age=86400',
                    'Access-Control-Allow-Origin' => '*',
                ]);
            }
        } catch (\Throwable $e) {}

        // 2. Fallback dari cadangan biner Base64 di database (aman untuk serverless / multi-instance)
        if (!empty($photo->photo_base64)) {
            $rawB64 = $photo->photo_base64;
            if (str_contains($rawB64, ',')) {
                $rawB64 = substr($rawB64, strpos($rawB64, ',') + 1);
            }
            $binary = base64_decode($rawB64);
            $ext = strtolower(pathinfo((string) $photo->photo, PATHINFO_EXTENSION));
            $mime = match ($ext) {
                'png' => 'image/png',
                'webp' => 'image/webp',
                'gif' => 'image/gif',
                default => 'image/jpeg',
            };
            return response($binary, 200, [
                'Content-Type' => $mime,
                'Cache-Control' => 'public, max-age=86400',
                'Access-Control-Allow-Origin' => '*',
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

        try {
            if ($photo->photo && Storage::disk('public')->exists($photo->photo)) {
                Storage::disk('public')->delete($photo->photo);
            }
        } catch (\Throwable $e) {}

        $photo->delete();

        return response()->json([
            'success' => true,
            'message' => 'Foto laporan berhasil dihapus',
        ]);
    }
}