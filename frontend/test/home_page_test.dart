import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/pages/home.dart';
import 'package:frontend/widgets/bottom_nav.dart';

void main() {
  testWidgets('home shows dashboard without initializing inactive tabs',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.pumpAndSettle();

    expect(find.text('Selamat Datang 👋'), findsOneWidget);
    expect(find.byType(BottomNav), findsOneWidget);
    expect(tester.getSize(find.byType(BottomNav)).height, lessThan(100));
    expect(tester.takeException(), isNull);
  });
}
