<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations to add high-performance database indexes.
     */
    public function up(): void
    {
        // Tabel reports berada di db_laporan
        Schema::connection('db_laporan')->table('reports', function (Blueprint $table) {
            $table->index('user_id', 'idx_reports_user_id');
            $table->index(['user_id', 'created_at'], 'idx_reports_user_created_at');
            $table->index('activity_date', 'idx_reports_activity_date');
        });

        // Tabel schedules tetap di database utama (default)
        Schema::table('schedules', function (Blueprint $table) {
            $table->index('user_id', 'idx_schedules_user_id');
            $table->index(['user_id', 'date'], 'idx_schedules_user_date');
            $table->index(['whatsapp_status', 'reminder_at'], 'idx_schedules_wa_reminder');
        });

        // Tabel report_templates sekarang di db_laporan
        Schema::connection('db_laporan')->table('report_templates', function (Blueprint $table) {
            $table->index('is_active', 'idx_report_templates_is_active');
        });

        // Tabel materials berada di db_materi
        Schema::connection('db_materi')->table('materials', function (Blueprint $table) {
            $table->index('created_at', 'idx_materials_created_at');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::connection('db_laporan')->table('reports', function (Blueprint $table) {
            $table->dropIndex('idx_reports_user_id');
            $table->dropIndex('idx_reports_user_created_at');
            $table->dropIndex('idx_reports_activity_date');
        });

        Schema::table('schedules', function (Blueprint $table) {
            $table->dropIndex('idx_schedules_user_id');
            $table->dropIndex('idx_schedules_user_date');
            $table->dropIndex('idx_schedules_wa_reminder');
        });

        Schema::connection('db_laporan')->table('report_templates', function (Blueprint $table) {
            $table->dropIndex('idx_report_templates_is_active');
        });

        Schema::connection('db_materi')->table('materials', function (Blueprint $table) {
            $table->dropIndex('idx_materials_created_at');
        });
    }
};