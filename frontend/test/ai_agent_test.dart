import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
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

    testWidgets('AiAgentPage renders AI Markdown responses (bold, italic, headings, lists, code) without raw markers', (tester) async {
      const sampleReply = '''
### Ringkasan Langkah

**Panduan Upload Materi**

1. **Buka Tab Materi**
   Pilih menu Materi pada beranda aplikasi.

2. **Tekan tombol Tambah Materi**
   Gunakan tombol upload dengan format _PDF_ atau *gambar* maksimal `10MB`.

- Pastikan koneksi stabil.
''';

      await AiAgentService.instance.saveHistory([
        AiChatMessage(
          id: 'u_1',
          role: 'user',
          content: 'Bagaimana cara upload materi?',
          createdAt: DateTime(2026, 11, 27, 10, 0),
        ),
        AiChatMessage(
          id: 'a_1',
          role: 'assistant',
          content: sampleReply,
          createdAt: DateTime(2026, 11, 27, 10, 1),
          usedTools: const ['get_app_features_guide'],
        ),
      ]);

      await tester.pumpWidget(
        const MaterialApp(
          home: AiAgentPage(),
        ),
      );
      await tester.pumpAndSettle();

      // Pesan user dan badge tool tetap tampil
      expect(find.text('Bagaimana cara upload materi?'), findsOneWidget);
      expect(find.text('Menggunakan: Panduan Phonebook'), findsOneWidget);

      // Jawaban AI dirender menggunakan MarkdownBody
      expect(find.byType(MarkdownBody), findsOneWidget);

      // Simbol Markdown mentah tidak tampil pada teks ter-render
      expect(find.textContaining('**'), findsNothing);
      expect(find.textContaining('###'), findsNothing);

      // Teks hasil parsing tampil rapi dengan bold span pada teks penting
      expect(find.textContaining('Panduan Upload Materi', findRichText: true), findsOneWidget);
      expect(find.textContaining('Buka Tab Materi', findRichText: true), findsOneWidget);
      expect(find.textContaining('Tekan tombol Tambah Materi', findRichText: true), findsOneWidget);

      bool hasBoldSpan = false;
      bool hasItalicSpan = false;

      bool inspectSpan(InlineSpan? root, String targetText, {bool checkBold = false, bool checkItalic = false}) {
        if (root == null) return false;
        if (root is TextSpan) {
          final matchesText = root.text?.contains(targetText) ?? false;
          final matchesStyle = (!checkBold ||
                  root.style?.fontWeight == FontWeight.w700 ||
                  root.style?.fontWeight == FontWeight.bold) &&
              (!checkItalic || root.style?.fontStyle == FontStyle.italic);
          if (matchesText && matchesStyle) {
            return true;
          }
          if (root.children != null) {
            return root.children!.any(
              (child) => inspectSpan(
                child,
                targetText,
                checkBold: checkBold,
                checkItalic: checkItalic,
              ),
            );
          }
        }
        return false;
      }

      for (final st in tester.widgetList<SelectableText>(find.byType(SelectableText))) {
        if (inspectSpan(st.textSpan, 'Buka Tab Materi', checkBold: true)) {
          hasBoldSpan = true;
        }
        if (inspectSpan(st.textSpan, 'PDF', checkItalic: true)) {
          hasItalicSpan = true;
        }
      }
      for (final rt in tester.widgetList<RichText>(find.byType(RichText))) {
        if (inspectSpan(rt.text, 'Buka Tab Materi', checkBold: true)) {
          hasBoldSpan = true;
        }
        if (inspectSpan(rt.text, 'PDF', checkItalic: true)) {
          hasItalicSpan = true;
        }
      }

      expect(hasBoldSpan, isTrue);
      expect(hasItalicSpan, isTrue);
    });

    testWidgets('AiAgentPage supports starting a new conversation and clears stored history', (tester) async {
      await AiAgentService.instance.saveHistory([
        AiChatMessage(
          id: 'u_prev',
          role: 'user',
          content: 'Pesan lama tersimpan',
          createdAt: DateTime(2026, 11, 27, 9, 30),
        ),
        AiChatMessage(
          id: 'a_prev',
          role: 'assistant',
          content: '**Jawaban tersimpan** sebelumnya.',
          createdAt: DateTime(2026, 11, 27, 9, 31),
        ),
      ]);

      await tester.pumpWidget(
        const MaterialApp(
          home: AiAgentPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pesan lama tersimpan'), findsOneWidget);
      expect(find.byIcon(Icons.add_comment_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add_comment_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Mulai Percakapan Baru?'), findsOneWidget);
      await tester.tap(find.text('Percakapan Baru'));
      await tester.pumpAndSettle();

      expect(find.text('Halo! Saya Asisten AI Phonebook'), findsOneWidget);
      expect(await AiAgentService.instance.loadHistory(), isEmpty);
    });
  });
}
