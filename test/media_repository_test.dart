import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:konya_city_companion/features/places/data/media_repository.dart';
import 'package:konya_city_companion/features/places/data/places_repository.dart';
import 'package:konya_city_companion/features/places/domain/place_media.dart';
import 'package:konya_city_companion/features/places/presentation/media_credits_screen.dart';
import 'package:konya_city_companion/features/places/presentation/providers/media_provider.dart';
import 'package:konya_city_companion/features/places/presentation/widgets/place_media_gallery.dart';

void main() {
  late MediaRepository repository;

  setUp(() {
    repository = MediaRepository();
  });

  group('MediaRepository Domain & Curation Tests', () {
    test('Media-to-place association retrieves approved media for place', () {
      final mediaList = repository.getApprovedMediaForPlace('mevlana-museum');

      expect(mediaList, isNotEmpty);
      expect(mediaList.length, greaterThanOrEqualTo(1));
      expect(mediaList.every((m) => m.placeId == 'mevlana-museum'), isTrue);
      expect(mediaList.every((m) => m.isApproved), isTrue);
    });

    test('Primary media returns first approved asset', () {
      final primary = repository.getPrimaryMediaForPlace('mevlana-museum');

      expect(primary, isNotNull);
      expect(primary!.originalMediaUrl, contains('wikimedia.org'));
      expect(primary.licenseName, equals('CC BY-SA 4.0'));
    });

    test(
      'Excludes rejected and review-pending media from approved queries',
      () {
        final approvedMedia = repository.getAllApprovedMedia();
        final allAuditMedia = repository.getAllMediaForAudit();

        expect(allAuditMedia.length, greaterThan(approvedMedia.length));
        expect(
          approvedMedia.any(
            (m) => m.mediaId == 'audit-rejected-generic-mosque',
          ),
          isFalse,
        );
        expect(
          approvedMedia.any(
            (m) => m.mediaId == 'audit-needs-review-unverified-blog-photo',
          ),
          isFalse,
        );
      },
    );

    test('Missing media returns empty list and null primary media', () {
      final mediaList = repository.getApprovedMediaForPlace(
        'non-existent-place-123',
      );
      final primary = repository.getPrimaryMediaForPlace(
        'non-existent-place-123',
      );

      expect(mediaList, isEmpty);
      expect(primary, isNull);
    });

    test('VerificationStatus filtering behaves as expected', () {
      final approved = repository.getPrimaryMediaForPlace('mevlana-museum')!;
      expect(approved.isApproved, isTrue);

      final auditList = repository.getAllMediaForAudit();
      final rejected = auditList.firstWhere(
        (m) => m.verificationStatus == VerificationStatus.rejected,
      );
      expect(rejected.isApproved, isFalse);
    });
  });

  group('Place Media Widgets & Screen Tests', () {
    testWidgets(
      'PlaceMediaGallery renders neutral fallback illustration when media list is empty',
      (WidgetTester tester) async {
        final placesRepo = PlacesRepository();
        final place = placesRepo.getPlaceById('mevlana-museum')!;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PlaceMediaGallery(mediaList: const [], place: place),
            ),
          ),
        );

        expect(find.text('History & Culture'), findsOneWidget);
        expect(find.text('Verified'), findsOneWidget);
      },
    );

    testWidgets(
      'PlaceMediaGallery renders page indicator when multiple photos exist',
      (WidgetTester tester) async {
        final placesRepo = PlacesRepository();
        final place = placesRepo.getPlaceById('mevlana-museum')!;
        final mediaList = repository.getApprovedMediaForPlace('mevlana-museum');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PlaceMediaGallery(mediaList: mediaList, place: place),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        if (mediaList.length > 1) {
          expect(find.text('1 / ${mediaList.length}'), findsOneWidget);
        }
        expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
      },
    );

    testWidgets(
      'MediaCreditsScreen renders all approved attributions and licenses',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [mediaRepositoryProvider.overrideWithValue(repository)],
            child: const MaterialApp(home: MediaCreditsScreen()),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Media Credits & Acknowledgements'), findsOneWidget);
        expect(find.text('Attribution & Open Licenses'), findsOneWidget);
        expect(find.textContaining('Wikimedia Commons'), findsWidgets);
        expect(find.textContaining('CC BY-SA 4.0'), findsWidgets);
        expect(find.text('View License'), findsWidgets);
        expect(find.text('Source Page'), findsWidgets);
      },
    );
  });
}
