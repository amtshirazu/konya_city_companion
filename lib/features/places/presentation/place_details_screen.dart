import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/theme/app_colors.dart';
import '../../map/config/map_config.dart';
import '../../map/services/cached_tile_provider.dart';
import '../domain/place.dart';
import 'providers/media_provider.dart';
import 'providers/saved_places_provider.dart';
import 'widgets/place_media_gallery.dart';

class PlaceDetailsScreen extends ConsumerWidget {
  const PlaceDetailsScreen({super.key, required this.place});

  final Place place;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedPlaceIdsAsync = ref.watch(savedPlacesProvider);
    final isSaved = savedPlaceIdsAsync.value?.contains(place.id) ?? false;
    final mediaList = ref.watch(placeMediaProvider(place.id));

    Future<void> toggleBookmark() async {
      final notifier = ref.read(savedPlacesProvider.notifier);
      final wasSaved = isSaved;
      final success = await notifier.toggleSave(place.id);

      if (!context.mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      if (success) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              wasSaved
                  ? '${place.name} removed from saved places'
                  : '${place.name} saved to your places',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Failed to update bookmark in database.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    void navigateToMapWithDirections() {
      if (place.latitude == null || place.longitude == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verified coordinates are required for directions.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final encodedId = Uri.encodeComponent(place.id);
      context.go('/map?placeId=$encodedId');
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(place.name),
        actions: [
          IconButton(
            tooltip: isSaved ? 'Remove bookmark' : 'Bookmark place',
            icon: Icon(
              isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: isSaved ? AppColors.primary : AppColors.textPrimary,
            ),
            onPressed: toggleBookmark,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Media Gallery / Hero Photo Carousel
            PlaceMediaGallery(mediaList: mediaList, place: place),
            const SizedBox(height: 20),

            // Header row with Name and Save button
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Central Konya',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: toggleBookmark,
                  icon: Icon(
                    isSaved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    size: 18,
                    color: isSaved ? AppColors.primary : AppColors.textPrimary,
                  ),
                  label: Text(
                    isSaved ? 'Saved' : 'Save',
                    style: TextStyle(
                      color: isSaved
                          ? AppColors.primary
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: isSaved ? AppColors.primary : AppColors.border,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Action Button: View on Map
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: navigateToMapWithDirections,
                icon: const Icon(Icons.map_rounded, size: 20),
                label: const Text('Show Place on Map'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Description
            Text(
              place.description,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),

            // Essential Information Section
            const Text(
              'Essential Information',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  // Address row
                  _InfoRow(
                    icon: Icons.map_outlined,
                    label: 'Address',
                    value: place.address ?? 'Address not added yet',
                    isPlaceholder: place.address == null,
                  ),
                  const Divider(height: 24, color: AppColors.border),

                  // Opening Hours row
                  _InfoRow(
                    icon: Icons.access_time_rounded,
                    label: 'Opening Hours',
                    value: place.openingHours ?? 'Hours not verified yet',
                    isPlaceholder: place.openingHours == null,
                  ),

                  if (place.phoneNumber != null) ...[
                    const Divider(height: 24, color: AppColors.border),
                    _InfoRow(
                      icon: Icons.phone_outlined,
                      label: 'Phone',
                      value: place.phoneNumber!,
                    ),
                  ],

                  if (place.websiteUrl != null) ...[
                    const Divider(height: 24, color: AppColors.border),
                    _InfoRow(
                      icon: Icons.language_rounded,
                      label: 'Website',
                      value: place.websiteUrl!,
                    ),
                  ],

                  if (place.priceInfo != null) ...[
                    const Divider(height: 24, color: AppColors.border),
                    _InfoRow(
                      icon: Icons.sell_outlined,
                      label: 'Price / Admission',
                      value: place.priceInfo!,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Location Section - Embedded Mini Map Preview Card
            const Text(
              'Location',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),

            Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: (place.latitude != null && place.longitude != null)
                    ? Stack(
                        children: [
                          FlutterMap(
                            options: MapOptions(
                              initialCenter: LatLng(
                                place.latitude!,
                                place.longitude!,
                              ),
                              initialZoom: 15.0,
                              interactionOptions: const InteractionOptions(
                                flags: InteractiveFlag.none,
                              ),
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: MapConfig.tileUrlTemplate,
                                userAgentPackageName:
                                    MapConfig.userAgentPackageName,
                                tileProvider: CachedTileProvider(),
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: LatLng(
                                      place.latitude!,
                                      place.longitude!,
                                    ),
                                    width: 44,
                                    height: 44,
                                    alignment: Alignment.center,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: place.accentColor,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: place.accentColor.withValues(
                                              alpha: 0.4,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        place.icon,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              RichAttributionWidget(
                                alignment: AttributionAlignment.bottomRight,
                                attributions: [
                                  TextSourceAttribution(
                                    MapConfig.attributionText,
                                  ),
                                ],
                              ),
                            ],
                          ),

                          // Floating Location Info Chip
                          Positioned(
                            left: 12,
                            right: 12,
                            bottom: 12,
                            child: Material(
                              color: Colors.white.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(14),
                              elevation: 2,
                              child: InkWell(
                                onTap: navigateToMapWithDirections,
                                borderRadius: BorderRadius.circular(14),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on_rounded,
                                        color: AppColors.primary,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          place.address ?? 'Central Konya',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: const Text(
                                          'Open Map',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Container(
                        padding: const EdgeInsets.all(20),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.location_off_rounded,
                              size: 32,
                              color: AppColors.textSecondary,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Verified coordinates needed to display map.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // Footer: Media Credits Link
            Center(
              child: TextButton.icon(
                onPressed: () => context.push('/media-credits'),
                icon: const Icon(Icons.copyright_rounded, size: 16),
                label: const Text('Media Credits & Licensing'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isPlaceholder = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isPlaceholder;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: isPlaceholder
                      ? AppColors.textSecondary.withValues(alpha: 0.7)
                      : AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
