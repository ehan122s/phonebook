<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ReportFile extends Model
{
    use HasFactory;

    protected $connection = 'db_laporan';

    protected $fillable = [
        'report_id',
        'user_id',
        'title',
        'description',
        'file_name',
        'storage_bucket',
        'storage_path',
        'file_url',
        'mime_type',
        'file_size',
    ];

    protected $casts = [
        'file_size' => 'integer',
    ];

    protected $appends = [
        'download_url',
    ];

    public function getDownloadUrlAttribute(): string
    {
        $base = 'https://phonebook-five-umber.vercel.app';
        if (!app()->runningInConsole() && request()) {
            $host = request()->getSchemeAndHttpHost();
            if ($host && !str_contains($host, 'localhost') && !str_contains($host, '127.0.0.1')) {
                $base = $host;
            }
        }

        return rtrim($base, '/') . '/api/report-files/' . $this->id . '/download';
    }

    public function report()
    {
        return $this->belongsTo(Report::class);
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
