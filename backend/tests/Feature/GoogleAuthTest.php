<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class GoogleAuthTest extends TestCase
{
    public function test_rejects_missing_id_token()
    {
        $response = $this->postJson('/api/auth/google', []);
        $response->assertStatus(422)
                 ->assertJsonValidationErrors(['id_token']);
    }

    public function test_rejects_invalid_token_from_google()
    {
        Http::fake([
            'https://oauth2.googleapis.com/tokeninfo*' => Http::response([
                'error' => 'invalid_token',
                'error_description' => 'Invalid Value',
            ], 400),
        ]);

        $response = $this->postJson('/api/auth/google', [
            'id_token' => 'invalid_fake_token',
        ]);

        $response->assertStatus(401)
                 ->assertJson([
                     'success' => false,
                     'message' => 'Token Google ID tidak valid atau telah kedaluwarsa.',
                 ]);
    }

    public function test_rejects_unverified_email()
    {
        Http::fake([
            'https://oauth2.googleapis.com/tokeninfo*' => Http::response([
                'iss' => 'https://accounts.google.com',
                'aud' => '52603373586-iv996p86tugj1e4nnldh994p3cec4j7n.apps.googleusercontent.com',
                'sub' => '1234567890',
                'email' => 'unverified@example.com',
                'email_verified' => 'false',
                'name' => 'Unverified User',
                'exp' => time() + 3600,
            ], 200),
        ]);

        $response = $this->postJson('/api/auth/google', [
            'id_token' => 'mock_token',
        ]);

        $response->assertStatus(403)
                 ->assertJson([
                     'success' => false,
                     'message' => 'Email Akun Google Anda belum diverifikasi oleh Google.',
                 ]);
    }

    public function test_rejects_disallowed_audience()
    {
        Http::fake([
            'https://oauth2.googleapis.com/tokeninfo*' => Http::response([
                'iss' => 'https://accounts.google.com',
                'aud' => 'attacker_client_id.apps.googleusercontent.com',
                'sub' => '1234567890',
                'email' => 'user@example.com',
                'email_verified' => 'true',
                'name' => 'Valid User',
                'exp' => time() + 3600,
            ], 200),
        ]);

        $response = $this->postJson('/api/auth/google', [
            'id_token' => 'mock_token',
        ]);

        $response->assertStatus(401)
                 ->assertJson([
                     'success' => false,
                     'message' => 'Audience token tidak dikenali oleh sistem Phonebook CDK V.',
                 ]);
    }

    public function test_authenticates_existing_user_with_valid_token()
    {
        $email = 'pegawai.test.' . time() . '@kehutanan.go.id';
        $user = User::create([
            'name' => 'Pegawai Test',
            'email' => $email,
            'password' => bcrypt('secret123'),
            'role' => 'user',
            'status' => 'Aktif',
        ]);

        Http::fake([
            'https://oauth2.googleapis.com/tokeninfo*' => Http::response([
                'iss' => 'https://accounts.google.com',
                'aud' => '52603373586-iv996p86tugj1e4nnldh994p3cec4j7n.apps.googleusercontent.com',
                'sub' => 'google_sub_99999',
                'email' => $email,
                'email_verified' => 'true',
                'name' => 'Pegawai Test',
                'picture' => 'https://example.com/avatar.jpg',
                'exp' => time() + 3600,
            ], 200),
        ]);

        $response = $this->postJson('/api/auth/google', [
            'id_token' => 'valid_mock_token',
        ]);

        $response->assertStatus(200)
                 ->assertJson([
                     'success' => true,
                     'is_registered' => true,
                     'message' => 'Login Google berhasil.',
                 ])
                 ->assertJsonStructure([
                     'data' => [
                         'user' => ['id', 'email', 'name'],
                         'token',
                     ],
                 ]);

        $user->delete();
    }

    public function test_rejects_inactive_user()
    {
        $email = 'nonaktif.' . time() . '@kehutanan.go.id';
        $user = User::create([
            'name' => 'Pegawai Nonaktif',
            'email' => $email,
            'password' => bcrypt('secret123'),
            'role' => 'user',
            'status' => 'Nonaktif',
        ]);

        Http::fake([
            'https://oauth2.googleapis.com/tokeninfo*' => Http::response([
                'iss' => 'https://accounts.google.com',
                'aud' => '52603373586-iv996p86tugj1e4nnldh994p3cec4j7n.apps.googleusercontent.com',
                'sub' => 'google_sub_inactive',
                'email' => $email,
                'email_verified' => 'true',
                'name' => 'Pegawai Nonaktif',
                'exp' => time() + 3600,
            ], 200),
        ]);

        $response = $this->postJson('/api/auth/google', [
            'id_token' => 'mock_token',
        ]);

        $response->assertStatus(403)
                 ->assertJson([
                     'success' => false,
                     'message' => 'Akun Anda berstatus Nonaktif. Silakan hubungi Administrator CDK V.',
                 ]);

        $user->delete();
    }

    public function test_auto_registers_new_user_with_valid_token()
    {
        $email = 'new.pegawai.' . time() . '@kehutanan.go.id';

        Http::fake([
            'https://oauth2.googleapis.com/tokeninfo*' => Http::response([
                'iss' => 'https://accounts.google.com',
                'aud' => '52603373586-iv996p86tugj1e4nnldh994p3cec4j7n.apps.googleusercontent.com',
                'sub' => 'google_sub_new_user',
                'email' => $email,
                'email_verified' => 'true',
                'name' => 'Pegawai Baru',
                'picture' => 'https://example.com/photo.jpg',
                'exp' => time() + 3600,
            ], 200),
        ]);

        $response = $this->postJson('/api/auth/google', [
            'id_token' => 'valid_token_new_user',
            'nip' => '19980101 202301 1 001',
            'jabatan' => 'Penyuluh Kehutanan Pemula',
            'wilayah' => 'Garut Selatan',
        ]);

        $response->assertStatus(201)
                 ->assertJson([
                     'success' => true,
                     'is_registered' => true,
                     'message' => 'Pendaftaran akun Google berhasil dan telah diverifikasi.',
                 ]);

        $user = User::where('email', $email)->first();
        $this->assertNotNull($user);
        $this->assertEquals('Pegawai Baru', $user->name);
        $this->assertEquals('19980101 202301 1 001', $user->nip);
        $this->assertEquals('user', $user->role);
        $this->assertEquals('Aktif', $user->status);

        $user->delete();
    }
}
