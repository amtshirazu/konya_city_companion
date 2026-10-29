import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:konya_city_companion/features/map/domain/route_request.dart';
import 'package:konya_city_companion/features/map/domain/travel_mode.dart';
import 'package:konya_city_companion/features/map/services/konya_transit_service.dart';

void main() {
  late KonyaTransitService service;

  setUp(() {
    service = const KonyaTransitService();
  });

  group('KonyaTransitService Tests', () {
    test(
      'Calculates multimodal tram journey along T1 Line (Alaeddin to Otogar)',
      () {
        const request = RouteRequest(
          origin: LatLng(37.8719, 32.4925), // Alaeddin
          destination: LatLng(37.9519, 32.5111), // Otogar
          destinationName: 'Konya Bus Terminal (Otogar)',
          mode: TravelMode.transit,
        );

        final result = service.calculateTransitJourney(request);

        expect(result.isTramAvailable, isTrue);
        expect(result.destinationName, equals('Konya Bus Terminal (Otogar)'));
        expect(result.totalDistanceKm, greaterThan(5.0));
        expect(result.totalDurationMinutes, greaterThan(10));
        expect(result.legs.length, equals(3));

        // Leg 1: Walk to Alaeddin stop
        expect(result.legs[0].isWalk, isTrue);
        expect(result.legs[0].startName, equals('Your Location'));

        // Leg 2: Ride Tram T1
        expect(result.legs[1].isTram, isTrue);
        expect(result.legs[1].tramLineCode, equals('T1'));

        // Leg 3: Walk to Otogar
        expect(result.legs[2].isWalk, isTrue);
        expect(result.legs[2].endName, equals('Konya Bus Terminal (Otogar)'));
      },
    );

    test(
      'Calculates multimodal tram journey along T2 Line (Alaeddin to Mevlana)',
      () {
        const request = RouteRequest(
          origin: LatLng(37.8722, 32.4931), // Alaeddin
          destination: LatLng(37.8703, 32.5042), // Mevlana
          destinationName: 'Mevlana Museum',
          mode: TravelMode.transit,
        );

        final result = service.calculateTransitJourney(request);

        expect(result.isTramAvailable, isTrue);
        expect(result.legs.any((leg) => leg.isTram), isTrue);
        final tramLeg = result.legs.firstWhere((leg) => leg.isTram);
        expect(tramLeg.tramLineCode, equals('T2'));
      },
    );

    test('Handles distant locations with walk-only fallback notice', () {
      const request = RouteRequest(
        origin: LatLng(37.8719, 32.4925),
        destination: LatLng(37.9256, 32.3922), // Sille Village (far from tram)
        destinationName: 'Sille Historic Village',
        mode: TravelMode.transit,
      );

      final result = service.calculateTransitJourney(request);

      expect(result.isTramAvailable, isFalse);
      expect(result.legs.length, equals(1));
      expect(result.legs.first.isWalk, isTrue);
      expect(result.noticeMessage, contains('beyond the active tram corridor'));
    });
  });
}
