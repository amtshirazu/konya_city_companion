// This is a basic Flutter widget test for Konya City Companion.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:konya_city_companion/app/app.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    // Build our app wrapped in ProviderScope and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(child: KonyaCityCompanionApp()),
    );

    // Verify that the app title and subtitle are displayed on home screen.
    expect(find.text('KONYA CITY COMPANION'), findsOneWidget);
    expect(find.text('Your city, made easier.'), findsOneWidget);
  });
}
