<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AppNotification;
use App\Models\Material;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\Storage;

class MaterialController extends Controller
{
    private function isAdmin($user): bool
    {
        return $user && strtolower((string) $user->role) === 'admin';
    }

    private function forgetMaterialsCache(): void
    {
        try {
            $this->forgetMaterialsCache();
        } catch (\Throwable $e) {
        }
    }

    /**
     * Display a listing of educational materials.
     * Accessible by ALL users (publicly or authenticated).
     */
    public function index()
    {
        $fetchQuery = static fn () => Material::with([
            'user:id,name,email,role,nip,jabatan,wilayah',
            'category:id,name',
        ])->latest()->get();

        try {
            $materials = Cache::remember('materials_index_v2', 180, $fetchQuery);
        } catch (\Throwable $e) {
            $materials = $fetchQuery();
        }

        return response()->json([
            'success' => true,
            'message' => 'Data materi edukasi berhasil diambil',
            'data' => $materials,
        ])->header('Cache-Control', 'public, max-age=60, s-maxage=180, stale-while-revalidate=300');
    }

    /**
     * Display a specific material.
     */
    public function show($id)
    {
        $material = Material::with(['user:id,name,email,role,nip,jabatan,wilayah', 'category'])
            ->find($id);

        if (!$material) {
            return response()->json([
                'success' => false,
                'message' => 'Materi edukasi tidak ditemukan',
            ], 404);
        }

        return response()->json([
            'success' => true,
            'data' => $material,
        ]);
    }

    /**
     * Download or serve an educational material file.
     */
    public function download($id)
    {
        $material = Material::find($id);

        if (!$material) {
            return response()->json([
                'success' => false,
                'message' => 'Materi tidak ditemukan',
            ], 404);
        }

        $filePath = $material->file_path;
        $fileName = $material->file_name ?: ($material->title . '.' . strtolower($material->file_type ?: 'pdf'));

        // If file_path is a direct external URL (Google Drive, HTTPS, etc.)
        if (filter_var($filePath, FILTER_VALIDATE_URL)) {
            return redirect($filePath);
        }

        // If stored in public storage disk
        try {
            if ($filePath && Storage::disk('public')->exists($filePath)) {
                return Storage::disk('public')->download($filePath, $fileName);
            }

            // Check in default storage
            if ($filePath && Storage::exists($filePath)) {
                return Storage::download($filePath, $fileName);
            }
        } catch (\Throwable $e) {}

        // Fallback: Generate an official formatted summary document for download
        $content = "DINAS KEHUTANAN PROVINSI JAWA BARAT\n";
        $content .= "CABANG DINAS KEHUTANAN (CDK) WILAYAH V GARUT\n";
        $content .= "=========================================================\n\n";
        $content .= "DOKUMEN MATERI EDUKASI KEHUTANAN\n\n";
        $content .= "JUDUL MATERI: " . $material->title . "\n";
        $content .= "KATEGORI    : " . ($material->category_name ?: 'Penyuluhan') . "\n";
        $content .= "PENGUNGGAH  : " . ($material->uploader_name ?: 'Administrator Kehutanan') . " (" . ($material->uploader_role ?: 'Penyuluh') . ")\n";
        $content .= "TANGGAL     : " . ($material->created_at ? $material->created_at->format('d F Y, H:i') : date('d F Y')) . "\n";
        $content .= "TIPE BERKAS : " . ($material->file_type ?: 'PDF') . "\n\n";
        $content .= "RINGKASAN & DESKRIPSI MATERI:\n";
        $content .= "---------------------------------------------------------\n";
        $content .= ($material->description ?: 'Tidak ada deskripsi tambahan.') . "\n\n";
        $content .= "---------------------------------------------------------\n";
        $content .= "Dokumen ini diunduh melalui Aplikasi Phonebook CDK Wilayah V.\n";

        $cleanTitle = preg_replace('/[^A-Za-z0-9_\-]/', '_', $material->title);
        $safeFileName = ($cleanTitle ?: 'Materi_Kehutanan') . '.txt';

        return response($content, 200, [
            'Content-Type' => 'text/plain; charset=utf-8',
            'Content-Disposition' => 'attachment; filename="' . $safeFileName . '"',
        ]);
    }

    /**
     * Store a newly created educational material.
     * Records uploader details and creates notification with material_id reference.
     */
    public function store(Request $request)
    {
        $validated = $request->validate([
            'title' => 'required|string|max:255',
            'category_id' => 'nullable|exists:categories,id',
            'category_name' => 'nullable|string|max:100',
            'description' => 'nullable|string',
            'file_type' => 'nullable|string|max:50',
            'file_name' => 'nullable|string|max:255',
            'file_path' => 'nullable|string',
            'drive_url' => 'nullable|string',
            'file' => 'nullable|file|max:20480',
            'uploader_name' => 'nullable|string|max:255',
            'uploader_role' => 'nullable|string|max:50',
        ]);

        $user = $request->user();

        // Determine uploader name and role
        $uploaderName = $validated['uploader_name']
            ?? ($user ? $user->name : 'Penyuluh Kehutanan');

        $uploaderRole = $validated['uploader_role']
            ?? ($user ? $user->role : 'user');

        $filePath = 'materials/default.pdf';
        $fileName = $validated['file_name'] ?? 'Materi Edukasi Kehutanan.pdf';
        $fileType = strtoupper($validated['file_type'] ?? 'PDF');

        if ($request->hasFile('file')) {
            $file = $request->file('file');
            $fileName = $file->getClientOriginalName();
            $fileType = strtoupper($file->getClientOriginalExtension() ?: $fileType);
            try {
                $stored = $file->store('materials', 'public');
                if ($stored) {
                    $filePath = $stored;
                } else {
                    $filePath = 'materials/' . $fileName;
                }
            } catch (\Throwable $e) {
                $filePath = 'materials/' . $fileName;
            }
        } elseif ($request->filled('drive_url')) {
            $filePath = $request->input('drive_url');
        } elseif ($request->filled('file_path')) {
            $filePath = $request->input('file_path');
        }

        $material = Material::create([
            'user_id' => $user ? $user->id : null,
            'category_id' => $validated['category_id'] ?? null,
            'category_name' => $validated['category_name'] ?? 'Penyuluhan',
            'title' => $validated['title'],
            'description' => $validated['description'] ?? null,
            'file_path' => $filePath,
            'file_name' => $fileName,
            'file_type' => $fileType,
            'uploader_name' => $uploaderName,
            'uploader_role' => $uploaderRole,
        ]);

        // Catat notifikasi materi baru ke tabel app_notifications
        try {
            if (Schema::hasTable('app_notifications')) {
                $targetUserId = $user ? $user->id : User::query()->value('id');
                if ($targetUserId) {
                    AppNotification::create([
                        'user_id' => $targetUserId,
                        'type' => 'materi',
                        'title' => 'Materi Baru: ' . $material->title,
                        'message' => "Materi edukasi \"{$material->title}\" ({$material->category_name}) telah diunggah oleh {$uploaderName}.",
                        'reference_id' => 'material_' . $material->id,
                        'metadata' => [
                            'material_id' => $material->id,
                            'materialId' => (string) $material->id,
                            'title' => $material->title,
                            'category' => $material->category_name,
                            'file_type' => $material->file_type,
                            'uploader_name' => $uploaderName,
                        ],
                        'is_read' => false,
                    ]);
                }
            }
        } catch (\Throwable $e) {}

        $material->load(['user:id,name,email,role,nip,jabatan,wilayah', 'category']);

        $this->forgetMaterialsCache();

        return response()->json([
            'success' => true,
            'message' => 'Materi edukasi berhasil diupload oleh ' . $uploaderName,
            'data' => $material,
        ], 201);
    }

    /**
     * Update an educational material.
     */
    public function update(Request $request, $id)
    {
        $user = $request->user();
        $material = Material::find($id);

        if (!$material) {
            return response()->json([
                'success' => false,
                'message' => 'Materi tidak ditemukan',
            ], 404);
        }

        // Authorization check: Admin or creator can edit
        if ($user && !$this->isAdmin($user) && $material->user_id && $material->user_id !== $user->id) {
            return response()->json([
                'success' => false,
                'message' => 'Anda tidak memiliki hak akses untuk mengedit materi ini',
            ], 403);
        }

        $validated = $request->validate([
            'category_id' => 'nullable|exists:categories,id',
            'category_name' => 'nullable|string|max:100',
            'title' => 'required|string|max:255',
            'description' => 'nullable|string',
            'file_type' => 'nullable|string|max:50',
            'file' => 'nullable|file|max:20480',
        ]);

        $material->title = $validated['title'];
        $material->category_id = $validated['category_id'] ?? $material->category_id;
        if (isset($validated['category_name'])) {
            $material->category_name = $validated['category_name'];
        }
        $material->description = $validated['description'] ?? $material->description;
        if (isset($validated['file_type'])) {
            $material->file_type = strtoupper($validated['file_type']);
        }

        if ($request->hasFile('file')) {
            try {
                if ($material->file_path && Storage::disk('public')->exists($material->file_path)) {
                    Storage::disk('public')->delete($material->file_path);
                }
            } catch (\Throwable $e) {}

            $file = $request->file('file');
            $material->file_name = $file->getClientOriginalName();
            $material->file_type = strtoupper($file->getClientOriginalExtension());
            try {
                $stored = $file->store('materials', 'public');
                if ($stored) {
                    $material->file_path = $stored;
                }
            } catch (\Throwable $e) {}
        }

        $material->save();
        $material->load(['user:id,name,email,role,nip,jabatan,wilayah', 'category']);

        $this->forgetMaterialsCache();

        return response()->json([
            'success' => true,
            'message' => 'Materi edukasi berhasil diperbarui',
            'data' => $material,
        ]);
    }

    /**
     * Delete an educational material.
     */
    public function destroy(Request $request, $id)
    {
        $user = $request->user();
        $material = Material::find($id);

        if (!$material) {
            return response()->json([
                'success' => false,
                'message' => 'Materi tidak ditemukan',
            ], 404);
        }

        // Authorization check: Admin or creator can delete
        if ($user && !$this->isAdmin($user) && $material->user_id && $material->user_id !== $user->id) {
            return response()->json([
                'success' => false,
                'message' => 'Anda tidak memiliki hak untuk menghapus materi ini',
            ], 403);
        }

        try {
            if ($material->file_path && Storage::disk('public')->exists($material->file_path)) {
                Storage::disk('public')->delete($material->file_path);
            }
        } catch (\Throwable $e) {}

        $material->delete();

        Cache::forget('materials_index_v2');

        return response()->json([
            'success' => true,
            'message' => 'Materi edukasi berhasil dihapus',
        ]);
    }
}