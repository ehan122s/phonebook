<?php

namespace App\Console\Commands;

use App\Models\AppNotification;
use App\Models\Schedule;
use App\Services\WhatsappService;
use Illuminate\Console\Command;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Schema;

class SendScheduleReminders extends Command
{
    protected $signature = 'schedules:send-reminders {--retry-failed : Coba kirim ulang jadwal yang sebelumnya gagal}';
    protected $description = 'Kirim pengingat jadwal kegiatan secara otomatis kepada pegawai via WhatsApp Fonnte (Asia/Jakarta)';

    public function handle()
    {
        $now = Carbon::now('Asia/Jakarta');
        $retryFailed = $this->option('retry-failed');

        $this->info("[$now] Memeriksa jadwal untuk pengingat WhatsApp otomatis...");

        $query = Schedule::with('user')
            ->where('reminder_enabled', true)
            ->whereNotNull('reminder_at')
            ->where('reminder_at', '<=', $now);

        if ($retryFailed) {
            $query->whereIn('whatsapp_status', ['pending', 'failed']);
        } else {
            $query->where(function ($q) {
                $q->where('whatsapp_status', 'pending')
                  ->orWhere(function ($sub) {
                      $sub->whereNull('whatsapp_status')
                          ->where('whatsapp_sent', false);
                  });
            });
        }

        // Jangan kirim ulang yang sudah berstatus 'sent'
        $query->where('whatsapp_status', '!=', 'sent')
              ->where('whatsapp_sent', false);

        $schedules = $query->get();

        if ($schedules->isEmpty()) {
            $this->line("Tidak ada pengingat yang perlu dikirim saat ini.");
            return Command::SUCCESS;
        }

        $this->info("Ditemukan {$schedules->count()} jadwal yang jatuh tempo pengingat.");

        foreach ($schedules as $schedule) {
            $user = $schedule->user;
            $timeStr = $schedule->start_time ?? '08:00';
            $location = $schedule->location ?? 'Wilayah Kerja CDK Wilayah V';
            $category = $schedule->category ?? 'Penyuluhan';
            $reminderMinutes = $schedule->reminder_minutes ?? 30;

            // Jika notifikasi WA dinonaktifkan pada jadwal ini
            if (isset($schedule->enable_wa_notification) && !$schedule->enable_wa_notification) {
                $schedule->update([
                    'whatsapp_status' => 'disabled',
                ]);
                $this->line("Jadwal #{$schedule->id} ({$schedule->title}): Notifikasi WhatsApp dinonaktifkan.");
                continue;
            }

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

            // Tentukan target nomor WhatsApp
            $targetPhone = !empty($schedule->wa_phone)
                ? $schedule->wa_phone
                : ($user ? ($user->whatsapp_number ?: $user->phone) : null);

            if (empty($targetPhone)) {
                $errorMsg = 'Nomor WhatsApp penerima tidak ditemukan';
                $schedule->update([
                    'whatsapp_status' => 'failed',
                    'whatsapp_error' => $errorMsg,
                ]);
                $this->error("Jadwal #{$schedule->id}: Gagal - {$errorMsg}");
                continue;
            }

            $res = null;
            $waDelivered = false;
            try {
                // Pengiriman langsung seketika (tanpa parameter schedule karena sudah jatuh tempo)
                $res = WhatsappService::sendReminder($targetPhone, $message);
                $waDelivered = !empty($res['success']);
            } catch (\Throwable $e) {
                $res = [
                    'success' => false,
                    'reason' => 'Exception: ' . $e->getMessage(),
                ];
                Log::error("SendScheduleReminders exception jadwal #{$schedule->id}: " . $e->getMessage());
            }

            if ($waDelivered) {
                $schedule->update([
                    'whatsapp_status' => 'sent',
                    'whatsapp_sent' => true,
                    'whatsapp_sent_at' => Carbon::now('Asia/Jakarta'),
                    'whatsapp_error' => null,
                    'whatsapp_message_id' => $res['message_id'] ?? null,
                ]);
                $this->info("Jadwal #{$schedule->id} ({$schedule->title}): Terkirim ke {$targetPhone} via Fonnte.");
            } else {
                $reason = $res['reason'] ?? 'Gagal mengirim pesan via WhatsApp API Gateway';
                $schedule->update([
                    'whatsapp_status' => 'failed',
                    'whatsapp_error' => $reason,
                ]);
                $this->warn("Jadwal #{$schedule->id} ({$schedule->title}): Gagal kirim ke {$targetPhone}. Alasan: {$reason}");
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
                            'whatsapp_delivered' => $waDelivered,
                            'whatsapp_status' => $waDelivered ? 'sent' : 'failed',
                            'whatsapp_error' => $waDelivered ? null : ($res['reason'] ?? null),
                        ],
                        'is_read' => false,
                    ]);
                }
            } catch (\Throwable $e) {
                Log::warning("AppNotification creation error: " . $e->getMessage());
            }
        }

        return Command::SUCCESS;
    }
}
