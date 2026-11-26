<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Tambahkan kolom metadata ImageKit ke tabel report_photos tanpa menghapus kolom lama
     * agar foto lama tetap bisa dibaca dan dimigrasi secara aman.
     */
    public function up(): void
    {
        $conn = 'db_foto';
        if (!Schema::connection($conn)->hasTable('report_photos')) {
            return;
        }

        Schema::connection($conn)->table('report_photos', function (Blueprint $table) use ($conn) {
            if (!Schema::connection($conn)->hasColumn('report_photos', 'imagekit_file_id')) {
                $table->string('imagekit_file_id', 255)->nullable()->index('idx_report_photos_imagekit_file_id');
            }
            if (!Schema::connection($conn)->hasColumn('report_photos', 'imagekit_url')) {
                $table->text('imagekit_url')->nullable();
            }
            if (!Schema::connection($conn)->hasColumn('report_photos', 'file_name')) {
                $table->string('file_name', 255)->nullable();
            }
            if (!Schema::connection($conn)->hasColumn('report_photos', 'mime_type')) {
                $table->string('mime_type', 100)->nullable();
            }
            if (!Schema::connection($conn)->hasColumn('report_photos', 'file_size')) {
                $table->unsignedBigInteger('file_size')->nullable();
            }
            if (!Schema::connection($conn)->hasColumn('report_photos', 'storage_provider')) {
                $table->string('storage_provider', 50)->default('local')->index('idx_report_photos_storage_provider');
            }
        });
    }

    public function down(): void
    {
        $conn = 'db_foto';
        if (!Schema::connection($conn)->hasTable('report_photos')) {
            return;
        }

        Schema::connection($conn)->table('report_photos', function (Blueprint $table) use ($conn) {
            $columns = [
                'imagekit_file_id',
                'imagekit_url',
                'file_name',
                'mime_type',
                'file_size',
                'storage_provider',
            ];
            foreach ($columns as $col) {
                if (Schema::connection($conn)->hasColumn('report_photos', $col)) {
                    $table->dropColumn($col);
                }
            }
        });
    }
};
