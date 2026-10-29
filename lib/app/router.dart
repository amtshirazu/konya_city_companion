import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'theme/app_colors.dart';
import '../features/explore/presentation/explore_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/map/presentation/map_screen.dart';
import '../features/places/data/places_repository.dart';
import '../features/places/presentation/media_credits_screen.dart';
import '../features/places/presentation/place_details_screen.dart';
import '../features/places/presentation/saved_places_screen.dart';
import '../shared/widgets/app_shell.dart';
import '../shared/widgets/placeholder_screen.dart';

class AppRouter {
  AppRouter._();

  static final PlacesRepository _repository = PlacesRepository();

  static final GoRouter router = GoRouter(
    initialLocation: '/home',
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          return AppShell(location: state.uri.path, child: child);
        },
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/explore',
            builder: (context, state) {
              return ExploreScreen(
                initialQuery: state.uri.queryParameters['query'] ?? '',
                initialCategory: state.uri.queryParameters['category'] ?? 'all',
              );
            },
          ),
          GoRoute(path: '/map', builder: (context, state) => const MapScreen()),
          GoRoute(
            path: '/saved',
            builder: (context, state) => const SavedPlacesScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const PlaceholderScreen(
              title: 'Settings',
              subtitle: 'Language and app preferences.',
              icon: 'settings',
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/place/:id',
        builder: (context, state) {
          final rawId = state.pathParameters['id'] ?? '';
          final place = _repository.getPlaceById(rawId);

          if (place == null) {
            return Scaffold(
              backgroundColor: AppColors.background,
              appBar: AppBar(title: const Text('Place not found')),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Icon(
                          Icons.search_off_rounded,
                          size: 36,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Place not found',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No destination matching "$rawId" could be found in our directory.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => context.go('/explore'),
                        icon: const Icon(Icons.explore_outlined, size: 18),
                        label: const Text('Back to Explore'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
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
              ),
            );
          }

          return PlaceDetailsScreen(place: place);
        },
      ),
      GoRoute(
        path: '/media-credits',
        builder: (context, state) => const MediaCreditsScreen(),
      ),
    ],
  );
}
