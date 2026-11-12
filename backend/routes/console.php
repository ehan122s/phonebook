use Illuminate\Support\Facades\Schedule;
use App\Models\Jadwal;
use App\Services\WhatsappService;
use Carbon\Carbon;

Schedule::call(function () {
    $now = Carbon::now('Asia/Jakarta');

    $schedules = Jadwal::where('is_completed', false)
        ->where('wa_notified', false)
        ->whereDate('tanggal_iso', $now->toDateString())
        ->get();

    foreach ($schedules as $jadwal) {
        $jadwalTime = Carbon::parse($jadwal->tanggal_iso . ' ' . $jadwal->waktu, 'Asia/Jakarta');
        $diffInMinutes = $now->diffInMinutes($jadwalTime, false);
        $reminderLimit = $jadwal->reminder_minutes ?? 30;

        // Jika waktu tersisa menuju jadwal <= batas pengingat (misal 30 menit)
        if ($diffInMinutes >= 0 && $diffInMinutes <= $reminderLimit) {
            $pesan = "*PENGINGAT JADWAL KEGIATAN CDK V*\n\n"
                   . "Halo, kegiatan Anda akan dimulai dalam *{$diffInMinutes} menit*:\n"
                   . "📌 *Kegiatan:* {$jadwal->judul}\n"
                   . "🏷️ *Kategori:* {$jadwal->kategori}\n"
                   . "⏰ *Waktu:* {$jadwal->waktu} WIB\n"
                   . "📍 *Lokasi:* {$jadwal->lokasi}\n\n"
                   . "Mohon persiapkan perlengkapan lapangan Anda.";

            if (!empty($jadwal->wa_phone)) {
                WhatsappService::sendReminder($jadwal->wa_phone, $pesan);
            }

            $jadwal->update(['wa_notified' => true]);
        }
    }
})->everyMinute();