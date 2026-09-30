<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Material;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class MaterialController extends Controller
{
    public function index()
    {
        $materials = Material::with(['user', 'category'])
            ->latest()
            ->get();

        return response()->json([
            'success' => true,
            'message' => 'Data materi berhasil diambil',
            'data' => $materials,
        ]);
    }

    public function show($id)
    {
        $material = Material::with(['user', 'category'])
            ->find($id);

        if (!$material) {
            return response()->json([
                'success' => false,
                'message' => 'Materi tidak ditemukan',
            ], 404);
        }

        return response()->json([
            'success' => true,
            'data' => $material,
        ]);
    }

    public function store(Request $request)
    {
        
        $validated = $request->validate([
            'category_id' => 'nullable|exists:categories,id',
            'title' => 'required|string|max:255',
            'description' => 'nullable|string',
            'file' => 'required|file|max:20480|mimes:pdf,doc,docx,ppt,pptx,xls,xlsx',
        ]);

        $file = $request->file('file');

        $path = $file->store('materials', 'public');

        $material = Material::create([
            'user_id' => $request->user()->id,
            'category_id' => $validated['category_id'] ?? null,
            'title' => $validated['title'],
            'description' => $validated['description'] ?? null,
            'file_path' => $path,
            'file_name' => $file->getClientOriginalName(),
            'file_type' => $file->getClientOriginalExtension(),
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Materi berhasil diupload',
            'data' => $material,
        ], 201);
    }

    public function update(Request $request, $id)
    {
        $material = Material::where('user_id', $request->user()->id)
            ->find($id);

        if (!$material) {
            return response()->json([
                'success' => false,
                'message' => 'Materi tidak ditemukan',
            ], 404);
        }

        $validated = $request->validate([
            'category_id' => 'nullable|exists:categories,id',
            'title' => 'required|string|max:255',
            'description' => 'nullable|string',
            'file' => 'nullable|file|max:20480|mimes:pdf,doc,docx,ppt,pptx,xls,xlsx',
        ]);

        $material->title = $validated['title'];
        $material->category_id = $validated['category_id'] ?? null;
        $material->description = $validated['description'] ?? null;

        if ($request->hasFile('file')) {
            if ($material->file_path) {
                Storage::disk('public')->delete($material->file_path);
            }

            $file = $request->file('file');

            $material->file_path = $file->store('materials', 'public');
            $material->file_name = $file->getClientOriginalName();
            $material->file_type = $file->getClientOriginalExtension();
        }

        $material->save();

        return response()->json([
            'success' => true,
            'message' => 'Materi berhasil diperbarui',
            'data' => $material,
        ]);
    }

    public function destroy(Request $request, $id)
    {
        $material = Material::where('user_id', $request->user()->id)
            ->find($id);

        if (!$material) {
            return response()->json([
                'success' => false,
                'message' => 'Materi tidak ditemukan',
            ], 404);
        }

        if ($material->file_path) {
            Storage::disk('public')->delete($material->file_path);
        }

        $material->delete();

        return response()->json([
            'success' => true,
            'message' => 'Materi berhasil dihapus',
        ]);
    }
}