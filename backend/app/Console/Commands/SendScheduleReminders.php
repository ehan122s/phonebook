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
            $category = $schedule->category ?? 'Penyuluhan';
            $reminderMinutes = $schedule->reminder_minutes ?? 30;

            $message = WhatsappService::formatReminderMessage(
                $schedule->title,
                $category,
                $schedule->date->format('d F Y'),
                $timeStr,
                $location,
                $reminderMinutes,
                $schedule->description
            );

            $targetPhone = !empty($schedule->wa_phone)
                ? $schedule->wa_phone
                : ($user ? $user->whatsapp_number : null);

            $waDelivered = false;
            if (!empty($targetPhone)) {
                try {
                    $res = WhatsappService::sendReminder($targetPhone, $message);
                    $waDelivered = !empty($res['success']);
                } catch (\Throwable $e) {
                    // Lanjutkan jika exception
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
                            'whatsapp_delivered' => $waDelivered,
                        ],
                        'is_read' => false,
                    ]);
                }
            } catch (\Throwable $e) {
            }

            if ($waDelivered) {
                $schedule->update(['whatsapp_sent' => true]);
            }
        }

        return Command::SUCCESS;
    }
}
