import 'dart:math';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../data/gtfs_database.dart';

class GtfsStopInfo {
  final String stopId;
  final String stopName;
  final LatLng location;
  final double distanceMeters;

  const GtfsStopInfo({
    required this.stopId,
    required this.stopName,
    required this.location,
    required this.distanceMeters,
  });
}

class GtfsTripOption {
  final String tripId;
  final String routeId;
  final String routeShortName;
  final String routeLongName;
  final int routeType; // 0 = Tram, 3 = Bus
  final Color? routeColor;
  final String boardingStopId;
  final String boardingStopName;
  final String boardingTime;
  final int startSequence;
  final String disembarkingStopId;
  final String disembarkingStopName;
  final String disembarkingTime;
  final int endSequence;
  final String? shapeId;
  final String? tripHeadsign;
  final int stopCount;
  final int durationMinutes;

  const GtfsTripOption({
    required this.tripId,
    required this.routeId,
    required this.routeShortName,
    required this.routeLongName,
    required this.routeType,
    this.routeColor,
    required this.boardingStopId,
    required this.boardingStopName,
    required this.boardingTime,
    required this.startSequence,
    required this.disembarkingStopId,
    required this.disembarkingStopName,
    required this.disembarkingTime,
    required this.endSequence,
    this.shapeId,
    this.tripHeadsign,
    required this.stopCount,
    required this.durationMinutes,
  });

  bool get isTram => routeType == 0;
}

class GtfsQueryService {
  GtfsQueryService({GtfsDatabase? databaseService})
    : _dbService = databaseService ?? GtfsDatabase();

  final GtfsDatabase _dbService;

  /// Finds GTFS stops near a given lat/lon coordinate within radiusMeters
  Future<List<GtfsStopInfo>> findStopsNear(
    LatLng position, {
    double radiusMeters = 800.0,
  }) async {
    final db = await _dbService.database;

    final double latDelta = radiusMeters / 111000.0;
    final double lonDelta =
        radiusMeters / (111000.0 * cos(position.latitude * (pi / 180.0)));

    final minLat = position.latitude - latDelta;
    final maxLat = position.latitude + latDelta;
    final minLon = position.longitude - lonDelta;
    final maxLon = position.longitude + lonDelta;

    final List<Map<String, dynamic>> rows = await db.query(
      'stops',
      columns: ['stop_id', 'stop_name', 'stop_lat', 'stop_lon'],
      where: 'stop_lat BETWEEN ? AND ? AND stop_lon BETWEEN ? AND ?',
      whereArgs: [minLat, maxLat, minLon, maxLon],
    );

    final List<GtfsStopInfo> results = [];
    for (final r in rows) {
      final stopLat = (r['stop_lat'] as num).toDouble();
      final stopLon = (r['stop_lon'] as num).toDouble();
      final stopLoc = LatLng(stopLat, stopLon);
      final distMeters = _distanceMeters(position, stopLoc);

      if (distMeters <= radiusMeters) {
        results.add(
          GtfsStopInfo(
            stopId: r['stop_id'] as String,
            stopName: r['stop_name'] as String,
            location: stopLoc,
            distanceMeters: distMeters,
          ),
        );
      }
    }

    results.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return results;
  }

  /// Finds GTFS scheduled trips connecting boarding stops to disembarking stops
  Future<List<GtfsTripOption>> findConnectingTrips({
    required List<String> startStopIds,
    required List<String> endStopIds,
    required DateTime targetTime,
  }) async {
    if (startStopIds.isEmpty || endStopIds.isEmpty) return [];

    final db = await _dbService.database;

    final dayColumn = _getDayColumn(targetTime.weekday);
    final formattedTime = _formatTime(targetTime);

    final startPlaceholders = List.filled(startStopIds.length, '?').join(', ');
    final endPlaceholders = List.filled(endStopIds.length, '?').join(', ');

    final sql =
        '''
      SELECT 
        t.trip_id,
        r.route_id,
        r.route_short_name,
        r.route_long_name,
        r.route_type,
        r.route_color,
        st1.stop_id AS boarding_stop_id,
        st1.departure_time AS boarding_time,
        st1.stop_sequence AS start_seq,
        st2.stop_id AS disembarking_stop_id,
        st2.arrival_time AS disembarking_time,
        st2.stop_sequence AS end_seq,
        t.shape_id,
        t.trip_headsign,
        s1.stop_name AS boarding_stop_name,
        s2.stop_name AS disembarking_stop_name
      FROM stop_times st1
      JOIN stop_times st2 ON st1.trip_id = st2.trip_id AND st1.stop_sequence < st2.stop_sequence
      JOIN trips t ON st1.trip_id = t.trip_id
      JOIN routes r ON t.route_id = r.route_id
      JOIN calendar c ON t.service_id = c.service_id
      JOIN stops s1 ON st1.stop_id = s1.stop_id
      JOIN stops s2 ON st2.stop_id = s2.stop_id
      WHERE st1.stop_id IN ($startPlaceholders)
        AND st2.stop_id IN ($endPlaceholders)
        AND st1.departure_time >= ?
        AND c.$dayColumn = 1
      ORDER BY st1.departure_time ASC
      LIMIT 5
    ''';

    final queryArgs = [...startStopIds, ...endStopIds, formattedTime];

    final List<Map<String, dynamic>> rows = await db.rawQuery(sql, queryArgs);

    final List<GtfsTripOption> options = [];
    for (final r in rows) {
      final startSeq = (r['start_seq'] as num).toInt();
      final endSeq = (r['end_seq'] as num).toInt();
      final stopCount = (endSeq - startSeq).abs();

      final bTimeStr = r['boarding_time'] as String;
      final dTimeStr = r['disembarking_time'] as String;
      final durationMins = _calculateDurationMinutes(bTimeStr, dTimeStr);

      Color? color;
      final colorHex = r['route_color'] as String?;
      if (colorHex != null && colorHex.isNotEmpty) {
        final cleanHex = colorHex.replaceAll('#', '');
        final parsed = int.tryParse('0xFF$cleanHex');
        if (parsed != null) color = Color(parsed);
      }

      options.add(
        GtfsTripOption(
          tripId: r['trip_id'] as String,
          routeId: r['route_id'] as String,
          routeShortName: (r['route_short_name'] as String?) ?? 'Bus',
          routeLongName: (r['route_long_name'] as String?) ?? '',
          routeType: (r['route_type'] as num).toInt(),
          routeColor: color,
          boardingStopId: r['boarding_stop_id'] as String,
          boardingStopName: r['boarding_stop_name'] as String,
          boardingTime: bTimeStr,
          startSequence: startSeq,
          disembarkingStopId: r['disembarking_stop_id'] as String,
          disembarkingStopName: r['disembarking_stop_name'] as String,
          disembarkingTime: dTimeStr,
          endSequence: endSeq,
          shapeId: r['shape_id'] as String?,
          tripHeadsign: r['trip_headsign'] as String?,
          stopCount: stopCount,
          durationMinutes: durationMins,
        ),
      );
    }

    return options;
  }

  /// Retrieves the shape polyline points for a shapeId
  Future<List<LatLng>> getTripShapePolyline(String shapeId) async {
    final db = await _dbService.database;

    final List<Map<String, dynamic>> rows = await db.query(
      'shapes',
      columns: ['shape_pt_lat', 'shape_pt_lon'],
      where: 'shape_id = ?',
      whereArgs: [shapeId],
      orderBy: 'shape_pt_sequence ASC',
    );

    return rows
        .map(
          (r) => LatLng(
            (r['shape_pt_lat'] as num).toDouble(),
            (r['shape_pt_lon'] as num).toDouble(),
          ),
        )
        .toList();
  }

  /// Retrieves list of intermediate stop names between startSequence and endSequence
  Future<List<String>> getIntermediateStopNames(
    String tripId,
    int startSequence,
    int endSequence,
  ) async {
    final db = await _dbService.database;

    final List<Map<String, dynamic>> rows = await db.rawQuery(
      '''
      SELECT s.stop_name
      FROM stop_times st
      JOIN stops s ON st.stop_id = s.stop_id
      WHERE st.trip_id = ? AND st.stop_sequence > ? AND st.stop_sequence < ?
      ORDER BY st.stop_sequence ASC
      ''',
      [tripId, startSequence, endSequence],
    );

    return rows.map((r) => r['stop_name'] as String).toList();
  }

  String _getDayColumn(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'monday';
      case DateTime.tuesday:
        return 'tuesday';
      case DateTime.wednesday:
        return 'wednesday';
      case DateTime.thursday:
        return 'thursday';
      case DateTime.friday:
        return 'friday';
      case DateTime.saturday:
        return 'saturday';
      case DateTime.sunday:
        return 'sunday';
      default:
        return 'monday';
    }
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  int _calculateDurationMinutes(String startStr, String endStr) {
    try {
      final p1 = startStr.split(':').map(int.parse).toList();
      final p2 = endStr.split(':').map(int.parse).toList();

      final s1 = p1[0] * 3600 + p1[1] * 60 + p1[2];
      final s2 = p2[0] * 3600 + p2[1] * 60 + p2[2];

      final diffSec = max(60, s2 - s1);
      return (diffSec / 60.0).round();
    } catch (_) {
      return 15;
    }
  }

  double _distanceMeters(LatLng a, LatLng b) {
    const double r = 6371000.0;
    final double dLat = (b.latitude - a.latitude) * (pi / 180.0);
    final double dLon = (b.longitude - a.longitude) * (pi / 180.0);

    final double sa =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(a.latitude * (pi / 180.0)) *
            cos(b.latitude * (pi / 180.0)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final double c = 2 * atan2(sqrt(sa), sqrt(1 - sa));
    return r * c;
  }
}
