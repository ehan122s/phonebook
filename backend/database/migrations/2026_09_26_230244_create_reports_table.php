<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::connection('db_laporan')->create('reports', function (Blueprint $table) {
            $table->id();

            $table->unsignedBigInteger('user_id')->index();

            $table->unsignedBigInteger('category_id')->nullable()->index();

            $table->string('title');
            $table->date('activity_date');
            $table->string('location');

            $table->decimal('latitude', 10, 7)->nullable();
            $table->decimal('longitude', 10, 7)->nullable();

            $table->text('description')->nullable();

            $table->enum('status', [
                'draft',
                'terkirim',
                'diperiksa',
                'disetujui',
                'ditolak'
            ])->default('draft');

            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::connection('db_laporan')->dropIfExists('reports');
    }
};