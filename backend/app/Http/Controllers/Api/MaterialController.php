<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Material;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class MaterialController extends Controller
{
    /**
     * Display a listing of educational materials.
     * Accessible by ALL users (publicly or authenticated).
     */
    public function index()
    {
        $materials = Material::with(['user:id,name,email,role,nip,jabatan,wilayah', 'category'])
            ->latest()
            ->get();

        return response()->json([
            'success' => true,
            'message' => 'Data materi edukasi berhasil diambil',
            'data' => $materials,
        ]);
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
     * Store a newly created educational material.
     * Records uploader details so it can show "uploaded by [who]".
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
            $filePath = $file->store('materials', 'public');
            $fileName = $file->getClientOriginalName();
            $fileType = strtoupper($file->getClientOriginalExtension());
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

        $material->load(['user:id,name,email,role,nip,jabatan,wilayah', 'category']);

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
        if ($user && $user->role !== 'admin' && $material->user_id && $material->user_id !== $user->id) {
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
            if ($material->file_path && Storage::disk('public')->exists($material->file_path)) {
                Storage::disk('public')->delete($material->file_path);
            }

            $file = $request->file('file');
            $material->file_path = $file->store('materials', 'public');
            $material->file_name = $file->getClientOriginalName();
            $material->file_type = strtoupper($file->getClientOriginalExtension());
        }

        $material->save();
        $material->load(['user:id,name,email,role,nip,jabatan,wilayah', 'category']);

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
        if ($user && $user->role !== 'admin' && $material->user_id && $material->user_id !== $user->id) {
            return response()->json([
                'success' => false,
                'message' => 'Anda tidak memiliki hak untuk menghapus materi ini',
            ], 403);
        }

        if ($material->file_path && Storage::disk('public')->exists($material->file_path)) {
            Storage::disk('public')->delete($material->file_path);
        }

        $material->delete();

        return response()->json([
            'success' => true,
            'message' => 'Materi edukasi berhasil dihapus',
        ]);
    }
}
