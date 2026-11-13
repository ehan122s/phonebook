<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            if (!Schema::hasColumn('users', 'nip')) {
                $table->string('nip', 50)->nullable()->after('name');
            }
            if (!Schema::hasColumn('users', 'jabatan')) {
                $table->string('jabatan', 100)->nullable()->after('nip');
            }
            if (!Schema::hasColumn('users', 'wilayah')) {
                $table->string('wilayah', 150)->nullable()->after('jabatan');
            }
            if (!Schema::hasColumn('users', 'avatar')) {
                $table->string('avatar', 1000)->nullable()->after('wilayah');
            }
            if (!Schema::hasColumn('users', 'google_id')) {
                $table->string('google_id', 255)->nullable()->after('avatar');
            }
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['nip', 'jabatan', 'wilayah', 'avatar', 'google_id']);
        });
    }
};
