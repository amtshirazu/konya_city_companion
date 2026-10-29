import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_colors.dart';
import '../../places/domain/place.dart';
import '../../places/presentation/providers/places_provider.dart';
import '../config/map_config.dart';
import '../domain/route_request.dart';
import '../domain/travel_mode.dart';
import 'providers/location_provider.dart';
import 'providers/routing_provider.dart';
import 'providers/transit_provider.dart';
import 'widgets/open_street_map_view.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final TextEditingController _searchController = TextEditingController();
  final MapController _mapController = MapController();
  String _selectedCategory = 'all';
  Place? _selectedPlace;
  bool _handledInitialPlaceId = false;
  bool _isNearbyMode = false;
  DateTime? _lastRerouteTime;

  final List<Map<String, String>> _categories = const [
    {'id': 'all', 'label': 'All'},
    {'id': 'history-culture', 'label': 'History & Culture'},
    {'id': 'mosques', 'label': 'Mosques'},
    {'id': 'parks-outdoors', 'label': 'Parks & Outdoors'},
    {'id': 'nature', 'label': 'Nature'},
    {'id': 'food-cafes', 'label': 'Food & Cafes'},
    {'id': 'essentials', 'label': 'Essentials'},
    {'id': 'transport', 'label': 'Transport'},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _onSelectPlace(Place place) {
    setState(() {
      _selectedPlace = place;
    });

    if (place.latitude != null && place.longitude != null) {
      _mapController.move(LatLng(place.latitude!, place.longitude!), 15.0);
    }
  }

  Future<void> _handleMyLocationPressed() async {
    final locationState = ref.read(userLocationProvider);
    final notifier = ref.read(userLocationProvider.notifier);

    if (locationState.status == LocationStatus.granted &&
        locationState.location != null) {
      _mapController.move(locationState.location!, 15.0);
      return;
    }

    if (locationState.status == LocationStatus.serviceDisabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('GPS / Location services are disabled.'),
          action: SnackBarAction(
            label: 'Enable',
            onPressed: () => notifier.openLocationSettings(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (locationState.status == LocationStatus.permissionDeniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Location permission is disabled in settings.'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: () => notifier.openAppSettings(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Show rationale dialog before asking for permission
    final shouldRequest = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission Needed'),
        content: const Text(
          'Konya City Companion uses location services to show your current position on the map and calculate directions to nearby attractions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Grant Access'),
          ),
        ],
      ),
    );

    if (shouldRequest == true) {
      final success = await notifier.requestLocationAccess();
      if (success) {
        final updatedState = ref.read(userLocationProvider);
        if (updatedState.location != null) {
          _mapController.move(updatedState.location!, 15.0);
        }
      }
    }
  }

  Future<void> _fetchAndFocusRoute(Place place) async {
    final locationState = ref.read(userLocationProvider);
    final selectedMode = ref.read(travelModeProvider);

    const defaultOrigin = LatLng(37.8719, 32.4925);
    final origin = locationState.location ?? defaultOrigin;
    final destLat = place.latitude ?? 37.8707;
    final destLng = place.longitude ?? 32.5050;
    final destination = LatLng(destLat, destLng);

    if (locationState.location != null) {
      debugPrint(
        '📍 ROUTE ORIGIN: Using Live Emulator/Device Location (${origin.latitude}, ${origin.longitude})',
      );
    } else {
      debugPrint(
        '📍 ROUTE ORIGIN: Live GPS not active. Using Central Konya (Alaaddin) fallback (${origin.latitude}, ${origin.longitude})',
      );
    }

    final request = RouteRequest(
      origin: origin,
      destination: destination,
      destinationName: place.name,
      mode: selectedMode,
    );

    if (selectedMode == TravelMode.transit) {
      ref.read(activeRouteProvider.notifier).clearRoute();
      await ref
          .read(activeTransitProvider.notifier)
          .calculateTransitJourney(request);
    } else {
      ref.read(activeTransitProvider.notifier).clearTransitJourney();
      await ref.read(activeRouteProvider.notifier).fetchRoute(request);
    }

    if (!mounted) return;

    if (place.latitude != null && place.longitude != null) {
      _mapController.move(LatLng(place.latitude!, place.longitude!), 14.2);
    }
  }

  Future<void> _calculateAndShowDirections(Place place) async {
    await _fetchAndFocusRoute(place);
    if (!mounted) return;
    _showDirectionsModalSheet(place);
  }

  Future<void> _openAtusPortal() async {
    final uri = Uri.parse('https://atus.konya.bel.tr');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showDirectionsModalSheet(Place place) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final routeState = ref.watch(activeRouteProvider);
            final activeTransitState = ref.watch(activeTransitProvider);
            final travelMode = ref.watch(travelModeProvider);
            final route = routeState.result;
            final transitJourney = activeTransitState.result;

            final modeIcon = switch (travelMode) {
              TravelMode.walking => Icons.directions_walk_rounded,
              TravelMode.driving => Icons.directions_car_rounded,
              TravelMode.cycling => Icons.directions_bike_rounded,
              TravelMode.transit => Icons.tram_rounded,
            };

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(20),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.80,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header with Place & Distance
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          modeIcon,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Route to ${place.name}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            if (travelMode == TravelMode.transit &&
                                transitJourney != null)
                              Text(
                                '${transitJourney.totalDistanceKm} km • ~${transitJourney.totalDurationMinutes} mins (Tram Guide)',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              )
                            else if (route != null)
                              Text(
                                '${route.distanceText} • ${route.durationText} (${travelMode.label})',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              )
                            else
                              const Text(
                                'Calculating route...',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Travel Mode Selector (Segmented)
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<TravelMode>(
                      segments: const [
                        ButtonSegment<TravelMode>(
                          value: TravelMode.walking,
                          label: Text('Walk'),
                          icon: Icon(Icons.directions_walk_rounded, size: 16),
                        ),
                        ButtonSegment<TravelMode>(
                          value: TravelMode.driving,
                          label: Text('Drive'),
                          icon: Icon(Icons.directions_car_rounded, size: 16),
                        ),
                        ButtonSegment<TravelMode>(
                          value: TravelMode.cycling,
                          label: Text('Cycle'),
                          icon: Icon(Icons.directions_bike_rounded, size: 16),
                        ),
                        ButtonSegment<TravelMode>(
                          value: TravelMode.transit,
                          label: Text('Tram'),
                          icon: Icon(Icons.tram_rounded, size: 16),
                        ),
                      ],
                      selected: {travelMode},
                      onSelectionChanged: (newSelection) {
                        final mode = newSelection.first;
                        ref.read(travelModeProvider.notifier).setMode(mode);
                        _fetchAndFocusRoute(place);
                      },
                      style: SegmentedButton.styleFrom(
                        selectedBackgroundColor: AppColors.primaryLight,
                        selectedForegroundColor: AppColors.primaryDark,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),

                  if (travelMode == TravelMode.transit &&
                      transitJourney != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: AppColors.primaryDark,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              transitJourney.noticeMessage ??
                                  'Scheduled Tram Timetable Data',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: _openAtusPortal,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                'Open ATUS',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (route != null && route.isFallback) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.wifi_off_rounded,
                            size: 16,
                            color: Colors.amber.shade900,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Offline route approximation in use.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.amber.shade900,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const Divider(height: 24, color: AppColors.border),

                  Text(
                    travelMode == TravelMode.transit
                        ? 'Konya Tram & Multimodal Journey Legs'
                        : 'Step-by-Step Directions',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Transit Legs or Step Directions List
                  Expanded(
                    child: travelMode == TravelMode.transit
                        ? (activeTransitState.isLoading
                              ? const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircularProgressIndicator(
                                        color: AppColors.primary,
                                      ),
                                      SizedBox(height: 14),
                                      Text(
                                        'Searching GTFS transit timetables...',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : (transitJourney == null
                                    ? const Center(
                                        child: Text(
                                          'No transit guide available.',
                                        ),
                                      )
                                    : ListView.separated(
                                        itemCount: transitJourney.legs.length,
                                        separatorBuilder: (_, _) =>
                                            const Padding(
                                              padding: EdgeInsets.only(
                                                left: 11,
                                                top: 4,
                                                bottom: 4,
                                              ),
                                              child: SizedBox(
                                                height: 12,
                                                child: VerticalDivider(
                                                  width: 2,
                                                  color: AppColors.border,
                                                ),
                                              ),
                                            ),
                                        itemBuilder: (context, index) {
                                          final leg =
                                              transitJourney.legs[index];
                                          final IconData legIcon;
                                          if (leg.isTram) {
                                            legIcon = Icons.tram_rounded;
                                          } else if (leg.isBus) {
                                            legIcon =
                                                Icons.directions_bus_rounded;
                                          } else {
                                            legIcon =
                                                Icons.directions_walk_rounded;
                                          }

                                          return Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              CircleAvatar(
                                                radius: 14,
                                                backgroundColor:
                                                    leg.legColor?.withValues(
                                                      alpha: 0.15,
                                                    ) ??
                                                    AppColors.primaryLight,
                                                child: Icon(
                                                  legIcon,
                                                  size: 16,
                                                  color:
                                                      leg.legColor ??
                                                      AppColors.primaryDark,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      leg.title,
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: AppColors
                                                            .textPrimary,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      leg.description,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: AppColors
                                                            .textSecondary,
                                                      ),
                                                    ),
                                                    if (leg
                                                        .intermediateStops
                                                        .isNotEmpty) ...[
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        'Via stops: ${leg.intermediateStops.join(", ")}',
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          fontStyle:
                                                              FontStyle.italic,
                                                          color: AppColors
                                                              .textSecondary,
                                                        ),
                                                      ),
                                                    ],
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      '${leg.distanceKm} km • ~${leg.durationMinutes} mins',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color:
                                                            leg.legColor ??
                                                            AppColors.primary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      )))
                        : (routeState.isLoading
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.primary,
                                  ),
                                )
                              : (route == null
                                    ? const Center(
                                        child: Text('No directions available.'),
                                      )
                                    : ListView.separated(
                                        itemCount: route.steps.length,
                                        separatorBuilder: (_, _) =>
                                            const Padding(
                                              padding: EdgeInsets.only(
                                                left: 11,
                                                top: 4,
                                                bottom: 4,
                                              ),
                                              child: SizedBox(
                                                height: 12,
                                                child: VerticalDivider(
                                                  width: 2,
                                                  color: AppColors.border,
                                                ),
                                              ),
                                            ),
                                        itemBuilder: (context, index) {
                                          final step = route.steps[index];
                                          return Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              CircleAvatar(
                                                radius: 12,
                                                backgroundColor:
                                                    AppColors.primaryLight,
                                                child: Text(
                                                  '${index + 1}',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w800,
                                                    color:
                                                        AppColors.primaryDark,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      step.instruction,
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: AppColors
                                                            .textPrimary,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      step.distanceText,
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color: AppColors
                                                            .textSecondary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ))),
                  ),

                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('View Polyline on Map'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _checkRouteTrackingAndRerouting(LatLng userLoc) {
    final routeState = ref.read(activeRouteProvider);
    final route = routeState.result;
    if (route == null || route.points.isEmpty || _selectedPlace == null) return;

    final destLat = _selectedPlace!.latitude ?? route.points.last.latitude;
    final destLng = _selectedPlace!.longitude ?? route.points.last.longitude;
    final destLoc = LatLng(destLat, destLng);

    // 1. Arrival Detection (< 25 meters)
    final distanceToDestMeters = _distanceMeters(userLoc, destLoc);
    if (distanceToDestMeters < 25.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You arrived at ${_selectedPlace!.name}!'),
          backgroundColor: AppColors.primaryDark,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // 2. Deviation Detection (> 100 meters off route polyline)
    final minDistanceToPolyline = _minDistanceToPolyline(userLoc, route.points);
    if (minDistanceToPolyline > 100.0) {
      final now = DateTime.now();
      if (_lastRerouteTime != null &&
          now.difference(_lastRerouteTime!) < const Duration(seconds: 10)) {
        return; // Throttle rerouting requests to avoid API spam
      }
      _lastRerouteTime = now;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Route deviation detected. Recalculating...'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );

      final mode = ref.read(travelModeProvider);
      final request = RouteRequest(
        origin: userLoc,
        destination: destLoc,
        destinationName: _selectedPlace!.name,
        mode: mode,
      );
      ref.read(activeRouteProvider.notifier).fetchRoute(request);
    }
  }

  double _distanceMeters(LatLng a, LatLng b) {
    const double r = 6371000.0; // Earth radius in meters
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

  double _minDistanceToPolyline(LatLng point, List<LatLng> polyline) {
    if (polyline.isEmpty) return double.infinity;
    double minMeters = double.infinity;
    for (final p in polyline) {
      final d = _distanceMeters(point, p);
      if (d < minMeters) minMeters = d;
    }
    return minMeters;
  }

  void _clearActiveRouteAndTransit() {
    ref.read(activeRouteProvider.notifier).clearRoute();
    ref.read(activeTransitProvider.notifier).clearTransitJourney();
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(placesRepositoryProvider);
    final userLocationState = ref.watch(userLocationProvider);
    final activeRouteState = ref.watch(activeRouteProvider);
    final activeTransitState = ref.watch(activeTransitProvider);
    final activeTransit = activeTransitState.result;

    const defaultOrigin = LatLng(
      MapConfig.initialLatitude,
      MapConfig.initialLongitude,
    );
    final currentOrigin = userLocationState.location ?? defaultOrigin;

    var places = repository.searchPlaces(
      query: _searchController.text,
      categoryId: _selectedCategory,
    );

    // Handle deep link / navigation query parameters for placeId or nearby
    if (!_handledInitialPlaceId) {
      _handledInitialPlaceId = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final uri = GoRouterState.of(context).uri;
        final rawPlaceId = uri.queryParameters['placeId'];
        final isNearbyParam = uri.queryParameters['nearby'] == 'true';

        if (rawPlaceId != null && rawPlaceId.isNotEmpty) {
          final targetPlace = repository.getPlaceById(rawPlaceId);
          if (targetPlace != null) {
            _onSelectPlace(targetPlace);
          }
        } else if (isNearbyParam) {
          setState(() {
            _isNearbyMode = true;
          });

          // Request / fetch current location if not granted
          if (userLocationState.status != LocationStatus.granted) {
            final notifier = ref.read(userLocationProvider.notifier);
            await notifier.requestLocationAccess();
          }

          final updatedLocState = ref.read(userLocationProvider);
          final origin = updatedLocState.location ?? defaultOrigin;

          final allPlaces = repository
              .getAllPlaces()
              .where((p) => p.latitude != null && p.longitude != null)
              .toList();

          allPlaces.sort((a, b) {
            final distA = _distanceMeters(
              origin,
              LatLng(a.latitude!, a.longitude!),
            );
            final distB = _distanceMeters(
              origin,
              LatLng(b.latitude!, b.longitude!),
            );
            return distA.compareTo(distB);
          });

          if (allPlaces.isNotEmpty) {
            _onSelectPlace(allPlaces.first);
          }
        }
      });
    }

    if (_isNearbyMode &&
        _searchController.text.isEmpty &&
        _selectedCategory == 'all') {
      places = places
          .where((p) => p.latitude != null && p.longitude != null)
          .toList();
      places.sort((a, b) {
        final distA = _distanceMeters(
          currentOrigin,
          LatLng(a.latitude!, a.longitude!),
        );
        final distB = _distanceMeters(
          currentOrigin,
          LatLng(b.latitude!, b.longitude!),
        );
        return distA.compareTo(distB);
      });
      places = places.take(35).toList();
    }

    // Ensure selected place remains valid within current filtered results
    if (_selectedPlace == null || !places.contains(_selectedPlace)) {
      _selectedPlace = places.isNotEmpty ? places.first : null;
    }

    // Listen for GPS location updates to perform deviation check & rerouting
    ref.listen<UserLocationState>(userLocationProvider, (prev, next) {
      if (next.status == LocationStatus.granted && next.location != null) {
        _checkRouteTrackingAndRerouting(next.location!);
      }
    });

    final hasActiveDirections =
        activeRouteState.result != null || activeTransit != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Controls (Search & Category Chips)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'KONYA MAP',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                      if (hasActiveDirections)
                        TextButton.icon(
                          onPressed: _clearActiveRouteAndTransit,
                          icon: const Icon(Icons.clear_rounded, size: 14),
                          label: const Text('Clear Route'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Explore Places on Map',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Search input
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search map locations...',
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Category Filter Chips
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final cat = _categories[index];
                        final id = cat['id']!;
                        final label = cat['label']!;
                        final isSelected = _selectedCategory == id;

                        return ChoiceChip(
                          label: Text(label),
                          selected: isSelected,
                          showCheckmark: false,
                          onSelected: (_) {
                            setState(() {
                              _selectedCategory = id;
                            });
                          },
                          backgroundColor: Colors.white,
                          selectedColor: AppColors.primaryLight,
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.border,
                          ),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? AppColors.primaryDark
                                : AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Map Area & Floating Selected Place Card
            Expanded(
              child: Stack(
                children: [
                  // OpenStreetMap View with Active Polyline Route and User Location
                  Positioned.fill(
                    child: OpenStreetMapView(
                      places: places,
                      selectedPlace: _selectedPlace,
                      onSelectPlace: _onSelectPlace,
                      userLocation: userLocationState.location,
                      activeRoute: activeRouteState.result,
                      transitJourney: activeTransit,
                      mapController: _mapController,
                    ),
                  ),

                  // Floating "My Location" Button
                  Positioned(
                    right: 16,
                    top: 16,
                    child: FloatingActionButton.small(
                      heroTag: 'my_location_btn',
                      onPressed: _handleMyLocationPressed,
                      backgroundColor: Colors.white,
                      foregroundColor:
                          userLocationState.status == LocationStatus.granted
                          ? AppColors.primary
                          : AppColors.textPrimary,
                      child: userLocationState.status == LocationStatus.loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            )
                          : Icon(
                              userLocationState.status == LocationStatus.granted
                                  ? Icons.my_location_rounded
                                  : Icons.location_searching_rounded,
                              size: 20,
                            ),
                    ),
                  ),

                  // Selected Place Preview Card
                  if (_selectedPlace != null)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: _MapPlacePreviewCard(
                        place: _selectedPlace!,
                        userLocation: userLocationState.location,
                        onTapCard: () {
                          final encodedId = Uri.encodeComponent(
                            _selectedPlace!.id,
                          );
                          context.push('/place/$encodedId');
                        },
                        onGetDirections: () {
                          _calculateAndShowDirections(_selectedPlace!);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapPlacePreviewCard extends StatelessWidget {
  const _MapPlacePreviewCard({
    required this.place,
    this.userLocation,
    required this.onTapCard,
    required this.onGetDirections,
  });

  final Place place;
  final LatLng? userLocation;
  final VoidCallback onTapCard;
  final VoidCallback onGetDirections;

  String? _getDistanceText() {
    if (userLocation == null ||
        place.latitude == null ||
        place.longitude == null) {
      return null;
    }
    const double r = 6371.0; // Earth radius in km
    final dLat = (place.latitude! - userLocation!.latitude) * (pi / 180.0);
    final dLon = (place.longitude! - userLocation!.longitude) * (pi / 180.0);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(userLocation!.latitude * (pi / 180.0)) *
            cos(place.latitude! * (pi / 180.0)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final distKm = r * c;
    if (distKm < 1.0) {
      return '${(distKm * 1000).round()} m away';
    }
    return '${distKm.toStringAsFixed(1)} km away';
  }

  @override
  Widget build(BuildContext context) {
    final distText = _getDistanceText();
    final categoryAndDistanceText = distText != null
        ? '$distText • ${place.categoryLabel}'
        : place.categoryLabel;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      child: InkWell(
        onTap: onTapCard,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: place.accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(place.icon, size: 28, color: place.accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      place.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      categoryAndDistanceText,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      place.address ?? 'Central Konya',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: onGetDirections,
                icon: const Icon(Icons.directions_rounded, size: 16),
                label: const Text('Directions'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
