<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
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

    public function googleLogin(Request $request)
    {
        $validated = $request->validate([
            'email' => 'required|email|max:255',
            'name' => 'required|string|max:255',
            'google_id' => 'nullable|string|max:255',
            'avatar' => 'nullable|string|max:1000',
        ]);

        $email = strtolower(trim($validated['email']));
        $name = trim($validated['name']);

        $user = User::where('email', $email)->first();

        $isAdminEmail = str_starts_with($email, 'admin@') ||
            $email === 'admin@kehutanan.go.id' ||
            $email === 'admin@phonebook.com' ||
            $email === 'admin@gmail.com';

        if (!$user) {
            $user = User::create([
                'name' => $name,
                'email' => $email,
                'password' => Hash::make(\Illuminate\Support\Str::random(32)),
                'role' => $isAdminEmail ? 'admin' : 'user',
            ]);
        } else {
            if ($isAdminEmail && ($user->role !== 'admin')) {
                $user->role = 'admin';
                $user->save();
            }
        }

        $token = $user->createToken('phonebook-token')->plainTextToken;

        return response()->json([
            'success' => true,
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
}