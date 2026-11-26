<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AppNotification;
use App\Models\Report;
use App\Models\ReportPhoto;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Schema;

class ReportController extends Controller
{
    private static ?bool $hasPhotoAddressColumn = null;
    private static ?bool $hasPhotoBase64Column = null;

    private function isAdmin($user): bool
    {
        return $user && strtolower((string) $user->role) === 'admin';
    }

    private function hasPhotoAddressColumn(): bool
    {
        if (self::$hasPhotoAddressColumn === null) {
            try {
                self::$hasPhotoAddressColumn = Cache::remember('schema_report_photos_address_v1', 3600, function () {
                    return Schema::connection('db_foto')
                        ->hasColumn('report_photos', 'address');
                });
            } catch (\Throwable $e) {
                self::$hasPhotoAddressColumn = false;
            }
        }
        return (bool) self::$hasPhotoAddressColumn;
    }

    private function hasPhotoBase64Column(): bool
    {
        if (self::$hasPhotoBase64Column === null) {
            try {
                self::$hasPhotoBase64Column = Cache::remember('schema_report_photos_base64_v1', 3600, function () {
                    return Schema::connection('db_foto')
                        ->hasColumn('report_photos', 'photo_base64');
                });
            } catch (\Throwable $e) {
                self::$hasPhotoBase64Column = false;
            }
        }
        return (bool) self::$hasPhotoBase64Column;
    }

    public function index(Request $request)
    {
        $user = $request->user();
        if (!$user) {
            return response()->json([
                'success' => false,
                'message' => 'Sesi login tidak valid. Silakan login kembali.',
            ], 401);
        }

        // Pilih hanya kolom yang benar-benar ada pada tabel report_photos.
        // Accessor `url` ditambahkan otomatis oleh model ReportPhoto.
        $photoColumns = ['id', 'report_id', 'photo', 'latitude', 'longitude', 'created_at'];
        if ($this->hasPhotoAddressColumn()) {
            $photoColumns[] = 'address';
        }

        $query = Report::with([
            'user:id,name,email,role',
            'category:id,name',
            'photos:' . implode(',', $photoColumns),
        ]);

        // Jika bukan admin, hanya tampilkan laporan milik user yang login.
        if (!$this->isAdmin($user)) {
            $query->where('user_id', $user->id);
        } elseif ($request->filled('user_id')) {
            $query->where('user_id', $request->query('user_id'));
        }

        if ($request->filled('status')) {
            $query->where('status', $request->query('status'));
        }
        if ($request->filled('date_from')) {
            $query->whereDate('activity_date', '>=', $request->query('date_from'));
        }
        if ($request->filled('date_to')) {
            $query->whereDate('activity_date', '<=', $request->query('date_to'));
        }

        $limit = max(1, min((int) $request->query('limit', 50), 100));
        $reports = $query->latest()->limit($limit)->get();

        return response()->json([
            'success' => true,
            'message' => 'Data laporan berhasil diambil',
            'data' => $reports,
        ])->header('Cache-Control', 'private, max-age=15, stale-while-revalidate=60');
    }

    public function show(Request $request, $id)
    {
        $user = $request->user();
        if (!$user) {
            return response()->json([
                'success' => false,
                'message' => 'Sesi login tidak valid. Silakan login kembali.',
            ], 401);
        }
        $query = Report::with(['user:id,name,email,role', 'category:id,name', 'photos']);
        if (!$this->isAdmin($user)) {
            $query->where('user_id', $user->id);
        }

        $report = $query->find($id);

        if (!$report) {
            return response()->json([
                'success' => false,
                'message' => 'Laporan tidak ditemukan',
            ], 404);
        }

        // Khusus laporan individual, buka photo_base64 untuk keperluan export dokumen
        if ($report->relationLoaded('photos')) {
            $report->photos->each->makeVisible('photo_base64');
        }

        return response()->json([
            'success' => true,
            'data' => $report,
        ]);
    }

    public function store(Request $request)
    {
        $user = $request->user();
        if (!$user) {
            return response()->json([
                'success' => false,
                'message' => 'Sesi login tidak valid. Silakan login kembali.',
            ], 401);
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

        $report = Report::create([
            'user_id' => $user->id,
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
                    'user_id' => $user->id,
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

        // Simpan lampiran foto jika dikirimkan bersamaan dengan form laporan
        if ($request->hasFile('photo')) {
            try {
                $photoFile = $request->file('photo');
                $path = $photoFile->store('reports', 'public');
                $photoBytes = file_get_contents($photoFile->getRealPath());
                $base64 = $photoBytes !== false ? base64_encode($photoBytes) : null;

                $photoData = [
                    'report_id' => $report->id,
                    'photo' => $path,
                    'latitude' => $validated['latitude'] ?? null,
                    'longitude' => $validated['longitude'] ?? null,
                ];
                if ($this->hasPhotoBase64Column()) {
                    $photoData['photo_base64'] = $base64;
                }
                if ($this->hasPhotoAddressColumn()) {
                    $photoData['address'] = $request->input('address', $report->location);
                }

                ReportPhoto::create($photoData);
            } catch (\Throwable $e) {}
        }

        $report->load(['user', 'category', 'photos']);

        return response()->json([
            'success' => true,
            'message' => 'Laporan berhasil dibuat',
            'data' => $report,
        ], 201);
    }

    public function update(Request $request, $id)
    {
        $user = $request->user();
        if (!$user) {
            return response()->json([
                'success' => false,
                'message' => 'Sesi login tidak valid. Silakan login kembali.',
            ], 401);
        }
        $query = Report::query();

        if (!$this->isAdmin($user)) {
            $query->where('user_id', $user->id);
        }

        $report = $query->find($id);

        if (!$report) {
            return response()->json([
                'success' => false,
                'message' => 'Laporan tidak ditemukan',
            ], 404);
        }

        $validated = $request->validate([
            'category_id' => 'sometimes|nullable|exists:categories,id',
            'title' => 'sometimes|required|string|max:255',
            'activity_date' => 'sometimes|required|date',
            'location' => 'sometimes|required|string|max:255',
            'latitude' => 'sometimes|nullable|numeric',
            'longitude' => 'sometimes|nullable|numeric',
            'description' => 'sometimes|nullable|string',
            'status' => 'sometimes|required|in:draft,terkirim,diperiksa,disetujui,ditolak',
        ]);

        $report->update($validated);

        if ($request->hasFile('photo')) {
            try {
                $photoFile = $request->file('photo');
                $path = $photoFile->store('reports', 'public');
                $photoBytes = file_get_contents($photoFile->getRealPath());
                $base64 = $photoBytes !== false ? base64_encode($photoBytes) : null;

                $photoData = [
                    'report_id' => $report->id,
                    'photo' => $path,
                    'latitude' => $validated['latitude'] ?? $report->latitude,
                    'longitude' => $validated['longitude'] ?? $report->longitude,
                ];
                if ($this->hasPhotoBase64Column()) {
                    $photoData['photo_base64'] = $base64;
                }
                if ($this->hasPhotoAddressColumn()) {
                    $photoData['address'] = $request->input('address', $report->location);
                }

                ReportPhoto::create($photoData);
            } catch (\Throwable $e) {}
        }

        $report->load(['user', 'category', 'photos']);

        return response()->json([
            'success' => true,
            'message' => 'Laporan berhasil diperbarui',
            'data' => $report,
        ]);
    }

    public function destroy(Request $request, $id)
    {
        $user = $request->user();
        if (!$user) {
            return response()->json([
                'success' => false,
                'message' => 'Sesi login tidak valid. Silakan login kembali.',
            ], 401);
        }
        $query = Report::query();

        if (!$this->isAdmin($user)) {
            $query->where('user_id', $user->id);
        }

        $report = $query->find($id);

        if (!$report) {
            return response()->json([
                'success' => false,
                'message' => 'Laporan tidak ditemukan',
            ], 404);
        }

        // Hapus foto terkait terlebih dahulu agar tidak memicu pelanggaran foreign key di PostgreSQL
        try {
            $report->photos()->delete();
        } catch (\Throwable $e) {
            // Abaikan jika tabel/relasi foto tidak tersedia
        }

        $report->delete();

        return response()->json([
            'success' => true,
            'message' => 'Laporan berhasil dihapus',
        ]);
    }
}