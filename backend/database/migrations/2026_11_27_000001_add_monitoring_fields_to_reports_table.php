<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Tambahkan kolom terstruktur untuk jenis Laporan Monitoring pada tabel reports.
     * Seluruh kolom bersifat nullable atau memiliki nilai default agar laporan lama tetap aman.
     */
    public function up(): void
    {
        $conn = 'db_laporan';
        $schema = Schema::connection($conn);

        if (!$schema->hasTable('reports')) {
            return;
        }

        $existingColumns = array_flip(array_map('strtolower', $schema->getColumnListing('reports')));
        $hasTypeIndex = method_exists($schema, 'hasIndex')
            ? $schema->hasIndex('reports', 'idx_reports_report_type')
            : false;

        $schema->table('reports', function (Blueprint $table) use ($existingColumns, $hasTypeIndex) {
            if (!isset($existingColumns['report_type'])) {
                $table->string('report_type', 50)->default('standard');
                if (!$hasTypeIndex) {
                    $table->index('report_type', 'idx_reports_report_type');
                }
            }
            if (!isset($existingColumns['activity_name'])) {
                $table->string('activity_name', 255)->nullable();
            }
            if (!isset($existingColumns['monitoring_period'])) {
                $table->string('monitoring_period', 150)->nullable();
            }
            if (!isset($existingColumns['officer_name'])) {
                $table->string('officer_name', 255)->nullable();
            }
            if (!isset($existingColumns['target_value'])) {
                $table->decimal('target_value', 12, 2)->nullable();
            }
            if (!isset($existingColumns['target_unit'])) {
                $table->string('target_unit', 100)->nullable();
            }
            if (!isset($existingColumns['target_period'])) {
                $table->string('target_period', 150)->nullable();
            }
            if (!isset($existingColumns['actual_value'])) {
                $table->decimal('actual_value', 12, 2)->nullable();
            }
            if (!isset($existingColumns['achievement_percentage'])) {
                $table->decimal('achievement_percentage', 6, 2)->nullable();
            }
            if (!isset($existingColumns['remaining_target'])) {
                $table->decimal('remaining_target', 12, 2)->nullable();
            }
            if (!isset($existingColumns['achievement_status'])) {
                $table->string('achievement_status', 50)->nullable();
            }
            if (!isset($existingColumns['field_facts'])) {
                $table->text('field_facts')->nullable();
            }
            if (!isset($existingColumns['obstacles'])) {
                $table->text('obstacles')->nullable();
            }
            if (!isset($existingColumns['failure_causes'])) {
                $table->text('failure_causes')->nullable();
            }
            if (!isset($existingColumns['recommendations'])) {
                $table->text('recommendations')->nullable();
            }
            if (!isset($existingColumns['follow_up_plan'])) {
                $table->text('follow_up_plan')->nullable();
            }
            if (!isset($existingColumns['next_target_date'])) {
                $table->date('next_target_date')->nullable();
            }
            if (!isset($existingColumns['monitoring_data'])) {
                $table->json('monitoring_data')->nullable();
            }
        });
    }

    public function down(): void
    {
        $conn = 'db_laporan';
        if (!Schema::connection($conn)->hasTable('reports')) {
            return;
        }

        Schema::connection($conn)->table('reports', function (Blueprint $table) use ($conn) {
            if (Schema::connection($conn)->hasColumn('reports', 'report_type')) {
                try {
                    $table->dropIndex('idx_reports_report_type');
                } catch (\Throwable $e) {
                    // Abaikan jika index tidak ada
                }
            }

            $columns = [
                'report_type',
                'activity_name',
                'monitoring_period',
                'officer_name',
                'target_value',
                'target_unit',
                'target_period',
                'actual_value',
                'achievement_percentage',
                'remaining_target',
                'achievement_status',
                'field_facts',
                'obstacles',
                'failure_causes',
                'recommendations',
                'follow_up_plan',
                'next_target_date',
                'monitoring_data',
            ];

            $toDrop = [];
            foreach ($columns as $col) {
                if (Schema::connection($conn)->hasColumn('reports', $col)) {
                    $toDrop[] = $col;
                }
            }

            if (!empty($toDrop)) {
                $table->dropColumn($toDrop);
            }
        });
    }
};
