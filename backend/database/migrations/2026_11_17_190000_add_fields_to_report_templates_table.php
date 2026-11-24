<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        // report_templates sekarang berada di db_laporan
        $conn = 'db_laporan';
        if (Schema::connection($conn)->hasTable('report_templates')) {
            Schema::connection($conn)->table('report_templates', function (Blueprint $table) use ($conn) {
                if (!Schema::connection($conn)->hasColumn('report_templates', 'template_body')) {
                    $table->text('template_body')->nullable();
                }
                if (!Schema::connection($conn)->hasColumn('report_templates', 'icon_key')) {
                    $table->string('icon_key')->nullable()->default('description');
                }
                if (!Schema::connection($conn)->hasColumn('report_templates', 'default_title')) {
                    $table->string('default_title')->nullable();
                }
                if (!Schema::connection($conn)->hasColumn('report_templates', 'require_photo')) {
                    $table->boolean('require_photo')->default(true);
                }
                if (!Schema::connection($conn)->hasColumn('report_templates', 'require_location')) {
                    $table->boolean('require_location')->default(true);
                }
            });
        }
        // Fallback: juga cek di database utama (backward compatibility)
        if (Schema::hasTable('report_templates')) {
            Schema::table('report_templates', function (Blueprint $table) {
                if (!Schema::hasColumn('report_templates', 'template_body')) {
                    $table->text('template_body')->nullable();
                }
                if (!Schema::hasColumn('report_templates', 'icon_key')) {
                    $table->string('icon_key')->nullable()->default('description');
                }
                if (!Schema::hasColumn('report_templates', 'default_title')) {
                    $table->string('default_title')->nullable();
                }
                if (!Schema::hasColumn('report_templates', 'require_photo')) {
                    $table->boolean('require_photo')->default(true);
                }
                if (!Schema::hasColumn('report_templates', 'require_location')) {
                    $table->boolean('require_location')->default(true);
                }
            });
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        $conn = 'db_laporan';
        if (Schema::connection($conn)->hasTable('report_templates')) {
            Schema::connection($conn)->table('report_templates', function (Blueprint $table) use ($conn) {
                $columns = ['template_body', 'icon_key', 'default_title', 'require_photo', 'require_location'];
                foreach ($columns as $column) {
                    if (Schema::connection($conn)->hasColumn('report_templates', $column)) {
                        $table->dropColumn($column);
                    }
                }
            });
        }
        if (Schema::hasTable('report_templates')) {
            Schema::table('report_templates', function (Blueprint $table) {
                $columns = ['template_body', 'icon_key', 'default_title', 'require_photo', 'require_location'];
                foreach ($columns as $column) {
                    if (Schema::hasColumn('report_templates', $column)) {
                        $table->dropColumn($column);
                    }
                }
            });
        }
    }
};
