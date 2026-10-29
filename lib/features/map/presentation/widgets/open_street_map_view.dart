import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../places/domain/place.dart';
import '../../config/map_config.dart';
import '../../domain/route_result.dart';
import '../../domain/transit_models.dart';
import '../../services/cached_tile_provider.dart';

class OpenStreetMapView extends StatefulWidget {
  const OpenStreetMapView({
    super.key,
    required this.places,
    required this.selectedPlace,
    required this.onSelectPlace,
    this.userLocation,
    this.activeRoute,
    this.transitJourney,
    this.mapController,
    this.tileProvider,
  });

  final List<Place> places;
  final Place? selectedPlace;
  final ValueChanged<Place> onSelectPlace;
  final LatLng? userLocation;
  final RouteResult? activeRoute;
  final TransitJourneyResult? transitJourney;
  final MapController? mapController;

  /// Optional tile provider override (defaults to CachedTileProvider)
  final TileProvider? tileProvider;

  @override
  State<OpenStreetMapView> createState() => _OpenStreetMapViewState();
}

class _OpenStreetMapViewState extends State<OpenStreetMapView> {
  late final TileProvider _effectiveTileProvider;
  CachedTileProvider? _cachedTileProvider;

  @override
  void initState() {
    super.initState();
    if (widget.tileProvider != null) {
      _effectiveTileProvider = widget.tileProvider!;
      if (widget.tileProvider is CachedTileProvider) {
        _cachedTileProvider = widget.tileProvider as CachedTileProvider;
      }
    } else {
      _cachedTileProvider = CachedTileProvider();
      _effectiveTileProvider = _cachedTileProvider!;
    }
  }

  @override
  void dispose() {
    if (widget.tileProvider == null) {
      _cachedTileProvider?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final validPlaces = widget.places
        .where((p) => p.latitude != null && p.longitude != null)
        .toList();

    const centerLocation = LatLng(
      MapConfig.initialLatitude,
      MapConfig.initialLongitude,
    );

    return Stack(
      children: [
        FlutterMap(
          mapController: widget.mapController,
          options: MapOptions(
            initialCenter: centerLocation,
            initialZoom: MapConfig.initialZoom,
            minZoom: 6.0,
            maxZoom: 18.0,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: MapConfig.tileUrlTemplate,
              userAgentPackageName: MapConfig.userAgentPackageName,
              tileProvider: _effectiveTileProvider,
            ),

            // Single Active Route Polyline
            if (widget.activeRoute != null &&
                widget.activeRoute!.points.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: widget.activeRoute!.points,
                    strokeWidth: 4.5,
                    color: AppColors.primary,
                    borderStrokeWidth: 1.5,
                    borderColor: Colors.white,
                  ),
                ],
              ),

            // Multimodal Transit Polyline Legs
            if (widget.transitJourney != null &&
                widget.transitJourney!.legs.isNotEmpty)
              PolylineLayer(
                polylines: <Polyline>[
                  for (final leg in widget.transitJourney!.legs)
                    if (leg.points.isNotEmpty)
                      Polyline(
                        points: leg.points,
                        strokeWidth: leg.isTram ? 5.5 : 3.5,
                        color: leg.legColor ?? AppColors.primary,
                        borderStrokeWidth: 1.5,
                        borderColor: Colors.white,
                      ),
                ],
              ),

            // Places, Transit Stops, and Location Markers
            MarkerLayer(
              markers: [
                // Current User Location Marker
                if (widget.userLocation != null)
                  Marker(
                    point: widget.userLocation!,
                    width: 32.0,
                    height: 32.0,
                    alignment: Alignment.center,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2196F3).withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1976D2),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1976D2)
                                  .withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.navigation_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                // Route Origin Marker if active route exists and no user location is present
                if (widget.activeRoute != null &&
                    widget.activeRoute!.points.isNotEmpty &&
                    widget.userLocation == null)
                  Marker(
                    point: widget.activeRoute!.points.first,
                    width: 32.0,
                    height: 32.0,
                    alignment: Alignment.center,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: AppColors.primaryDark,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.my_location_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),

                // Transit Tram Boarding & Disembarking Stop Markers
                if (widget.transitJourney != null)
                  for (final leg in widget.transitJourney!.legs)
                    if (leg.isTram && leg.points.isNotEmpty) ...[
                      // Boarding stop
                      Marker(
                        point: leg.points.first,
                        width: 28.0,
                        height: 28.0,
                        alignment: Alignment.center,
                        child: Container(
                          decoration: BoxDecoration(
                            color: leg.legColor ?? Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.tram_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      // Disembarking stop
                      Marker(
                        point: leg.points.last,
                        width: 28.0,
                        height: 28.0,
                        alignment: Alignment.center,
                        child: Container(
                          decoration: BoxDecoration(
                            color: leg.legColor ?? Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.tram_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],

                // Compact Place Markers
                ...validPlaces.map((place) {
                  final isSelected = widget.selectedPlace?.id == place.id;
                  final point = LatLng(place.latitude!, place.longitude!);

                  return Marker(
                    point: point,
                    width: isSelected ? 36.0 : 26.0,
                    height: isSelected ? 36.0 : 26.0,
                    alignment: Alignment.center,
                    child: GestureDetector(
                      onTap: () => widget.onSelectPlace(place),
                      child: Tooltip(
                        message: place.name,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: EdgeInsets.all(isSelected ? 5 : 3),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : place.accentColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: isSelected ? 2.0 : 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isSelected
                                    ? AppColors.primary.withValues(alpha: 0.4)
                                    : Colors.black.withValues(alpha: 0.2),
                                blurRadius: isSelected ? 8 : 3,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            place.icon,
                            size: isSelected ? 17 : 13,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),

            RichAttributionWidget(
              alignment: AttributionAlignment.bottomRight,
              attributions: [TextSourceAttribution(MapConfig.attributionText)],
            ),
          ],
        ),

        // Unobtrusive Tile Cache Status Indicator Badge
        if (_cachedTileProvider != null)
          Positioned(
            top: 12,
            left: 12,
            child: ValueListenableBuilder<TileCacheStatus>(
              valueListenable: _cachedTileProvider!.statusNotifier,
              builder: (context, status, child) {
                final String label;
                final IconData icon;
                final Color iconColor;

                switch (status) {
                  case TileCacheStatus.online:
                    label = 'Map Online';
                    icon = Icons.cloud_done_rounded;
                    iconColor = AppColors.primary;
                  case TileCacheStatus.cached:
                    label = 'Cached Map (Offline)';
                    icon = Icons.offline_pin_rounded;
                    iconColor = AppColors.primary;
                  case TileCacheStatus.offlineUncached:
                    label = 'Offline - Missing Tiles';
                    icon = Icons.cloud_off_rounded;
                    iconColor = const Color(0xFFD97706);
                }

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 14, color: iconColor),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
