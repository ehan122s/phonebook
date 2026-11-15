<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('schedules', function (Blueprint $table) {
            if (!Schema::hasColumn('schedules', 'whatsapp_status')) {
                $table->string('whatsapp_status', 20)->default('pending')->after('whatsapp_sent');
            }
            if (!Schema::hasColumn('schedules', 'whatsapp_error')) {
                $table->text('whatsapp_error')->nullable()->after('whatsapp_status');
            }
            if (!Schema::hasColumn('schedules', 'whatsapp_sent_at')) {
                $table->timestamp('whatsapp_sent_at')->nullable()->after('whatsapp_error');
            }
            if (!Schema::hasColumn('schedules', 'whatsapp_message_id')) {
                $table->string('whatsapp_message_id', 100)->nullable()->after('whatsapp_sent_at');
            }
        });

        // Inisialisasi status awal berdasarkan data yang sudah ada
        DB::table('schedules')
            ->where('whatsapp_sent', true)
            ->update(['whatsapp_status' => 'sent']);

        DB::table('schedules')
            ->where('enable_wa_notification', false)
            ->update(['whatsapp_status' => 'disabled']);
    }

    public function down(): void
    {
        Schema::table('schedules', function (Blueprint $table) {
            $columns = [];
            if (Schema::hasColumn('schedules', 'whatsapp_status')) {
                $columns[] = 'whatsapp_status';
            }
            if (Schema::hasColumn('schedules', 'whatsapp_error')) {
                $columns[] = 'whatsapp_error';
            }
            if (Schema::hasColumn('schedules', 'whatsapp_sent_at')) {
                $columns[] = 'whatsapp_sent_at';
            }
            if (Schema::hasColumn('schedules', 'whatsapp_message_id')) {
                $columns[] = 'whatsapp_message_id';
            }
            if (!empty($columns)) {
                $table->dropColumn($columns);
            }
        });
    }
};
