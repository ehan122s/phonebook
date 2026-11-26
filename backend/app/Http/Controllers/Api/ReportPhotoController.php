<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Report;
use App\Models\ReportPhoto;
use App\Services\ReportPhotoService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\ValidationException;

class ReportPhotoController extends Controller
{
    public function __construct(
        private readonly ReportPhotoService $photoService
    ) {}

    public function store(Request $request, $reportId)
    {
        $user = $request->user();
        $query = Report::query();
        if ($user && strtolower((string) $user->role) !== 'admin') {
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

        try {
            $reportPhoto = $this->photoService->storeForReport(
                $report,
                $request->file('photo'),
                $validated['photo_base64'] ?? null,
                [
                    'latitude' => $validated['latitude'] ?? null,
                    'longitude' => $validated['longitude'] ?? null,
                    'address' => $validated['address'] ?? null,
                ]
            );
        } catch (ValidationException $e) {
            throw $e;
        } catch (\Throwable $e) {
            return response()->json([
                'success' => false,
                'message' => $e->getMessage() ?: 'Gagal mengunggah foto laporan.',
            ], 502);
        }

        return response()->json([
            'success' => true,
            'message' => 'Foto laporan dan titik geolokasi berhasil diupload',
            'data' => $reportPhoto,
        ], 201);
    }

    /**
     * Menyajikan berkas foto laporan ke frontend / preview.
     * Foto ImageKit langsung diarahkan ke URL ImageKit; foto lama tetap dilayani via fallback.
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

        // 1. Jika tersimpan di ImageKit atau URL eksternal, redirect langsung
        if (!empty($photo->imagekit_url) && filter_var($photo->imagekit_url, FILTER_VALIDATE_URL)) {
            return redirect()->away($photo->imagekit_url);
        }
        if (!empty($photo->photo) && filter_var($photo->photo, FILTER_VALIDATE_URL)) {
            return redirect()->away($photo->photo);
        }

        // 2. Fallback foto lama dari penyimpanan lokal disk public
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
        } catch (\Throwable $e) {
            // Lanjutkan ke fallback base64
        }

        // 3. Fallback foto lama dari kolom photo_base64
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

        if (!$photo || !$user || (strtolower((string) $user->role) !== 'admin' && (!$photo->report || (int) $photo->report->user_id !== (int) $user->id))) {
            return response()->json([
                'success' => false,
                'message' => 'Foto tidak ditemukan',
            ], 404);
        }

        $this->photoService->deletePhoto($photo);

        return response()->json([
            'success' => true,
            'message' => 'Foto laporan berhasil dihapus',
        ]);
    }
}
