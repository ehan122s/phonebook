<?php

namespace Tests\Feature;

use App\Models\User;
use App\Services\MonitoringCalculationService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Hash;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class MonitoringReportTest extends TestCase
{
    use RefreshDatabase;

    private User $akun1;
    private User $akun2;
    private User $admin;

    protected function setUp(): void
    {
        parent::setUp();

        $this->akun1 = User::create([
            'name' => 'Penyuluh Monitoring',
            'email' => 'monitoring1@kehutanan.go.id',
            'password' => Hash::make('password123'),
            'role' => 'user',
            'status' => 'Aktif',
        ]);

        $this->akun2 = User::create([
            'name' => 'Pegawai Lain',
            'email' => 'monitoring2@kehutanan.go.id',
            'password' => Hash::make('password123'),
            'role' => 'user',
            'status' => 'Aktif',
        ]);

        $this->admin = User::create([
            'name' => 'Admin Monitoring',
            'email' => 'admin.monitoring@kehutanan.go.id',
            'password' => Hash::make('admin12345'),
            'role' => 'admin',
            'status' => 'Aktif',
        ]);
    }

    public function test_monitoring_calculation_service_handles_valid_exceeded_and_zero_targets(): void
    {
        $service = app(MonitoringCalculationService::class);

        $partial = $service->calculate(5, 3);
        $this->assertEquals(60.0, $partial['achievement_percentage']);
        $this->assertEquals(2.0, $partial['remaining_target']);
        $this->assertSame(MonitoringCalculationService::STATUS_NOT_ACHIEVED, $partial['achievement_status']);

        $exceeded = $service->calculate(10, 12);
        $this->assertEquals(120.0, $exceeded['achievement_percentage']);
        $this->assertEquals(0.0, $exceeded['remaining_target']);
        $this->assertSame(MonitoringCalculationService::STATUS_ACHIEVED, $exceeded['achievement_status']);

        $zeroTarget = $service->calculate(0, 4);
        $this->assertNull($zeroTarget['achievement_percentage']);
        $this->assertNull($zeroTarget['remaining_target']);
        $this->assertSame(MonitoringCalculationService::STATUS_NEEDS_CHECK, $zeroTarget['achievement_status']);

        $missingActual = $service->calculate(5, null);
        $this->assertNull($missingActual['achievement_percentage']);
        $this->assertSame(MonitoringCalculationService::STATUS_NEEDS_CHECK, $missingActual['achievement_status']);
    }

    public function test_user_can_create_monitoring_report_with_authoritative_server_calculation(): void
    {
        Sanctum::actingAs($this->akun1);

        $response = $this->postJson('/api/reports', [
            'report_type' => 'monitoring',
            'title' => 'Monitoring Pembinaan KTH Semester II',
            'activity_date' => '2026-11-27',
            'location' => 'Kecamatan Cisurupan, Garut',
            'status' => 'terkirim',
            'activity_name' => 'Pembinaan Kelompok Tani Hutan',
            'monitoring_period' => 'Oktober - November 2026',
            'officer_name' => 'Penyuluh Monitoring',
            'target_value' => 5,
            'target_unit' => 'kelompok',
            'target_period' => '2 bulan',
            'actual_value' => 3,
            // Tampered client metrics should be overridden by backend calculation.
            'achievement_percentage' => 99,
            'remaining_target' => 0,
            'achievement_status' => 'Tercapai',
            'field_facts' => '3 kelompok sudah aktif memproduksi bibit.',
            'obstacles' => 'Akses jalan ke 2 kelompok lainnya terdampak longsor.',
            'failure_causes' => 'Curah hujan tinggi memutus jalan desa.',
            'recommendations' => 'Jadwalkan ulang pendampingan bersama aparat desa.',
            'follow_up_plan' => 'Kunjungan lanjutan pekan depan.',
            'next_target_date' => '2026-12-07',
        ]);

        $response->assertStatus(201)
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.report_type', 'monitoring')
            ->assertJsonPath('data.target_unit', 'kelompok')
            ->assertJsonPath('data.achievement_status', MonitoringCalculationService::STATUS_NOT_ACHIEVED);

        $data = $response->json('data');
        $this->assertEquals(5.0, (float) $data['target_value']);
        $this->assertEquals(3.0, (float) $data['actual_value']);
        $this->assertEquals(60.0, (float) $data['achievement_percentage']);
        $this->assertEquals(2.0, (float) $data['remaining_target']);
        $this->assertNotEmpty($data['description']);
        $this->assertStringContainsString('5 kelompok', $data['description']);
        $this->assertStringContainsString('60%', $data['description']);
    }

    public function test_monitoring_supports_custom_units_and_marks_tercapai_when_actual_meets_target(): void
    {
        Sanctum::actingAs($this->akun1);

        $response = $this->postJson('/api/reports', [
            'report_type' => 'monitoring',
            'title' => 'Monitoring Penanaman Bibit',
            'activity_date' => '2026-11-27',
            'location' => 'Blok Cikajang',
            'status' => 'terkirim',
            'activity_name' => 'Penanaman Bibit Penghijauan',
            'monitoring_period' => 'November 2026',
            'officer_name' => 'Penyuluh Monitoring',
            'target_value' => 100,
            'target_unit' => 'batang',
            'target_period' => '1 bulan',
            'actual_value' => 115,
            'field_facts' => 'Penanaman selesai 115 batang bersama warga.',
            'obstacles' => 'Tidak ada kendala berarti.',
            'recommendations' => 'Lanjutkan pemeliharaan berkala.',
            'follow_up_plan' => 'Pengecekan pertumbuhan 30 hari ke depan.',
        ]);

        $response->assertStatus(201)
            ->assertJsonPath('data.achievement_status', MonitoringCalculationService::STATUS_ACHIEVED)
            ->assertJsonPath('data.target_unit', 'batang');

        $data = $response->json('data');
        $this->assertEquals(115.0, (float) $data['achievement_percentage']);
        $this->assertEquals(0.0, (float) $data['remaining_target']);
    }

    public function test_finalized_monitoring_rejects_zero_target_or_missing_actual_and_supports_draft_edit(): void
    {
        Sanctum::actingAs($this->akun1);

        // Finalizing with zero target must fail validation cleanly (no division by zero).
        $invalidRes = $this->postJson('/api/reports', [
            'report_type' => 'monitoring',
            'title' => 'Monitoring Tidak Valid',
            'activity_date' => '2026-11-27',
            'location' => 'Garut',
            'status' => 'terkirim',
            'activity_name' => 'Patroli',
            'monitoring_period' => 'Nov 2026',
            'officer_name' => 'Petugas',
            'target_value' => 0,
            'target_unit' => 'lokasi',
            'target_period' => '1 bulan',
            'actual_value' => 2,
            'field_facts' => 'Fakta',
            'obstacles' => 'Kendala',
            'recommendations' => 'Rekomendasi',
            'follow_up_plan' => 'Tindak lanjut',
        ]);
        $invalidRes->assertStatus(422);

        // Partial Monitoring draft IS allowed without all required submit fields.
        $draftRes = $this->postJson('/api/reports', [
            'report_type' => 'monitoring',
            'title' => 'Draft Monitoring Awal',
            'activity_date' => '2026-11-27',
            'location' => 'KPH Garut',
            'status' => 'draft',
            'target_value' => 0,
            'target_unit' => 'peserta',
        ]);
        $draftRes->assertStatus(201)
            ->assertJsonPath('data.status', 'draft')
            ->assertJsonPath('data.achievement_status', MonitoringCalculationService::STATUS_NEEDS_CHECK);

        $reportId = $draftRes->json('data.id');

        // Edit draft before completion and finalize.
        $updateRes = $this->putJson("/api/reports/{$reportId}", [
            'report_type' => 'monitoring',
            'title' => 'Monitoring Final Setelah Edit',
            'activity_date' => '2026-11-27',
            'location' => 'KPH Garut',
            'status' => 'terkirim',
            'activity_name' => 'Pelatihan Peserta KTH',
            'monitoring_period' => 'November 2026',
            'officer_name' => 'Penyuluh Monitoring',
            'target_value' => 20,
            'target_unit' => 'peserta',
            'target_period' => '1 minggu',
            'actual_value' => 20,
            'field_facts' => 'Seluruh 20 peserta hadir.',
            'obstacles' => 'Ruangan cukup padat.',
            'recommendations' => 'Gunakan balai desa lebih luas.',
            'follow_up_plan' => 'Evaluasi materi bulan depan.',
        ]);

        $updateRes->assertStatus(200)
            ->assertJsonPath('data.status', 'terkirim')
            ->assertJsonPath('data.achievement_status', MonitoringCalculationService::STATUS_ACHIEVED);

        $this->assertEquals(100.0, (float) $updateRes->json('data.achievement_percentage'));
        $this->assertEquals(0.0, (float) $updateRes->json('data.remaining_target'));
    }

    public function test_monitoring_report_respects_user_isolation_and_standard_reports_remain_working(): void
    {
        Sanctum::actingAs($this->akun1);

        $monRes = $this->postJson('/api/reports', [
            'report_type' => 'monitoring',
            'title' => 'Monitoring Privat Akun 1',
            'activity_date' => '2026-11-27',
            'location' => 'Pakuwon',
            'status' => 'draft',
            'target_value' => 4,
            'target_unit' => 'dokumen',
            'actual_value' => 2,
        ]);
        $monRes->assertStatus(201);
        $monId = $monRes->json('data.id');

        // Standard report continues working as before.
        $stdRes = $this->postJson('/api/reports', [
            'title' => 'Laporan Kegiatan Biasa',
            'activity_date' => '2026-11-27',
            'location' => 'Pakuwon',
            'description' => 'Kegiatan berjalan lancar.',
            'status' => 'terkirim',
        ]);
        $stdRes->assertStatus(201)
            ->assertJsonPath('data.report_type', 'standard');

        // Another user cannot view/edit Monitoring report owned by Akun 1.
        Sanctum::actingAs($this->akun2);
        $this->getJson("/api/reports/{$monId}")->assertStatus(404);
        $this->putJson("/api/reports/{$monId}", ['title' => 'Bypass'])->assertStatus(404);

        // Admin CAN view Akun 1's Monitoring report.
        Sanctum::actingAs($this->admin);
        $this->getJson("/api/reports/{$monId}")
            ->assertStatus(200)
            ->assertJsonPath('data.report_type', 'monitoring');
    }

    public function test_report_templates_endpoint_includes_updated_laporan_monitoring(): void
    {
        Cache::forget('report_templates_active_v3');

        $response = $this->getJson('/api/report-templates');
        $response->assertStatus(200)->assertJsonPath('success', true);

        $templates = $response->json('data');
        $monitoring = collect($templates)->firstWhere('name', 'Laporan Monitoring');

        $this->assertNotNull($monitoring);
        $this->assertSame('Monitoring & Evaluasi', $monitoring['category']);
        $this->assertFalse((bool) $monitoring['require_photo']);
    }
}
