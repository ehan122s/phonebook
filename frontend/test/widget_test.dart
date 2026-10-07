import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/main.dart';

void main() {
  testWidgets('Menampilkan halaman login Phonebook', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const PhonebookApp());

    expect(find.text('PHONEBOOK'), findsOneWidget);
    expect(find.text('Aplikasi Pelaporan Kehutanan'), findsOneWidget);
    expect(find.text('LOGIN'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });
}