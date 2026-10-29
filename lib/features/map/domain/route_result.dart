import 'package:latlong2/latlong.dart';

import 'route_step.dart';
import 'travel_mode.dart';

enum RouteStatus {
  success,
  notFound,
  networkError,
  serviceUnavailable,
  fallbackUsed,
}

class RouteResult {
  final RouteStatus status;
  final String destinationName;
  final double distanceKm;
  final int durationMinutes;
  final List<LatLng> points;
  final List<RouteStep> steps;
  final TravelMode mode;
  final String? errorMessage;
  final bool isFallback;

  const RouteResult({
    required this.status,
    required this.destinationName,
    required this.distanceKm,
    required this.durationMinutes,
    required this.points,
    required this.steps,
    required this.mode,
    this.errorMessage,
    this.isFallback = false,
  });

  bool get isSuccess =>
      status == RouteStatus.success || status == RouteStatus.fallbackUsed;

  String get distanceText => '${distanceKm.toStringAsFixed(1)} km';
  String get durationText => '~ $durationMinutes mins';
}
