<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ReportPhoto extends Model
{
    use HasFactory;

    protected $fillable = [
        'report_id',
        'photo',
        'photo_base64',
        'latitude',
        'longitude',
    ];

    protected $hidden = [
        'photo_base64',
    ];

    protected $appends = [
        'url',
    ];

    protected $casts = [
        'latitude' => 'decimal:7',
        'longitude' => 'decimal:7',
    ];

    public function getUrlAttribute()
    {
        if (filter_var($this->photo, FILTER_VALIDATE_URL)) {
            return $this->photo;
        }
        return url('/api/report-photos/' . $this->id . '/file');
    }

    public function report()
    {
        return $this->belongsTo(Report::class);
    }
}