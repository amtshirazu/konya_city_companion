import '../domain/place_media.dart';
import 'sample_media.dart';

class MediaRepository {
  final List<PlaceMedia> _mediaCatalog;

  MediaRepository({List<PlaceMedia>? mediaCatalog})
    : _mediaCatalog = List.unmodifiable(mediaCatalog ?? sampleMediaCatalog);

  /// Returns only approved media associated with a given place ID.
  List<PlaceMedia> getApprovedMediaForPlace(String placeId) {
    final decodedId = Uri.decodeComponent(placeId);
    return _mediaCatalog
        .where((m) => m.placeId == decodedId && m.isApproved)
        .toList();
  }

  /// Returns the primary approved photo/video for a given place ID, if available.
  PlaceMedia? getPrimaryMediaForPlace(String placeId) {
    final approvedList = getApprovedMediaForPlace(placeId);
    return approvedList.isNotEmpty ? approvedList.first : null;
  }

  /// Returns all approved media entries across the directory.
  List<PlaceMedia> getAllApprovedMedia() {
    return _mediaCatalog.where((m) => m.isApproved).toList();
  }

  /// Returns the complete media catalog including rejected and needs_review items for audit purposes.
  List<PlaceMedia> getAllMediaForAudit() {
    return _mediaCatalog;
  }
}
