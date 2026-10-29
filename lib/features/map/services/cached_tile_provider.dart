import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../config/map_config.dart';

/// Indicates the current map tile connectivity and caching state.
enum TileCacheStatus {
  /// Map tiles loaded freshly from online tile server
  online,

  /// Map tiles loaded from local persistent disk cache
  cached,

  /// Device is offline and tile was not previously cached
  offlineUncached,
}

/// A compliant tile provider for `flutter_map` that persists viewed tiles to disk,
/// respects HTTP cache headers and provider terms, and provides offline resilience.
class CachedTileProvider extends TileProvider {
  CachedTileProvider({
    super.headers,
    this.customCacheDirPath,
    this.maxAge = MapConfig.maxTileCacheAge,
    this.maxSizeBytes = MapConfig.maxTileCacheSizeBytes,
    this.silenceExceptions = true,
    this.httpClient,
    this.onStatusChanged,
  });

  /// Optional override for the tile cache directory (useful for testing)
  final String? customCacheDirPath;

  /// Maximum age before tile is considered stale and re-fetched if online
  final Duration maxAge;

  /// Maximum disk cache size limit in bytes (default 50 MB)
  final int maxSizeBytes;

  /// Whether network or tile load exceptions should be silenced (returning transparent tile)
  final bool silenceExceptions;

  /// Optional custom HTTP client (for mocking or custom transport)
  final http.Client? httpClient;

  /// Callback to notify UI of tile status transitions
  final ValueChanged<TileCacheStatus>? onStatusChanged;

  /// Holds the resolved base directory for storing tile files
  Directory? _resolvedCacheDir;
  bool _isInitializing = false;
  bool _isDisposed = false;

  /// Exposes the current overall cache status
  final ValueNotifier<TileCacheStatus> statusNotifier =
      ValueNotifier<TileCacheStatus>(TileCacheStatus.online);

  Future<Directory> _getCacheDir() async {
    if (_resolvedCacheDir != null) return _resolvedCacheDir!;

    if (customCacheDirPath != null) {
      _resolvedCacheDir = Directory(customCacheDirPath!);
    } else {
      try {
        final baseDir = await getTemporaryDirectory();
        _resolvedCacheDir = Directory(
          p.join(baseDir.path, MapConfig.tileCacheSubfolder),
        );
      } catch (_) {
        _resolvedCacheDir = Directory(
          p.join(Directory.systemTemp.path, MapConfig.tileCacheSubfolder),
        );
      }
    }

    if (!await _resolvedCacheDir!.exists()) {
      await _resolvedCacheDir!.create(recursive: true);
    }

    // Schedule pruning in background without blocking tile loading
    if (!_isInitializing) {
      _isInitializing = true;
      unawaited(_pruneCache(_resolvedCacheDir!));
    }

    return _resolvedCacheDir!;
  }

  void _updateStatus(TileCacheStatus newStatus) {
    if (_isDisposed) return;
    if (statusNotifier.value != newStatus) {
      statusNotifier.value = newStatus;
      onStatusChanged?.call(newStatus);
    }
  }

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final primaryUrl = getTileUrl(coordinates, options);
    final fallbackUrl = getTileFallbackUrl(coordinates, options);

    final mergedHeaders = <String, String>{
      'User-Agent': MapConfig.userAgentPackageName,
      ...headers,
    };

    return CachedTileImageProvider(
      url: primaryUrl,
      fallbackUrl: fallbackUrl,
      headers: mergedHeaders,
      getCacheDir: _getCacheDir,
      maxAge: maxAge,
      silenceExceptions: silenceExceptions,
      httpClient: httpClient,
      onStatusChanged: _updateStatus,
    );
  }

  /// Prune old and excess tiles to keep disk space under limit
  Future<void> _pruneCache(Directory cacheDir) async {
    try {
      if (!await cacheDir.exists()) return;

      final files = <File>[];
      int totalSize = 0;
      final now = DateTime.now();

      final entities = await cacheDir.list(followLinks: false).toList();
      for (final entity in entities) {
        if (entity is File && entity.path.endsWith('.tile')) {
          final stat = await entity.stat();
          final age = now.difference(stat.modified);

          // Delete files older than maxAge
          if (age > maxAge) {
            await entity.delete();
            continue;
          }

          files.add(entity);
          totalSize += stat.size;
        }
      }

      // If size exceeds limit, delete oldest files (LRU)
      if (totalSize > maxSizeBytes) {
        files.sort(
          (a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()),
        );

        for (final file in files) {
          if (totalSize <= maxSizeBytes) break;
          final size = file.lengthSync();
          await file.delete();
          totalSize -= size;
        }
      }
    } catch (_) {
      // Ignore background pruning errors
    }
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    statusNotifier.dispose();
    super.dispose();
  }
}

/// Dedicated ImageProvider that loads a map tile from local disk cache if available,
/// or downloads and saves it from the network if online.
@immutable
class CachedTileImageProvider extends ImageProvider<CachedTileImageProvider> {
  const CachedTileImageProvider({
    required this.url,
    this.fallbackUrl,
    required this.headers,
    required this.getCacheDir,
    required this.maxAge,
    required this.silenceExceptions,
    this.httpClient,
    this.onStatusChanged,
  });

  final String url;
  final String? fallbackUrl;
  final Map<String, String> headers;
  final Future<Directory> Function() getCacheDir;
  final Duration maxAge;
  final bool silenceExceptions;
  final http.Client? httpClient;
  final ValueChanged<TileCacheStatus>? onStatusChanged;

  String _sanitizeUrlToFilename(String targetUrl) {
    // Generate simple, unique filename from URL hash
    final bytes = utf8.encode(targetUrl);
    final hash = bytes
        .fold<int>(5381, (prev, elem) => ((prev << 5) + prev) + elem)
        .toUnsigned(32)
        .toRadixString(16);
    // Include zoom/x/y in filename for easy identification
    final uri = Uri.tryParse(targetUrl);
    final pathSegments = uri?.pathSegments ?? [];
    final lastSegments = pathSegments.length > 3
        ? pathSegments.sublist(pathSegments.length - 3)
        : pathSegments;
    final safeName = lastSegments.join('_');
    return '${safeName}_$hash.tile';
  }

  @override
  ImageStreamCompleter loadImage(
    CachedTileImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadTile(key, decode),
      scale: 1.0,
      debugLabel: url,
    );
  }

  Future<ui.Codec> _loadTile(
    CachedTileImageProvider key,
    ImageDecoderCallback decode,
  ) async {
    try {
      final cacheDir = await getCacheDir();
      final filename = _sanitizeUrlToFilename(url);
      final cacheFile = File(p.join(cacheDir.path, filename));

      final exists = await cacheFile.exists();
      if (exists) {
        final stat = await cacheFile.stat();
        final age = DateTime.now().difference(stat.modified);

        // Fresh cache hit
        if (age <= maxAge) {
          onStatusChanged?.call(TileCacheStatus.cached);
          final bytes = await cacheFile.readAsBytes();
          final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
          return await decode(buffer);
        }
      }

      // Need network fetch
      final client = httpClient ?? http.Client();
      final shouldCloseClient = httpClient == null;

      try {
        final uri = Uri.parse(url);
        final response = await client
            .get(uri, headers: headers)
            .timeout(const Duration(seconds: 4));

        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          // Save to local cache
          await cacheFile.writeAsBytes(response.bodyBytes, flush: true);
          onStatusChanged?.call(TileCacheStatus.online);
          final buffer = await ui.ImmutableBuffer.fromUint8List(
            response.bodyBytes,
          );
          return await decode(buffer);
        }
      } catch (networkError) {
        // Network failed (offline, timeout, or HTTP error)
        if (exists) {
          // Fall back to stale cached file on disk for offline resilience
          onStatusChanged?.call(TileCacheStatus.cached);
          final bytes = await cacheFile.readAsBytes();
          final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
          return await decode(buffer);
        }
      } finally {
        if (shouldCloseClient) {
          client.close();
        }
      }

      // Try fallback URL if provided
      if (fallbackUrl != null) {
        try {
          final fallbackClient = httpClient ?? http.Client();
          final fallbackUri = Uri.parse(fallbackUrl!);
          final response = await fallbackClient
              .get(fallbackUri, headers: headers)
              .timeout(const Duration(seconds: 4));
          if (httpClient == null) fallbackClient.close();

          if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
            await cacheFile.writeAsBytes(response.bodyBytes, flush: true);
            onStatusChanged?.call(TileCacheStatus.online);
            final buffer = await ui.ImmutableBuffer.fromUint8List(
              response.bodyBytes,
            );
            return await decode(buffer);
          }
        } catch (_) {}
      }

      // Offline & no cached tile available
      onStatusChanged?.call(TileCacheStatus.offlineUncached);
      if (!silenceExceptions) {
        throw Exception('Tile could not be loaded: $url');
      }

      final transparentBuffer = await ui.ImmutableBuffer.fromUint8List(
        TileProvider.transparentImage,
      );
      return await decode(transparentBuffer);
    } catch (e) {
      if (!silenceExceptions) rethrow;
      final transparentBuffer = await ui.ImmutableBuffer.fromUint8List(
        TileProvider.transparentImage,
      );
      return await decode(transparentBuffer);
    }
  }

  @override
  SynchronousFuture<CachedTileImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) {
    return SynchronousFuture(this);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CachedTileImageProvider &&
        other.url == url &&
        other.fallbackUrl == fallbackUrl;
  }

  @override
  int get hashCode => Object.hash(url, fallbackUrl);
}
