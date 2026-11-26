<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Material;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class MaterialVisibilityTest extends TestCase
{
    use RefreshDatabase;

    private User $penyuluh;
    private User $koordinator;
    private User $admin;

    protected function setUp(): void
    {
        parent::setUp();

        $this->penyuluh = User::create([
            'name' => 'Penyuluh Kehutanan 1',
            'email' => 'penyuluh1@kehutanan.go.id',
            'password' => Hash::make('password123'),
            'role' => 'user',
            'status' => 'Aktif',
            'jabatan' => 'Penyuluh Kehutanan',
        ]);

        $this->koordinator = User::create([
            'name' => 'Koordinator Wilayah 2',
            'email' => 'koordinator2@kehutanan.go.id',
            'password' => Hash::make('password123'),
            'role' => 'user',
            'status' => 'Aktif',
            'jabatan' => 'Koordinator Penyuluh',
        ]);

        $this->admin = User::create([
            'name' => 'Administrator CDK',
            'email' => 'admin@kehutanan.go.id',
            'password' => Hash::make('admin12345'),
            'role' => 'admin',
            'status' => 'Aktif',
            'jabatan' => 'Administrator',
        ]);
    }

    public function test_materials_uploaded_by_admin_penyuluh_koordinator_are_visible_and_downloadable_by_all_active_users(): void
    {
        Storage::fake('public');
        $category = Category::create(['name' => 'Penyuluhan', 'description' => 'Materi penyuluhan']);

        // 1. Admin unggah materi via file <= 20MB
        Sanctum::actingAs($this->admin);
        $adminRes = $this->postJson('/api/materials', [
            'title' => 'Panduan RHL Admin',
            'category_id' => $category->id,
            'category_name' => 'Penyuluhan',
            'description' => 'Materi resmi dari admin',
            'file_type' => 'PDF',
            'file' => UploadedFile::fake()->create('panduan_rhl.pdf', 1024, 'application/pdf'),
        ]);
        $adminRes->assertStatus(201);
        $adminMaterialId = $adminRes->json('data.id');

        // 2. Penyuluh (Akun 1) unggah materi via Google Drive URL
        Sanctum::actingAs($this->penyuluh);
        $penyuluhRes = $this->postJson('/api/materials', [
            'title' => 'Teknik Agroforestri Penyuluh',
            'category_name' => 'Konservasi & Ekosistem',
            'description' => 'Materi dari penyuluh lapangan',
            'file_type' => 'PDF',
            'drive_url' => 'https://drive.google.com/file/d/abc123/view',
        ]);
        $penyuluhRes->assertStatus(201);
        $penyuluhMaterialId = $penyuluhRes->json('data.id');

        // 3. Koordinator (Akun 2) unggah materi
        Sanctum::actingAs($this->koordinator);
        $koordRes = $this->postJson('/api/materials', [
            'title' => 'SOP Patroli Karhutla Koordinator',
            'category_name' => 'Kebakaran Hutan',
            'description' => 'Materi koordinasi karhutla',
            'file_type' => 'DOCX',
            'drive_url' => 'https://drive.google.com/file/d/xyz789/view',
        ]);
        $koordRes->assertStatus(201);
        $koordMaterialId = $koordRes->json('data.id');

        // 4. Verifikasi SEMUA akun aktif melihat ketiga materi tersebut
        foreach ([$this->penyuluh, $this->koordinator, $this->admin] as $viewer) {
            Sanctum::actingAs($viewer);
            $listRes = $this->getJson('/api/materials');
            $listRes->assertStatus(200)->assertJson(['success' => true]);

            $titles = collect($listRes->json('data'))->pluck('title')->all();
            $this->assertContains('Panduan RHL Admin', $titles);
            $this->assertContains('Teknik Agroforestri Penyuluh', $titles);
            $this->assertContains('SOP Patroli Karhutla Koordinator', $titles);

            // Verifikasi bisa membuka detail & download materi milik akun lain
            $this->getJson("/api/materials/{$adminMaterialId}")->assertStatus(200);
            $this->getJson("/api/materials/{$penyuluhMaterialId}")->assertStatus(200);
            $this->getJson("/api/materials/{$koordMaterialId}")->assertStatus(200);

            $this->get("/api/materials/{$adminMaterialId}/download")->assertStatus(200);
            $this->get("/api/materials/{$penyuluhMaterialId}/download")->assertStatus(302);
        }
    }

    public function test_material_rbac_edit_and_delete_enforced_strictly(): void
    {
        Sanctum::actingAs($this->penyuluh);
        $createRes = $this->postJson('/api/materials', [
            'title' => 'Materi Milik Penyuluh',
            'category_name' => 'Penyuluhan',
            'drive_url' => 'https://drive.google.com/file/d/own123/view',
        ]);
        $createRes->assertStatus(201);
        $materialId = $createRes->json('data.id');

        // Akun 2 (Koordinator) TIDAK boleh mengedit atau menghapus materi milik Akun 1 (Penyuluh)
        Sanctum::actingAs($this->koordinator);
        $this->putJson("/api/materials/{$materialId}", ['title' => 'Dibajak Koordinator'])
            ->assertStatus(403);
        $this->putJson("/api/materials/{$materialId}/public", ['title' => 'Dibajak via Public'])
            ->assertStatus(403);
        $this->deleteJson("/api/materials/{$materialId}")
            ->assertStatus(403);
        $this->deleteJson("/api/materials/{$materialId}/public")
            ->assertStatus(403);

        // Akun 1 (Penyuluh pemilik) BOLEH mengedit materinya sendiri
        Sanctum::actingAs($this->penyuluh);
        $this->putJson("/api/materials/{$materialId}", ['title' => 'Materi Penyuluh Revisi'])
            ->assertStatus(200)
            ->assertJsonPath('data.title', 'Materi Penyuluh Revisi');

        // Admin BOLEH mengedit & menghapus materi milik siapa saja
        Sanctum::actingAs($this->admin);
        $this->putJson("/api/materials/{$materialId}", ['title' => 'Materi Diedit Admin'])
            ->assertStatus(200)
            ->assertJsonPath('data.title', 'Materi Diedit Admin');
        $this->deleteJson("/api/materials/{$materialId}")
            ->assertStatus(200);

        $this->assertDatabaseMissing('materials', ['id' => $materialId]);
    }
}
