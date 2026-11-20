<?php

namespace App\Console\Commands;

use App\Services\DiscordAppUpdateService;
use Illuminate\Console\Command;

class SendDiscordUpdatePanel extends Command
{
    protected $signature = 'discord:send-update-panel';
    protected $description = 'Kirim pesan Panel Pengumuman Update Aplikasi ke channel Discord';

    public function handle()
    {
        $this->info('Mengirim Panel Kontrol Pembaruan ke channel Discord...');

        $result = DiscordAppUpdateService::sendControlPanelToChannel();

        if ($result['success']) {
            $this->info('✅ ' . $result['message']);
            return Command::SUCCESS;
        } else {
            $this->error('❌ ' . $result['message']);
            return Command::FAILURE;
        }
    }
}
