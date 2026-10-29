import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/media_repository.dart';
import '../../domain/place_media.dart';

final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  return MediaRepository();
});

final placeMediaProvider = Provider.family<List<PlaceMedia>, String>((
  ref,
  placeId,
) {
  final repository = ref.watch(mediaRepositoryProvider);
  return repository.getApprovedMediaForPlace(placeId);
});

final primaryMediaProvider = Provider.family<PlaceMedia?, String>((
  ref,
  placeId,
) {
  final repository = ref.watch(mediaRepositoryProvider);
  return repository.getPrimaryMediaForPlace(placeId);
});
