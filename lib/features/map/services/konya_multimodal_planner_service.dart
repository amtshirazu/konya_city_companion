import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/theme/app_colors.dart';
import '../domain/route_request.dart';
import '../domain/travel_mode.dart';
import '../domain/transit_models.dart';
import 'gtfs_query_service.dart';
import 'konya_transit_service.dart';
import 'osrm_routing_service.dart';

class KonyaMultimodalPlannerService {
  KonyaMultimodalPlannerService({
    GtfsQueryService? gtfsQueryService,
    OsrmRoutingService? walkingRoutingService,
    KonyaTransitService? fallbackTransitService,
  }) : _gtfsQuery = gtfsQueryService ?? GtfsQueryService(),
       _walkingService = walkingRoutingService ?? OsrmRoutingService(),
       _fallbackService = fallbackTransitService ?? const KonyaTransitService();

  final GtfsQueryService _gtfsQuery;
  final OsrmRoutingService _walkingService;
  final KonyaTransitService _fallbackService;

  Future<TransitJourneyResult> calculateMultimodalJourney(
    RouteRequest request,
  ) async {
    final origin = request.origin;
    final destination = request.destination;

    try {
      // 1. Find nearby GTFS stops for origin and destination (3000m radius)
      final originStops = await _gtfsQuery.findStopsNear(
        origin,
        radiusMeters: 3000.0,
      );
      final destStops = await _gtfsQuery.findStopsNear(
        destination,
        radiusMeters: 3000.0,
      );

      if (originStops.isEmpty || destStops.isEmpty) {
        return _fallbackService.calculateTransitJourney(request);
      }

      final startStopIds = originStops.map((s) => s.stopId).toList();
      final endStopIds = destStops.map((s) => s.stopId).toList();

      // 2. Query direct GTFS connecting trips
      var targetTime = DateTime.now();
      if (targetTime.hour >= 23 || targetTime.hour < 6) {
        // If late night, query morning schedule starting 08:00 AM
        targetTime = DateTime(
          targetTime.year,
          targetTime.month,
          targetTime.day,
          8,
          0,
          0,
        );
      }

      final directTrips = await _gtfsQuery.findConnectingTrips(
        startStopIds: startStopIds,
        endStopIds: endStopIds,
        targetTime: targetTime,
      );

      if (directTrips.isNotEmpty) {
        // Sort candidate direct trips to heavily penalize walking distance and pick minimal-effort route
        directTrips.sort((a, b) {
          final bStopA = originStops.firstWhere(
            (s) => s.stopId == a.boardingStopId,
            orElse: () => originStops.first,
          );
          final dStopA = destStops.firstWhere(
            (s) => s.stopId == a.disembarkingStopId,
            orElse: () => destStops.first,
          );
          final walkDistA = bStopA.distanceMeters + dStopA.distanceMeters;

          final bStopB = originStops.firstWhere(
            (s) => s.stopId == b.boardingStopId,
            orElse: () => originStops.first,
          );
          final dStopB = destStops.firstWhere(
            (s) => s.stopId == b.disembarkingStopId,
            orElse: () => destStops.first,
          );
          final walkDistB = bStopB.distanceMeters + dStopB.distanceMeters;

          final scoreA = walkDistA + (a.durationMinutes * 25.0);
          final scoreB = walkDistB + (b.durationMinutes * 25.0);
          return scoreA.compareTo(scoreB);
        });

        final trip = directTrips.first;
        return await _buildDirectGtfsJourney(
          request,
          trip,
          originStops,
          destStops,
        );
      }

      // 3. Search for 2-Leg Transfer Route via Central Alaaddin Hub
      final alaaddinStops = await _gtfsQuery.findStopsNear(
        const LatLng(37.8725, 32.4938),
        radiusMeters: 400.0,
      );

      if (alaaddinStops.isNotEmpty) {
        final alaaddinIds = alaaddinStops.map((s) => s.stopId).toList();

        // Leg 1: Origin -> Alaaddin Hub
        final leg1Trips = await _gtfsQuery.findConnectingTrips(
          startStopIds: startStopIds,
          endStopIds: alaaddinIds,
          targetTime: targetTime,
        );

        // Leg 2: Alaaddin Hub -> Destination
        final leg2Trips = await _gtfsQuery.findConnectingTrips(
          startStopIds: alaaddinIds,
          endStopIds: endStopIds,
          targetTime: targetTime.add(const Duration(minutes: 25)),
        );

        if (leg1Trips.isNotEmpty && leg2Trips.isNotEmpty) {
          return await _buildTransferGtfsJourney(
            request,
            leg1Trips.first,
            leg2Trips.first,
            originStops,
            destStops,
          );
        }
      }

      // Fall back to curated transit service if no direct/transfer GTFS schedule found
      return _fallbackService.calculateTransitJourney(request);
    } catch (e) {
      debugPrint(
        'Notice: GTFS query error, falling back to curated transit dataset: $e',
      );
      return _fallbackService.calculateTransitJourney(request);
    }
  }

  Future<TransitJourneyResult> _buildDirectGtfsJourney(
    RouteRequest request,
    GtfsTripOption trip,
    List<GtfsStopInfo> originStops,
    List<GtfsStopInfo> destStops,
  ) async {
    final originStop = originStops.firstWhere(
      (s) => s.stopId == trip.boardingStopId,
      orElse: () => originStops.first,
    );
    final destStop = destStops.firstWhere(
      (s) => s.stopId == trip.disembarkingStopId,
      orElse: () => destStops.first,
    );

    // Leg 1: Walk to Boarding Stop via LocationIQ
    final walk1Route = await _walkingService.calculateRoute(
      RouteRequest(
        origin: request.origin,
        destination: originStop.location,
        destinationName: originStop.stopName,
        mode: TravelMode.walking,
      ),
    );

    // Leg 2: Transit Ride (Bus/Tram) & Shape Polyline
    List<LatLng> shapePoints = [];
    if (trip.shapeId != null) {
      shapePoints = await _gtfsQuery.getTripShapePolyline(trip.shapeId!);
    }
    if (shapePoints.isEmpty) {
      shapePoints = [originStop.location, destStop.location];
    }

    final intermediateStops = await _gtfsQuery.getIntermediateStopNames(
      trip.tripId,
      trip.startSequence,
      trip.endSequence,
    );

    final String typeLabel = trip.isTram
        ? 'Tram ${trip.routeShortName}'
        : 'Bus ${trip.routeShortName}';
    final Color legColor =
        trip.routeColor ??
        (trip.isTram ? const Color(0xFFD32F2F) : AppColors.primary);

    final transitLeg = TransitLeg(
      type: trip.isTram ? TransitLegType.tramRide : TransitLegType.busRide,
      title: '$typeLabel (${trip.routeLongName})',
      description:
          'Board at ${trip.boardingStopName} (${trip.boardingTime.substring(0, 5)}) → Ride ${trip.stopCount} stops to ${trip.disembarkingStopName}',
      startName: trip.boardingStopName,
      endName: trip.disembarkingStopName,
      distanceKm: double.parse((trip.stopCount * 0.4).toStringAsFixed(1)),
      durationMinutes: trip.durationMinutes,
      points: shapePoints,
      legColor: legColor,
      intermediateStops: intermediateStops,
    );

    // Leg 3: Walk to Destination via LocationIQ
    final walk2Route = await _walkingService.calculateRoute(
      RouteRequest(
        origin: destStop.location,
        destination: request.destination,
        destinationName: request.destinationName,
        mode: TravelMode.walking,
      ),
    );

    final legs = [
      TransitLeg(
        type: TransitLegType.walk,
        title: 'Walk to ${originStop.stopName}',
        description:
            'Walk ${walk1Route.distanceText} (${walk1Route.durationText})',
        startName: 'Origin Location',
        endName: originStop.stopName,
        distanceKm: walk1Route.distanceKm,
        durationMinutes: walk1Route.durationMinutes,
        points: walk1Route.points,
        legColor: const Color(0xFF1976D2),
      ),
      transitLeg,
      TransitLeg(
        type: TransitLegType.walk,
        title: 'Walk to ${request.destinationName}',
        description:
            'Walk ${walk2Route.distanceText} (${walk2Route.durationText})',
        startName: destStop.stopName,
        endName: request.destinationName,
        distanceKm: walk2Route.distanceKm,
        durationMinutes: walk2Route.durationMinutes,
        points: walk2Route.points,
        legColor: const Color(0xFF1976D2),
      ),
    ];

    final totalKm =
        walk1Route.distanceKm + transitLeg.distanceKm + walk2Route.distanceKm;
    final totalMins =
        walk1Route.durationMinutes +
        trip.durationMinutes +
        walk2Route.durationMinutes;

    return TransitJourneyResult(
      destinationName: request.destinationName,
      totalDistanceKm: double.parse(totalKm.toStringAsFixed(1)),
      totalDurationMinutes: totalMins,
      legs: legs,
      noticeMessage:
          'Live GTFS Schedule: ${trip.routeShortName} (${trip.boardingTime.substring(0, 5)} Departure)',
    );
  }

  Future<TransitJourneyResult> _buildTransferGtfsJourney(
    RouteRequest request,
    GtfsTripOption trip1,
    GtfsTripOption trip2,
    List<GtfsStopInfo> originStops,
    List<GtfsStopInfo> destStops,
  ) async {
    final originStop = originStops.firstWhere(
      (s) => s.stopId == trip1.boardingStopId,
      orElse: () => originStops.first,
    );
    final destStop = destStops.firstWhere(
      (s) => s.stopId == trip2.disembarkingStopId,
      orElse: () => destStops.first,
    );

    final walk1Route = await _walkingService.calculateRoute(
      RouteRequest(
        origin: request.origin,
        destination: originStop.location,
        destinationName: originStop.stopName,
        mode: TravelMode.walking,
      ),
    );

    List<LatLng> shapePoints1 = [];
    if (trip1.shapeId != null) {
      shapePoints1 = await _gtfsQuery.getTripShapePolyline(trip1.shapeId!);
    }
    if (shapePoints1.isEmpty) {
      shapePoints1 = [originStop.location, const LatLng(37.8725, 32.4938)];
    }

    List<LatLng> shapePoints2 = [];
    if (trip2.shapeId != null) {
      shapePoints2 = await _gtfsQuery.getTripShapePolyline(trip2.shapeId!);
    }
    if (shapePoints2.isEmpty) {
      shapePoints2 = [const LatLng(37.8725, 32.4938), destStop.location];
    }

    final walk2Route = await _walkingService.calculateRoute(
      RouteRequest(
        origin: destStop.location,
        destination: request.destination,
        destinationName: request.destinationName,
        mode: TravelMode.walking,
      ),
    );

    final legs = [
      TransitLeg(
        type: TransitLegType.walk,
        title: 'Walk to ${originStop.stopName}',
        description:
            'Walk ${walk1Route.distanceText} (${walk1Route.durationText})',
        startName: 'Origin Location',
        endName: originStop.stopName,
        distanceKm: walk1Route.distanceKm,
        durationMinutes: walk1Route.durationMinutes,
        points: walk1Route.points,
        legColor: const Color(0xFF1976D2),
      ),
      TransitLeg(
        type: trip1.isTram ? TransitLegType.tramRide : TransitLegType.busRide,
        title: '${trip1.isTram ? "Tram" : "Bus"} ${trip1.routeShortName}',
        description:
            'Board at ${trip1.boardingStopName} → Disembark at ${trip1.disembarkingStopName}',
        startName: trip1.boardingStopName,
        endName: trip1.disembarkingStopName,
        distanceKm: double.parse((trip1.stopCount * 0.4).toStringAsFixed(1)),
        durationMinutes: trip1.durationMinutes,
        points: shapePoints1,
        legColor:
            trip1.routeColor ??
            (trip1.isTram ? const Color(0xFFD32F2F) : AppColors.primary),
      ),
      const TransitLeg(
        type: TransitLegType.walk,
        title: 'Transfer at Alaaddin Central Hub',
        description: 'Walk 50m to transfer turnstile',
        startName: 'Alaaddin Tram Stop',
        endName: 'Alaaddin Bus Turnike',
        distanceKm: 0.1,
        durationMinutes: 3,
        points: [LatLng(37.87187, 32.49385), LatLng(37.87328, 32.49415)],
        legColor: Color(0xFF1976D2),
      ),
      TransitLeg(
        type: trip2.isTram ? TransitLegType.tramRide : TransitLegType.busRide,
        title: '${trip2.isTram ? "Tram" : "Bus"} ${trip2.routeShortName}',
        description:
            'Board at ${trip2.boardingStopName} → Disembark at ${trip2.disembarkingStopName}',
        startName: trip2.boardingStopName,
        endName: trip2.disembarkingStopName,
        distanceKm: double.parse((trip2.stopCount * 0.4).toStringAsFixed(1)),
        durationMinutes: trip2.durationMinutes,
        points: shapePoints2,
        legColor:
            trip2.routeColor ??
            (trip2.isTram ? const Color(0xFFD32F2F) : AppColors.primary),
      ),
      TransitLeg(
        type: TransitLegType.walk,
        title: 'Walk to ${request.destinationName}',
        description:
            'Walk ${walk2Route.distanceText} (${walk2Route.durationText})',
        startName: destStop.stopName,
        endName: request.destinationName,
        distanceKm: walk2Route.distanceKm,
        durationMinutes: walk2Route.durationMinutes,
        points: walk2Route.points,
        legColor: const Color(0xFF1976D2),
      ),
    ];

    final totalKm =
        walk1Route.distanceKm +
        (trip1.stopCount * 0.4) +
        0.1 +
        (trip2.stopCount * 0.4) +
        walk2Route.distanceKm;
    final totalMins =
        walk1Route.durationMinutes +
        trip1.durationMinutes +
        3 +
        trip2.durationMinutes +
        walk2Route.durationMinutes;

    return TransitJourneyResult(
      destinationName: request.destinationName,
      totalDistanceKm: double.parse(totalKm.toStringAsFixed(1)),
      totalDurationMinutes: totalMins,
      legs: legs,
      noticeMessage:
          'GTFS Transfer Journey: ${trip1.routeShortName} → Alaaddin → ${trip2.routeShortName}',
    );
  }
}
