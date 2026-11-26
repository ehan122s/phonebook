<?php

namespace Tests\Feature;

use App\Models\Report;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class UserControllerTest extends TestCase
{
    use RefreshDatabase;

    private User $regularUser;
    private User $inactiveUser;
    private User $admin;

    protected function setUp(): void
    {
        parent::setUp();

        $this->regularUser = User::create([
            'name' => 'Rizky Penyuluh',
            'email' => 'rizky@kehutanan.go.id',
            'password' => Hash::make('secret123'),
            'role' => 'user',
            'status' => 'Aktif',
            'nip' => '199001012020011001',
            'wilayah' => 'Garut Selatan',
        ]);

        $this->inactiveUser = User::create([
            'name' => 'Akun Nonaktif',
            'email' => 'nonaktif@kehutanan.go.id',
            'password' => Hash::make('secret123'),
            'role' => 'user',
            'status' => 'Nonaktif',
        ]);

        $this->admin = User::create([
            'name' => 'Admin Utama',
            'email' => 'admin@kehutanan.go.id',
            'password' => Hash::make('admin12345'),
            'role' => 'admin',
            'status' => 'Aktif',
        ]);
    }

    public function test_non_admin_is_blocked_from_user_management_and_monitoring_endpoints(): void
    {
        Sanctum::actingAs($this->regularUser);

        $this->getJson('/api/users')->assertStatus(403);
        $this->postJson('/api/users', [
            'name' => 'Hacker',
            'email' => 'hacker@example.com',
            'password' => '123456',
            'password_confirmation' => '123456',
        ])->assertStatus(403);
        $this->putJson("/api/users/{$this->admin->id}", ['name' => 'Changed'])->assertStatus(403);
        $this->deleteJson("/api/users/{$this->admin->id}")->assertStatus(403);
        $this->getJson('/api/admin/monitoring')->assertStatus(403);
    }

    public function test_inactive_user_cannot_login_via_email_or_google_endpoints(): void
    {
        // Login Email/Password harus ditolak 403
        $this->postJson('/api/login', [
            'email' => 'nonaktif@kehutanan.go.id',
            'password' => 'secret123',
        ])->assertStatus(403)
            ->assertJson(['success' => false]);

        // Google Check & Google Login juga harus menolak 403
        $this->postJson('/api/google-check', [
            'email' => 'nonaktif@kehutanan.go.id',
        ])->assertStatus(403);

        $this->postJson('/api/google-login', [
            'email' => 'nonaktif@kehutanan.go.id',
            'name' => 'Akun Nonaktif',
        ])->assertStatus(403);

        // User dengan status 'aktif' (huruf kecil) di Supabase tetap bisa login (tidak dianggap nonaktif)
        $lowercaseActive = User::create([
            'name' => 'Aktif Lowercase',
            'email' => 'aktif.lower@kehutanan.go.id',
            'password' => Hash::make('secret123'),
            'role' => 'user',
            'status' => 'aktif',
        ]);
        $this->postJson('/api/login', [
            'email' => 'aktif.lower@kehutanan.go.id',
            'password' => 'secret123',
        ])->assertStatus(200)->assertJson(['success' => true]);
    }

    public function test_admin_can_search_case_insensitive_edit_without_breaking_password_and_safely_delete_user_with_relations(): void
    {
        Sanctum::actingAs($this->admin);

        // 1. Pencarian case-insensitive
        $searchRes = $this->getJson('/api/users?search=RIZKY');
        $searchRes->assertStatus(200);
        $this->assertCount(1, $searchRes->json('data'));

        // 2. Edit user tanpa mengisi password tidak merusak hash password lama
        $oldHash = $this->regularUser->password;
        $this->putJson("/api/users/{$this->regularUser->id}", [
            'name' => 'Rizky Penyuluh Updated',
            'password' => '',
        ])->assertStatus(200);

        $this->regularUser->refresh();
        $this->assertEquals('Rizky Penyuluh Updated', $this->regularUser->name);
        $this->assertEquals($oldHash, $this->regularUser->password);
        $this->assertTrue(Hash::check('secret123', $this->regularUser->password));

        // 3. Hapus user yang punya relasi laporan tidak menyebabkan HTTP 500, melainkan menonaktifkan akun
        Report::create([
            'user_id' => $this->regularUser->id,
            'title' => 'Laporan Terkait',
            'activity_date' => '2026-11-26',
            'location' => 'Garut',
            'status' => 'terkirim',
        ]);

        $delRes = $this->deleteJson("/api/users/{$this->regularUser->id}");
        $delRes->assertStatus(200)
            ->assertJson([
                'success' => true,
                'deactivated' => true,
            ]);

        $this->regularUser->refresh();
        $this->assertEquals('Nonaktif', $this->regularUser->status);
    }
}
