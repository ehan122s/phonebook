<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('schedules', function (Blueprint $table) {
            if (!Schema::hasColumn('schedules', 'category')) {
                $table->string('category')->nullable()->default('Penyuluhan')->after('title');
            }
            if (!Schema::hasColumn('schedules', 'reminder_minutes')) {
                $table->integer('reminder_minutes')->default(30)->after('reminder_enabled');
            }
            if (!Schema::hasColumn('schedules', 'is_completed')) {
                $table->boolean('is_completed')->default(false)->after('whatsapp_sent');
            }
        });
    }

    public function down(): void
    {
        Schema::table('schedules', function (Blueprint $table) {
            $columns = [];
            if (Schema::hasColumn('schedules', 'category')) {
                $columns[] = 'category';
            }
            if (Schema::hasColumn('schedules', 'reminder_minutes')) {
                $columns[] = 'reminder_minutes';
            }
            if (Schema::hasColumn('schedules', 'is_completed')) {
                $columns[] = 'is_completed';
            }
            if (!empty($columns)) {
                $table->dropColumn($columns);
            }
        });
    }
};
