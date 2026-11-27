import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/pages/ai/ai_agent_page.dart';
import 'package:frontend/services/ai_agent_service.dart';

void main() {
  group('AiAgentService & AiAgentPage Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({'user_id': '99'});
    });

    test('saveHistory and loadHistory persist bounded conversation per user', () async {
      final messages = List.generate(
        50,
        (i) => AiChatMessage(
          id: 'm_$i',
          role: i.isEven ? 'user' : 'assistant',
          content: 'Pesan ke-$i',
          createdAt: DateTime(2026, 11, 27, 9, 0),
        ),
      );

      await AiAgentService.instance.saveHistory(messages);
      final loaded = await AiAgentService.instance.loadHistory();

      // Maksimal 40 pesan tersimpan agar riwayat tidak membengkak tanpa batas
      expect(loaded.length, 40);
      expect(loaded.first.content, 'Pesan ke-10');
      expect(loaded.last.content, 'Pesan ke-49');

      await AiAgentService.instance.clearHistory();
      final afterClear = await AiAgentService.instance.loadHistory();
      expect(afterClear, isEmpty);
    });

    testWidgets('AiAgentPage renders starter prompts and input bar cleanly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AiAgentPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Asisten AI Phonebook'), findsOneWidget);
      expect(find.text('Rangkum laporan terbaru saya'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    });
  });
}
