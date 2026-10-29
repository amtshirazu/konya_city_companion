enum MediaType { photo, video }

enum VerificationStatus { approved, rejected, needsReview }

class PlaceMedia {
  final String mediaId;
  final String placeId;
  final MediaType mediaType;
  final String title;
  final String sourceName;
  final String sourcePageUrl;
  final String? creatorName;
  final String originalMediaUrl;
  final String licenseName;
  final String licenseUrl;
  final String attributionText;
  final bool commercialUseAllowed;
  final bool modificationAllowed;
  final bool redistributionOrHostingAllowed;
  final bool offlineCachingAllowed;
  final String? apiOrPlatformConditions;
  final String placeMatchEvidence;
  final DateTime verificationDate;
  final VerificationStatus verificationStatus;
  final String? verificationNotes;

  const PlaceMedia({
    required this.mediaId,
    required this.placeId,
    required this.mediaType,
    required this.title,
    required this.sourceName,
    required this.sourcePageUrl,
    this.creatorName,
    required this.originalMediaUrl,
    required this.licenseName,
    required this.licenseUrl,
    required this.attributionText,
    required this.commercialUseAllowed,
    required this.modificationAllowed,
    required this.redistributionOrHostingAllowed,
    required this.offlineCachingAllowed,
    this.apiOrPlatformConditions,
    required this.placeMatchEvidence,
    required this.verificationDate,
    required this.verificationStatus,
    this.verificationNotes,
  });

  bool get isApproved => verificationStatus == VerificationStatus.approved;
  bool get isPhoto => mediaType == MediaType.photo;
  bool get isVideo => mediaType == MediaType.video;
}
