import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../app/theme/app_colors.dart';

class CachedImageWidget extends StatefulWidget {
  final String url;
  final BoxFit fit;
  final Widget? fallbackWidget;
  final Map<String, String>? headers;

  const CachedImageWidget({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.fallbackWidget,
    this.headers,
  });

  @override
  State<CachedImageWidget> createState() => _CachedImageWidgetState();
}

class _CachedImageWidgetState extends State<CachedImageWidget> {
  File? _cachedFile;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant CachedImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _loadImage();
    }
  }

  String _getCacheFilename(String url) {
    final sanitized = url.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final hash = url.hashCode.toRadixString(16);
    final shortName = sanitized.length > 30
        ? sanitized.substring(sanitized.length - 30)
        : sanitized;
    return 'img_${shortName}_$hash.jpg';
  }

  Future<void> _loadImage() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final cacheDir = await getTemporaryDirectory();
      final mediaCacheDir = Directory(
        p.join(cacheDir.path, 'konya_media_cache'),
      );
      if (!await mediaCacheDir.exists()) {
        await mediaCacheDir.create(recursive: true);
      }

      final filename = _getCacheFilename(widget.url);
      final cacheFile = File(p.join(mediaCacheDir.path, filename));

      if (await cacheFile.exists()) {
        if (!mounted) return;
        setState(() {
          _cachedFile = cacheFile;
          _isLoading = false;
        });
        return;
      }

      // Fetch from network
      final uri = Uri.parse(widget.url);
      final response = await http
          .get(
            uri,
            headers: {
              'User-Agent': 'com.amtilyst.konya_city_companion',
              ...?widget.headers,
            },
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        await cacheFile.writeAsBytes(response.bodyBytes, flush: true);
        if (!mounted) return;
        setState(() {
          _cachedFile = cacheFile;
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: AppColors.primaryLight,
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
        ),
      );
    }

    if (_hasError || _cachedFile == null) {
      return widget.fallbackWidget ??
          Container(
            color: AppColors.primaryLight,
            child: const Center(
              child: Icon(
                Icons.image_not_supported_rounded,
                color: AppColors.primary,
                size: 32,
              ),
            ),
          );
    }

    return Image.file(
      _cachedFile!,
      fit: widget.fit,
      errorBuilder: (context, error, stackTrace) {
        return widget.fallbackWidget ??
            Container(
              color: AppColors.primaryLight,
              child: const Center(
                child: Icon(
                  Icons.broken_image_rounded,
                  color: AppColors.primary,
                  size: 32,
                ),
              ),
            );
      },
    );
  }
}
