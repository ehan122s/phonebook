<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('report_photos', function (Blueprint $table) {
            if (!Schema::hasColumn('report_photos', 'photo_base64')) {
                $table->longText('photo_base64')->nullable()->after('photo');
            }
        });
    }

    public function down(): void
    {
        Schema::table('report_photos', function (Blueprint $table) {
            if (Schema::hasColumn('report_photos', 'photo_base64')) {
                $table->dropColumn('photo_base64');
            }
        });
    }
};
