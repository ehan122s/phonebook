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

    protected $appends = [
        'uploader',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

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
}
