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
        Schema::create('bug_reports', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('reporter_name');
            $table->string('reporter_email')->nullable();
            $table->string('category', 100);
            $table->string('priority', 50)->default('Sedang');
            $table->string('title', 255);
            $table->text('description');
            $table->string('app_version', 50)->nullable();
            $table->string('device_info', 500)->nullable();
            $table->boolean('discord_sent')->default(false);
            $table->string('discord_error', 500)->nullable();
            $table->string('status', 50)->default('baru');
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('bug_reports');
    }
};
