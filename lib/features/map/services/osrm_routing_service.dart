import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../config/map_config.dart';
import '../domain/route_request.dart';
import '../domain/route_result.dart';
import '../domain/route_step.dart';
import '../domain/travel_mode.dart';
import 'routing_service.dart';

class OsrmRoutingService implements RoutingService {
  final http.Client _httpClient;
  final String _baseUrl;
  final String _apiKey;

  OsrmRoutingService({http.Client? httpClient, String? baseUrl, String? apiKey})
    : _httpClient = httpClient ?? http.Client(),
      _baseUrl = baseUrl ?? MapConfig.locationIqBaseUrl,
      _apiKey = apiKey ?? MapConfig.locationIqApiKey;

  @override
  Future<RouteResult> calculateRoute(RouteRequest request) async {
    final profile = request.mode.osrmProfile;
    final originLng = request.origin.longitude;
    final originLat = request.origin.latitude;
    final destLng = request.destination.longitude;
    final destLat = request.destination.latitude;

    final url = Uri.parse(
      '$_baseUrl/directions/$profile/$originLng,$originLat;$destLng,$destLat?key=$_apiKey&overview=full&geometries=geojson&steps=true',
    );

    try {
      final response = await _httpClient
          .get(url)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        if (data['code'] == 'Ok' &&
            data['routes'] != null &&
            (data['routes'] as List).isNotEmpty) {
          final routeData = data['routes'][0] as Map<String, dynamic>;
          return _parseOsrmRoute(routeData, request);
        }
      }

      return _generateFallbackRoute(
        request,
        status: RouteStatus.serviceUnavailable,
        errorMessage: 'Routing server returned status ${response.statusCode}.',
      );
    } on Error {
      rethrow;
    } catch (e) {
      return _generateFallbackRoute(
        request,
        status: RouteStatus.networkError,
        errorMessage: 'Network connection or timeout issue: $e',
      );
    }
  }

  RouteResult _parseOsrmRoute(
    Map<String, dynamic> routeData,
    RouteRequest request,
  ) {
    final double totalDistanceMeters = (routeData['distance'] as num)
        .toDouble();
    double totalDurationSeconds = (routeData['duration'] as num).toDouble();

    if (request.mode == TravelMode.cycling) {
      // LocationIQ walking profile returns walking duration; cycling is ~3.33x faster (~15 km/h)
      totalDurationSeconds = totalDurationSeconds / 3.33;
    }

    final double distanceKm = max(0.1, totalDistanceMeters / 1000.0);
    final int durationMinutes = max(1, (totalDurationSeconds / 60.0).round());

    // Extract polyline points from GeoJSON coordinates: [[lng, lat], ...]
    final List<LatLng> points = [];
    if (routeData['geometry'] != null &&
        routeData['geometry']['coordinates'] != null) {
      final coords = routeData['geometry']['coordinates'] as List;
      for (final coord in coords) {
        if (coord is List && coord.length >= 2) {
          final lng = (coord[0] as num).toDouble();
          final lat = (coord[1] as num).toDouble();
          points.add(LatLng(lat, lng));
        }
      }
    }

    if (points.isEmpty) {
      points.add(request.origin);
      points.add(request.destination);
    }

    // Extract turn steps from legs
    final List<RouteStep> steps = [];
    if (routeData['legs'] != null && (routeData['legs'] as List).isNotEmpty) {
      final leg = routeData['legs'][0] as Map<String, dynamic>;
      if (leg['steps'] != null) {
        final rawSteps = leg['steps'] as List;
        for (int i = 0; i < rawSteps.length; i++) {
          final stepJson = rawSteps[i] as Map<String, dynamic>;
          final parsedStep = _parseOsrmStep(
            stepJson,
            i,
            rawSteps.length,
            request,
          );
          steps.add(parsedStep);
        }
      }
    }

    if (steps.isEmpty) {
      steps.addAll(_generateDefaultSteps(request, distanceKm));
    }

    return RouteResult(
      status: RouteStatus.success,
      destinationName: request.destinationName,
      distanceKm: double.parse(distanceKm.toStringAsFixed(1)),
      durationMinutes: durationMinutes,
      points: points,
      steps: steps,
      mode: request.mode,
      isFallback: false,
    );
  }

  RouteStep _parseOsrmStep(
    Map<String, dynamic> stepJson,
    int index,
    int totalSteps,
    RouteRequest request,
  ) {
    final double distance = (stepJson['distance'] as num).toDouble();
    final double duration = (stepJson['duration'] as num).toDouble();
    final String roadName = (stepJson['name'] as String?)?.trim() ?? '';

    final maneuver = stepJson['maneuver'] as Map<String, dynamic>?;
    final type = maneuver?['type'] as String?;
    final modifier = maneuver?['modifier'] as String?;

    LatLng location = request.origin;
    if (maneuver?['location'] != null) {
      final locList = maneuver!['location'] as List;
      if (locList.length >= 2) {
        location = LatLng(
          (locList[1] as num).toDouble(),
          (locList[0] as num).toDouble(),
        );
      }
    }

    String instruction = _buildStepInstruction(
      type: type,
      modifier: modifier,
      roadName: roadName,
      index: index,
      totalSteps: totalSteps,
      destinationName: request.destinationName,
      mode: request.mode,
    );

    return RouteStep(
      instruction: instruction,
      distanceMeters: distance,
      durationSeconds: duration,
      distanceText: RouteStep.formatDistance(distance),
      durationText: RouteStep.formatDuration(duration),
      location: location,
      maneuverType: type,
      modifier: modifier,
    );
  }

  String _buildStepInstruction({
    required String? type,
    required String? modifier,
    required String roadName,
    required int index,
    required int totalSteps,
    required String destinationName,
    required TravelMode mode,
  }) {
    final modeAction = switch (mode) {
      TravelMode.walking => 'Walk',
      TravelMode.cycling => 'Cycle',
      TravelMode.driving || TravelMode.transit => 'Drive',
    };

    if (index == 0) {
      if (roadName.isNotEmpty) {
        return '$modeAction along $roadName';
      }
      return 'Head towards $destinationName';
    }

    if (index == totalSteps - 1 || type == 'arrive') {
      return 'Arrive at $destinationName';
    }

    final formattedModifier = modifier != null
        ? modifier.replaceAll('_', ' ')
        : '';

    switch (type) {
      case 'turn':
        if (formattedModifier.isNotEmpty && roadName.isNotEmpty) {
          return 'Turn $formattedModifier onto $roadName';
        } else if (formattedModifier.isNotEmpty) {
          return 'Turn $formattedModifier';
        } else if (roadName.isNotEmpty) {
          return 'Turn onto $roadName';
        }
        return 'Continue along route';

      case 'new name':
      case 'continue':
        if (roadName.isNotEmpty) {
          return 'Continue onto $roadName';
        }
        return 'Continue straight';

      case 'roundabout':
      case 'rotary':
        if (roadName.isNotEmpty) {
          return 'At roundabout, take exit onto $roadName';
        }
        return 'Enter roundabout and take exit';

      case 'fork':
        if (formattedModifier.isNotEmpty) {
          return 'At fork, keep $formattedModifier';
        }
        return 'Keep right at fork';

      default:
        if (roadName.isNotEmpty) {
          return 'Follow $roadName';
        }
        return 'Proceed along path';
    }
  }

  RouteResult _generateFallbackRoute(
    RouteRequest request, {
    required RouteStatus status,
    String? errorMessage,
  }) {
    final distanceKm = _calculateStraightDistance(
      request.origin,
      request.destination,
    );
    final speedKmH = switch (request.mode) {
      TravelMode.walking => 4.5,
      TravelMode.cycling => 15.0,
      TravelMode.driving || TravelMode.transit => 30.0,
    };
    final durationMins = max(2, (distanceKm / speedKmH * 60).round());

    final points = [
      request.origin,
      LatLng(
        request.origin.latitude +
            (request.destination.latitude - request.origin.latitude) * 0.4,
        request.origin.longitude +
            (request.destination.longitude - request.origin.longitude) * 0.2,
      ),
      LatLng(
        request.origin.latitude +
            (request.destination.latitude - request.origin.latitude) * 0.7,
        request.origin.longitude +
            (request.destination.longitude - request.origin.longitude) * 0.8,
      ),
      request.destination,
    ];

    final steps = _generateDefaultSteps(request, distanceKm);

    return RouteResult(
      status: RouteStatus.fallbackUsed,
      destinationName: request.destinationName,
      distanceKm: double.parse(distanceKm.toStringAsFixed(1)),
      durationMinutes: durationMins,
      points: points,
      steps: steps,
      mode: request.mode,
      errorMessage: errorMessage,
      isFallback: true,
    );
  }

  List<RouteStep> _generateDefaultSteps(
    RouteRequest request,
    double distanceKm,
  ) {
    final action = switch (request.mode) {
      TravelMode.walking => 'Walk',
      TravelMode.cycling => 'Cycle',
      TravelMode.driving || TravelMode.transit => 'Drive',
    };

    return [
      RouteStep(
        instruction: 'Start at origin location',
        distanceMeters: 0,
        durationSeconds: 0,
        distanceText: '0 m',
        durationText: '0 mins',
        location: request.origin,
        maneuverType: 'depart',
      ),
      RouteStep(
        instruction:
            '$action along main arterial road toward ${request.destinationName}',
        distanceMeters: distanceKm * 700,
        durationSeconds: (distanceKm * 700) / 1.2,
        distanceText: RouteStep.formatDistance(distanceKm * 700),
        durationText: RouteStep.formatDuration((distanceKm * 700) / 1.2),
        location: request.origin,
        maneuverType: 'continue',
      ),
      RouteStep(
        instruction: 'Arrive at ${request.destinationName}',
        distanceMeters: distanceKm * 300,
        durationSeconds: (distanceKm * 300) / 1.2,
        distanceText: RouteStep.formatDistance(distanceKm * 300),
        durationText: RouteStep.formatDuration((distanceKm * 300) / 1.2),
        location: request.destination,
        maneuverType: 'arrive',
      ),
    ];
  }

  double _calculateStraightDistance(LatLng start, LatLng end) {
    const double earthRadiusKm = 6371.0;
    final double dLat = (end.latitude - start.latitude) * (pi / 180.0);
    final double dLon = (end.longitude - start.longitude) * (pi / 180.0);

    final double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(start.latitude * (pi / 180.0)) *
            cos(end.latitude * (pi / 180.0)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return max(0.2, earthRadiusKm * c);
  }
}
