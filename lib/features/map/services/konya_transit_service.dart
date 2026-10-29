import 'dart:math';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../data/konya_tram_data.dart';
import '../domain/route_request.dart';
import '../domain/transit_models.dart';

class KonyaTransitService {
  const KonyaTransitService();

  TransitJourneyResult calculateTransitJourney(RouteRequest request) {
    final origin = request.origin;
    final destination = request.destination;

    final rawEndStop = _findNearestStop(destination);
    final rawStartStop = _findNearestStop(
      origin,
      targetLineCode: rawEndStop.lineCode,
    );

    final startStop = rawStartStop;
    final endStop = rawEndStop;

    final walkToStopMeters = _distanceMeters(origin, startStop.location);
    final walkFromStopMeters = _distanceMeters(endStop.location, destination);

    // If destination or origin is > 3 km away from nearest tram stop, tram is not practical
    if (walkToStopMeters > 3000 || walkFromStopMeters > 3000) {
      return _buildWalkOnlyResult(
        request,
        reason: 'Destination is beyond the active tram corridor. Direct walking or driving is recommended.',
      );
    }

    // Determine tram line and intermediate stops
    final TramLine line = _getTramLineForStops(startStop, endStop);
    final List<TramStop> lineStops = line.stops;

    final startIndex = lineStops.indexWhere((s) => s.id == startStop.id);
    final endIndex = lineStops.indexWhere((s) => s.id == endStop.id);

    // If same stop or negative range, handle appropriately
    if (startIndex == -1 || endIndex == -1 || startIndex == endIndex) {
      return _buildWalkOnlyResult(
        request,
        reason: 'Origin and destination share the same nearest tram stop.',
      );
    }

    final isForward = startIndex < endIndex;
    final int stopCount = (endIndex - startIndex).abs();
    final List<TramStop> rideStops = isForward
        ? lineStops.sublist(startIndex, endIndex + 1)
        : lineStops.sublist(endIndex, startIndex + 1).reversed.toList();

    final double walkToStopKm = walkToStopMeters / 1000.0;
    final int walkToStopMins = max(1, (walkToStopKm / 4.5 * 60).round());

    final double walkFromStopKm = walkFromStopMeters / 1000.0;
    final int walkFromStopMins = max(1, (walkFromStopKm / 4.5 * 60).round());

    final double tramRideKm = _calculatePathDistanceKm(
      rideStops.map((s) => s.location).toList(),
    );
    final int tramRideMins = max(3, stopCount * 2); // ~2 mins per stop

    final List<String> intermediateStopNames = rideStops
        .skip(1)
        .take(max(0, rideStops.length - 2))
        .map((s) => s.name)
        .toList();

    final List<TransitLeg> legs = [
      // Leg 1: Walk to origin stop
      TransitLeg(
        type: TransitLegType.walk,
        title: 'Walk to ${startStop.name} Tram Stop',
        description:
            'Walk ${walkToStopKm.toStringAsFixed(1)} km to ${startStop.name}',
        startName: 'Your Location',
        endName: startStop.name,
        distanceKm: double.parse(walkToStopKm.toStringAsFixed(1)),
        durationMinutes: walkToStopMins,
        legColor: const Color(0xFF13795B),
        points: [origin, startStop.location],
      ),

      // Leg 2: Ride Tram T1 / T2
      TransitLeg(
        type: TransitLegType.tramRide,
        title: 'Board Tram ${line.code} (${line.name})',
        description:
            'Ride $stopCount stops from ${startStop.name} to ${endStop.name}',
        startName: startStop.name,
        endName: endStop.name,
        distanceKm: double.parse(tramRideKm.toStringAsFixed(1)),
        durationMinutes: tramRideMins,
        tramLineCode: line.code,
        legColor: line.color,
        points: rideStops.map((s) => s.location).toList(),
        intermediateStops: intermediateStopNames,
      ),

      // Leg 3: Walk from destination stop
      TransitLeg(
        type: TransitLegType.walk,
        title: 'Walk to ${request.destinationName}',
        description:
            'Walk ${walkFromStopKm.toStringAsFixed(1)} km to your destination',
        startName: endStop.name,
        endName: request.destinationName,
        distanceKm: double.parse(walkFromStopKm.toStringAsFixed(1)),
        durationMinutes: walkFromStopMins,
        legColor: const Color(0xFF13795B),
        points: [endStop.location, destination],
      ),
    ];

    final double totalDistanceKm = walkToStopKm + tramRideKm + walkFromStopKm;
    final int totalDurationMins =
        walkToStopMins + tramRideMins + walkFromStopMins;

    return TransitJourneyResult(
      destinationName: request.destinationName,
      totalDistanceKm: double.parse(totalDistanceKm.toStringAsFixed(1)),
      totalDurationMinutes: totalDurationMins,
      legs: legs,
      noticeMessage:
          'Scheduled Tram Timetable • Open ATUS for Live Vehicle Status',
      isTramAvailable: true,
    );
  }

  TramStop _findNearestStop(LatLng point, {String? targetLineCode}) {
    final allStops = targetLineCode != null
        ? KonyaTramData.allStops
              .where((s) => s.lineCode == targetLineCode)
              .toList()
        : KonyaTramData.allStops;

    TramStop nearest = allStops.first;
    double minDistance = double.infinity;

    for (final stop in allStops) {
      final distance = _distanceMeters(point, stop.location);
      if (distance < minDistance) {
        minDistance = distance;
        nearest = stop;
      }
    }

    return nearest;
  }

  TramLine _getTramLineForStops(TramStop start, TramStop end) {
    if (start.lineCode == 'T2' || end.lineCode == 'T2') {
      return KonyaTramData.lineT2;
    }
    return KonyaTramData.lineT1;
  }

  TransitJourneyResult _buildWalkOnlyResult(
    RouteRequest request, {
    required String reason,
  }) {
    final distanceKm = _calculateStraightDistance(
      request.origin,
      request.destination,
    );
    final durationMins = max(2, (distanceKm / 4.5 * 60).round());

    final leg = TransitLeg(
      type: TransitLegType.walk,
      title: 'Walk directly to ${request.destinationName}',
      description: reason,
      startName: 'Origin',
      endName: request.destinationName,
      distanceKm: double.parse(distanceKm.toStringAsFixed(1)),
      durationMinutes: durationMins,
      legColor: const Color(0xFF13795B),
      points: [request.origin, request.destination],
    );

    return TransitJourneyResult(
      destinationName: request.destinationName,
      totalDistanceKm: double.parse(distanceKm.toStringAsFixed(1)),
      totalDurationMinutes: durationMins,
      legs: [leg],
      noticeMessage: reason,
      isTramAvailable: false,
    );
  }

  double _distanceMeters(LatLng a, LatLng b) {
    const double r = 6371000.0;
    final double dLat = (b.latitude - a.latitude) * (pi / 180.0);
    final double dLon = (b.longitude - a.longitude) * (pi / 180.0);

    final double sa =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(a.latitude * (pi / 180.0)) *
            cos(b.latitude * (pi / 180.0)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final double c = 2 * atan2(sqrt(sa), sqrt(1 - sa));
    return r * c;
  }

  double _calculatePathDistanceKm(List<LatLng> points) {
    if (points.length < 2) return 0.2;
    double sum = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      sum += _distanceMeters(points[i], points[i + 1]);
    }
    return max(0.2, sum / 1000.0);
  }

  double _calculateStraightDistance(LatLng start, LatLng end) {
    return max(0.1, _distanceMeters(start, end) / 1000.0);
  }
}
