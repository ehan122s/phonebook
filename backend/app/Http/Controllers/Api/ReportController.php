<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AppNotification;
use App\Models\Report;
use App\Services\MonitoringCalculationService;
use App\Services\ReportFileService;
use App\Services\ReportPhotoService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Schema;

class ReportController extends Controller
{
    public function __construct(
        private readonly ReportPhotoService $photoService,
        private readonly ReportFileService $fileService,
        private readonly MonitoringCalculationService $monitoringCalculator
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
            'report_type' => 'nullable|string|max:50',
            'activity_name' => 'nullable|string|max:255',
            'monitoring_period' => 'nullable|string|max:150',
            'officer_name' => 'nullable|string|max:255',
            'target_value' => 'nullable|numeric|min:0',
            'target_unit' => 'nullable|string|max:100',
            'target_period' => 'nullable|string|max:150',
            'actual_value' => 'nullable|numeric|min:0',
            'field_facts' => 'nullable|string',
            'obstacles' => 'nullable|string',
            'failure_causes' => 'nullable|string',
            'recommendations' => 'nullable|string',
            'follow_up_plan' => 'nullable|string',
            'next_target_date' => 'nullable|date',
            'monitoring_data' => 'nullable|array',
        ]);

        $reportType = $this->resolveReportType($validated, $request);
        $targetStatus = $validated['status'] ?? 'draft';

        if ($reportType === 'monitoring' && $targetStatus !== 'draft') {
            $request->validate([
                'activity_name' => 'required|string|max:255',
                'monitoring_period' => 'required|string|max:150',
                'officer_name' => 'required|string|max:255',
                'target_value' => 'required|numeric|gt:0',
                'target_unit' => 'required|string|max:100',
                'actual_value' => 'required|numeric|min:0',
                'field_facts' => 'required|string',
            ], [
                'activity_name.required' => 'Nama kegiatan yang dimonitor wajib diisi.',
                'monitoring_period.required' => 'Periode monitoring wajib diisi.',
                'officer_name.required' => 'Nama petugas/pelaksana wajib diisi.',
                'target_value.required' => 'Nilai target wajib diisi.',
                'target_value.gt' => 'Nilai target harus lebih dari 0.',
                'target_unit.required' => 'Satuan target wajib dipilih atau diisi.',
                'actual_value.required' => 'Hasil aktual wajib diisi.',
                'field_facts.required' => 'Fakta lapangan wajib diisi.',
            ]);
        }

        $createData = [
            'user_id' => $user->id,
            'category_id' => $validated['category_id'] ?? null,
            'title' => $validated['title'],
            'activity_date' => $validated['activity_date'],
            'location' => $validated['location'],
            'latitude' => $validated['latitude'] ?? null,
            'longitude' => $validated['longitude'] ?? null,
            'description' => $validated['description'] ?? null,
            'status' => $targetStatus,
        ];

        $createData = $this->mergeMonitoringPayload($createData, $validated, $reportType, $user->name ?? null);

        $report = Report::create($createData);

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
            'report_type' => 'sometimes|nullable|string|max:50',
            'activity_name' => 'sometimes|nullable|string|max:255',
            'monitoring_period' => 'sometimes|nullable|string|max:150',
            'officer_name' => 'sometimes|nullable|string|max:255',
            'target_value' => 'sometimes|nullable|numeric|min:0',
            'target_unit' => 'sometimes|nullable|string|max:100',
            'target_period' => 'sometimes|nullable|string|max:150',
            'actual_value' => 'sometimes|nullable|numeric|min:0',
            'field_facts' => 'sometimes|nullable|string',
            'obstacles' => 'sometimes|nullable|string',
            'failure_causes' => 'sometimes|nullable|string',
            'recommendations' => 'sometimes|nullable|string',
            'follow_up_plan' => 'sometimes|nullable|string',
            'next_target_date' => 'sometimes|nullable|date',
            'monitoring_data' => 'sometimes|nullable|array',
        ]);

        $reportType = $validated['report_type']
            ?? ($report->report_type ?: $this->resolveReportType($validated, $request));
        $targetStatus = $validated['status'] ?? $report->status;

        $mergedForCalc = array_merge([
            'title' => $report->title,
            'activity_name' => $report->activity_name,
            'monitoring_period' => $report->monitoring_period,
            'officer_name' => $report->officer_name,
            'target_value' => $report->target_value,
            'target_unit' => $report->target_unit,
            'target_period' => $report->target_period,
            'actual_value' => $report->actual_value,
            'field_facts' => $report->field_facts,
            'obstacles' => $report->obstacles,
            'failure_causes' => $report->failure_causes,
            'recommendations' => $report->recommendations,
            'follow_up_plan' => $report->follow_up_plan,
            'next_target_date' => $report->next_target_date?->format('Y-m-d'),
            'description' => $report->description,
        ], collect($validated)->except(['photo'])->all());

        if ($reportType === 'monitoring' && $targetStatus !== 'draft') {
            validator($mergedForCalc, [
                'activity_name' => 'required|string|max:255',
                'monitoring_period' => 'required|string|max:150',
                'officer_name' => 'required|string|max:255',
                'target_value' => 'required|numeric|gt:0',
                'target_unit' => 'required|string|max:100',
                'actual_value' => 'required|numeric|min:0',
                'field_facts' => 'required|string',
            ], [
                'activity_name.required' => 'Nama kegiatan yang dimonitor wajib diisi.',
                'monitoring_period.required' => 'Periode monitoring wajib diisi.',
                'officer_name.required' => 'Nama petugas/pelaksana wajib diisi.',
                'target_value.required' => 'Nilai target wajib diisi.',
                'target_value.gt' => 'Nilai target harus lebih dari 0.',
                'target_unit.required' => 'Satuan target wajib dipilih atau diisi.',
                'actual_value.required' => 'Hasil aktual wajib diisi.',
                'field_facts.required' => 'Fakta lapangan wajib diisi.',
            ])->validate();
        }

        $updatePayload = collect($validated)->except(['photo'])->all();
        $updatePayload = $this->mergeMonitoringPayload($updatePayload, $mergedForCalc, $reportType, $user->name ?? null, isUpdate: true);

        $report->update($updatePayload);

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

    private function resolveReportType(array $validated, Request $request): string
    {
        $explicit = strtolower(trim((string) ($validated['report_type'] ?? $request->input('report_type', ''))));
        if ($explicit === 'monitoring') {
            return 'monitoring';
        }

        $hasMonitoringInput = isset($validated['target_value'])
            || isset($validated['actual_value'])
            || !empty($validated['activity_name'])
            || !empty($validated['monitoring_period']);

        return $hasMonitoringInput ? 'monitoring' : 'standard';
    }

    private function hasMonitoringColumns(): bool
    {
        try {
            return Cache::remember('schema_reports_monitoring_cols_v1', 300, static function () {
                return Schema::connection('db_laporan')->hasColumn('reports', 'report_type')
                    && Schema::connection('db_laporan')->hasColumn('reports', 'target_value');
            });
        } catch (\Throwable $e) {
            return false;
        }
    }

    /**
     * Lengkapi payload Monitoring & hitung otomatis persentase capaian, sisa target, dan status.
     *
     * @param  array<string, mixed>  $basePayload
     * @param  array<string, mixed>  $sourceData
     * @return array<string, mixed>
     */
    private function mergeMonitoringPayload(
        array $basePayload,
        array $sourceData,
        string $reportType,
        ?string $defaultOfficerName = null,
        bool $isUpdate = false
    ): array {
        if (!$this->hasMonitoringColumns()) {
            return $basePayload;
        }

        if ($reportType !== 'monitoring') {
            if (!$isUpdate) {
                $basePayload['report_type'] = 'standard';
            }
            return $basePayload;
        }

        $targetVal = array_key_exists('target_value', $sourceData) && $sourceData['target_value'] !== null && $sourceData['target_value'] !== ''
            ? (float) $sourceData['target_value']
            : null;
        $actualVal = array_key_exists('actual_value', $sourceData) && $sourceData['actual_value'] !== null && $sourceData['actual_value'] !== ''
            ? (float) $sourceData['actual_value']
            : null;

        $calc = $this->monitoringCalculator->calculate($targetVal, $actualVal);

        $monitoringFields = [
            'report_type' => 'monitoring',
            'activity_name' => $sourceData['activity_name'] ?? $basePayload['title'] ?? null,
            'monitoring_period' => $sourceData['monitoring_period'] ?? null,
            'officer_name' => !empty($sourceData['officer_name']) ? $sourceData['officer_name'] : $defaultOfficerName,
            'target_value' => $targetVal,
            'target_unit' => $sourceData['target_unit'] ?? null,
            'target_period' => $sourceData['target_period'] ?? ($sourceData['monitoring_period'] ?? null),
            'actual_value' => $actualVal,
            'achievement_percentage' => $calc['achievement_percentage'],
            'remaining_target' => $calc['remaining_target'],
            'achievement_status' => $calc['achievement_status'],
            'field_facts' => $sourceData['field_facts'] ?? null,
            'obstacles' => $sourceData['obstacles'] ?? null,
            'failure_causes' => $sourceData['failure_causes'] ?? null,
            'recommendations' => $sourceData['recommendations'] ?? null,
            'follow_up_plan' => $sourceData['follow_up_plan'] ?? null,
            'next_target_date' => !empty($sourceData['next_target_date']) ? $sourceData['next_target_date'] : null,
        ];

        if (isset($sourceData['monitoring_data']) && is_array($sourceData['monitoring_data'])) {
            $monitoringFields['monitoring_data'] = $sourceData['monitoring_data'];
        }

        $merged = array_merge($basePayload, $monitoringFields);

        if (empty($merged['description'])) {
            $merged['description'] = $this->monitoringCalculator->buildStructuredSummaryText($merged);
        }

        return $merged;
    }
}
