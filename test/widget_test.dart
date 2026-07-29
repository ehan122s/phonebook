import 'package:flutter_test/flutter_test.dart';
import 'package:sipenyuluh/main.dart';

void main() {
  testWidgets('shows setup when Supabase is not configured', (tester) async {
    await tester.pumpWidget(const SipenyuluhApp(isSupabaseConfigured: false));
    expect(find.text('SIPENYULUH'), findsOneWidget);
  });
}
