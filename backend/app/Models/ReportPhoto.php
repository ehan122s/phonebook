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
        'imagekit_file_id',
        'imagekit_url',
        'file_name',
        'mime_type',
        'file_size',
        'storage_provider',
    ];

    protected $connection = 'db_foto';

    protected $hidden = [
        'photo_base64', // Wajib disembunyikan agar query list laporan tidak meledak hingga 7MB+
    ];

    protected $appends = [
        'url',
    ];

    protected $casts = [
        'latitude' => 'decimal:7',
        'longitude' => 'decimal:7',
        'file_size' => 'integer',
    ];

    public function getUrlAttribute(): string
    {
        // 1. Prioritaskan URL ImageKit jika tersedia
        if (!empty($this->imagekit_url) && filter_var($this->imagekit_url, FILTER_VALIDATE_URL)) {
            return $this->imagekit_url;
        }

        // 2. Gunakan URL eksternal atau data URI jika tersimpan langsung di kolom photo
        if (!empty($this->photo) && (filter_var($this->photo, FILTER_VALIDATE_URL) || str_starts_with($this->photo, 'data:image'))) {
            return $this->photo;
        }

        // 3. Fallback untuk foto lama (storage lokal atau base64 legacy)
        $base = 'https://phonebook-five-umber.vercel.app';
        if (!app()->runningInConsole() && request()) {
            $host = request()->getSchemeAndHttpHost();
            if ($host && !str_contains($host, 'localhost') && !str_contains($host, '127.0.0.1')) {
                $base = $host;
            }
        }

        return rtrim($base, '/') . '/api/report-photos/' . $this->id . '/file';
    }

    /**
     * Relasi cross-database: reports ada di db_laporan.
     */
    public function report()
    {
        return $this->belongsTo(Report::class);
    }
}
