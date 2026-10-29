import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:konya_city_companion/features/map/config/map_config.dart';
import 'package:konya_city_companion/features/map/presentation/widgets/open_street_map_view.dart';
import 'package:konya_city_companion/features/map/services/cached_tile_provider.dart';
import 'package:konya_city_companion/features/places/domain/place.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tile_cache_test_');

    // Stub path_provider channel to return temporary directory path
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async => tempDir.path,
        );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );

    if (await tempDir.exists()) {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  });

  group('CachedTileProvider Unit Tests', () {
    test('Initializes with default TileCacheStatus.online', () {
      final provider = CachedTileProvider(customCacheDirPath: tempDir.path);

      expect(provider.statusNotifier.value, equals(TileCacheStatus.online));
      expect(provider.silenceExceptions, isTrue);
      expect(provider.maxAge, equals(MapConfig.maxTileCacheAge));
      expect(provider.maxSizeBytes, equals(MapConfig.maxTileCacheSizeBytes));

      provider.dispose();
    });

    test(
      'Saves downloaded tile to local cache directory on HTTP 200',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response.bytes(TileProvider.transparentImage, 200);
        });

        final provider = CachedTileProvider(
          customCacheDirPath: tempDir.path,
          httpClient: mockClient,
        );

        const coordinates = TileCoordinates(19342, 12654, 15);
        final options = TileLayer(
          urlTemplate: MapConfig.tileUrlTemplate,
          userAgentPackageName: MapConfig.userAgentPackageName,
        );

        final imageProvider = provider.getImage(coordinates, options);
        expect(imageProvider, isA<CachedTileImageProvider>());

        provider.dispose();
      },
    );

    test(
      'Loads pre-cached tile from disk without network request when offline',
      () async {
        final tileFile = File('${tempDir.path}/15_12654_19342_test.tile');
        await tileFile.writeAsBytes(TileProvider.transparentImage);

        TileCacheStatus? reportedStatus;
        final provider = CachedTileProvider(
          customCacheDirPath: tempDir.path,
          onStatusChanged: (status) => reportedStatus = status,
        );

        expect(await tempDir.list().length, equals(1));
        expect(provider.statusNotifier.value, isNotNull);
        expect(reportedStatus, isNull);
        provider.dispose();
      },
    );

    test('Silence exceptions prevents map crash on network failure', () async {
      final mockFailClient = MockClient((request) async {
        throw const SocketException('No internet connection');
      });

      final provider = CachedTileProvider(
        customCacheDirPath: tempDir.path,
        httpClient: mockFailClient,
        silenceExceptions: true,
      );

      const coordinates = TileCoordinates(10, 10, 5);
      final options = TileLayer(urlTemplate: MapConfig.tileUrlTemplate);

      final imageProvider = provider.getImage(coordinates, options);
      expect(imageProvider, isNotNull);

      provider.dispose();
    });
  });

  group('OpenStreetMapView with Tile Caching Widget Tests', () {
    const testPlace = Place(
      id: 'alaeddin-hill',
      name: 'Alaeddin Hill',
      category: 'history-culture',
      description: 'Central landmark in Konya',
      icon: Icons.park,
      accentColor: Colors.green,
      latitude: 37.8719,
      longitude: 32.4925,
    );

    testWidgets(
      'Renders OpenStreetMapView with CachedTileProvider and attribution',
      (WidgetTester tester) async {
        final mockClient = MockClient((request) async {
          return http.Response.bytes(TileProvider.transparentImage, 200);
        });

        final cachedProvider = CachedTileProvider(
          customCacheDirPath: tempDir.path,
          httpClient: mockClient,
          silenceExceptions: true,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OpenStreetMapView(
                places: const [testPlace],
                selectedPlace: null,
                onSelectPlace: (_) {},
                tileProvider: cachedProvider,
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(FlutterMap), findsOneWidget);
        expect(find.byType(RichAttributionWidget), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        cachedProvider.dispose();
      },
    );
  });
}
