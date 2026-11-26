<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Buat tabel report_files di database laporan (Supabase PostgreSQL)
     * untuk menyimpan metadata dokumen/lampiran laporan yang diunggah ke Supabase Storage.
     */
    public function up(): void
    {
        $conn = 'db_laporan';
        if (Schema::connection($conn)->hasTable('report_files')) {
            return;
        }

        $defaultConn = config('database.default');
        $sameDatabase = config("database.connections.{$defaultConn}.database") === config("database.connections.{$conn}.database")
            && config("database.connections.{$defaultConn}.driver") === config("database.connections.{$conn}.driver");

        Schema::connection($conn)->create('report_files', function (Blueprint $table) use ($sameDatabase) {
            $table->id();
            $table->unsignedBigInteger('report_id')->index('idx_report_files_report_id');
            $table->unsignedBigInteger('user_id')->index('idx_report_files_user_id');

            $table->string('title', 255)->nullable();
            $table->text('description')->nullable();
            $table->string('file_name', 255);
            $table->string('storage_bucket', 100)->default('reports');
            $table->string('storage_path', 500);
            $table->text('file_url')->nullable();
            $table->string('mime_type', 150);
            $table->unsignedBigInteger('file_size');

            $table->timestamps();

            $table->index(['report_id', 'created_at'], 'idx_report_files_report_created');

            $table->foreign('report_id')
                ->references('id')
                ->on('reports')
                ->cascadeOnDelete();

            if ($sameDatabase && Schema::hasTable('users')) {
                $table->foreign('user_id')
                    ->references('id')
                    ->on('users')
                    ->cascadeOnDelete();
            }
        });
    }

    public function down(): void
    {
        Schema::connection('db_laporan')->dropIfExists('report_files');
    }
};
