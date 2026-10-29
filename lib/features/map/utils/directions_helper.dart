import 'package:url_launcher/url_launcher.dart';

import '../../places/domain/place.dart';

abstract class DirectionsHelper {
  /// Generates a Google Maps search/directions URL for the given place.
  static Uri getDirectionsUri(Place place) {
    if (place.latitude != null && place.longitude != null) {
      return Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${place.latitude},${place.longitude}',
      );
    } else {
      final query = Uri.encodeComponent('${place.name}, Konya, Turkey');
      return Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$query',
      );
    }
  }

  /// Opens Google Maps in an external browser or app to provide directions.
  static Future<bool> openDirections(Place place) async {
    final uri = getDirectionsUri(place);
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }
}
