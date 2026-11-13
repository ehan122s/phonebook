<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    public function register(Request $request)
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'email' => 'required|email|max:255|unique:users,email',
            'password' => 'required|string|min:8|confirmed',
        ]);

        $user = User::create([
            'name' => $validated['name'],
            'email' => $validated['email'],
            'password' => Hash::make($validated['password']),
        ]);

        $token = $user->createToken('phonebook-token')->plainTextToken;

        return response()->json([
            'success' => true,
            'message' => 'Registrasi berhasil',
            'data' => [
                'user' => $user,
                'token' => $token,
            ],
        ], 201);
    }

    public function login(Request $request)
    {
        $validated = $request->validate([
            'email' => 'required|email',
            'password' => 'required|string',
        ]);

        $user = User::where('email', $validated['email'])->first();

        if (!$user || !Hash::check($validated['password'], $user->password)) {
            throw ValidationException::withMessages([
                'email' => ['Email atau password salah.'],
            ]);
        }

        $token = $user->createToken('phonebook-token')->plainTextToken;

        return response()->json([
            'success' => true,
            'message' => 'Login berhasil',
            'data' => [
                'user' => $user,
                'token' => $token,
            ],
        ]);
    }

    /**
     * Otentikasi resmi Google OAuth 2.0 via Google ID Token.
     * Menerima id_token dari client Flutter, memverifikasi tanda tangan kriptografis,
     * issuer, audience, masa berlaku, dan status email_verified langsung ke Google API.
     */
    public function googleAuth(Request $request)
    {
        $validated = $request->validate([
            'id_token' => 'required|string',
            'nip' => 'nullable|string|max:50',
            'jabatan' => 'nullable|string|max:100',
            'wilayah' => 'nullable|string|max:150',
            'whatsapp_number' => 'nullable|string|max:25',
        ]);

        $idToken = trim($validated['id_token']);

        // 1. Verifikasi tanda tangan dan keaslian ID Token langsung ke server resmi Google
        try {
            $googleResponse = Http::timeout(8)->get('https://oauth2.googleapis.com/tokeninfo', [
                'id_token' => $idToken,
            ]);
        } catch (\Throwable $e) {
            return response()->json([
                'success' => false,
                'message' => 'Gagal menghubungi server verifikasi Google: ' . $e->getMessage(),
            ], 503);
        }

        if (!$googleResponse->successful()) {
            return response()->json([
                'success' => false,
                'message' => 'Token Google ID tidak valid atau telah kedaluwarsa.',
                'error_detail' => $googleResponse->json('error_description') ?? $googleResponse->json('error'),
            ], 401);
        }

        $payload = $googleResponse->json();

        // 2. Verifikasi Issuer (harus accounts.google.com atau https://accounts.google.com)
        $issuer = $payload['iss'] ?? '';
        if ($issuer !== 'accounts.google.com' && $issuer !== 'https://accounts.google.com') {
            return response()->json([
                'success' => false,
                'message' => 'Issuer token tidak valid.',
            ], 401);
        }

        // 3. Verifikasi Audience (harus cocok dengan salah satu Client ID aplikasi Phonebook)
        $audience = $payload['aud'] ?? '';
        $allowedClientIds = config('services.google.allowed_client_ids', []);
        $primaryClientId = config('services.google.client_id');
        if ($primaryClientId && !in_array($primaryClientId, $allowedClientIds, true)) {
            $allowedClientIds[] = $primaryClientId;
        }

        if (!empty($allowedClientIds) && !in_array($audience, $allowedClientIds, true)) {
            return response()->json([
                'success' => false,
                'message' => 'Audience token tidak dikenali oleh sistem Phonebook CDK V.',
                'aud' => $audience,
            ], 401);
        }

        // 4. Verifikasi Masa Berlaku (exp)
        $exp = isset($payload['exp']) ? (int) $payload['exp'] : 0;
        if ($exp < time()) {
            return response()->json([
                'success' => false,
                'message' => 'Sesi token Google telah kedaluwarsa.',
            ], 401);
        }

        // 5. Verifikasi email_verified
        $emailVerified = ($payload['email_verified'] ?? '') === 'true' || ($payload['email_verified'] ?? false) === true;
        if (!$emailVerified) {
            return response()->json([
                'success' => false,
                'message' => 'Email Akun Google Anda belum diverifikasi oleh Google.',
            ], 403);
        }

        // 6. Ambil data terverifikasi dari Google payload
        $email = strtolower(trim($payload['email'] ?? ''));
        $name = trim($payload['name'] ?? ($payload['given_name'] ?? explode('@', $email)[0]));
        $googleId = (string) ($payload['sub'] ?? '');
        $avatar = $payload['picture'] ?? null;

        if (empty($email)) {
            return response()->json([
                'success' => false,
                'message' => 'Data email tidak ditemukan dalam klaim token Google.',
            ], 422);
        }

        // 7. Evaluasi hak akses dan status pengguna di database Phonebook
        $user = User::where('email', $email)->first();

        $isAdminEmail = str_starts_with($email, 'admin@') ||
            $email === 'admin@kehutanan.go.id' ||
            $email === 'admin@phonebook.com' ||
            $email === 'admin@gmail.com';

        if ($user) {
            // Cek status akun
            if (isset($user->status) && strtolower($user->status) === 'nonaktif') {
                return response()->json([
                    'success' => false,
                    'message' => 'Akun Anda berstatus Nonaktif. Silakan hubungi Administrator CDK V.',
                ], 403);
            }

            // Perbarui data Google jika belum tersimpan
            $updates = [];
            if (empty($user->google_id) && !empty($googleId)) {
                $updates['google_id'] = $googleId;
            }
            if (empty($user->avatar) && !empty($avatar)) {
                $updates['avatar'] = $avatar;
            }
            if ($isAdminEmail && $user->role !== 'admin') {
                $updates['role'] = 'admin';
            }
            if (!empty($validated['nip']) && empty($user->nip)) {
                $updates['nip'] = trim($validated['nip']);
            }
            if (!empty($validated['jabatan'])) {
                $updates['jabatan'] = trim($validated['jabatan']);
            }
            if (!empty($validated['wilayah'])) {
                $updates['wilayah'] = trim($validated['wilayah']);
            }
            if (!empty($validated['whatsapp_number']) && empty($user->whatsapp_number)) {
                $updates['whatsapp_number'] = trim($validated['whatsapp_number']);
            }

            if (!empty($updates)) {
                $user->update($updates);
            }

            $token = $user->createToken('phonebook-google-token')->plainTextToken;

            return response()->json([
                'success' => true,
                'is_registered' => true,
                'message' => 'Login Google berhasil.',
                'data' => [
                    'user' => $user,
                    'token' => $token,
                ],
            ]);
        }

        // 8. Registrasi otomatis untuk pengguna baru yang memiliki email Google terverifikasi
        $newUserRole = $isAdminEmail ? 'admin' : 'user';
        $userData = [
            'name' => $name,
            'email' => $email,
            'password' => Hash::make(Str::random(32)),
            'role' => $newUserRole,
            'status' => 'Aktif',
            'google_id' => $googleId,
            'avatar' => $avatar,
            'nip' => $validated['nip'] ?? '',
            'jabatan' => $validated['jabatan'] ?? 'Penyuluh Kehutanan',
            'wilayah' => $validated['wilayah'] ?? 'CDK Wilayah Garut',
            'whatsapp_number' => $validated['whatsapp_number'] ?? '',
        ];

        $user = User::create($userData);
        $token = $user->createToken('phonebook-google-token')->plainTextToken;

        return response()->json([
            'success' => true,
            'is_registered' => true,
            'message' => 'Pendaftaran akun Google berhasil dan telah diverifikasi.',
            'data' => [
                'user' => $user,
                'token' => $token,
            ],
        ], 201);
    }

    public function googleCheck(Request $request)
    {
        $validated = $request->validate([
            'email' => 'required|email|max:255',
        ]);

        $email = strtolower(trim($validated['email']));
        $user = User::where('email', $email)->first();

        if ($user) {
            $isAdminEmail = str_starts_with($email, 'admin@') ||
                $email === 'admin@kehutanan.go.id' ||
                $email === 'admin@phonebook.com' ||
                $email === 'admin@gmail.com';

            if ($isAdminEmail && ($user->role !== 'admin')) {
                $user->role = 'admin';
                $user->save();
            }

            $token = $user->createToken('phonebook-token')->plainTextToken;

            return response()->json([
                'success' => true,
                'is_registered' => true,
                'message' => 'Akun Google telah terdaftar',
                'data' => [
                    'user' => $user,
                    'token' => $token,
                ],
            ]);
        }

        return response()->json([
            'success' => true,
            'is_registered' => false,
            'message' => 'Akun Google belum terdaftar di sistem. Silakan lengkapi profil.',
            'data' => null,
        ]);
    }

    public function googleRegister(Request $request)
    {
        $validated = $request->validate([
            'email' => 'required|email|max:255',
            'name' => 'required|string|max:255',
            'nip' => 'nullable|string|max:50',
            'jabatan' => 'nullable|string|max:100',
            'wilayah' => 'nullable|string|max:150',
            'whatsapp_number' => 'nullable|string|max:25',
            'google_id' => 'nullable|string|max:255',
            'avatar' => 'nullable|string|max:1000',
        ]);

        $email = strtolower(trim($validated['email']));
        $name = trim($validated['name']);

        $isAdminEmail = str_starts_with($email, 'admin@') ||
            $email === 'admin@kehutanan.go.id' ||
            $email === 'admin@phonebook.com' ||
            $email === 'admin@gmail.com';

        $user = User::where('email', $email)->first();

        $userData = [
            'name' => $name,
            'email' => $email,
            'role' => $isAdminEmail ? 'admin' : 'user',
        ];

        if (isset($validated['nip'])) $userData['nip'] = $validated['nip'];
        if (isset($validated['jabatan'])) $userData['jabatan'] = $validated['jabatan'];
        if (isset($validated['wilayah'])) $userData['wilayah'] = $validated['wilayah'];
        if (isset($validated['whatsapp_number'])) $userData['whatsapp_number'] = $validated['whatsapp_number'];
        if (isset($validated['google_id'])) $userData['google_id'] = $validated['google_id'];
        if (isset($validated['avatar'])) $userData['avatar'] = $validated['avatar'];

        if (!$user) {
            $userData['password'] = Hash::make(\Illuminate\Support\Str::random(32));
            $user = User::create($userData);
        } else {
            $user->update($userData);
        }

        $token = $user->createToken('phonebook-token')->plainTextToken;

        return response()->json([
            'success' => true,
            'is_registered' => true,
            'message' => 'Pendaftaran akun Google berhasil',
            'data' => [
                'user' => $user,
                'token' => $token,
            ],
        ], 201);
    }

    public function googleLogin(Request $request)
    {
        $validated = $request->validate([
            'email' => 'required|email|max:255',
            'name' => 'required|string|max:255',
            'google_id' => 'nullable|string|max:255',
            'avatar' => 'nullable|string|max:1000',
            'force_create' => 'nullable|boolean',
        ]);

        $email = strtolower(trim($validated['email']));
        $name = trim($validated['name']);

        $user = User::where('email', $email)->first();

        $isAdminEmail = str_starts_with($email, 'admin@') ||
            $email === 'admin@kehutanan.go.id' ||
            $email === 'admin@phonebook.com' ||
            $email === 'admin@gmail.com';

        if (!$user) {
            if ($request->boolean('force_create')) {
                $user = User::create([
                    'name' => $name,
                    'email' => $email,
                    'password' => Hash::make(\Illuminate\Support\Str::random(32)),
                    'role' => $isAdminEmail ? 'admin' : 'user',
                ]);
            } else {
                return response()->json([
                    'success' => true,
                    'is_registered' => false,
                    'message' => 'Akun belum terdaftar. Silakan lengkapi profil terlebih dahulu.',
                    'data' => null,
                ]);
            }
        } else {
            if ($isAdminEmail && ($user->role !== 'admin')) {
                $user->role = 'admin';
                $user->save();
            }
        }

        $token = $user->createToken('phonebook-token')->plainTextToken;

        return response()->json([
            'success' => true,
            'is_registered' => true,
            'message' => 'Login Google berhasil',
            'data' => [
                'user' => $user,
                'token' => $token,
            ],
        ]);
    }

    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json([
            'success' => true,
            'message' => 'Logout berhasil',
        ]);
    }

    public function user(Request $request)
    {
        return response()->json([
            'success' => true,
            'data' => $request->user(),
        ]);
    }

    public function updateProfile(Request $request)
    {
        $user = $request->user();

        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'whatsapp_number' => 'nullable|string|max:25',
            'wilayah' => 'nullable|string|max:150',
            'avatar' => 'nullable|string|max:2000',
        ]);

        $user->name = trim($validated['name']);
        if (array_key_exists('whatsapp_number', $validated)) {
            $user->whatsapp_number = $validated['whatsapp_number'] ?? '';
        }
        if (array_key_exists('wilayah', $validated)) {
            $user->wilayah = $validated['wilayah'] ?? '';
        }
        if (array_key_exists('avatar', $validated)) {
            $user->avatar = $validated['avatar'] ?? '';
        }

        $user->save();

        return response()->json([
            'success' => true,
            'message' => 'Profil berhasil diperbarui',
            'data' => $user,
        ]);
    }

    public function changePassword(Request $request)
    {
        $user = $request->user();

        $validated = $request->validate([
            'current_password' => 'required|string',
            'new_password' => 'required|string|min:8|confirmed',
        ]);

        if (!Hash::check($validated['current_password'], $user->password)) {
            throw ValidationException::withMessages([
                'current_password' => ['Password saat ini tidak sesuai.'],
            ]);
        }

        $user->password = Hash::make($validated['new_password']);
        $user->save();

        return response()->json([
            'success' => true,
            'message' => 'Password berhasil diubah',
        ]);
    }
}