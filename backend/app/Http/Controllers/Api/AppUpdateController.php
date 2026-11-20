<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AppUpdate;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class AppUpdateController extends Controller
{
    /**
     * Mengambil informasi update aplikasi terbaru yang sudah dipublikasikan.
     */
    public function latest(Request $request)
    {
        $latest = AppUpdate::getLatestPublished();

        $response = response()->json([
            'success' => true,
            'data' => $latest,
            'message' => $latest ? 'Informasi update aplikasi berhasil diambil.' : 'Belum ada data update yang dipublikasikan.',
        ]);

        // Optimasi Edge & Browser Caching
        return $response->header('Cache-Control', 'public, max-age=60, s-maxage=180, stale-while-revalidate=300');
    }

    /**
     * Memeriksa apakah versi aplikasi pengguna membutuhkan pembaruan.
     */
    public function check(Request $request)
    {
        $clientVersion = (string) ($request->input('version') ?: $request->query('version') ?: '1.0.0');
        $result = AppUpdate::checkUpdate($clientVersion);

        return response()->json([
            'success' => true,
            'data' => $result,
            'message' => $result['has_update']
                ? ($result['is_mandatory'] ? 'Pembaruan aplikasi wajib tersedia!' : 'Pembaruan aplikasi opsional tersedia.')
                : 'Aplikasi Anda sudah menggunakan versi terbaru.',
        ]);
    }

    /**
     * Mengambil riwayat pembaruan aplikasi yang telah dipublikasikan.
     */
    public function history(Request $request)
    {
        $limit = min((int) ($request->query('limit', 15)), 50);
        $updates = AppUpdate::published()
            ->orderByDesc('published_at')
            ->orderByDesc('id')
            ->limit($limit)
            ->get();

        return response()->json([
            'success' => true,
            'data' => $updates,
        ]);
    }

    /**
     * Membuat data pembaruan aplikasi baru (draft atau langsung dipublikasikan).
     */
    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'version' => ['required', 'string', 'max:32', 'regex:/^[0-9]+(\.[0-9]+)*(\+[0-9]+)?$/'],
            'title' => ['required', 'string', 'max:255'],
            'description' => ['required', 'string'],
            'apk_url' => ['required', 'url', 'regex:/^https:\/\//i'],
            'type' => ['nullable', 'in:optional,mandatory,OPTIONAL,MANDATORY'],
            'is_published' => ['nullable', 'boolean'],
            'min_supported_version' => ['nullable', 'string', 'max:32'],
        ], [
            'apk_url.regex' => 'Link download APK wajib menggunakan protokol aman HTTPS (https://).',
            'version.regex' => 'Format versi harus sesuai standar semantic versioning (contoh: 1.2.0).',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validasi gagal.',
                'errors' => $validator->errors(),
            ], 422);
        }

        $type = strtolower($request->input('type', 'optional')) === 'mandatory' ? 'mandatory' : 'optional';
        $isPublished = filter_var($request->input('is_published', false), FILTER_VALIDATE_BOOLEAN);

        $update = AppUpdate::create([
            'version' => trim($request->input('version')),
            'title' => trim($request->input('title')),
            'description' => trim($request->input('description')),
            'apk_url' => trim($request->input('apk_url')),
            'type' => $type,
            'is_published' => $isPublished,
            'published_at' => $isPublished ? Carbon::now('Asia/Jakarta') : null,
            'min_supported_version' => $request->input('min_supported_version') ? trim($request->input('min_supported_version')) : null,
            'discord_user_id' => $request->input('discord_user_id'),
            'discord_user_name' => $request->input('discord_user_name'),
        ]);

        return response()->json([
            'success' => true,
            'message' => $isPublished ? 'Pembaruan aplikasi berhasil dipublikasikan.' : 'Draft pembaruan aplikasi berhasil disimpan.',
            'data' => $update,
        ], 201);
    }

    /**
     * Mempublikasikan draft pembaruan aplikasi.
     */
    public function publish(Request $request, $id)
    {
        $update = AppUpdate::find($id);
        if (!$update) {
            return response()->json([
                'success' => false,
                'message' => 'Data pembaruan tidak ditemukan.',
            ], 404);
        }

        $update->is_published = true;
        $update->published_at = Carbon::now('Asia/Jakarta');
        $update->save();

        // Siarkan pengumuman ke channel khusus update (1572971111266910289)
        \App\Services\DiscordAppUpdateService::broadcastPublishedUpdate($update, 'Administrator');

        return response()->json([
            'success' => true,
            'message' => "Pembaruan versi {$update->version} berhasil dipublikasikan.",
            'data' => $update,
        ]);
    }

    /**
     * Membatalkan publikasi pembaruan aplikasi.
     */
    public function unpublish(Request $request, $id)
    {
        $update = AppUpdate::find($id);
        if (!$update) {
            return response()->json([
                'success' => false,
                'message' => 'Data pembaruan tidak ditemukan.',
            ], 404);
        }

        $update->is_published = false;
        $update->save();

        return response()->json([
            'success' => true,
            'message' => "Publikasi pembaruan versi {$update->version} telah dinonaktifkan.",
            'data' => $update,
        ]);
    }

    /**
     * Menghapus record pembaruan aplikasi.
     */
    public function destroy(Request $request, $id)
    {
        $update = AppUpdate::find($id);
        if (!$update) {
            return response()->json([
                'success' => false,
                'message' => 'Data pembaruan tidak ditemukan.',
            ], 404);
        }

        $version = $update->version;
        $update->delete();

        return response()->json([
            'success' => true,
            'message' => "Pembaruan versi {$version} berhasil dihapus.",
        ]);
    }
}
