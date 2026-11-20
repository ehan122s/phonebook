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
        Schema::create('app_updates', function (Blueprint $table) {
            $table->id();
            $table->string('version', 64)->index();
            $table->string('title');
            $table->text('description');
            $table->text('apk_url');
            $table->string('type', 32)->default('optional'); // 'optional' or 'mandatory'
            $table->boolean('is_published')->default(false)->index();
            $table->timestamp('published_at')->nullable()->index();
            $table->string('min_supported_version', 64)->nullable();
            $table->string('discord_user_id', 64)->nullable();
            $table->string('discord_user_name', 128)->nullable();
            $table->timestamps();

            // Composite index for fast retrieval of latest published update
            $table->index(['is_published', 'published_at']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('app_updates');
    }
};
