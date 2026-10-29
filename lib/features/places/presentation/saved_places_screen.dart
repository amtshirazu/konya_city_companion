import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/cached_image_widget.dart';
import '../domain/place.dart';
import 'providers/media_provider.dart';
import 'providers/places_provider.dart';
import 'providers/saved_places_provider.dart';

class SavedPlacesScreen extends ConsumerWidget {
  const SavedPlacesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedPlacesAsync = ref.watch(savedPlacesProvider);
    final repository = ref.watch(placesRepositoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: savedPlacesAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (error, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(28.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 48,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Failed to load saved places',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.refresh(savedPlacesProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
          data: (savedIds) {
            final savedPlaces = <Place>[];
            for (final id in savedIds) {
              final place = repository.getPlaceById(id);
              if (place != null) {
                savedPlaces.add(place);
              }
            }

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SAVED PLACES',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.6,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Saved places',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 27,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.7,
                              ),
                            ),
                            if (savedPlaces.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  '${savedPlaces.length}',
                                  style: const TextStyle(
                                    color: AppColors.primaryDark,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          savedPlaces.isNotEmpty
                              ? 'Quickly access your bookmarked destinations around Konya.'
                              : 'Save places you want to visit later.',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (savedPlaces.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 20, 28, 48),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(26),
                            ),
                            child: const Icon(
                              Icons.bookmark_border_rounded,
                              size: 40,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'No saved places yet',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Explore Konya and tap the bookmark icon to save your favorite destinations for easy access.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () => context.go('/explore'),
                            icon: const Icon(Icons.explore_outlined, size: 18),
                            label: const Text('Explore places'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final place = savedPlaces[index];

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _SavedPlaceCard(
                            place: place,
                            onTap: () {
                              final encodedId = Uri.encodeComponent(place.id);
                              context.push('/place/$encodedId');
                            },
                            onRemove: () async {
                              final success = await ref
                                  .read(savedPlacesProvider.notifier)
                                  .removePlace(place.id);

                              if (!context.mounted) return;
                              final messenger = ScaffoldMessenger.of(context);
                              messenger.clearSnackBars();
                              if (success) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${place.name} removed from saved places',
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              } else {
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Failed to remove saved place.',
                                    ),
                                    backgroundColor: Colors.red,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                          ),
                        );
                      }, childCount: savedPlaces.length),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SavedPlaceCard extends ConsumerWidget {
  const _SavedPlaceCard({
    required this.place,
    required this.onTap,
    required this.onRemove,
  });

  final Place place;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  Widget _buildFallbackIllustration() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: place.accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(place.icon, size: 30, color: place.accentColor),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primaryMedia = ref.watch(primaryMediaProvider(place.id));

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: primaryMedia != null
                      ? CachedImageWidget(
                          url: primaryMedia.originalMediaUrl,
                          fit: BoxFit.cover,
                          fallbackWidget: _buildFallbackIllustration(),
                        )
                      : _buildFallbackIllustration(),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      place.categoryLabel,
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      place.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove from saved',
                icon: const Icon(
                  Icons.bookmark_remove_rounded,
                  color: AppColors.primary,
                ),
                onPressed: onRemove,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
