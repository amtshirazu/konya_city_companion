import '../domain/place.dart';
import 'sample_places.dart';

class PlacesRepository {
  final List<Place> _places;

  PlacesRepository({List<Place>? places})
    : _places = List.unmodifiable(places ?? samplePlaces);

  /// Returns all places in the directory.
  List<Place> getAllPlaces() {
    return _places;
  }

  /// Finds a single place by its stable ID.
  Place? getPlaceById(String id) {
    final decodedId = Uri.decodeComponent(id);
    for (final place in _places) {
      if (place.id == decodedId) return place;
    }
    return null;
  }

  /// Filters places by category ID (e.g., 'history-culture', 'mosques', etc.).
  List<Place> getPlacesByCategory(String categoryId) {
    if (categoryId == 'all') return _places;
    return _places.where((place) => place.category == categoryId).toList();
  }

  /// Searches and filters places based on search query and category ID.
  List<Place> searchPlaces({String query = '', String categoryId = 'all'}) {
    final cleanQuery = query.trim().toLowerCase();

    return _places.where((place) {
      final matchesQuery =
          cleanQuery.isEmpty ||
          place.name.toLowerCase().contains(cleanQuery) ||
          place.categoryLabel.toLowerCase().contains(cleanQuery) ||
          place.description.toLowerCase().contains(cleanQuery) ||
          (place.address?.toLowerCase().contains(cleanQuery) ?? false);

      final matchesCategory =
          categoryId == 'all' || place.category == categoryId;

      return matchesQuery && matchesCategory;
    }).toList();
  }

  /// Returns featured places for the Home screen.
  List<Place> getFeaturedPlaces({int limit = 6}) {
    return _places.take(limit).toList();
  }
}
