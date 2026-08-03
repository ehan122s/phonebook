import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipenyuluh/main.dart';
import 'package:sipenyuluh/src/halaman/dashboard/ringkasan.dart';

void main() {
  testWidgets('shows setup when Supabase is not configured', (tester) async {
    await tester.pumpWidget(const SipenyuluhApp(isSupabaseConfigured: false));
    expect(find.text('SIPENYULUH'), findsOneWidget);
  });

  testWidgets('shows stat cards on a narrow dashboard layout', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: 'Total Dokumen',
                    value: '12',
                    icon: Icons.folder_open_rounded,
                    color: Color(0xFF047857),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    label: 'Pengumuman Baru',
                    value: '1',
                    icon: Icons.notifications_active_rounded,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Total Dokumen'), findsOneWidget);
    expect(find.text('Pengumuman Baru'), findsOneWidget);
  });
}
