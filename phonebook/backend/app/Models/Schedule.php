<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Schedule extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'title',
        'category',
        'date',
        'start_time',
        'end_time',
        'location',
        'description',
        'reminder_enabled',
        'reminder_minutes',
        'reminder_at',
        'whatsapp_sent',
        'is_completed',
    ];

    protected $casts = [
        'date' => 'date:Y-m-d',
        'reminder_enabled' => 'boolean',
        'reminder_minutes' => 'integer',
        'reminder_at' => 'datetime',
        'whatsapp_sent' => 'boolean',
        'is_completed' => 'boolean',
    ];

    /**
     * Pastikan start_time selalu dikembalikan dalam format HH:mm (tanpa detik :00)
     * agar konsisten antara frontend Flutter dan backend Laravel.
     */
    public function getStartTimeAttribute($value): ?string
    {
        if ($value === null || $value === '') {
            return null;
        }
        $str = trim((string) $value);
        if (preg_match('/^(\d{1,2}):(\d{2})(?::\d{2})?$/', $str, $matches)) {
            return str_pad($matches[1], 2, '0', STR_PAD_LEFT) . ':' . $matches[2];
        }
        return $str;
    }

    public function getEndTimeAttribute($value): ?string
    {
        if ($value === null || $value === '') {
            return null;
        }
        $str = trim((string) $value);
        if (preg_match('/^(\d{1,2}):(\d{2})(?::\d{2})?$/', $str, $matches)) {
            return str_pad($matches[1], 2, '0', STR_PAD_LEFT) . ':' . $matches[2];
        }
        return $str;
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}