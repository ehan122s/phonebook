<?php

namespace Tests;

use Illuminate\Foundation\Testing\TestCase as BaseTestCase;
use Illuminate\Support\Facades\DB;

abstract class TestCase extends BaseTestCase
{
    public function createApplication()
    {
        $app = parent::createApplication();
        $config = $app->make('config');

        if ($config->get('database.default') === 'sqlite') {
            $dbPath = $config->get('database.connections.sqlite.database');
            if ($dbPath === ':memory:') {
                $dbPath = sys_get_temp_dir() . '/phonebook_phpunit_' . getmypid() . '.sqlite';
                if (!file_exists($dbPath)) {
                    @touch($dbPath);
                }
                $config->set('database.connections.sqlite.database', $dbPath);
            }

            $sqliteCfg = $config->get('database.connections.sqlite');
            foreach (['pgsql', 'mysql', 'db_laporan', 'db_foto', 'db_materi'] as $conn) {
                $config->set("database.connections.{$conn}", $sqliteCfg);
            }
        }

        return $app;
    }

    protected function setUp(): void
    {
        parent::setUp();

        if (config('database.default') === 'sqlite') {
            $pdo = DB::connection()->getPdo();
            foreach (['pgsql', 'mysql', 'db_laporan', 'db_foto', 'db_materi'] as $conn) {
                DB::connection($conn)->setPdo($pdo);
                DB::connection($conn)->setReadPdo($pdo);
            }
            if (!\Illuminate\Support\Facades\Schema::hasTable('users')) {
                $this->artisan('migrate');
            }
        }
    }
}
