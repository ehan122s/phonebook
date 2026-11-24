<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Material extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'category_id',
        'category_name',
        'title',
        'description',
        'file_path',
        'file_name',
        'file_type',
        'uploader_name',
        'uploader_role',
    ];

    protected $connection = 'db_materi';

    protected $appends = [
        'uploader',
        'download_url',

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

    public function getUploaderAttribute(): string
    {
        if (!empty($this->uploader_name)) {
            return $this->uploader_name;
        }

        if ($this->user && !empty($this->user->name)) {
            return $this->user->name;
        }

        return 'Administrator Kehutanan';
    }

    public function getDownloadUrlAttribute(): string
    {
        if (filter_var($this->file_path, FILTER_VALIDATE_URL)) {
            return $this->file_path;
        }

        $base = 'https://phonebook-five-umber.vercel.app';
        if (!app()->runningInConsole() && request()) {
            $host = request()->getSchemeAndHttpHost();
            if ($host && !str_contains($host, 'localhost') && !str_contains($host, '127.0.0.1')) {
                $base = $host;
            }
        }

        return rtrim($base, '/') . '/api/materials/' . $this->id . '/download';
    }
}
