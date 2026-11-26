<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AppNotification;
use App\Models\Report;
use App\Services\ReportFileService;
use App\Services\ReportPhotoService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Schema;

class ReportController extends Controller
{
    public function __construct(
        private readonly ReportPhotoService $photoService,
        private readonly ReportFileService $fileService
    ) {}

    private function isAdmin($user): bool
    {
        return $user && strtolower((string) $user->role) === 'admin';
    }

    /**
     * Daftar kolom report_photos yang aman untuk list query (tanpa photo_base64).
     *
     * @return array<int, string>
     */
    private function getSafePhotoSelectColumns(): array
    {
        $base = ['id', 'report_id', 'photo', 'latitude', 'longitude', 'created_at'];
        $optional = [
            'address',
            'imagekit_file_id',
            'imagekit_url',
            'file_name',
            'mime_type',
            'file_size',
            'storage_provider',
        ];

        try {
            $existing = Cache::remember('schema_report_photos_columns_v2', 300, static function () {
                return Schema::connection('db_foto')->getColumnListing('report_photos');
            });
            foreach ($optional as $col) {
                if (in_array($col, $existing, true)) {
                    $base[] = $col;
                }
            }
        } catch (\Throwable $e) {
            // Gunakan kolom dasar jika inspeksi schema gagal
        }

        return $base;
    }

    private function hasReportFilesTable(): bool
    {
        try {
            return Cache::remember('schema_report_files_table_v1', 300, static function () {
                return Schema::connection('db_laporan')->hasTable('report_files');
            });
        } catch (\Throwable $e) {
            return false;
        }
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

        $relations = [
            'user:id,name,email,role',
            'category:id,name',
            'photos:' . implode(',', $this->getSafePhotoSelectColumns()),
        ];

        if ($this->hasReportFilesTable()) {
            $relations[] = 'files';
        }

        $query = Report::with($relations);

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

        $relations = ['user:id,name,email,role', 'category:id,name', 'photos'];
        if ($this->hasReportFilesTable()) {
            $relations[] = 'files';
        }

        $query = Report::with($relations);
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

        // Untuk foto lama tanpa URL ImageKit, buka photo_base64 guna kompatibilitas export dokumen
        if ($report->relationLoaded('photos')) {
            $report->photos->each(function ($photo) {
                if (empty($photo->imagekit_url)) {
                    $photo->makeVisible('photo_base64');
                }
            });
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
            'photo' => 'nullable|file|mimes:jpg,jpeg,png,webp,gif|max:10240',
            'document' => 'nullable|file|mimes:pdf,doc,docx,xls,xlsx,csv,txt|max:20480',
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

        // Unggah lampiran foto jika dikirimkan bersamaan dengan form laporan
        if ($request->hasFile('photo')) {
            try {
                $this->photoService->storeForReport($report, $request->file('photo'), null, [
                    'latitude' => $validated['latitude'] ?? null,
                    'longitude' => $validated['longitude'] ?? null,
                    'address' => $request->input('address', $report->location),
                ]);
            } catch (\Throwable $e) {
                // Laporan tetap dibuat; lampiran dapat diunggah ulang secara terpisah
            }
        }

        // Unggah lampiran dokumen jika dikirimkan bersamaan dengan form laporan
        if ($request->hasFile('document') && $this->hasReportFilesTable()) {
            try {
                $this->fileService->uploadForReport($report, $request->file('document'), [
                    'title' => $request->input('document_title'),
                    'description' => $request->input('document_description'),
                ]);
            } catch (\Throwable $e) {
                // Laporan tetap dibuat; dokumen dapat diunggah ulang melalui endpoint dokumen
            }
        }

        $relations = ['user', 'category', 'photos'];
        if ($this->hasReportFilesTable()) {
            $relations[] = 'files';
        }
        $report->load($relations);

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
            'photo' => 'nullable|file|mimes:jpg,jpeg,png,webp,gif|max:10240',
        ]);

        $report->update(collect($validated)->except(['photo'])->all());

        if ($request->hasFile('photo')) {
            try {
                $this->photoService->storeForReport($report, $request->file('photo'), null, [
                    'latitude' => $validated['latitude'] ?? $report->latitude,
                    'longitude' => $validated['longitude'] ?? $report->longitude,
                    'address' => $request->input('address', $report->location),
                ]);
            } catch (\Throwable $e) {
                // Abaikan agar pembaruan metadata laporan tetap berhasil
            }
        }

        $relations = ['user', 'category', 'photos'];
        if ($this->hasReportFilesTable()) {
            $relations[] = 'files';
        }
        $report->load($relations);

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

        // Hapus file foto dari ImageKit / disk lokal terlebih dahulu
        try {
            foreach ($report->photos()->get() as $photo) {
                $this->photoService->deletePhoto($photo);
            }
        } catch (\Throwable $e) {
            // Tetap lanjutkan penghapusan laporan
        }

        // Hapus dokumen lampiran dari Supabase Storage jika tabel tersedia
        if ($this->hasReportFilesTable()) {
            try {
                foreach ($report->files()->get() as $file) {
                    $this->fileService->deleteFile($file);
                }
            } catch (\Throwable $e) {
                // Tetap lanjutkan penghapusan laporan
            }
        }

        $report->delete();

        return response()->json([
            'success' => true,
            'message' => 'Laporan berhasil dihapus',
        ]);
    }
}
