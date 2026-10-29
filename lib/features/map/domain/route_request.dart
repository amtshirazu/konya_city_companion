import 'package:latlong2/latlong.dart';

import 'travel_mode.dart';

class RouteRequest {
  final LatLng origin;
  final LatLng destination;
  final String destinationName;
  final TravelMode mode;

  const RouteRequest({
    required this.origin,
    required this.destination,
    required this.destinationName,
    this.mode = TravelMode.walking,
  });
}
