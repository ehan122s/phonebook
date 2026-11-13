<?php

namespace App\Console\Commands;

use App\Models\AppNotification;
use App\Models\Schedule;
use App\Services\WhatsappService;
use Illuminate\Console\Command;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Schema;

class SendScheduleReminders extends Command
{
    protected $signature = 'schedules:send-reminders';
    protected $description = 'Kirim pengingat jadwal kegiatan kepada pegawai sesuai waktu reminder (Asia/Jakarta)';

    public function handle()
    {
        $now = Carbon::now('Asia/Jakarta');

        $schedules = Schedule::with('user')
            ->where('reminder_enabled', true)
            ->where('whatsapp_sent', false)
            ->whereNotNull('reminder_at')
            ->where('reminder_at', '<=', $now)
            ->get();

        foreach ($schedules as $schedule) {
            $user = $schedule->user;
            $timeStr = $schedule->start_time ?? '08:00';
            $location = $schedule->location ?? '-';
            $reminderMinutes = $schedule->reminder_minutes ?? 30;

            $message = "Pengingat Jadwal Kegiatan: \"{$schedule->title}\" akan dilaksanakan pada {$schedule->date->format('Y-m-d')} pukul {$timeStr} WIB di {$location} (Pengingat {$reminderMinutes} menit sebelum jadwal).";

            if ($user && !empty($user->whatsapp_number)) {
                try {
                    WhatsappService::sendReminder($user->whatsapp_number, $message);
                } catch (\Throwable $e) {
                    // Lanjutkan meskipun pengiriman WA gagal
                }
            }

            try {
                if (Schema::hasTable('app_notifications') && $user) {
                    AppNotification::create([
                        'user_id' => $user->id,
                        'type' => 'reminder',
                        'title' => 'Pengingat Jadwal: ' . $schedule->title,
                        'message' => $message,
                        'reference_id' => 'reminder_' . $schedule->id,
                        'metadata' => [
                            'schedule_id' => $schedule->id,
                            'date' => $schedule->date->format('Y-m-d'),
                            'start_time' => $timeStr,
                            'reminder_minutes' => $reminderMinutes,
                            'location' => $location,
                        ],
                        'is_read' => false,
                    ]);
                }
            } catch (\Throwable $e) {
            }

            $schedule->update(['whatsapp_sent' => true]);
        }

        return Command::SUCCESS;
    }
}
