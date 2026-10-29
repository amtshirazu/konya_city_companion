import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/cached_image_widget.dart';
import '../../domain/place.dart';
import '../../domain/place_media.dart';

class PlaceMediaGallery extends StatefulWidget {
  final List<PlaceMedia> mediaList;
  final Place place;

  const PlaceMediaGallery({
    super.key,
    required this.mediaList,
    required this.place,
  });

  @override
  State<PlaceMediaGallery> createState() => _PlaceMediaGalleryState();
}

class _PlaceMediaGalleryState extends State<PlaceMediaGallery> {
  int _currentPage = 0;

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showLicenseInfoDialog(PlaceMedia media) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(media.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Attribution: ${media.attributionText}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              'License: ${media.licenseName}',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              'Source: ${media.sourceName}',
              style: const TextStyle(fontSize: 12),
            ),
            if (media.creatorName != null)
              Text(
                'Creator: ${media.creatorName}',
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _launchUrl(media.licenseUrl);
            },
            child: const Text('View License'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _launchUrl(media.sourcePageUrl);
            },
            child: const Text('Source Page'),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackIllustration() {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: widget.place.accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.place.accentColor.withValues(alpha: 0.08),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.place.icon,
                  size: 64,
                  color: widget.place.accentColor,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        widget.place.categoryLabel,
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: widget.place.isVerified
                            ? AppColors.primaryLight
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: widget.place.isVerified
                              ? AppColors.primary.withValues(alpha: 0.3)
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.place.isVerified
                                ? Icons.verified_rounded
                                : Icons.help_outline_rounded,
                            size: 14,
                            color: widget.place.isVerified
                                ? AppColors.primary
                                : Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.place.isVerified
                                ? 'Verified'
                                : 'Needs Review',
                            style: TextStyle(
                              color: widget.place.isVerified
                                  ? AppColors.primaryDark
                                  : Colors.grey.shade700,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mediaList.isEmpty) {
      return _buildFallbackIllustration();
    }

    final currentMedia = widget.mediaList[_currentPage];

    return Container(
      width: double.infinity,
      height: 230,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            PageView.builder(
              itemCount: widget.mediaList.length,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemBuilder: (context, index) {
                final media = widget.mediaList[index];
                return CachedImageWidget(
                  url: media.originalMediaUrl,
                  fallbackWidget: _buildFallbackIllustration(),
                );
              },
            ),

            // Page Indicator for Carousel
            if (widget.mediaList.length > 1)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${_currentPage + 1} / ${widget.mediaList.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

            // Discreet Info Button for Licensing Details
            Positioned(
              top: 12,
              left: 12,
              child: GestureDetector(
                onTap: () => _showLicenseInfoDialog(currentMedia),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.50),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.info_outline_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
