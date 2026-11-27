<?php

namespace App\Providers;

use DateTimeInterface;
use Illuminate\Database\Connection;
use Illuminate\Database\PostgresConnection;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        // PgBouncer / Supabase Transaction Pooler (port 6543) memakai PDO::ATTR_EMULATE_PREPARES=true.
        // Pada mode emulasi, default Connection::prepareBindings mengubah boolean menjadi integer (1/0),
        // yang ditolak PostgreSQL pada kolom boolean (SQLSTATE[42804]). Mengirim literal 'true'/'false'
        // valid baik pada mode emulasi maupun native prepared statement PostgreSQL.
        Connection::resolverFor('pgsql', function ($connection, $database, $prefix, $config) {
            return new class($connection, $database, $prefix, $config) extends PostgresConnection {
                public function prepareBindings(array $bindings): array
                {
                    $grammar = $this->getQueryGrammar();

                    foreach ($bindings as $key => $value) {
                        if ($value instanceof DateTimeInterface) {
                            $bindings[$key] = $value->format($grammar->getDateFormat());
                        } elseif (is_bool($value)) {
                            $bindings[$key] = $value ? 'true' : 'false';
                        }
                    }

                    return $bindings;
                }
            };
        });
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        //
    }
}
