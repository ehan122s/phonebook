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
        'date',
        'start_time',
        'end_time',
        'location',
        'description',
        'reminder_enabled',
        'reminder_at',
        'whatsapp_sent',
    ];

    protected $casts = [
        'date' => 'date',
        'reminder_enabled' => 'boolean',
        'reminder_at' => 'datetime',
        'whatsapp_sent' => 'boolean',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}