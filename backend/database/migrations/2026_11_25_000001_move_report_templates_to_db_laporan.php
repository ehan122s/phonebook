<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * Pindahkan tabel report_templates ke database db_laporan.
     * Jika tabel sudah ada di database utama, data akan dipindahkan.
     */
    public function up(): void
    {
        // Buat tabel report_templates di db_laporan jika belum ada
        if (!Schema::connection('db_laporan')->hasTable('report_templates')) {
            Schema::connection('db_laporan')->create('report_templates', function (Blueprint $table) {
                $table->id();
                $table->string('name');
                $table->string('category');
                $table->text('description')->nullable();
                $table->json('fields_config')->nullable();
                $table->json('placeholders')->nullable();
                $table->string('file_name')->nullable();
                $table->string('file_path')->nullable();
                $table->longText('file_base64')->nullable();
                $table->boolean('is_active')->default(true);
                $table->unsignedBigInteger('uploaded_by')->nullable();
                $table->text('template_body')->nullable();
                $table->string('icon_key')->nullable()->default('description');
                $table->string('default_title')->nullable();
                $table->boolean('require_photo')->default(true);
                $table->boolean('require_location')->default(true);
                $table->timestamps();

                $table->index('is_active', 'idx_report_templates_is_active');
            });
        }

        // Migrasi data dari database utama ke db_laporan jika kedua database berbeda dan tabel lama ada
        $defaultConn = config('database.default');
        $defaultDb = config("database.connections.{$defaultConn}.database");
        $laporanDb = config('database.connections.db_laporan.database');

        if ($defaultConn !== 'db_laporan' && $defaultDb !== $laporanDb) {
            try {
                if (Schema::connection($defaultConn)->hasTable('report_templates')) {
                    $oldData = DB::connection($defaultConn)->table('report_templates')->get();
                    foreach ($oldData as $row) {
                        $data = (array) $row;
                        $exists = DB::connection('db_laporan')
                            ->table('report_templates')
                            ->where('id', $data['id'])
                            ->exists();
                        if (!$exists) {
                            DB::connection('db_laporan')->table('report_templates')->insert($data);
                        }
                    }
                }
            } catch (\Throwable $e) {
                // Abaikan jika koneksi asal tidak tersedia
            }
        }
    }

    public function down(): void
    {
        Schema::connection('db_laporan')->dropIfExists('report_templates');
    }
};
