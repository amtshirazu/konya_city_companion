import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/saved_places_database.dart';

final savedPlacesDatabaseProvider = Provider<SavedPlacesDatabase>((ref) {
  final db = SavedPlacesDatabase();
  ref.onDispose(() {
    db.close();
  });
  return db;
});

class SavedPlacesNotifier extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    final db = ref.watch(savedPlacesDatabaseProvider);
    try {
      final ids = await db.getSavedPlaceIds();
      return Set<String>.from(ids);
    } catch (e) {
      return const {};
    }
  }

  bool isSaved(String placeId) {
    return state.value?.contains(placeId) ?? false;
  }

  Future<bool> toggleSave(String placeId) async {
    final current = state.value ?? {};
    if (current.contains(placeId)) {
      return await removePlace(placeId);
    } else {
      return await savePlace(placeId);
    }
  }

  Future<bool> savePlace(String placeId) async {
    final previousState = state;
    final current = Set<String>.from(previousState.value ?? {});
    if (current.contains(placeId)) return true;

    current.add(placeId);
    state = AsyncValue.data(Set.unmodifiable(current));

    try {
      final db = ref.read(savedPlacesDatabaseProvider);
      await db.savePlace(placeId);
      return true;
    } catch (e) {
      state = previousState;
      return false;
    }
  }

  Future<bool> removePlace(String placeId) async {
    final previousState = state;
    final current = Set<String>.from(previousState.value ?? {});
    if (!current.contains(placeId)) return true;

    current.remove(placeId);
    state = AsyncValue.data(Set.unmodifiable(current));

    try {
      final db = ref.read(savedPlacesDatabaseProvider);
      await db.removePlace(placeId);
      return true;
    } catch (e) {
      state = previousState;
      return false;
    }
  }
}

final savedPlacesProvider =
    AsyncNotifierProvider<SavedPlacesNotifier, Set<String>>(
      SavedPlacesNotifier.new,
    );
