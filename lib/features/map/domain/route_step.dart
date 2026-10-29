import 'package:latlong2/latlong.dart';

class RouteStep {
  final String instruction;
  final double distanceMeters;
  final double durationSeconds;
  final String distanceText;
  final String durationText;
  final String? maneuverType;
  final String? modifier;
  final LatLng location;

  const RouteStep({
    required this.instruction,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.distanceText,
    required this.durationText,
    required this.location,
    this.maneuverType,
    this.modifier,
  });

  static String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }

  static String formatDuration(double seconds) {
    final minutes = (seconds / 60).round();
    if (minutes < 1) {
      return '< 1 min';
    } else if (minutes < 60) {
      return '$minutes mins';
    } else {
      final hours = minutes ~/ 60;
      final remainingMins = minutes % 60;
      return remainingMins > 0 ? '$hours hr $remainingMins mins' : '$hours hr';
    }
  }
}
