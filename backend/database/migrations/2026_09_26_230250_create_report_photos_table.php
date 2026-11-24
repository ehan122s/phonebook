<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::connection('db_foto')->create('report_photos', function (Blueprint $table) {
            $table->id();

            $table->unsignedBigInteger('report_id')->index();

            $table->string('photo');

            $table->decimal('latitude', 10, 7)->nullable();
            $table->decimal('longitude', 10, 7)->nullable();

            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::connection('db_foto')->dropIfExists('report_photos');
    }
};