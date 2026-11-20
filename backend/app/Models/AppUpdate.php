<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class AppUpdate extends Model
{
    use HasFactory;

    protected $table = 'app_updates';

    protected $fillable = [
        'version',
        'title',
        'description',
        'apk_url',
        'type', // 'optional' or 'mandatory'
        'is_published',
        'published_at',
        'min_supported_version',
        'discord_user_id',
        'discord_user_name',
    ];

    protected $casts = [
        'is_published' => 'boolean',
        'published_at' => 'datetime',
    ];

    /**
     * Scope query untuk update yang sudah dipublikasikan.
     */
    public function scopePublished($query)
    {
        return $query->where('is_published', true);
    }

    /**
     * Memeriksa apakah update ini bertipe wajib (mandatory).
     */
    public function isMandatory(): bool
    {
        return strtolower((string) $this->type) === 'mandatory';
    }

    /**
     * Mengambil entitas update terbaru yang berstatus published.
     */
    public static function getLatestPublished(): ?self
    {
        return self::published()
            ->orderByDesc('published_at')
            ->orderByDesc('id')
            ->first();
    }

    /**
     * Membandingkan versi client dengan versi server.
     * Mengembalikan status apakah client perlu update dan apakah update tersebut wajib.
     */
    public static function checkUpdate(string $clientVersion): array
    {
        $cleanClient = preg_replace('/[^0-9.]/', '', explode('+', $clientVersion)[0]);
        $latest = self::getLatestPublished();

        if (!$latest) {
            return [
                'has_update' => false,
                'is_mandatory' => false,
                'current_version' => $clientVersion,
                'latest_version' => $clientVersion,
                'update' => null,
            ];
        }

        $cleanLatest = preg_replace('/[^0-9.]/', '', explode('+', $latest->version)[0]);

        // Periksa apakah versi server lebih tinggi dari versi klien
        $hasUpdate = version_compare($cleanClient, $cleanLatest, '<');

        // Periksa apakah ada aturan min_supported_version yang memaksa update mandatory
        $isMandatory = false;
        if ($hasUpdate) {
            if ($latest->isMandatory()) {
                $isMandatory = true;
            } elseif (!empty($latest->min_supported_version)) {
                $cleanMin = preg_replace('/[^0-9.]/', '', explode('+', $latest->min_supported_version)[0]);
                if (version_compare($cleanClient, $cleanMin, '<')) {
                    $isMandatory = true;
                }
            }
        }

        return [
            'has_update' => $hasUpdate,
            'is_mandatory' => $isMandatory,
            'current_version' => $clientVersion,
            'latest_version' => $latest->version,
            'update' => $hasUpdate ? $latest : null,
        ];
    }
}
