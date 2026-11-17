<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class BugReport extends Model
{
    protected $fillable = [
        'ticket_code',
        'ticket_number',
        'user_id',
        'reporter_name',
        'reporter_email',
        'reporter_phone',
        'whatsapp',
        'category',
        'priority',
        'title',
        'description',
        'rejection_reason',
        'resolution_reason',
        'handled_by',
        'developer_id',
        'app_version',
        'device_info',
        'discord_sent',
        'discord_error',
        'discord_message_id',
        'discord_channel_id',
        'status',
        'approved_at',
        'accepted_at',
        'resolved_at',
        'wa_sent',
        'wa_status',
        'whatsapp_delivery_status',
        'wa_history',
    ];

    protected $casts = [
        'discord_sent' => 'boolean',
        'wa_sent' => 'boolean',
        'wa_history' => 'array',
        'approved_at' => 'datetime',
        'accepted_at' => 'datetime',
        'resolved_at' => 'datetime',
    ];

    protected static function booted()
    {
        static::saving(function ($model) {
            if (empty($model->ticket_number) && !empty($model->ticket_code)) {
                $model->ticket_number = $model->ticket_code;
            } elseif (empty($model->ticket_code) && !empty($model->ticket_number)) {
                $model->ticket_code = $model->ticket_number;
            }
            if (empty($model->whatsapp) && !empty($model->reporter_phone)) {
                $model->whatsapp = $model->reporter_phone;
            } elseif (empty($model->reporter_phone) && !empty($model->whatsapp)) {
                $model->reporter_phone = $model->whatsapp;
            }
            if (empty($model->accepted_at) && !empty($model->approved_at)) {
                $model->accepted_at = $model->approved_at;
            } elseif (empty($model->approved_at) && !empty($model->accepted_at)) {
                $model->approved_at = $model->accepted_at;
            }
            if (empty($model->whatsapp_delivery_status) && !empty($model->wa_status)) {
                $model->whatsapp_delivery_status = $model->wa_status;
            } elseif (empty($model->wa_status) && !empty($model->whatsapp_delivery_status)) {
                $model->wa_status = $model->whatsapp_delivery_status;
            }
        });
    }

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
