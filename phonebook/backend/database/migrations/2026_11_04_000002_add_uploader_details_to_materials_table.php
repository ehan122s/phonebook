<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('materials', function (Blueprint $table) {
            if (!Schema::hasColumn('materials', 'uploader_name')) {
                $table->string('uploader_name', 255)->nullable()->after('file_type');
            }
            if (!Schema::hasColumn('materials', 'uploader_role')) {
                $table->string('uploader_role', 50)->nullable()->after('uploader_name');
            }
            if (!Schema::hasColumn('materials', 'category_name')) {
                $table->string('category_name', 100)->nullable()->after('category_id');
            }
        });
    }

    public function down(): void
    {
        Schema::table('materials', function (Blueprint $table) {
            $table->dropColumn(['uploader_name', 'uploader_role', 'category_name']);
        });
    }
};
