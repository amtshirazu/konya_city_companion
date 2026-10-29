import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:konya_city_companion/app/app.dart';

void main() {
  testWidgets('Navigating to a valid place ID displays place details', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: KonyaCityCompanionApp()),
    );

    // Drag down to scroll the Home screen
    await tester.drag(find.byType(ListView).first, const Offset(0, -400));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final finder = find.text('Mevlana Museum');
    expect(finder, findsWidgets);
    await tester.tap(finder.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify Place Details Screen
    expect(find.text('Essential Information'), findsOneWidget);
    expect(
      find.text('Aziziye, Mevlana Cd. No:1, 42030 Karatay/Konya'),
      findsWidgets,
    );
    expect(find.text('09:00 - 17:00 (Daily)'), findsOneWidget);
    expect(find.text('Show Place on Map'), findsOneWidget);
    expect(find.text('Location'), findsWidgets);
    expect(find.text('Open Map'), findsOneWidget);
  });

  testWidgets('Unknown place ID displays Place not found screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: KonyaCityCompanionApp()),
    );

    final BuildContext context = tester.element(find.byType(Scaffold).first);
    context.push('/place/unknown-id-123');
    await tester.pumpAndSettle();

    expect(find.text('Place not found'), findsWidgets);
    expect(find.text('Back to Explore'), findsOneWidget);
  });
}
