<?php

// Pastikan direktori storage di /tmp tersedia untuk lingkungan serverless Vercel
$storageDirs = [
    '/tmp/storage/framework/views',
    '/tmp/storage/framework/cache',
    '/tmp/storage/framework/cache/data',
    '/tmp/storage/framework/sessions',
    '/tmp/storage/logs',
    '/tmp/storage/app/public',
];

foreach ($storageDirs as $dir) {
    if (!is_dir($dir)) {
        mkdir($dir, 0755, true);
    }
}

// Reset SCRIPT_NAME agar Symfony/Laravel tidak memotong prefix '/api' dari REQUEST_URI
$_SERVER['SCRIPT_NAME'] = '/index.php';
$_SERVER['PHP_SELF'] = '/index.php';

// Teruskan request ke public/index.php Laravel
require __DIR__ . '/../public/index.php';
