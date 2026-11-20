<?php

namespace Tests\Feature;

use App\Models\AppUpdate;
use App\Services\DiscordAppUpdateService;
use Carbon\Carbon;
use Tests\TestCase;

class AppUpdateTest extends TestCase
{
    protected function tearDown(): void
    {
        AppUpdate::where('version', 'like', '99.%')->delete();
        parent::tearDown();
    }

    public function test_latest_endpoint_returns_success()
    {
        $response = $this->getJson('/api/app-update/latest');

        $response->assertStatus(200)
            ->assertJsonStructure([
                'success',
                'data',
                'message',
            ]);
    }

    public function test_check_endpoint_detects_newer_version()
    {
        // Buat dummy update versi 99.1.0
        $update = AppUpdate::create([
            'version' => '99.1.0',
            'title' => 'Test Pembaruan Phonebook',
            'description' => 'Fitur uji coba otomatis',
            'apk_url' => 'https://phonebook-five-umber.vercel.app/test.apk',
            'type' => 'optional',
            'is_published' => true,
            'published_at' => Carbon::now('Asia/Jakarta'),
        ]);

        // Klien versi 99.0.0 harus terdeteksi ada update
        $res = $this->postJson('/api/app-update/check', ['version' => '99.0.0']);
        $res->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'has_update' => true,
                    'is_mandatory' => false,
                    'latest_version' => '99.1.0',
                ],
            ]);

        // Klien versi 99.1.0 tidak boleh terdeteksi ada update
        $resCurrent = $this->postJson('/api/app-update/check', ['version' => '99.1.0']);
        $resCurrent->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'has_update' => false,
                    'is_mandatory' => false,
                ],
            ]);

        // Klien versi 99.2.0 (lebih tinggi) tidak boleh terdeteksi ada update
        $resNewer = $this->postJson('/api/app-update/check', ['version' => '99.2.0']);
        $resNewer->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'has_update' => false,
                ],
            ]);

        $update->delete();
    }

    public function test_check_endpoint_detects_mandatory_update()
    {
        $update = AppUpdate::create([
            'version' => '99.2.0',
            'title' => 'Test Pembaruan Wajib',
            'description' => 'Pembaruan keamanan wajib',
            'apk_url' => 'https://phonebook-five-umber.vercel.app/mandatory.apk',
            'type' => 'mandatory',
            'is_published' => true,
            'published_at' => Carbon::now('Asia/Jakarta'),
        ]);

        $res = $this->postJson('/api/app-update/check', ['version' => '99.0.0']);
        $res->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'has_update' => true,
                    'is_mandatory' => true,
                ],
            ]);

        $update->delete();
    }

    public function test_store_endpoint_validates_https_and_semver()
    {
        // 1. URL bukan HTTPS
        $res = $this->postJson('/api/app-update', [
            'version' => '99.3.0',
            'title' => 'Update Test',
            'description' => 'Deskripsi update',
            'apk_url' => 'http://insecure-site.com/phonebook.apk',
            'type' => 'optional',
        ]);
        $res->assertStatus(422)
            ->assertJsonValidationErrors(['apk_url']);

        // 2. Format semver salah
        $resSemver = $this->postJson('/api/app-update', [
            'version' => 'version-abc',
            'title' => 'Update Test',
            'description' => 'Deskripsi update',
            'apk_url' => 'https://phonebook-five-umber.vercel.app/app.apk',
            'type' => 'optional',
        ]);
        $resSemver->assertStatus(422)
            ->assertJsonValidationErrors(['version']);
    }

    public function test_store_creates_and_publishes_update()
    {
        $res = $this->postJson('/api/app-update', [
            'version' => '99.4.0',
            'title' => 'Pembaruan Sukses',
            'description' => 'Changelog lengkap',
            'apk_url' => 'https://phonebook-five-umber.vercel.app/releases/phonebook-v99.4.0.apk',
            'type' => 'optional',
            'is_published' => false,
        ]);

        $res->assertStatus(201)
            ->assertJson(['success' => true]);

        $id = $res->json('data.id');

        // Publikasikan
        $publishRes = $this->postJson("/api/app-update/{$id}/publish");
        $publishRes->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'is_published' => true,
                ],
            ]);

        // Hapus
        $delRes = $this->deleteJson("/api/app-update/{$id}");
        $delRes->assertStatus(200);
    }

    public function test_discord_service_builds_valid_modal_and_embeds()
    {
        $modal = DiscordAppUpdateService::buildUpdateModal();
        $this->assertEquals(9, $modal['type']);
        $this->assertEquals('modal_app_update', $modal['data']['custom_id']);
        $this->assertCount(5, $modal['data']['components']);

        $update = new AppUpdate([
            'id' => 9999,
            'version' => '99.5.0',
            'title' => 'Test Discord Update',
            'description' => 'Fitur Discord Baru',
            'apk_url' => 'https://phonebook-five-umber.vercel.app/app.apk',
            'type' => 'mandatory',
            'is_published' => false,
        ]);

        $draftEmbed = DiscordAppUpdateService::buildDraftEmbed($update, '@Admin (123)');
        $this->assertStringContainsString('DRAFT', $draftEmbed['title']);

        $publishedEmbed = DiscordAppUpdateService::buildPublishedEmbed($update, '@Admin (123)');
        $this->assertStringContainsString('RESMI DIPUBLIKASIKAN', $publishedEmbed['title']);

        $canceledEmbed = DiscordAppUpdateService::buildCanceledEmbed($update, '@Admin (123)');
        $this->assertStringContainsString('DIBATALKAN', $canceledEmbed['title']);
    }
}
