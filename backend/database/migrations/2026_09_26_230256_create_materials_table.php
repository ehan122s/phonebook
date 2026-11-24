<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::connection('db_materi')->create('materials', function (Blueprint $table) {
            $table->id();

            $table->unsignedBigInteger('user_id')->nullable()->index();
            $table->unsignedBigInteger('category_id')->nullable()->index();

            $table->string('title');
            $table->text('description')->nullable();

            $table->string('file_path');
            $table->string('file_name');
            $table->string('file_type')->nullable();

            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::connection('db_materi')->dropIfExists('materials');
    }
};