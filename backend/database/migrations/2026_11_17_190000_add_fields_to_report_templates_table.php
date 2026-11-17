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
        if (Schema::hasTable('report_templates')) {
            Schema::table('report_templates', function (Blueprint $table) {
                if (!Schema::hasColumn('report_templates', 'template_body')) {
                    $table->text('template_body')->nullable();
                }
                if (!Schema::hasColumn('report_templates', 'icon_key')) {
                    $table->string('icon_key')->nullable()->default('description');
                }
                if (!Schema::hasColumn('report_templates', 'default_title')) {
                    $table->string('default_title')->nullable();
                }
                if (!Schema::hasColumn('report_templates', 'require_photo')) {
                    $table->boolean('require_photo')->default(true);
                }
                if (!Schema::hasColumn('report_templates', 'require_location')) {
                    $table->boolean('require_location')->default(true);
                }
            });
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        if (Schema::hasTable('report_templates')) {
            Schema::table('report_templates', function (Blueprint $table) {
                $columns = ['template_body', 'icon_key', 'default_title', 'require_photo', 'require_location'];
                foreach ($columns as $column) {
                    if (Schema::hasColumn('report_templates', $column)) {
                        $table->dropColumn($column);
                    }
                }
            });
        }
    }
};
