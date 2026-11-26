<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ReportTemplate extends Model
{
    use HasFactory;

    protected $connection = 'db_laporan';

    protected $fillable = [
        'name',
        'category',
        'description',
        'fields_config',
        'placeholders',
        'file_name',
        'file_path',
        'file_base64',
        'is_active',
        'uploaded_by',
        'template_body',
        'icon_key',
        'default_title',
        'require_photo',
        'require_location',
    ];

    protected $casts = [
        'fields_config' => 'array',
        'placeholders' => 'array',
        'is_active' => 'boolean',
        'require_photo' => 'boolean',
        'require_location' => 'boolean',
    ];

    protected $appends = [
        'title',
    ];

    /**
     * Map 'name' column to 'title' attribute for full frontend compatibility.
     */
    public function getTitleAttribute(): ?string
    {
        return $this->name;
    }

    public function setTitleAttribute(?string $value): void
    {
        $this->attributes['name'] = $value;
    }

    /**
     * Relasi cross-database: users ada di database utama (mysql).
     * Laravel otomatis menggunakan connection dari model User.
     */
    public function user()
    {
        return $this->belongsTo(User::class, 'uploaded_by');
    }
}
