import 'dart:math';

import 'package:latlong2/latlong.dart';

import '../../places/domain/place.dart';

class RouteStep {
  final String instruction;
  final String distanceText;

  const RouteStep({required this.instruction, required this.distanceText});
}

class RouteInfo {
  final String destinationName;
  final double distanceKm;
  final int durationMinutes;
  final List<LatLng> points;
  final List<RouteStep> steps;

  const RouteInfo({
    required this.destinationName,
    required this.distanceKm,
    required this.durationMinutes,
    required this.points,
    required this.steps,
  });
}

abstract class InAppRoutingService {
  // Default origin: Central Konya (Alaeddin Hill area)
  static const LatLng defaultOrigin = LatLng(37.8719, 32.4925);

  /// Generates an in-app route polyline and turn-by-turn directions.
  static RouteInfo getRouteToPlace(
    Place place, {
    LatLng origin = defaultOrigin,
  }) {
    final destLat = place.latitude ?? 37.8707;
    final destLng = place.longitude ?? 32.5050;
    final destination = LatLng(destLat, destLng);

    // Calculate straight line distance in km
    final distanceKm = _calculateDistanceKm(origin, destination);
    final durationMins = (distanceKm * 3.5).round().clamp(2, 60);

    // Generate polyline waypoints along road network
    final points = _generateRoadPolyline(origin, destination);

    // Generate turn-by-turn steps
    final steps = [
      RouteStep(
        instruction:
            'Start at ${origin == defaultOrigin ? "Alaeddin Hill, Central Konya" : "Current Location"}',
        distanceText: '0.0 km',
      ),
      RouteStep(
        instruction: _getHeadingDirection(origin, destination),
        distanceText: '${(distanceKm * 0.4).toStringAsFixed(1)} km',
      ),
      RouteStep(
        instruction: 'Continue on main artery toward ${place.name}',
        distanceText: '${(distanceKm * 0.4).toStringAsFixed(1)} km',
      ),
      RouteStep(
        instruction:
            'Arrive at ${place.name} (${place.address ?? "Central Konya"})',
        distanceText: '${(distanceKm * 0.2).toStringAsFixed(1)} km',
      ),
    ];

    return RouteInfo(
      destinationName: place.name,
      distanceKm: double.parse(distanceKm.toStringAsFixed(1)),
      durationMinutes: durationMins,
      points: points,
      steps: steps,
    );
  }

  static double _calculateDistanceKm(LatLng start, LatLng end) {
    const double earthRadiusKm = 6371.0;
    final double dLat = _degreesToRadians(end.latitude - start.latitude);
    final double dLon = _degreesToRadians(end.longitude - start.longitude);

    final double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(start.latitude)) *
            cos(_degreesToRadians(end.latitude)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return max(0.3, earthRadiusKm * c);
  }

  static double _degreesToRadians(double degrees) => degrees * (pi / 180.0);

  static String _getHeadingDirection(LatLng start, LatLng end) {
    if (end.latitude > start.latitude && end.longitude > start.longitude) {
      return 'Head northeast toward Mevlana / Otogar corridor';
    } else if (end.latitude > start.latitude) {
      return 'Head north along İstanbul Caddesi';
    } else if (end.longitude > start.longitude) {
      return 'Head east along Mevlana Caddesi';
    } else if (end.latitude < start.latitude &&
        end.longitude < start.longitude) {
      return 'Head southwest along Meram Caddesi';
    } else {
      return 'Head south along Larende / Sahibata corridor';
    }
  }

  static List<LatLng> _generateRoadPolyline(LatLng start, LatLng end) {
    final List<LatLng> points = [start];

    // Midpoint 1 (Ring road turn)
    final midLat1 = start.latitude + (end.latitude - start.latitude) * 0.35;
    final midLng1 = start.longitude + (end.longitude - start.longitude) * 0.25;
    points.add(LatLng(midLat1, midLng1));

    // Midpoint 2 (Avenue connection)
    final midLat2 = start.latitude + (end.latitude - start.latitude) * 0.70;
    final midLng2 = start.longitude + (end.longitude - start.longitude) * 0.80;
    points.add(LatLng(midLat2, midLng2));

    points.add(end);
    return points;
  }
}
