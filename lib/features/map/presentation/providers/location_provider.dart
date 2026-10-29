import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../services/location_service.dart';

enum LocationStatus {
  initial,
  loading,
  granted,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  error,
}

class UserLocationState {
  final LocationStatus status;
  final LatLng? location;
  final String? errorMessage;
  final bool isTracking;

  const UserLocationState({
    required this.status,
    this.location,
    this.errorMessage,
    this.isTracking = false,
  });

  UserLocationState copyWith({
    LocationStatus? status,
    LatLng? location,
    String? errorMessage,
    bool? isTracking,
  }) {
    return UserLocationState(
      status: status ?? this.status,
      location: location ?? this.location,
      errorMessage: errorMessage ?? this.errorMessage,
      isTracking: isTracking ?? this.isTracking,
    );
  }
}

final locationServiceProvider = Provider<LocationService>((ref) {
  return const GeolocatorLocationService();
});

class UserLocationNotifier extends Notifier<UserLocationState> {
  StreamSubscription<Position>? _positionSubscription;

  @override
  UserLocationState build() {
    ref.onDispose(() {
      _positionSubscription?.cancel();
    });
    return const UserLocationState(status: LocationStatus.initial);
  }

  LocationService get _locationService => ref.read(locationServiceProvider);

  /// Checks existing permission and determines current status without triggering a prompt
  Future<void> checkCurrentPermission() async {
    final serviceEnabled = await _locationService.isLocationServiceEnabled();
    if (!serviceEnabled) {
      state = state.copyWith(
        status: LocationStatus.serviceDisabled,
        errorMessage: 'Location services are disabled on your device.',
      );
      return;
    }

    final permission = await _locationService.checkPermission();
    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      await fetchCurrentLocation();
    } else if (permission == LocationPermission.deniedForever) {
      state = state.copyWith(
        status: LocationStatus.permissionDeniedForever,
        errorMessage: 'Location permission permanently denied.',
      );
    } else if (permission == LocationPermission.denied) {
      state = state.copyWith(
        status: LocationStatus.permissionDenied,
        errorMessage: 'Location permission not granted.',
      );
    }
  }

  /// Requests user location permission and fetches coordinates if granted
  Future<bool> requestLocationAccess({bool startTracking = true}) async {
    state = state.copyWith(status: LocationStatus.loading, errorMessage: null);

    final serviceEnabled = await _locationService.isLocationServiceEnabled();
    if (!serviceEnabled) {
      state = state.copyWith(
        status: LocationStatus.serviceDisabled,
        errorMessage: 'GPS / Location services are turned off.',
      );
      return false;
    }

    var permission = await _locationService.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await _locationService.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      state = state.copyWith(
        status: LocationStatus.permissionDenied,
        errorMessage: 'Location permission was denied.',
      );
      return false;
    }

    if (permission == LocationPermission.deniedForever) {
      state = state.copyWith(
        status: LocationStatus.permissionDeniedForever,
        errorMessage: 'Location permission is permanently denied. Please enable it in App Settings.',
      );
      return false;
    }

    // Permission granted
    final success = await fetchCurrentLocation();
    if (success && startTracking) {
      _startPositionStream();
    }
    return success;
  }

  /// Fetches a single current position fix
  Future<bool> fetchCurrentLocation() async {
    try {
      final position = await _locationService.getCurrentPosition();
      if (position != null) {
        debugPrint(
          '==================================================\n'
          '📍 CURRENT USER LOCATION (GPS FIX):\n'
          '   Latitude  : ${position.latitude}\n'
          '   Longitude : ${position.longitude}\n'
          '==================================================',
        );
        state = state.copyWith(
          status: LocationStatus.granted,
          location: LatLng(position.latitude, position.longitude),
          errorMessage: null,
        );
        return true;
      } else {
        debugPrint(
          '📍 GPS FIX FAILED: Unable to retrieve location coordinates.',
        );
        state = state.copyWith(
          status: LocationStatus.error,
          errorMessage: 'Unable to retrieve location coordinates.',
        );
        return false;
      }
    } catch (e) {
      debugPrint('📍 GPS FIX ERROR: $e');
      state = state.copyWith(
        status: LocationStatus.error,
        errorMessage: 'Failed to acquire location: $e',
      );
      return false;
    }
  }

  /// Starts listening to GPS position stream for active updates
  void _startPositionStream() {
    _positionSubscription?.cancel();
    state = state.copyWith(isTracking: true);

    _positionSubscription = _locationService
        .getPositionStream(distanceFilter: 10)
        .listen(
          (position) {
            debugPrint(
              '📍 LIVE GPS TRACKING UPDATE: Lat = ${position.latitude}, Lng = ${position.longitude}',
            );
            state = state.copyWith(
              status: LocationStatus.granted,
              location: LatLng(position.latitude, position.longitude),
              errorMessage: null,
            );
          },
          onError: (error) {
            // Keep existing location if available, mark error state
            state = state.copyWith(
              errorMessage: 'Location update interrupted: $error',
            );
          },
        );
  }

  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    state = state.copyWith(isTracking: false);
  }

  Future<bool> openAppSettings() => _locationService.openAppSettings();
  Future<bool> openLocationSettings() =>
      _locationService.openLocationSettings();
}

final userLocationProvider =
    NotifierProvider<UserLocationNotifier, UserLocationState>(
      UserLocationNotifier.new,
    );
