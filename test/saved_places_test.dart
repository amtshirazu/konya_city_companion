import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:konya_city_companion/features/places/data/places_repository.dart';
import 'package:konya_city_companion/features/places/data/saved_places_database.dart';
import 'package:konya_city_companion/features/places/domain/place.dart';
import 'package:konya_city_companion/features/places/presentation/providers/saved_places_provider.dart';
import 'package:konya_city_companion/features/places/presentation/saved_places_screen.dart';

/// In-memory fake SQLite database simulating the saved_places table,
/// primary key constraints, creation timestamps, and error handling.
class FakeSavedPlacesDatabase implements SavedPlacesDatabase {
  final Map<String, String> _table = {};
  bool isClosed = false;
  bool shouldThrowError = false;

  @override
  String get dbName => 'fake_konya_companion.db';

  @override
  get databaseFactoryOverride => null;

  @override
  get database async {
    if (isClosed) {
      throw Exception('Database is closed');
    }
    return null as dynamic;
  }

  @override
  Future<List<String>> getSavedPlaceIds() async {
    if (shouldThrowError) {
      throw Exception('Database read error simulated');
    }
    if (isClosed) {
      throw Exception('Database is closed');
    }
    // Return IDs sorted by creation time descending
    final entries = _table.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.map((e) => e.key).toList();
  }

  @override
  Future<bool> isSaved(String placeId) async {
    if (shouldThrowError) {
      throw Exception('Database query error simulated');
    }
    if (isClosed) {
      throw Exception('Database is closed');
    }
    return _table.containsKey(placeId);
  }

  @override
  Future<void> savePlace(String placeId) async {
    if (shouldThrowError) {
      throw Exception('Database write error simulated');
    }
    if (isClosed) {
      throw Exception('Database is closed');
    }
    // Simulate PRIMARY KEY REPLACE behavior
    _table[placeId] = DateTime.now().toIso8601String();
  }

  @override
  Future<void> removePlace(String placeId) async {
    if (shouldThrowError) {
      throw Exception('Database delete error simulated');
    }
    if (isClosed) {
      throw Exception('Database is closed');
    }
    _table.remove(placeId);
  }

  @override
  Future<void> clearAll() async {
    if (isClosed) {
      throw Exception('Database is closed');
    }
    _table.clear();
  }

  @override
  Future<void> close() async {
    isClosed = true;
  }
}

void main() {
  group('SavedPlacesDatabase SQLite Domain Tests', () {
    test(
      'Creating the saved_places table schema and verifying configuration',
      () {
        expect(SavedPlacesDatabase.tableName, equals('saved_places'));
        expect(SavedPlacesDatabase.columnPlaceId, equals('place_id'));
        expect(SavedPlacesDatabase.columnCreatedAt, equals('created_at'));
        expect(SavedPlacesDatabase.databaseVersion, equals(1));
      },
    );

    test('Loading an empty database returns empty list', () async {
      final db = FakeSavedPlacesDatabase();
      final savedIds = await db.getSavedPlaceIds();

      expect(savedIds, isEmpty);
      await db.close();
    });

    test('Adding a bookmark persists ID in database', () async {
      final db = FakeSavedPlacesDatabase();
      await db.savePlace('mevlana-museum');

      final savedIds = await db.getSavedPlaceIds();
      final isSaved = await db.isSaved('mevlana-museum');

      expect(savedIds, contains('mevlana-museum'));
      expect(isSaved, isTrue);
      await db.close();
    });

    test('Removing a bookmark deletes ID from database', () async {
      final db = FakeSavedPlacesDatabase();
      await db.savePlace('mevlana-museum');

      await db.removePlace('mevlana-museum');
      final savedIds = await db.getSavedPlaceIds();
      final isSaved = await db.isSaved('mevlana-museum');

      expect(savedIds, isEmpty);
      expect(isSaved, isFalse);
      await db.close();
    });

    test('Preventing duplicate IDs using primary key constraint', () async {
      final db = FakeSavedPlacesDatabase();
      await db.savePlace('mevlana-museum');
      await db.savePlace('mevlana-museum');
      await db.savePlace('mevlana-museum');

      final savedIds = await db.getSavedPlaceIds();

      expect(savedIds.length, equals(1));
      expect(savedIds.first, equals('mevlana-museum'));
      await db.close();
    });

    test(
      'Persisting bookmarks after recreating the repository/provider instance',
      () async {
        final sharedDb = FakeSavedPlacesDatabase();
        await sharedDb.savePlace('karatay-madrasa');

        // Create new ProviderContainer with same DB backing instance
        final container = ProviderContainer(
          overrides: [savedPlacesDatabaseProvider.overrideWithValue(sharedDb)],
        );
        addTearDown(container.dispose);

        final savedIds = await container.read(savedPlacesProvider.future);
        expect(savedIds, contains('karatay-madrasa'));
      },
    );
  });

  group('Riverpod & Repository Integration Tests', () {
    test('Resolving saved IDs into valid place objects', () async {
      final db = FakeSavedPlacesDatabase();
      await db.savePlace('mevlana-museum');
      await db.savePlace('karatay-madrasa');

      final container = ProviderContainer(
        overrides: [savedPlacesDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      final savedIds = await container.read(savedPlacesProvider.future);
      final repository = PlacesRepository();

      final savedPlaces = <Place>[];
      for (final id in savedIds) {
        final place = repository.getPlaceById(id);
        if (place != null) {
          savedPlaces.add(place);
        }
      }

      expect(savedPlaces.length, equals(2));
      expect(savedPlaces.any((p) => p.name == 'Mevlana Museum'), isTrue);
      expect(savedPlaces.any((p) => p.name == 'Karatay Museum'), isTrue);
    });

    test('Handling unknown or deleted place IDs safely', () async {
      final db = FakeSavedPlacesDatabase();
      await db.savePlace('unknown-obsolete-place-id');
      await db.savePlace('mevlana-museum');

      final container = ProviderContainer(
        overrides: [savedPlacesDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      final savedIds = await container.read(savedPlacesProvider.future);
      final repository = PlacesRepository();

      final validPlaces = <Place>[];
      for (final id in savedIds) {
        final place = repository.getPlaceById(id);
        if (place != null) {
          validPlaces.add(place);
        }
      }

      expect(validPlaces.length, equals(1));
      expect(validPlaces.first.id, equals('mevlana-museum'));
    });

    test('Loading state behavior and state updates', () async {
      final db = FakeSavedPlacesDatabase();
      final container = ProviderContainer(
        overrides: [savedPlacesDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      expect(
        container.read(savedPlacesProvider),
        isA<AsyncLoading<Set<String>>>(),
      );

      final initialIds = await container.read(savedPlacesProvider.future);
      expect(initialIds, isEmpty);

      final notifier = container.read(savedPlacesProvider.notifier);
      await notifier.savePlace('mevlana-museum');

      expect(
        container.read(savedPlacesProvider).value,
        contains('mevlana-museum'),
      );
    });

    test(
      'Database failures and rapid consecutive operations handling',
      () async {
        final db = FakeSavedPlacesDatabase();
        final container = ProviderContainer(
          overrides: [savedPlacesDatabaseProvider.overrideWithValue(db)],
        );
        addTearDown(container.dispose);

        await container.read(savedPlacesProvider.future);
        final notifier = container.read(savedPlacesProvider.notifier);

        // Rapid consecutive operations
        final futures = [
          notifier.savePlace('place-1'),
          notifier.savePlace('place-2'),
          notifier.savePlace('place-3'),
          notifier.removePlace('place-1'),
        ];

        final results = await Future.wait(futures);
        expect(results.every((res) => res == true), isTrue);

        final finalState = container.read(savedPlacesProvider).value ?? {};
        expect(finalState, contains('place-2'));
        expect(finalState, contains('place-3'));
        expect(finalState, isNot(contains('place-1')));

        // Database failure rollback test
        db.shouldThrowError = true;
        final saveSuccess = await notifier.savePlace('should-fail-id');
        expect(saveSuccess, isFalse);
        expect(
          container.read(savedPlacesProvider).value,
          isNot(contains('should-fail-id')),
        );
      },
    );
  });

  group('Saved Places Screen Widget Tests', () {
    testWidgets('Saved screen shows empty state when no places are saved', (
      WidgetTester tester,
    ) async {
      final db = FakeSavedPlacesDatabase();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [savedPlacesDatabaseProvider.overrideWithValue(db)],
          child: const MaterialApp(home: SavedPlacesScreen()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('No saved places yet'), findsOneWidget);
      expect(find.text('Explore places'), findsOneWidget);
    });

    testWidgets('Saved places appear when loaded from database', (
      WidgetTester tester,
    ) async {
      final db = FakeSavedPlacesDatabase();
      await db.savePlace('mevlana-museum');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [savedPlacesDatabaseProvider.overrideWithValue(db)],
          child: const MaterialApp(home: SavedPlacesScreen()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Mevlana Museum'), findsOneWidget);
      expect(find.text('No saved places yet'), findsNothing);
    });
  });
}
