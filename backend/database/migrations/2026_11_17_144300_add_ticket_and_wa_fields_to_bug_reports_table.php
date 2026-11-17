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
        Schema::table('bug_reports', function (Blueprint $table) {
            $table->string('ticket_code', 64)->nullable()->unique()->after('id');
            $table->string('reporter_phone', 32)->nullable()->after('reporter_email');
            $table->text('rejection_reason')->nullable()->after('description');
            $table->string('handled_by', 128)->nullable()->after('rejection_reason');
            $table->string('discord_message_id', 64)->nullable()->after('discord_error');
            $table->string('discord_channel_id', 64)->nullable()->after('discord_message_id');
            $table->timestamp('approved_at')->nullable()->after('status');
            $table->timestamp('resolved_at')->nullable()->after('approved_at');
            $table->boolean('wa_sent')->default(false)->after('resolved_at');
            $table->string('wa_status', 32)->nullable()->after('wa_sent');
            $table->json('wa_history')->nullable()->after('wa_status');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('bug_reports', function (Blueprint $table) {
            $table->dropColumn([
                'ticket_code',
                'reporter_phone',
                'rejection_reason',
                'handled_by',
                'discord_message_id',
                'discord_channel_id',
                'approved_at',
                'resolved_at',
                'wa_sent',
                'wa_status',
                'wa_history',
            ]);
        });
    }
};
