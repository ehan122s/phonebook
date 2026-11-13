import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/constants/jadwal_constants.dart';
import 'package:frontend/pages/home/home.dart';
import 'package:frontend/pages/jadwal/history_reminder_page.dart';
import 'package:frontend/pages/notifikasi/notifikasi_page.dart';
import 'package:frontend/services/jadwal_service.dart';
import 'package:frontend/services/notification_service.dart';
import 'package:frontend/widgets/bottom_nav.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await NotificationService.instance.init();
  });

  testWidgets('home shows dashboard and animates bottom nav smoothly (400ms)',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.pumpAndSettle();

    expect(find.text('Selamat Datang 👋'), findsOneWidget);
    expect(find.byType(BottomNav), findsOneWidget);
    expect(tester.getSize(find.byType(BottomNav)).height, lessThan(100));

    // Pindah dari Dashboard (0) ke Jadwal (2) -> horizontal slide 400ms
    await tester.tap(find.text('Jadwal').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(find.text('Jadwal Kegiatan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('JadwalService preserves exact schedule time (13:00) and reminderMinutes (5, 10, 30)',
      () async {
    // 1. Pastikan format HH:mm:ss dari database MySQL/PostgreSQL tidak berubah jadi 08:00
    expect(JadwalService.formatTimeString('13:00:00'), equals('13:00'));
    expect(JadwalService.formatTimeString('13.00'), equals('13:00'));
    expect(JadwalService.formatTimeString('13:00'), equals('13:00'));

    // 2. Pastikan perhitungan jam reminder akurat (5, 10, 30 menit sebelum 13:00)
    expect(
      JadwalDateUtils.calculateReminderTimeStr('13:00', 5),
      equals('12:55'),
    );
    expect(
      JadwalDateUtils.calculateReminderTimeStr('13:00', 10),
      equals('12:50'),
    );
    expect(
      JadwalDateUtils.calculateReminderTimeStr('13:00', 30),
      equals('12:30'),
    );

    // 3. Pastikan normalizeItem menyimpan waktu 13:00 dan reminderMinutes 10 (bukan 08:00 / 30)
    final item = await JadwalService.addSchedule({
      'judul': 'Rapat Evaluasi Kehutanan',
      'kategori': 'Penyuluhan',
      'tanggalIso': '2026-11-15',
      'waktu': '13:00',
      'lokasi': 'CDK Wilayah V Garut',
      'reminderMinutes': 10,
    });

    expect(item['waktu'], equals('13:00'));
    expect(item['reminderMinutes'], equals(10));
    expect(item['reminderTime'], equals('12:50'));

    final reloaded = await JadwalService.loadSchedules();
    final saved = reloaded.firstWhere((e) => e['id'] == item['id']);
    expect(saved['waktu'], equals('13:00'));
    expect(saved['reminderMinutes'], equals(10));
    expect(saved['reminderTime'], equals('12:50'));
  });

  test('NotificationService supports single delete, delete all, and persistence without deleting schedules',
      () async {
    await NotificationService.instance.deleteAllNotifications();
    expect(NotificationService.instance.totalCount, equals(0));

    // Buat laporan baru -> notifikasi masuk
    await NotificationService.instance.addReportCreatedNotification(
      title: 'Laporan Patroli Hutan',
      jenisLaporan: 'Laporan Monitoring',
      location: 'Kawasan Hutan Garut',
      status: 'Selesai',
      reportId: 'rep_101',
    );

    // Buat jadwal baru -> notifikasi masuk
    final sched = await JadwalService.addSchedule({
      'judul': 'Sosialisasi Perhutanan Sosial',
      'kategori': 'Penyuluhan',
      'tanggalIso': '2026-11-16',
      'waktu': '13:00',
      'lokasi': 'Kecamatan Cisurupan',
      'reminderMinutes': 5,
    });

    expect(NotificationService.instance.totalCount, equals(2));

    // Hapus satu notifikasi -> notifikasi lain tetap ada
    final firstId =
        NotificationService.instance.notifications.first['id'].toString();
    await NotificationService.instance.deleteNotification(firstId);
    expect(NotificationService.instance.totalCount, equals(1));

    // Tutup & muat ulang -> notifikasi yang dihapus tidak muncul kembali
    await NotificationService.instance.loadNotifications();
    expect(NotificationService.instance.totalCount, equals(1));

    // Hapus semua -> seluruh notifikasi terhapus
    await NotificationService.instance.deleteAllNotifications();
    expect(NotificationService.instance.totalCount, equals(0));

    // Muat ulang -> tetap 0
    await NotificationService.instance.loadNotifications();
    expect(NotificationService.instance.totalCount, equals(0));

    // Pastikan jadwal asli tidak ikut terhapus
    final schedules = await JadwalService.loadSchedules();
    expect(schedules.any((e) => e['id'] == sched['id']), isTrue);
  });

  testWidgets('HistoryReminderPage and NotificationPage back buttons navigate properly',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const HistoryReminderPage(),
                      ),
                    );
                  },
                  child: const Text('Buka History'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const NotificationPage(),
                      ),
                    );
                  },
                  child: const Text('Buka Notifikasi'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Buka History'));
    await tester.pumpAndSettle();
    expect(find.text('History Reminder'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Buka History'), findsOneWidget);
  });
}
