abstract class MapConfig {
  /// Default center coordinates for Central Konya, Türkiye
  static const double initialLatitude = 37.8715;
  static const double initialLongitude = 32.4930;
  static const double initialZoom = 14.2;

  /// Primary OpenStreetMap tile server URL template.
  /// Complies with OSM Tile Usage Policy by sending custom User-Agent header
  /// and displaying clear, visible attribution on screen.
  static const String tileUrlTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Custom HTTP User-Agent identifier sent with tile requests
  static const String userAgentPackageName =
      'com.amtilyst.konya_city_companion';

  /// Required OSM attribution text string
  static const String attributionText = '© OpenStreetMap contributors';

  /// Fallback / Alternative tile server option (CartoDB Voyager)
  static const String cartoDbTileUrlTemplate =
      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';
  static const List<String> cartoSubdomains = ['a', 'b', 'c', 'd'];

  /// Map Tile Cache configuration constants
  static const String tileCacheSubfolder = 'konya_map_tiles';

  /// Maximum cache retention duration (14 days - complies with OSM policy >= 7 days)
  static const Duration maxTileCacheAge = Duration(days: 14);

  /// Maximum disk space allocated for tile storage (50 MB limit)
  static const int maxTileCacheSizeBytes = 50 * 1024 * 1024;

  /// LocationIQ API key for production OSRM routing
  static const String locationIqApiKey = 'pk.187637b996c83e4039fa4366f8cbddd6';

  /// Base URL for LocationIQ Directions API
  static const String locationIqBaseUrl = 'https://us1.locationiq.com/v1';
}
