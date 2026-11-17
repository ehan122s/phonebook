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
        Schema::table('bug_reports', function (Blueprint $table) {
            if (!Schema::hasColumn('bug_reports', 'resolution_reason')) {
                $table->text('resolution_reason')->nullable()->after('rejection_reason');
            }
            if (!Schema::hasColumn('bug_reports', 'developer_id')) {
                $table->string('developer_id', 64)->nullable()->after('handled_by');
            }
            if (!Schema::hasColumn('bug_reports', 'ticket_number')) {
                $table->string('ticket_number', 64)->nullable()->after('ticket_code');
            }
            if (!Schema::hasColumn('bug_reports', 'whatsapp')) {
                $table->string('whatsapp', 32)->nullable()->after('reporter_phone');
            }
            if (!Schema::hasColumn('bug_reports', 'accepted_at')) {
                $table->timestamp('accepted_at')->nullable()->after('approved_at');
            }
            if (!Schema::hasColumn('bug_reports', 'whatsapp_delivery_status')) {
                $table->string('whatsapp_delivery_status', 32)->nullable()->after('wa_status');
            }
        });

        Schema::table('report_photos', function (Blueprint $table) {
            if (!Schema::hasColumn('report_photos', 'address')) {
                $table->text('address')->nullable()->after('longitude');
            }
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('bug_reports', function (Blueprint $table) {
            $cols = ['resolution_reason', 'developer_id', 'ticket_number', 'whatsapp', 'accepted_at', 'whatsapp_delivery_status'];
            foreach ($cols as $col) {
                if (Schema::hasColumn('bug_reports', $col)) {
                    $table->dropColumn($col);
                }
            }
        });

        Schema::table('report_photos', function (Blueprint $table) {
            if (Schema::hasColumn('report_photos', 'address')) {
                $table->dropColumn('address');
            }
        });
    }
};
