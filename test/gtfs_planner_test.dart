import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:konya_city_companion/features/map/data/gtfs_database.dart';
import 'package:konya_city_companion/features/map/domain/route_request.dart';
import 'package:konya_city_companion/features/map/domain/travel_mode.dart';
import 'package:konya_city_companion/features/map/services/gtfs_query_service.dart';
import 'package:konya_city_companion/features/map/services/konya_multimodal_planner_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('GtfsQueryService Tests', () {
    late GtfsDatabase dbService;
    late GtfsQueryService queryService;

    setUp(() {
      dbService = GtfsDatabase(databaseFactory: databaseFactoryFfi);
      queryService = GtfsQueryService(databaseService: dbService);
    });

    tearDown(() async {
      await dbService.close();
    });

    test('findStopsNear locates nearby stops around Alaaddin Square', () async {
      const alaaddinCenter = LatLng(37.8725, 32.4938);
      final stops = await queryService.findStopsNear(
        alaaddinCenter,
        radiusMeters: 800.0,
      );

      expect(stops, isNotEmpty);
      expect(
        stops.any((s) => s.stopName.toLowerCase().contains('alaaddin')),
        isTrue,
      );
    });

    test(
      'findConnectingTrips locates GTFS scheduled trips for Bus 64 Sille',
      () async {
        // Alaaddin Turnike (2415a) to Sille Son Durak (1700a)
        final trips = await queryService.findConnectingTrips(
          startStopIds: ['2415a', '2414a'],
          endStopIds: ['1700a', '1700d', '1698a'],
          targetTime: DateTime(2026, 10, 24, 12, 0, 0), // 12:00 PM
        );

        expect(trips, isNotEmpty);
        final trip = trips.first;
        expect(trip.routeShortName, contains('64'));
        expect(trip.stopCount, greaterThan(10));
      },
    );

    test('getTripShapePolyline retrieves GPS track points', () async {
      // Query shape for Bus 64-A
      const alaaddinCenter = LatLng(37.8725, 32.4938);
      final stops = await queryService.findStopsNear(
        alaaddinCenter,
        radiusMeters: 800.0,
      );
      expect(stops, isNotEmpty);

      final trips = await queryService.findConnectingTrips(
        startStopIds: [stops.first.stopId],
        endStopIds: ['1700a'],
        targetTime: DateTime(2026, 10, 24, 12, 0, 0),
      );

      if (trips.isNotEmpty && trips.first.shapeId != null) {
        final shapePoints = await queryService.getTripShapePolyline(
          trips.first.shapeId!,
        );
        expect(shapePoints, isNotEmpty);
        expect(shapePoints.length, greaterThan(10));
      }
    });
  });

  group('KonyaMultimodalPlannerService Integration Tests', () {
    test('calculateMultimodalJourney builds transit journey from Central Konya to Sille', () async {
      final dbService = GtfsDatabase(databaseFactory: databaseFactoryFfi);
      final queryService = GtfsQueryService(databaseService: dbService);
      final planner = KonyaMultimodalPlannerService(
        gtfsQueryService: queryService,
      );

      const request = RouteRequest(
        origin: LatLng(37.8719, 32.4925), // Alaaddin Hill
        destination: LatLng(37.9264, 32.4143), // Sille Village
        destinationName: 'Sille Village',
        mode: TravelMode.transit,
      );

      final result = await planner.calculateMultimodalJourney(request);

      expect(result.legs, isNotEmpty);
      expect(result.totalDistanceKm, greaterThan(5.0));
      expect(result.totalDurationMinutes, greaterThan(10));

      await dbService.close();
    });
  });
}
