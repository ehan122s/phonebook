<?php

use Illuminate\Support\Facades\Schedule;
use Illuminate\Support\Facades\Artisan;

Artisan::command('schedules:remind', function () {
    $this->call('schedules:send-reminders');
})->purpose('Kirim pengingat jadwal kegiatan via WhatsApp & Notifikasi');

Schedule::command('schedules:send-reminders')->everyMinute();
