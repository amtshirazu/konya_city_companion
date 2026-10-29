import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:konya_city_companion/app/app.dart';
import 'package:konya_city_companion/features/map/services/in_app_routing_service.dart';
import 'package:konya_city_companion/features/map/utils/directions_helper.dart';
import 'package:konya_city_companion/features/places/domain/place.dart';

void main() {
  group('InAppRoutingService Tests', () {
    test('getRouteToPlace calculates route polyline and steps', () {
      const place = Place(
        id: 'mevlana-museum',
        name: 'Mevlana Museum',
        category: 'history-culture',
        description: 'Test description',
        icon: Icons.account_balance,
        accentColor: Colors.green,
        latitude: 37.8707,
        longitude: 32.5050,
      );

      final route = InAppRoutingService.getRouteToPlace(place);

      expect(route.destinationName, equals('Mevlana Museum'));
      expect(route.distanceKm, greaterThan(0));
      expect(route.durationMinutes, greaterThan(0));
      expect(route.points.length, greaterThanOrEqualTo(2));
      expect(route.steps, isNotEmpty);
    });

    test(
      'DirectionsHelper creates coordinate query when lat/lng available',
      () {
        const place = Place(
          id: 'mevlana-museum',
          name: 'Mevlana Museum',
          category: 'history-culture',
          description: 'Test description',
          icon: Icons.account_balance,
          accentColor: Colors.green,
          latitude: 37.8707,
          longitude: 32.5050,
        );

        final uri = DirectionsHelper.getDirectionsUri(place);
        expect(
          uri.toString(),
          contains(
            'https://www.google.com/maps/search/?api=1&query=37.8707,32.505',
          ),
        );
      },
    );
  });

  group('Map Screen Widget Tests', () {
    testWidgets(
      'Map tab renders search field, OpenStreetMap view, and attribution',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const ProviderScope(child: KonyaCityCompanionApp()),
        );

        // Tap on Map bottom navigation tab
        await tester.tap(find.text('Map'));
        await tester.pumpAndSettle();

        expect(find.text('Explore Places on Map'), findsOneWidget);
        expect(find.byType(FlutterMap), findsOneWidget);
        expect(find.byType(RichAttributionWidget), findsOneWidget);
        expect(find.text('Directions'), findsWidgets);
      },
    );

    testWidgets(
      'Tapping Directions opens in-app route details sheet with travel mode toggle',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const ProviderScope(child: KonyaCityCompanionApp()),
        );

        // Tap on Map bottom navigation tab
        await tester.tap(find.text('Map'));
        await tester.pumpAndSettle();

        // Tap Directions button
        await tester.tap(find.text('Directions').first);
        await tester.pumpAndSettle();

        expect(find.text('Step-by-Step Directions'), findsOneWidget);
        expect(find.text('Walk'), findsWidgets);
        expect(find.text('Drive'), findsWidgets);
        expect(find.text('Tram'), findsWidgets);
        expect(find.text('View Polyline on Map'), findsOneWidget);
      },
    );
  });
}
