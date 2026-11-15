<?php

namespace App\Jobs;

use App\Models\AppNotification;
use App\Models\Schedule;
use App\Services\WhatsappService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Schema;

class SendScheduleWhatsappReminder implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public Schedule $schedule;

    /**
     * Create a new job instance.
     */
    public function __construct(Schedule $schedule)
    {
        $this->schedule = $schedule;
    }

    /**
     * Execute the job.
     */
    public function handle(): void
    {
        // Reload schedule dari database untuk memeriksa status terkini
        $schedule = Schedule::with('user')->find($this->schedule->id);
        if (!$schedule) {
            Log::info("Job SendScheduleWhatsappReminder: Jadwal #{$this->schedule->id} sudah tidak ada.");
            return;
        }

        // Cegah pengiriman ganda jika sudah terkirim atau dinonaktifkan
        if ($schedule->whatsapp_status === 'sent' || $schedule->whatsapp_sent) {
            Log::info("Job SendScheduleWhatsappReminder: Jadwal #{$schedule->id} sudah terkirim sebelumnya.");
            return;
        }

        if (isset($schedule->enable_wa_notification) && !$schedule->enable_wa_notification) {
            $schedule->update(['whatsapp_status' => 'disabled']);
            return;
        }

        $user = $schedule->user;
        $targetPhone = !empty($schedule->wa_phone)
            ? $schedule->wa_phone
            : ($user ? ($user->whatsapp_number ?: $user->phone) : null);

        if (empty($targetPhone)) {
            $schedule->update([
                'whatsapp_status' => 'failed',
                'whatsapp_error' => 'Nomor WhatsApp penerima kosong atau tidak valid',
            ]);
            return;
        }

        $timeStr = $schedule->start_time ?? '08:00';
        $location = $schedule->location ?? 'Wilayah Kerja CDK Wilayah V';
        $category = $schedule->category ?? 'Penyuluhan';
        $reminderMinutes = $schedule->reminder_minutes ?? 30;

        $dateFormatted = $schedule->date instanceof Carbon
            ? $schedule->date->translatedFormat('l, d F Y')
            : Carbon::parse($schedule->date)->translatedFormat('l, d F Y');

        $message = WhatsappService::formatReminderMessage(
            $schedule->title,
            $category,
            $dateFormatted,
            $timeStr,
            $location,
            $reminderMinutes,
            $schedule->description
        );

        $res = WhatsappService::sendReminder($targetPhone, $message);

        if (!empty($res['success'])) {
            $schedule->update([
                'whatsapp_status' => 'sent',
                'whatsapp_sent' => true,
                'whatsapp_sent_at' => Carbon::now('Asia/Jakarta'),
                'whatsapp_error' => null,
                'whatsapp_message_id' => $res['message_id'] ?? null,
            ]);
            Log::info("Job SendScheduleWhatsappReminder: Jadwal #{$schedule->id} berhasil dikirim ke {$targetPhone}.");
        } else {
            $reason = $res['reason'] ?? 'Gagal mengirim pesan pengingat ke Fonnte';
            $schedule->update([
                'whatsapp_status' => 'failed',
                'whatsapp_error' => $reason,
            ]);
            Log::warning("Job SendScheduleWhatsappReminder: Jadwal #{$schedule->id} gagal dikirim. Alasan: {$reason}");
        }

        // Catat ke app_notifications
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
                        'date' => $schedule->date instanceof Carbon ? $schedule->date->format('Y-m-d') : $schedule->date,
                        'start_time' => $timeStr,
                        'reminder_minutes' => $reminderMinutes,
                        'location' => $location,
                        'whatsapp_status' => !empty($res['success']) ? 'sent' : 'failed',
                        'whatsapp_error' => !empty($res['success']) ? null : ($res['reason'] ?? null),
                    ],
                    'is_read' => false,
                ]);
            }
        } catch (\Throwable $e) {
            Log::warning("Job AppNotification error: " . $e->getMessage());
        }
    }
}
