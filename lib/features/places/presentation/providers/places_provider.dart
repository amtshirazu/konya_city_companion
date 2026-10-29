import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/places_repository.dart';
import '../../domain/place.dart';

final placesRepositoryProvider = Provider<PlacesRepository>((ref) {
  return PlacesRepository();
});

final allPlacesProvider = Provider<List<Place>>((ref) {
  final repository = ref.watch(placesRepositoryProvider);
  return repository.getAllPlaces();
});

final placeByIdProvider = Provider.family<Place?, String>((ref, id) {
  final repository = ref.watch(placesRepositoryProvider);
  return repository.getPlaceById(id);
});
