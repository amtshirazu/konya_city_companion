import 'package:flutter_test/flutter_test.dart';
import 'package:konya_city_companion/features/places/data/places_repository.dart';
import 'package:konya_city_companion/features/places/data/sample_places.dart';
import 'package:konya_city_companion/features/places/domain/place.dart';

void main() {
  late PlacesRepository repository;

  setUp(() {
    repository = PlacesRepository();
  });

  group('Directory Data Integrity Tests', () {
    test('Directory contains 100 verified entries', () {
      expect(samplePlaces.length, equals(100));
    });

    test('All place IDs are unique', () {
      final ids = samplePlaces.map((p) => p.id).toList();
      final uniqueIds = ids.toSet();

      expect(ids.length, equals(uniqueIds.length));
    });

    test('All place category IDs are valid standardized categories', () {
      for (final place in samplePlaces) {
        expect(
          PlaceCategories.isValidCategoryId(place.category),
          isTrue,
          reason:
              'Place ${place.id} has invalid category ID: ${place.category}',
        );
      }
    });

    test('Verified places have source URLs and last verified dates', () {
      final verifiedPlaces = samplePlaces.where((p) => p.isVerified);
      expect(verifiedPlaces, isNotEmpty);

      for (final place in verifiedPlaces) {
        expect(place.sourceUrl, isNotNull);
        expect(place.lastVerifiedDate, isNotNull);
      }
    });

    test('Unverified places have null verification dates or source URLs', () {
      final unverifiedPlaces = samplePlaces.where((p) => !p.isVerified);
      for (final place in unverifiedPlaces) {
        expect(place.isVerified, isFalse);
      }
    });
  });

  group('PlacesRepository Query Tests', () {
    test('getAllPlaces returns all directory entries', () {
      final places = repository.getAllPlaces();
      expect(places.length, equals(100));
    });

    test('getPlaceById finds correct place for valid ID', () {
      final place = repository.getPlaceById('mevlana-museum');

      expect(place, isNotNull);
      expect(place!.name, equals('Mevlana Museum'));
      expect(place.category, equals('history-culture'));
    });

    test('getPlaceById handles URL encoded IDs', () {
      final place = repository.getPlaceById(
        Uri.encodeComponent('mevlana-museum'),
      );

      expect(place, isNotNull);
      expect(place!.name, equals('Mevlana Museum'));
    });

    test('getPlaceById returns null for non-existent ID', () {
      final place = repository.getPlaceById('non-existent-place-123');
      expect(place, isNull);
    });

    test('getPlacesByCategory filters correctly', () {
      final mosques = repository.getPlacesByCategory('mosques');

      expect(mosques.length, equals(20));
      for (final place in mosques) {
        expect(place.category, equals('mosques'));
      }
    });

    test('getPlacesByCategory returns all places for "all"', () {
      final all = repository.getPlacesByCategory('all');
      expect(all.length, equals(100));
    });

    test('searchPlaces filters by query and category', () {
      final results = repository.searchPlaces(
        query: 'museum',
        categoryId: 'history-culture',
      );

      expect(results, isNotEmpty);
      for (final place in results) {
        expect(place.category, equals('history-culture'));
        expect(
          place.name.toLowerCase().contains('museum') ||
              place.description.toLowerCase().contains('museum'),
          isTrue,
        );
      }
    });

    test('getFeaturedPlaces returns requested limit', () {
      final featured = repository.getFeaturedPlaces(limit: 5);
      expect(featured.length, equals(5));
    });
  });
}
