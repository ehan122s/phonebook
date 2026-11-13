<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class UserController extends Controller
{
    /**
     * Mengambil seluruh daftar pengguna dari database.
     */
    public function index()
    {
        $users = User::orderBy('id', 'desc')->get()->map(function ($u) {
            return [
                'id' => (string) $u->id,
                'nip' => (string) ($u->nip ?? ''),
                'name' => (string) $u->name,
                'email' => (string) $u->email,
                'whatsapp' => (string) ($u->whatsapp_number ?? ''),
                'wilayah' => (string) ($u->wilayah ?? 'CDK Wilayah Garut'),
                'role' => (string) ($u->role ?? 'user'),
                'status' => (string) ($u->status ?? 'Aktif'),
                'avatar' => (string) ($u->avatar ?? ''),
            ];
        });

        return response()->json([
            'success' => true,
            'message' => 'Daftar pengguna berhasil dimuat',
            'data' => $users,
        ]);
    }

    /**
     * Menyimpan atau memperbarui pengguna di database.
     */
    public function store(Request $request)
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'email' => 'required|email|max:255',
            'nip' => 'nullable|string|max:50',
            'whatsapp' => 'nullable|string|max:25',
            'wilayah' => 'nullable|string|max:150',
            'role' => 'nullable|string|max:50',
            'status' => 'nullable|string|max:20',
        ]);

        $email = strtolower(trim($validated['email']));
        $user = User::where('email', $email)->first();

        $data = [
            'name' => trim($validated['name']),
            'email' => $email,
            'nip' => $validated['nip'] ?? '',
            'whatsapp_number' => $validated['whatsapp'] ?? '',
            'wilayah' => $validated['wilayah'] ?? 'CDK Wilayah Garut',
            'role' => $validated['role'] ?? 'user',
            'status' => $validated['status'] ?? 'Aktif',
        ];

        if (!$user) {
            $data['password'] = Hash::make(Str::random(32));
            $user = User::create($data);
        } else {
            $user->update($data);
        }

        return response()->json([
            'success' => true,
            'message' => 'Pengguna berhasil disimpan',
            'data' => [
                'id' => (string) $user->id,
                'nip' => (string) ($user->nip ?? ''),
                'name' => (string) $user->name,
                'email' => (string) $user->email,
                'whatsapp' => (string) ($user->whatsapp_number ?? ''),
                'wilayah' => (string) ($user->wilayah ?? ''),
                'role' => (string) ($user->role ?? 'user'),
                'status' => (string) ($user->status ?? 'Aktif'),
            ],
        ]);
    }

    /**
     * Menghapus pengguna dari database.
     */
    public function destroy($id)
    {
        $user = User::where('id', $id)->orWhere('email', $id)->first();

        if ($user) {
            $user->delete();
            return response()->json([
                'success' => true,
                'message' => 'Pengguna berhasil dihapus',
            ]);
        }

        return response()->json([
            'success' => false,
            'message' => 'Pengguna tidak ditemukan',
        ], 404);
    }
}
