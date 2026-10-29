import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../places/domain/place.dart';

class MapPreviewCanvas extends StatelessWidget {
  const MapPreviewCanvas({
    super.key,
    required this.places,
    required this.selectedPlace,
    required this.onSelectPlace,
  });

  final List<Place> places;
  final Place? selectedPlace;
  final ValueChanged<Place> onSelectPlace;

  // Geographic bounds for Central Konya
  static const double _minLat = 37.82;
  static const double _maxLat = 37.98;
  static const double _minLng = 32.38;
  static const double _maxLng = 32.58;

  Offset _getPlaceOffset(Place place, Size size) {
    if (place.latitude == null || place.longitude == null) {
      return Offset(size.width / 2, size.height / 2);
    }

    final double normX = ((place.longitude! - _minLng) / (_maxLng - _minLng))
        .clamp(0.08, 0.92);
    final double normY =
        1.0 -
        ((place.latitude! - _minLat) / (_maxLat - _minLat)).clamp(0.08, 0.92);

    return Offset(normX * size.width, normY * size.height);
  }

  @override
  Widget build(BuildContext context) {
    final validPlaces = places
        .where((p) => p.latitude != null && p.longitude != null)
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        return Stack(
          children: [
            // Styled Map Background Canvas
            CustomPaint(size: size, painter: _MapGridPainter()),

            // Top-left Map Banner Label
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.map_rounded,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Central Konya Map Preview (${validPlaces.length} markers)',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Place Markers
            for (final place in validPlaces) ...[
              Builder(
                builder: (context) {
                  final offset = _getPlaceOffset(place, size);
                  final isSelected = selectedPlace?.id == place.id;

                  return Positioned(
                    left: offset.dx - 18,
                    top: offset.dy - 36,
                    child: GestureDetector(
                      onTap: () => onSelectPlace(place),
                      child: Tooltip(
                        message: place.name,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: EdgeInsets.all(isSelected ? 6 : 4),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : place.accentColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: isSelected ? 2.5 : 2.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isSelected
                                    ? AppColors.primary.withValues(alpha: 0.4)
                                    : Colors.black.withValues(alpha: 0.2),
                                blurRadius: isSelected ? 10 : 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            place.icon,
                            size: isSelected ? 20 : 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        );
      },
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Canvas background
    final bgPaint = Paint()..color = const Color(0xFFF1F5F2);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Green space accents (simulating parks and topography around Konya)
    final parkPaint = Paint()
      ..color = const Color(0xFFE2EFE7)
      ..style = PaintingStyle.fill;

    // Alaeddin Hill central park circle
    canvas.drawCircle(
      Offset(size.width * 0.52, size.height * 0.48),
      38,
      parkPaint,
    );

    // Kültür Park area
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.45, size.height * 0.42, 50, 35),
        const Radius.circular(12),
      ),
      parkPaint,
    );

    // Major road arterial lines
    final ringPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10.0;

    final ringBorderPaint = Paint()
      ..color = const Color(0xFFD3E0D8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12.0;

    final centerOffset = Offset(size.width * 0.52, size.height * 0.48);

    // Ring road around Alaeddin Hill
    canvas.drawCircle(centerOffset, 42, ringBorderPaint);
    canvas.drawCircle(centerOffset, 42, ringPaint);

    // Radial main roads
    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 6.0;

    final roadBorderPaint = Paint()
      ..color = const Color(0xFFD3E0D8)
      ..strokeWidth = 8.0;

    // Mevlana Caddesi (Eastbound)
    canvas.drawLine(
      centerOffset,
      Offset(size.width * 0.95, size.height * 0.50),
      roadBorderPaint,
    );
    canvas.drawLine(
      centerOffset,
      Offset(size.width * 0.95, size.height * 0.50),
      roadPaint,
    );

    // Ankara Caddesi (Northeast)
    canvas.drawLine(
      centerOffset,
      Offset(size.width * 0.85, size.height * 0.10),
      roadBorderPaint,
    );
    canvas.drawLine(
      centerOffset,
      Offset(size.width * 0.85, size.height * 0.10),
      roadPaint,
    );

    // İstanbul Caddesi (Northwest)
    canvas.drawLine(
      centerOffset,
      Offset(size.width * 0.15, size.height * 0.15),
      roadBorderPaint,
    );
    canvas.drawLine(
      centerOffset,
      Offset(size.width * 0.15, size.height * 0.15),
      roadPaint,
    );

    // Meram Caddesi (Southwest)
    canvas.drawLine(
      centerOffset,
      Offset(size.width * 0.10, size.height * 0.85),
      roadBorderPaint,
    );
    canvas.drawLine(
      centerOffset,
      Offset(size.width * 0.10, size.height * 0.85),
      roadPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
