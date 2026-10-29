enum TravelMode {
  walking,
  driving,
  cycling,
  transit;

  String get label {
    switch (this) {
      case TravelMode.walking:
        return 'Walking';
      case TravelMode.driving:
        return 'Driving';
      case TravelMode.cycling:
        return 'Bicycle';
      case TravelMode.transit:
        return 'Public Transport';
    }
  }

  /// LocationIQ Directions API profile identifier
  String get osrmProfile {
    switch (this) {
      case TravelMode.walking:
        return 'walking';
      case TravelMode.driving:
        return 'driving';
      case TravelMode.cycling:
        return 'walking'; // LocationIQ v1 Directions API uses 'walking' for non-motorized pedestrian & cycle paths
      case TravelMode.transit:
        return 'walking';
    }
  }
}
