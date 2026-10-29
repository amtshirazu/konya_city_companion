import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/category_tile.dart';
import '../../../shared/widgets/place_card.dart';
import '../../places/domain/place.dart';
import '../../places/presentation/providers/places_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _openExplore(
    BuildContext context, {
    String? query,
    String category = 'all',
  }) {
    final queryParameters = <String, String>{};

    if (query != null && query.trim().isNotEmpty) {
      queryParameters['query'] = query.trim();
    }

    if (category != 'all') {
      queryParameters['category'] = category;
    }

    final uri = Uri(
      path: '/explore',
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );

    context.go(uri.toString());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(placesRepositoryProvider);
    final featuredPlaces = repository.getFeaturedPlaces(limit: 8);

    final categories = [
      (
        label: PlaceCategories.historyCulture.label,
        icon: PlaceCategories.historyCulture.icon,
        id: PlaceCategories.historyCulture.id,
      ),
      (
        label: PlaceCategories.mosques.label,
        icon: PlaceCategories.mosques.icon,
        id: PlaceCategories.mosques.id,
      ),
      (
        label: PlaceCategories.parksOutdoors.label,
        icon: PlaceCategories.parksOutdoors.icon,
        id: PlaceCategories.parksOutdoors.id,
      ),
      (
        label: PlaceCategories.foodCafes.label,
        icon: PlaceCategories.foodCafes.icon,
        id: PlaceCategories.foodCafes.id,
      ),
      (
        label: PlaceCategories.essentials.label,
        icon: PlaceCategories.essentials.icon,
        id: PlaceCategories.essentials.id,
      ),
      (
        label: PlaceCategories.transport.label,
        icon: PlaceCategories.transport.icon,
        id: PlaceCategories.transport.id,
      ),
    ];

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 28),
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.explore_rounded,
                    color: Colors.white,
                    size: 27,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'KONYA CITY COMPANION',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Discover Konya',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Settings',
                  onPressed: () => context.go('/settings'),
                  icon: const Icon(
                    Icons.tune_rounded,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 26),

          // Introductory message
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 22),
            child: Text(
              'Your city, made easier.',
              style: TextStyle(
                fontSize: 27,
                height: 1.2,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 22),
            child: Text(
              'Find remarkable places and everyday essentials '
              'around Konya.',
              style: TextStyle(
                fontSize: 14,
                height: 1.55,
                color: AppColors.textSecondary,
              ),
            ),
          ),

          const SizedBox(height: 22),

          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: TextField(
              textInputAction: TextInputAction.search,
              onSubmitted: (value) {
                _openExplore(context, query: value);
              },
              decoration: InputDecoration(
                hintText: 'Search places, services...',
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.primary,
                  size: 25,
                ),
                suffixIcon: IconButton(
                  tooltip: 'Explore all places',
                  onPressed: () => _openExplore(context),
                  icon: const Icon(
                    Icons.tune_rounded,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 30),

          // Categories
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Explore by category',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton(
                  onPressed: () => _openExplore(context),
                  child: const Text('View all'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 110,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 9),
              itemBuilder: (context, index) {
                final category = categories[index];

                return CategoryTile(
                  label: category.label,
                  icon: category.icon,
                  onTap: () {
                    _openExplore(context, category: category.id);
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 27),

          // Featured places
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Discover Konya',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton(
                  onPressed: () => _openExplore(context),
                  child: const Text('See all'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 270,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              scrollDirection: Axis.horizontal,
              itemCount: featuredPlaces.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final place = featuredPlaces[index];

                return PlaceCard(
                  place: place,
                  onTap: () {
                    final encodedId = Uri.encodeComponent(place.id);
                    context.push('/place/$encodedId');
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 28),

          // Nearby places banner
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Material(
              color: AppColors.primaryDark,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: () => context.go('/map?nearby=true'),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(
                          Icons.near_me_rounded,
                          color: Colors.white,
                          size: 27,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Need something nearby?',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Find the closest places and attractions around you.',
                              style: TextStyle(
                                color: Color(0xFFD7E9E0),
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
