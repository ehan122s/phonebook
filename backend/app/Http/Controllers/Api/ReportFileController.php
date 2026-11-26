<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Report;
use App\Models\ReportFile;
use App\Services\ReportFileService;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

class ReportFileController extends Controller
{
    public function __construct(
        private readonly ReportFileService $fileService
    ) {}

    private function isAdmin($user): bool
    {
        return $user && strtolower((string) $user->role) === 'admin';
    }

    private function findAuthorizedReport(Request $request, $reportId): ?Report
    {
        $user = $request->user();
        if (!$user) {
            return null;
        }

        $query = Report::query();
        if (!$this->isAdmin($user)) {
            $query->where('user_id', $user->id);
        }

        return $query->find($reportId);
    }

    /**
     * Daftar dokumen lampiran milik suatu laporan.
     */
    public function index(Request $request, $reportId)
    {
        $report = $this->findAuthorizedReport($request, $reportId);
        if (!$report) {
            return response()->json([
                'success' => false,
                'message' => 'Laporan tidak ditemukan',
            ], 404);
        }

        $files = $report->files()->latest()->get();

        return response()->json([
            'success' => true,
            'data' => $files,
        ]);
    }

    /**
     * Unggah dokumen laporan ke Supabase Storage.
     */
    public function store(Request $request, $reportId)
    {
        $report = $this->findAuthorizedReport($request, $reportId);
        if (!$report) {
            return response()->json([
                'success' => false,
                'message' => 'Laporan tidak ditemukan',
            ], 404);
        }

        $validated = $request->validate([
            'file' => 'required|file|mimes:pdf,doc,docx,xls,xlsx,csv,txt|max:20480',
            'title' => 'nullable|string|max:255',
            'description' => 'nullable|string|max:1000',
        ]);

        try {
            $reportFile = $this->fileService->uploadForReport(
                $report,
                $request->file('file'),
                [
                    'title' => $validated['title'] ?? null,
                    'description' => $validated['description'] ?? null,
                ]
            );
        } catch (ValidationException $e) {
            throw $e;
        } catch (\Throwable $e) {
            return response()->json([
                'success' => false,
                'message' => $e->getMessage() ?: 'Gagal mengunggah dokumen laporan.',
            ], 502);
        }

        return response()->json([
            'success' => true,
            'message' => 'Dokumen laporan berhasil diunggah ke penyimpanan',
            'data' => $reportFile,
        ], 201);
    }

    /**
     * Unduh dokumen laporan (stream file atau buat signed URL sementara jika ?format=url).
     */
    public function download(Request $request, $id)
    {
        $user = $request->user();
        $reportFile = ReportFile::with('report')->find($id);

        if (!$reportFile || !$user) {
            return response()->json([
                'success' => false,
                'message' => 'Dokumen tidak ditemukan',
            ], 404);
        }

        $ownerId = $reportFile->report ? (int) $reportFile->report->user_id : (int) $reportFile->user_id;
        if (!$this->isAdmin($user) && $ownerId !== (int) $user->id) {
            return response()->json([
                'success' => false,
                'message' => 'Anda tidak memiliki akses untuk mengunduh dokumen ini',
            ], 403);
        }

        if ($request->query('format') === 'url') {
            try {
                $signedUrl = $this->fileService->createSignedUrl($reportFile);
                return response()->json([
                    'success' => true,
                    'data' => [
                        'url' => $signedUrl,
                        'file_name' => $reportFile->file_name,
                        'expires_in' => (int) config('services.supabase.signed_url_expires', 300),
                    ],
                ]);
            } catch (\Throwable $e) {
                return response()->json([
                    'success' => false,
                    'message' => $e->getMessage() ?: 'Gagal membuat tautan unduhan dokumen.',
                ], 502);
            }
        }

        try {
            $downloaded = $this->fileService->fetchContent($reportFile);
            $safeName = str_replace(['"', "\r", "\n"], '', $reportFile->file_name ?: 'dokumen_laporan');

            return response($downloaded['content'], 200, [
                'Content-Type' => $reportFile->mime_type ?: $downloaded['content_type'],
                'Content-Disposition' => 'attachment; filename="' . $safeName . '"',
                'Cache-Control' => 'private, no-store',
            ]);
        } catch (\Throwable $e) {
            return response()->json([
                'success' => false,
                'message' => $e->getMessage() ?: 'Gagal mengunduh dokumen laporan.',
            ], 404);
        }
    }

    /**
     * Hapus dokumen laporan dari Supabase Storage dan database.
     */
    public function destroy(Request $request, $id)
    {
        $user = $request->user();
        $reportFile = ReportFile::with('report')->find($id);

        if (!$reportFile || !$user) {
            return response()->json([
                'success' => false,
                'message' => 'Dokumen tidak ditemukan',
            ], 404);
        }

        $ownerId = $reportFile->report ? (int) $reportFile->report->user_id : (int) $reportFile->user_id;
        if (!$this->isAdmin($user) && $ownerId !== (int) $user->id) {
            return response()->json([
                'success' => false,
                'message' => 'Dokumen tidak ditemukan',
            ], 404);
        }

        $this->fileService->deleteFile($reportFile);

        return response()->json([
            'success' => true,
            'message' => 'Dokumen laporan berhasil dihapus',
        ]);
    }
}
