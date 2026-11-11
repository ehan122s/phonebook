<?php

namespace App\Console\Commands;

use App\Models\Schedule;
use Illuminate\Console\Command;
use Illuminate\Support\Carbon;

class SendScheduleReminders extends Command
{
    protected $signature = 'schedules:send-reminders';
    protected $description = 'Kirim pengingat jadwal kegiatan kepada pegawai';

    public function handle()
    {
        return Command::SUCCESS;
    }
}
