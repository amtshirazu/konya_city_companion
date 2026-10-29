import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

import 'package:konya_city_companion/features/map/domain/route_request.dart';
import 'package:konya_city_companion/features/map/domain/route_result.dart';
import 'package:konya_city_companion/features/map/domain/route_step.dart';
import 'package:konya_city_companion/features/map/domain/travel_mode.dart';
import 'package:konya_city_companion/features/map/presentation/providers/routing_provider.dart';
import 'package:konya_city_companion/features/map/services/osrm_routing_service.dart';

void main() {
  group('RouteStep Formatters Tests', () {
    test('formatDistance formats meters and kilometers', () {
      expect(RouteStep.formatDistance(350), equals('350 m'));
      expect(RouteStep.formatDistance(1200), equals('1.2 km'));
      expect(RouteStep.formatDistance(4500), equals('4.5 km'));
    });

    test('formatDuration formats seconds to minutes and hours', () {
      expect(RouteStep.formatDuration(20), equals('< 1 min'));
      expect(RouteStep.formatDuration(300), equals('5 mins'));
      expect(RouteStep.formatDuration(3600), equals('1 hr'));
      expect(RouteStep.formatDuration(5400), equals('1 hr 30 mins'));
    });
  });

  group('OsrmRoutingService Unit Tests', () {
    const origin = LatLng(37.8719, 32.4925); // Alaeddin Hill
    const destination = LatLng(37.8707, 32.5050); // Mevlana Museum

    test('Parses valid OSRM response correctly', () async {
      final mockJsonResponse = jsonEncode({
        'code': 'Ok',
        'routes': [
          {
            'distance': 1400.0,
            'duration': 900.0,
            'geometry': {
              'type': 'LineString',
              'coordinates': [
                [32.4925, 37.8719],
                [32.4980, 37.8712],
                [32.5050, 37.8707],
              ],
            },
            'legs': [
              {
                'steps': [
                  {
                    'distance': 600.0,
                    'duration': 400.0,
                    'name': 'Mevlana Caddesi',
                    'maneuver': {
                      'type': 'depart',
                      'modifier': 'straight',
                      'location': [32.4925, 37.8719],
                    },
                  },
                  {
                    'distance': 800.0,
                    'duration': 500.0,
                    'name': 'Mevlana Meydanı',
                    'maneuver': {
                      'type': 'arrive',
                      'modifier': 'straight',
                      'location': [32.5050, 37.8707],
                    },
                  },
                ],
              },
            ],
          },
        ],
      });

      final mockClient = MockClient((request) async {
        expect(request.url.toString(), contains('walking'));
        return http.Response(
          mockJsonResponse,
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = OsrmRoutingService(httpClient: mockClient);
      final request = const RouteRequest(
        origin: origin,
        destination: destination,
        destinationName: 'Mevlana Museum',
        mode: TravelMode.walking,
      );

      final result = await service.calculateRoute(request);

      expect(result.status, equals(RouteStatus.success));
      expect(result.isSuccess, isTrue);
      expect(result.destinationName, equals('Mevlana Museum'));
      expect(result.distanceKm, equals(1.4));
      expect(result.durationMinutes, equals(15));
      expect(result.points.length, equals(3));
      expect(result.steps.length, equals(2));
      expect(result.steps.first.instruction, contains('Mevlana Caddesi'));
      expect(result.isFallback, isFalse);
    });

    test(
      'Generates fallback route when OSRM request times out or fails',
      () async {
        final mockClient = MockClient((request) async {
          throw Exception('Network timeout simulated');
        });

        final service = OsrmRoutingService(httpClient: mockClient);
        final request = const RouteRequest(
          origin: origin,
          destination: destination,
          destinationName: 'Mevlana Museum',
          mode: TravelMode.driving,
        );

        final result = await service.calculateRoute(request);

        expect(result.isSuccess, isTrue);
        expect(result.status, equals(RouteStatus.fallbackUsed));
        expect(result.isFallback, isTrue);
        expect(result.points.length, greaterThanOrEqualTo(2));
        expect(result.steps.length, greaterThan(0));
      },
    );
  });

  group('ActiveRouteNotifier Tests', () {
    test('ActiveRouteNotifier fetches and clears route state', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(activeRouteProvider.notifier);
      expect(container.read(activeRouteProvider).result, isNull);

      const request = RouteRequest(
        origin: LatLng(37.8719, 32.4925),
        destination: LatLng(37.8707, 32.5050),
        destinationName: 'Mevlana Museum',
      );

      final result = await notifier.fetchRoute(request);

      expect(result, isNotNull);
      expect(container.read(activeRouteProvider).result, equals(result));

      notifier.clearRoute();
      expect(container.read(activeRouteProvider).result, isNull);
    });
  });
}
