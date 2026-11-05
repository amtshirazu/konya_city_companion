# 🏰 Konya City Companion

A modern, offline-resilient Flutter mobile application designed for tourists, international students, newcomers, and residents exploring **Konya, Türkiye**.

The app combines interactive mapping, place discovery, multi-modal public transit journey planning (buses & trams), LocationIQ turn-by-turn routing, and local SQLite data persistence.

---

## ✨ Features & Current App State

### 1. 🗺️ Interactive Maps & Compliant Tile Caching
* Built on `flutter_map` with OpenStreetMap raster tiles (`tile.openstreetmap.org`).
* **Persistent Disk Caching (`CachedTileProvider`):** Caches previously viewed map tiles on disk with automatic 14-day retention and a 50MB LRU storage quota.
* **Offline Resilience:** Shows cached map tiles when offline with an unobtrusive status badge (*Map Online*, *Cached Map*, *Offline - Missing Tiles*).

### 2. 🚶‍♂️🚗🚴 Multi-Mode Turn-by-Turn Routing
* Powered by the **LocationIQ OSRM Directions API**.
* Supports **Walking**, **Driving**, and **Cycling** travel modes with speed-adjusted duration estimates.
* Displays step-by-step turn maneuvers, road names, distances, and travel times.
* Features automatic off-route deviation detection (>100m) and arrival detection (<25m).

### 3. 🚌🚃 Multimodal GTFS Public Transit Planner
* **Local GTFS SQLite Engine (`konya_gtfs.db`):** On-device transit database storing 581,000+ stop times, 130,000+ shape points, and 4,400+ bus/tram stops from Konya Büyükşehir Belediyesi.
* **Multimodal Itineraries:** Computes seamless 3-to-5 leg journeys:
  $$\text{Walk Leg (LocationIQ)} \longrightarrow \text{Bus/Tram Leg (GTFS Schedule)} \longrightarrow \text{Transfer / Walk Leg (LocationIQ)}$$
* **Minimal-Walk Optimization:** Ranks candidate transit routes to prioritize connections with minimal walking effort.
* Displays live schedule departures, route numbers, intermediate stop names, line branding colors, and route polylines on the map.

### 4. 🏛️ Place Discovery & Saved Places
* Browse verified historical monuments (Mevlana Museum, Sille Village, Alaeddin Hill), parks, cafes, and cultural landmarks.
* **Bookmark Persistence:** Save favorite places locally using a SQLite database (`sqflite`).
* **Media Gallery & Credits:** Rich image galleries with Wikimedia attribution credits.

---

## 🛠️ Tech Stack & Architecture

| Component | Technology |
| :--- | :--- |
| **Framework** | Flutter / Dart (SDK ^3.13.2) |
| **State Management** | Flutter Riverpod (`flutter_riverpod`) |
| **Map Rendering** | `flutter_map`, `latlong2` |
| **Tile Caching** | Custom disk provider (`path_provider`, `dart:io`) |
| **Road Routing API** | LocationIQ OSRM Directions API (`http`) |
| **Transit Engine** | On-device GTFS SQLite database (`sqflite`) |
| **Local Data Storage** | SQLite (`sqflite` & `sqflite_common_ffi`) |
| **Location Services** | `geolocator` |

---

## 🚀 Getting Started

### 1. Prerequisites
* Flutter SDK (3.13.2 or newer)
* Android Studio or VS Code with Flutter extension
* Python 3.x (for initial GTFS database conversion)

### 2. GTFS Database Conversion
To build or update the local GTFS SQLite database from raw GTFS text files:
```powershell
python convert_gtfs_to_sqlite.py
```
*(This processes all 11 GTFS text files in `gtfs_11_2025/` and outputs `konya_gtfs.db` in seconds).*

### 3. Run the Flutter App
```powershell
# Get dependencies
flutter pub get

# Run on connected device or emulator
flutter run
```

---

## 🧪 Testing & Code Quality

The project includes comprehensive unit, widget, and integration tests:

```powershell
# Format code
dart format lib test

# Run static analysis
flutter analyze

# Run test suite
flutter test test/gtfs_planner_test.dart test/routing_service_test.dart test/map_screen_test.dart test/cached_tile_provider_test.dart
```

---

## 📜 License & Attribution
* **Map Tiles & Data:** © [OpenStreetMap](https://www.openstreetmap.org/copyright) contributors.
* **Transit Schedule Data:** Konya Büyükşehir Belediyesi GTFS Feed.
* **Routing API:** Powered by [LocationIQ](https://locationiq.com/).
