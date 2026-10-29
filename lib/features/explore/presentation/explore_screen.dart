import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/cached_image_widget.dart';
import '../../places/domain/place.dart';
import '../../places/presentation/providers/media_provider.dart';
import '../../places/presentation/providers/places_provider.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({
    super.key,
    this.initialQuery = '',
    this.initialCategory = 'all',
  });

  final String initialQuery;
  final String initialCategory;

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  late final TextEditingController _searchController;
  late String _selectedCategory;

  final List<Map<String, String>> _categories = const [
    {'id': 'all', 'label': 'All places'},
    {'id': 'history-culture', 'label': 'History & Culture'},
    {'id': 'mosques', 'label': 'Mosques'},
    {'id': 'parks-outdoors', 'label': 'Parks & Outdoors'},
    {'id': 'nature', 'label': 'Nature'},
    {'id': 'food-cafes', 'label': 'Food & Cafes'},
    {'id': 'essentials', 'label': 'Essentials'},
    {'id': 'transport', 'label': 'Transport'},
  ];

  @override
  void initState() {
    super.initState();

    _searchController = TextEditingController(text: widget.initialQuery);

    _selectedCategory = _isValidCategory(widget.initialCategory)
        ? widget.initialCategory
        : 'all';
  }

  @override
  void didUpdateWidget(covariant ExploreScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.initialQuery != widget.initialQuery) {
      _searchController.text = widget.initialQuery;
    }

    if (oldWidget.initialCategory != widget.initialCategory) {
      _selectedCategory = _isValidCategory(widget.initialCategory)
          ? widget.initialCategory
          : 'all';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isValidCategory(String category) {
    return _categories.any((item) => item['id'] == category);
  }

  String get _selectedCategoryLabel {
    return _categories.firstWhere(
      (item) => item['id'] == _selectedCategory,
    )['label']!;
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(placesRepositoryProvider);
    final places = repository.searchPlaces(
      query: _searchController.text,
      categoryId: _selectedCategory,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'EXPLORE KONYA',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Find your next place.',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.7,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Discover places to visit, explore and enjoy.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Search field
                    TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search places, categories...',
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppColors.primary,
                        ),
                        suffixIcon: _searchController.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      'Browse categories',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Horizontally scrollable category filters
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _categories.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final category = _categories[index];
                          final id = category['id']!;
                          final label = category['label']!;
                          final selected = _selectedCategory == id;

                          return ChoiceChip(
                            label: Text(label),
                            selected: selected,
                            showCheckmark: false,
                            onSelected: (_) {
                              setState(() {
                                _selectedCategory = id;
                              });
                            },
                            backgroundColor: Colors.white,
                            selectedColor: AppColors.primaryLight,
                            side: BorderSide(
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.border,
                            ),
                            labelStyle: TextStyle(
                              color: selected
                                  ? AppColors.primaryDark
                                  : AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Results heading
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _selectedCategory == 'all'
                                ? 'Places to discover'
                                : _selectedCategoryLabel,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          '${places.length} ${places.length == 1 ? 'place' : 'places'}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),

            // Results list or empty state
            if (places.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 20, 28, 48),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Icon(
                          Icons.travel_explore_rounded,
                          size: 36,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        _searchController.text.trim().isNotEmpty
                            ? 'No matching places'
                            : 'More places coming soon',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _searchController.text.trim().isNotEmpty
                            ? 'Try another search or choose a different category.'
                            : 'We have not added sample places to this category yet. More places will appear as the directory grows.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 18),
                      OutlinedButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _selectedCategory = 'all';
                          });
                        },
                        child: const Text('Show all places'),
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
                    final place = places[index];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ExplorePlaceCard(
                        place: place,
                        onTap: () {
                          final encodedId = Uri.encodeComponent(place.id);
                          context.push('/place/$encodedId');
                        },
                      ),
                    );
                  }, childCount: places.length),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ExplorePlaceCard extends ConsumerWidget {
  const _ExplorePlaceCard({required this.place, required this.onTap});

  final Place place;
  final VoidCallback onTap;

  Widget _buildFallbackIllustration() {
    return Container(
      width: 76,
      height: 84,
      decoration: BoxDecoration(
        color: place.accentColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(place.icon, size: 34, color: place.accentColor),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 76,
                  height: 84,
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        place.categoryLabel,
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      place.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      place.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
