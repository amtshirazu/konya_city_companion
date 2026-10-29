import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'package:konya_city_companion/features/map/presentation/providers/location_provider.dart';
import 'package:konya_city_companion/features/map/services/location_service.dart';

class MockLocationService implements LocationService {
  bool serviceEnabled = true;
  LocationPermission permission = LocationPermission.denied;
  bool grantOnRequest = true;
  Position? currentPosition;
  bool throwErrorOnPosition = false;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    if (permission == LocationPermission.denied && grantOnRequest) {
      permission = LocationPermission.whileInUse;
    }
    return permission;
  }

  @override
  Future<Position?> getCurrentPosition() async {
    if (throwErrorOnPosition) {
      throw Exception('GPS fix failed');
    }
    return currentPosition ??
        Position(
          longitude: 32.4925,
          latitude: 37.8719,
          timestamp: DateTime.now(),
          accuracy: 5.0,
          altitude: 100.0,
          altitudeAccuracy: 1.0,
          heading: 0.0,
          headingAccuracy: 1.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        );
  }

  @override
  Stream<Position> getPositionStream({int distanceFilter = 10}) async* {
    if (currentPosition != null) {
      yield currentPosition!;
    }
  }

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}

void main() {
  late MockLocationService mockService;
  late ProviderContainer container;

  setUp(() {
    mockService = MockLocationService();
    container = ProviderContainer(
      overrides: [locationServiceProvider.overrideWithValue(mockService)],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('UserLocationNotifier Unit Tests', () {
    test('Initial state is LocationStatus.initial', () {
      final state = container.read(userLocationProvider);
      expect(state.status, equals(LocationStatus.initial));
      expect(state.location, isNull);
    });

    test('Handles service disabled state gracefully', () async {
      mockService.serviceEnabled = false;
      final notifier = container.read(userLocationProvider.notifier);
      final result = await notifier.requestLocationAccess();

      final state = container.read(userLocationProvider);
      expect(result, isFalse);
      expect(state.status, equals(LocationStatus.serviceDisabled));
      expect(state.errorMessage, contains('GPS'));
    });

    test('Handles permission denied state', () async {
      mockService.permission = LocationPermission.denied;
      mockService.grantOnRequest = false;
      final notifier = container.read(userLocationProvider.notifier);

      final result = await notifier.requestLocationAccess();

      final state = container.read(userLocationProvider);
      expect(state.status, equals(LocationStatus.permissionDenied));
      expect(result, isFalse);
    });

    test('Handles permission denied forever state', () async {
      mockService.permission = LocationPermission.deniedForever;
      final notifier = container.read(userLocationProvider.notifier);
      final result = await notifier.requestLocationAccess();

      final state = container.read(userLocationProvider);
      expect(result, isFalse);
      expect(state.status, equals(LocationStatus.permissionDeniedForever));
    });

    test('Grants permission and fetches valid GPS location', () async {
      mockService.permission = LocationPermission.whileInUse;
      mockService.grantOnRequest = true;
      mockService.currentPosition = Position(
        latitude: 37.8707,
        longitude: 32.5050,
        timestamp: DateTime.now(),
        accuracy: 3.0,
        altitude: 100.0,
        altitudeAccuracy: 1.0,
        heading: 0.0,
        headingAccuracy: 1.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );

      final notifier = container.read(userLocationProvider.notifier);
      final result = await notifier.requestLocationAccess();

      final state = container.read(userLocationProvider);
      expect(result, isTrue);
      expect(state.status, equals(LocationStatus.granted));
      expect(state.location, equals(const LatLng(37.8707, 32.5050)));
    });
  });
}
