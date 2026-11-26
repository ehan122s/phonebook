<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Report extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'category_id',
        'title',
        'activity_date',
        'location',
        'latitude',
        'longitude',
        'description',
        'status',
    ];

    
protected static function booted(): void
{
    static::deleting(function (Report $report) {
        $report->photos()->delete();
        try {
            $report->files()->delete();
        } catch (\Throwable $e) {
            // Abaikan jika tabel report_files belum dimigrasi
        }
    });
}

    protected $casts = [
        'activity_date' => 'date',
        'latitude' => 'decimal:7',
        'longitude' => 'decimal:7',
    ];

    /**
     * Relasi cross-database: users ada di database utama (mysql).
     * Laravel otomatis menggunakan connection dari model User.
     */
    public function user()
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Relasi cross-database: categories ada di database utama (mysql).
     * Laravel otomatis menggunakan connection dari model Category.
     */
    public function category()
    {
        return $this->belongsTo(Category::class);
    }

    /**
     * Relasi cross-database: report_photos ada di db_foto.
     * Laravel otomatis menggunakan connection dari model ReportPhoto.
     */
    public function photos()
    {
        return $this->hasMany(ReportPhoto::class);
    }

    /**
     * Relasi ke dokumen/lampiran laporan di Supabase Storage.
     */
    public function files()
    {
        return $this->hasMany(ReportFile::class);
    }

    protected $connection = 'db_laporan';

}