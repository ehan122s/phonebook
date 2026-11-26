<?php

namespace Tests\Feature;

use App\Models\Report;
use App\Models\ReportFile;
use App\Models\ReportPhoto;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Config;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ReportMediaStorageTest extends TestCase
{
    use RefreshDatabase;

    private User $user1;
    private User $user2;
    private User $admin;

    protected function setUp(): void
    {
        parent::setUp();

        $this->user1 = User::create([
            'name' => 'Penyuluh Satu',
            'email' => 'media1@kehutanan.go.id',
            'password' => Hash::make('password123'),
            'role' => 'user',
            'status' => 'Aktif',
        ]);

        $this->user2 = User::create([
            'name' => 'Penyuluh Dua',
            'email' => 'media2@kehutanan.go.id',
            'password' => Hash::make('password123'),
            'role' => 'user',
            'status' => 'Aktif',
        ]);

        $this->admin = User::create([
            'name' => 'Admin CDK V',
            'email' => 'admin.media@kehutanan.go.id',
            'password' => Hash::make('admin12345'),
            'role' => 'admin',
            'status' => 'Aktif',
        ]);

        Config::set('services.imagekit', [
            'public_key' => 'public_test_key',
            'private_key' => 'private_test_secret_should_never_leak',
            'url_endpoint' => 'https://ik.imagekit.io/testphonebook',
            'folder' => '/phonebook/reports',
            'upload_endpoint' => 'https://upload.imagekit.io/api/v1/files/upload',
            'api_endpoint' => 'https://api.imagekit.io/v1',
        ]);

        Config::set('services.supabase', [
            'url' => 'https://example.supabase.co',
            'service_role_key' => 'service_role_test_secret_should_never_leak',
            'anon_key' => 'anon_test_key',
            'storage_bucket' => 'reports',
            'storage_public' => false,
            'signed_url_expires' => 300,
        ]);
    }

    public function test_upload_view_and_delete_report_photo_via_imagekit(): void
    {
        Http::fake([
            'https://upload.imagekit.io/api/v1/files/upload' => Http::response([
                'fileId' => 'ik_file_12345',
                'url' => 'https://ik.imagekit.io/testphonebook/phonebook/reports/foto_uji.jpg',
                'name' => 'foto_uji_abc.jpg',
                'size' => 2048,
                'filePath' => '/phonebook/reports/foto_uji_abc.jpg',
            ], 200),
            'https://api.imagekit.io/v1/files/ik_file_12345' => Http::response([], 204),
        ]);

        Sanctum::actingAs($this->user1);

        $report = Report::create([
            'user_id' => $this->user1->id,
            'title' => 'Patroli Hutan Garut',
            'activity_date' => '2026-11-26',
            'location' => 'Gunung Guntur',
            'status' => 'terkirim',
        ]);

        $pngBytes = base64_decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==');
        $image = UploadedFile::fake()->createWithContent('kegiatan.png', $pngBytes);

        $uploadRes = $this->post("/api/reports/{$report->id}/photos", [
            'photo' => $image,
            'latitude' => -7.15234,
            'longitude' => 107.8421,
            'address' => 'Blok Pasir Wangi, Garut',
        ], ['Accept' => 'application/json']);

        $uploadRes->assertStatus(201)
            ->assertJson([
                'success' => true,
                'data' => [
                    'report_id' => $report->id,
                    'imagekit_file_id' => 'ik_file_12345',
                    'imagekit_url' => 'https://ik.imagekit.io/testphonebook/phonebook/reports/foto_uji.jpg',
                    'url' => 'https://ik.imagekit.io/testphonebook/phonebook/reports/foto_uji.jpg',
                    'storage_provider' => 'imagekit',
                ],
            ]);

        $photoId = $uploadRes->json('data.id');
        $photoModel = ReportPhoto::findOrFail($photoId);
        $this->assertNull($photoModel->photo_base64);
        $this->assertEquals('imagekit', $photoModel->storage_provider);

        // Pastikan private key tidak pernah muncul di response JSON
        $this->assertStringNotContainsString('private_test_secret_should_never_leak', $uploadRes->getContent());

        // Endpoint file redirect ke URL ImageKit
        $this->get("/api/report-photos/{$photoId}/file")
            ->assertStatus(302)
            ->assertRedirect('https://ik.imagekit.io/testphonebook/phonebook/reports/foto_uji.jpg');

        // List & detail laporan menampilkan URL ImageKit
        $this->getJson('/api/reports')
            ->assertStatus(200)
            ->assertJsonPath('data.0.photos.0.url', 'https://ik.imagekit.io/testphonebook/phonebook/reports/foto_uji.jpg');

        // User lain dilarang menghapus foto
        Sanctum::actingAs($this->user2);
        $this->deleteJson("/api/report-photos/{$photoId}")->assertStatus(404);

        // Pemilik menghapus foto -> ImageKit delete API ikut dipanggil
        Sanctum::actingAs($this->user1);
        $this->deleteJson("/api/report-photos/{$photoId}")->assertStatus(200);
        $this->assertDatabaseMissing('report_photos', ['id' => $photoId]);

        Http::assertSent(fn ($req) => $req->method() === 'DELETE' && str_contains($req->url(), 'api.imagekit.io/v1/files/ik_file_12345'));
    }

    public function test_upload_download_and_delete_report_document_via_supabase_storage(): void
    {
        Http::fake([
            'https://example.supabase.co/storage/v1/object/reports/*' => function ($request) {
                if ($request->method() === 'POST') {
                    return Http::response(['Key' => 'reports/1/1/lap.pdf'], 200);
                }
                if ($request->method() === 'GET') {
                    return Http::response('%PDF-1.4 mock binary content', 200, [
                        'Content-Type' => 'application/pdf',
                    ]);
                }
                return Http::response([], 200);
            },
            'https://example.supabase.co/storage/v1/object/sign/reports/*' => Http::response([
                'signedURL' => '/object/sign/reports/1/1/lap.pdf?token=signed_abc',
            ], 200),
            'https://example.supabase.co/storage/v1/object/reports' => Http::response([
                ['name' => 'deleted'],
            ], 200),
        ]);

        Sanctum::actingAs($this->user1);

        $report = Report::create([
            'user_id' => $this->user1->id,
            'title' => 'Laporan Rehabilitasi',
            'activity_date' => '2026-11-26',
            'location' => 'Garut',
            'status' => 'terkirim',
        ]);

        $pdf = UploadedFile::fake()->createWithContent('lampiran_resmi.pdf', "%PDF-1.4\n1 0 obj\n<<>>\nendobj\ntrailer\n<<>>\n%%EOF");

        $uploadRes = $this->post("/api/reports/{$report->id}/files", [
            'file' => $pdf,
            'title' => 'Lampiran Berita Acara',
        ], ['Accept' => 'application/json']);

        $uploadRes->assertStatus(201)
            ->assertJson([
                'success' => true,
                'data' => [
                    'report_id' => $report->id,
                    'user_id' => $this->user1->id,
                    'file_name' => 'lampiran_resmi.pdf',
                    'storage_bucket' => 'reports',
                    'mime_type' => 'application/pdf',
                ],
            ]);

        $fileId = $uploadRes->json('data.id');
        $fileRecord = ReportFile::findOrFail($fileId);
        $this->assertStringStartsWith("reports/{$this->user1->id}/{$report->id}/", $fileRecord->storage_path);
        $this->assertStringNotContainsString('service_role_test_secret_should_never_leak', $uploadRes->getContent());

        // Download dokumen oleh pemilik
        $dlRes = $this->get("/api/report-files/{$fileId}/download");
        $dlRes->assertStatus(200);
        $this->assertEquals('%PDF-1.4 mock binary content', $dlRes->getContent());

        // Signed URL oleh admin
        Sanctum::actingAs($this->admin);
        $signedRes = $this->getJson("/api/report-files/{$fileId}/download?format=url");
        $signedRes->assertStatus(200)
            ->assertJsonPath('data.url', 'https://example.supabase.co/storage/v1/object/sign/reports/1/1/lap.pdf?token=signed_abc');

        // User lain tidak boleh mengakses, mengunduh, atau menghapus dokumen
        Sanctum::actingAs($this->user2);
        $this->getJson("/api/reports/{$report->id}/files")->assertStatus(404);
        $this->getJson("/api/report-files/{$fileId}/download")->assertStatus(403);
        $this->deleteJson("/api/report-files/{$fileId}")->assertStatus(404);

        // Pemilik dapat menghapus dokumen -> Supabase Storage delete dipanggil
        Sanctum::actingAs($this->user1);
        $this->deleteJson("/api/report-files/{$fileId}")->assertStatus(200);
        $this->assertDatabaseMissing('report_files', ['id' => $fileId]);

        Http::assertSent(fn ($req) => $req->method() === 'DELETE' && str_contains($req->url(), '/storage/v1/object/reports'));
    }

    public function test_invalid_file_uploads_are_rejected_with_validation_errors(): void
    {
        Sanctum::actingAs($this->user1);
        $report = Report::create([
            'user_id' => $this->user1->id,
            'title' => 'Uji Validasi',
            'activity_date' => '2026-11-26',
            'location' => 'Garut',
            'status' => 'draft',
        ]);

        // Upload script PHP menyamar jadi foto
        $fakePhpAsPhoto = UploadedFile::fake()->createWithContent('shell.php', '<?php echo "bad";');
        $this->postJson("/api/reports/{$report->id}/photos", [
            'photo' => $fakePhpAsPhoto,
        ])->assertStatus(422);

        // Upload ekstensi .exe ke dokumen laporan
        $exeDoc = UploadedFile::fake()->create('malware.exe', 100, 'application/x-msdownload');
        $this->postJson("/api/reports/{$report->id}/files", [
            'file' => $exeDoc,
        ])->assertStatus(422);
    }

    public function test_network_failure_returns_safe_error_without_leaking_credentials(): void
    {
        Http::fake([
            'https://upload.imagekit.io/*' => fn () => throw new ConnectionException('cURL error 28: Connection timed out'),
            'https://example.supabase.co/*' => fn () => throw new ConnectionException('cURL error 6: Could not resolve host'),
        ]);

        Sanctum::actingAs($this->user1);
        $report = Report::create([
            'user_id' => $this->user1->id,
            'title' => 'Uji Koneksi Terputus',
            'activity_date' => '2026-11-26',
            'location' => 'Garut',
            'status' => 'draft',
        ]);

        $pngBytes = base64_decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==');
        $image = UploadedFile::fake()->createWithContent('test.png', $pngBytes);
        $photoRes = $this->post("/api/reports/{$report->id}/photos", ['photo' => $image], ['Accept' => 'application/json']);
        $photoRes->assertStatus(502)->assertJson(['success' => false]);
        $this->assertStringNotContainsString('private_test_secret_should_never_leak', $photoRes->getContent());

        $pdf = UploadedFile::fake()->createWithContent('doc.pdf', "%PDF-1.4\n%%EOF");
        $fileRes = $this->post("/api/reports/{$report->id}/files", ['file' => $pdf], ['Accept' => 'application/json']);
        $fileRes->assertStatus(502)->assertJson(['success' => false]);
        $this->assertStringNotContainsString('service_role_test_secret_should_never_leak', $fileRes->getContent());
    }

    public function test_legacy_photo_migration_command_preserves_old_data_and_updates_imagekit_metadata(): void
    {
        Http::fake([
            'https://upload.imagekit.io/api/v1/files/upload' => Http::response([
                'fileId' => 'ik_migrated_999',
                'url' => 'https://ik.imagekit.io/testphonebook/phonebook/reports/migrated_1.png',
                'name' => 'migrated_1.png',
                'size' => 128,
            ], 200),
            'https://ik.imagekit.io/*' => Http::response('ok', 200),
        ]);

        $report = Report::create([
            'user_id' => $this->user1->id,
            'title' => 'Laporan Lama Base64',
            'activity_date' => '2026-10-01',
            'location' => 'Garut',
            'status' => 'terkirim',
        ]);

        // 1x1 PNG valid base64
        $pngBase64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
        $legacyPhoto = ReportPhoto::create([
            'report_id' => $report->id,
            'photo' => 'reports/legacy_1.png',
            'photo_base64' => $pngBase64,
            'storage_provider' => 'local',
        ]);

        // Dry run tidak memodifikasi data
        $this->artisan('photos:migrate-imagekit --dry-run')
            ->assertExitCode(0);
        $legacyPhoto->refresh();
        $this->assertNull($legacyPhoto->imagekit_url);

        // Migrasi sebenarnya
        $this->artisan('photos:migrate-imagekit')
            ->assertExitCode(0);

        $legacyPhoto->refresh();
        $this->assertEquals('imagekit', $legacyPhoto->storage_provider);
        $this->assertEquals('ik_migrated_999', $legacyPhoto->imagekit_file_id);
        $this->assertEquals('https://ik.imagekit.io/testphonebook/phonebook/reports/migrated_1.png', $legacyPhoto->imagekit_url);
        // Pastikan photo_base64 lama TIDAK dihapus otomatis
        $this->assertEquals($pngBase64, $legacyPhoto->photo_base64);

        // Bersihkan file backup uji coba dari storage/app/backups
        foreach (glob(storage_path('app/backups/report_photos_backup_*.json')) ?: [] as $f) {
            @unlink($f);
        }
    }

    public function test_deleting_report_cleans_up_imagekit_photos_and_supabase_documents(): void
    {
        Http::fake([
            'https://upload.imagekit.io/api/v1/files/upload' => Http::response([
                'fileId' => 'ik_cascade_1',
                'url' => 'https://ik.imagekit.io/testphonebook/phonebook/reports/cascade.png',
                'name' => 'cascade.png',
                'size' => 128,
            ], 200),
            'https://api.imagekit.io/v1/files/ik_cascade_1' => Http::response([], 204),
            'https://example.supabase.co/storage/v1/object/reports/*' => Http::response(['Key' => 'reports/1/1/doc.pdf'], 200),
            'https://example.supabase.co/storage/v1/object/reports' => Http::response([['name' => 'deleted']], 200),
        ]);

        Sanctum::actingAs($this->user1);
        $report = Report::create([
            'user_id' => $this->user1->id,
            'title' => 'Laporan Cascade Hapus',
            'activity_date' => '2026-11-26',
            'location' => 'Garut',
            'status' => 'terkirim',
        ]);

        $pngBytes = base64_decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==');
        $this->post("/api/reports/{$report->id}/photos", [
            'photo' => UploadedFile::fake()->createWithContent('cascade.png', $pngBytes),
        ], ['Accept' => 'application/json'])->assertStatus(201);

        $this->post("/api/reports/{$report->id}/files", [
            'file' => UploadedFile::fake()->createWithContent('cascade.pdf', "%PDF-1.4\n%%EOF"),
        ], ['Accept' => 'application/json'])->assertStatus(201);

        $this->deleteJson("/api/reports/{$report->id}")->assertStatus(200);

        $this->assertDatabaseMissing('reports', ['id' => $report->id]);
        $this->assertDatabaseMissing('report_photos', ['report_id' => $report->id]);
        $this->assertDatabaseMissing('report_files', ['report_id' => $report->id]);

        Http::assertSent(fn ($req) => $req->method() === 'DELETE' && str_contains($req->url(), 'api.imagekit.io/v1/files/ik_cascade_1'));
        Http::assertSent(fn ($req) => $req->method() === 'DELETE' && str_contains($req->url(), '/storage/v1/object/reports'));
    }
}
