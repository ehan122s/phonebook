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
        'address',
    ];

    protected $hidden = [
        // Jangan sembunyikan photo_base64 agar klien Flutter dapat langsung merender/mengunduh dokumen
        // tanpa bergantung pada HTTP roundtrip sekunder yang rawan lambat atau terblokir.
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
        if (!empty($this->photo) && (filter_var($this->photo, FILTER_VALIDATE_URL) || str_starts_with($this->photo, 'data:image'))) {
            return $this->photo;
        }

        $base = 'https://phonebook-five-umber.vercel.app';
        if (!app()->runningInConsole() && request()) {
            $host = request()->getSchemeAndHttpHost();
            if ($host && !str_contains($host, 'localhost') && !str_contains($host, '127.0.0.1')) {
                $base = $host;
            }
        }

        return rtrim($base, '/') . '/api/report-photos/' . $this->id . '/file';
    }

    public function report()
    {
        return $this->belongsTo(Report::class);
    }
}