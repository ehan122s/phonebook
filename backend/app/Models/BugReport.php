<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class BugReport extends Model
{
    protected $fillable = [
        'ticket_code',
        'user_id',
        'reporter_name',
        'reporter_email',
        'reporter_phone',
        'category',
        'priority',
        'title',
        'description',
        'rejection_reason',
        'handled_by',
        'app_version',
        'device_info',
        'discord_sent',
        'discord_error',
        'discord_message_id',
        'discord_channel_id',
        'status',
        'approved_at',
        'resolved_at',
        'wa_sent',
        'wa_status',
        'wa_history',
    ];

    protected $casts = [
        'discord_sent' => 'boolean',
        'wa_sent' => 'boolean',
        'wa_history' => 'array',
        'approved_at' => 'datetime',
        'resolved_at' => 'datetime',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Generate unique ticket code with format PB-YYYY-XXXX (e.g. PB-2026-0001).
     */
    public static function generateTicketCode(): string
    {
        $year = date('Y');
        $prefix = "PB-{$year}-";

        $latest = self::where('ticket_code', 'LIKE', "{$prefix}%")
            ->orderBy('id', 'desc')
            ->first();

        $nextSeq = 1;
        if ($latest && preg_match('/PB-\d{4}-(\d+)/', $latest->ticket_code, $matches)) {
            $nextSeq = ((int) $matches[1]) + 1;
        }

        return sprintf('%s%04d', $prefix, $nextSeq);
    }
}
