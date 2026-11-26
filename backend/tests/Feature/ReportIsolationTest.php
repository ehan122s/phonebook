<?php

namespace Tests\Feature;

use App\Models\Report;
use App\Models\ReportPhoto;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ReportIsolationTest extends TestCase
{
    use RefreshDatabase;

    private User $akun1;
    private User $akun2;
    private User $admin;

    protected function setUp(): void
    {
        parent::setUp();

        $this->akun1 = User::create([
            'name' => 'Penyuluh Satu',
            'email' => 'akun1@kehutanan.go.id',
            'password' => Hash::make('password123'),
            'role' => 'user',
            'status' => 'Aktif',
        ]);

        $this->akun2 = User::create([
            'name' => 'Koordinator Dua',
            'email' => 'akun2@kehutanan.go.id',
            'password' => Hash::make('password123'),
            'role' => 'user',
            'status' => 'Aktif',
        ]);

        $this->admin = User::create([
            'name' => 'Admin Kehutanan',
            'email' => 'admin@kehutanan.go.id',
            'password' => Hash::make('admin12345'),
            'role' => 'admin',
            'status' => 'Aktif',
        ]);
    }

    public function test_user_cannot_view_edit_delete_or_attach_photo_to_another_users_report(): void
    {
        Sanctum::actingAs($this->akun1);

        $createRes = $this->postJson('/api/reports', [
            'title' => 'Laporan Rahasia Akun 1',
            'activity_date' => '2026-11-26',
            'location' => 'KPH Garut',
            'latitude' => -7.216,
            'longitude' => 107.901,
            'status' => 'terkirim',
        ]);
        $createRes->assertStatus(201);
        $reportId = $createRes->json('data.id');

        $photo = ReportPhoto::create([
            'report_id' => $reportId,
            'photo' => 'reports/sample.jpg',
            'latitude' => -7.216,
            'longitude' => 107.901,
        ]);

        // Akun 2 tidak boleh melihat laporan Akun 1 di daftar
        Sanctum::actingAs($this->akun2);
        $listRes = $this->getJson('/api/reports');
        $listRes->assertStatus(200);
        $ids = collect($listRes->json('data'))->pluck('id')->all();
        $this->assertNotContains($reportId, $ids);

        // Akun 2 tidak boleh melihat detail, mengedit, menghapus, atau menambah/menghapus foto laporan Akun 1
        $this->getJson("/api/reports/{$reportId}")->assertStatus(404);
        $this->putJson("/api/reports/{$reportId}", ['title' => 'Dibajak'])->assertStatus(404);
        $this->deleteJson("/api/reports/{$reportId}")->assertStatus(404);
        $this->postJson("/api/reports/{$reportId}/photos", ['photo_base64' => base64_encode('fake')])->assertStatus(404);
        $this->deleteJson("/api/report-photos/{$photo->id}")->assertStatus(404);

        // Admin tetap bisa melihat laporan Akun 1
        Sanctum::actingAs($this->admin);
        $adminList = $this->getJson('/api/reports');
        $adminList->assertStatus(200);
        $this->assertContains($reportId, collect($adminList->json('data'))->pluck('id')->all());
        $this->getJson("/api/reports/{$reportId}")->assertStatus(200);

        // Pemilik (Akun 1) dapat menghapus laporannya yang memiliki foto tanpa error foreign key (SQLSTATE)
        Sanctum::actingAs($this->akun1);
        $this->deleteJson("/api/reports/{$reportId}")->assertStatus(200);
        $this->assertDatabaseMissing('reports', ['id' => $reportId]);
        $this->assertDatabaseMissing('report_photos', ['id' => $photo->id]);
    }
}
