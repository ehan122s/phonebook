<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Report extends Model
{
    use HasFactory;

    protected $connection = 'db_laporan';

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
        'report_type',
        'activity_name',
        'monitoring_period',
        'officer_name',
        'target_value',
        'target_unit',
        'target_period',
        'actual_value',
        'achievement_percentage',
        'remaining_target',
        'achievement_status',
        'field_facts',
        'obstacles',
        'failure_causes',
        'recommendations',
        'follow_up_plan',
        'next_target_date',
        'monitoring_data',
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
        'next_target_date' => 'date:Y-m-d',
        'latitude' => 'decimal:7',
        'longitude' => 'decimal:7',
        'target_value' => 'float',
        'actual_value' => 'float',
        'achievement_percentage' => 'float',
        'remaining_target' => 'float',
        'monitoring_data' => 'array',
    ];

    /**
     * Relasi cross-database: users ada di database utama.
     */
    public function user()
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Relasi cross-database: categories ada di database utama.
     */
    public function category()
    {
        return $this->belongsTo(Category::class);
    }

    /**
     * Relasi cross-database: report_photos ada di db_foto.
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
}
