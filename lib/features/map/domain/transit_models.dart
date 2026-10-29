import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class TramStop {
  final String id;
  final String name;
  final String lineCode; // e.g. 'T1', 'T2'
  final LatLng location;
  final int sequenceIndex;

  const TramStop({
    required this.id,
    required this.name,
    required this.lineCode,
    required this.location,
    required this.sequenceIndex,
  });
}

class TramLine {
  final String id;
  final String code; // 'T1' or 'T2'
  final String name;
  final Color color;
  final List<TramStop> stops;

  const TramLine({
    required this.id,
    required this.code,
    required this.name,
    required this.color,
    required this.stops,
  });
}

enum TransitLegType { walk, tramRide, busRide }

class TransitLeg {
  final TransitLegType type;
  final String title;
  final String description;
  final String startName;
  final String endName;
  final double distanceKm;
  final int durationMinutes;
  final String? tramLineCode;
  final Color? legColor;
  final List<LatLng> points;
  final List<String> intermediateStops;

  const TransitLeg({
    required this.type,
    required this.title,
    required this.description,
    required this.startName,
    required this.endName,
    required this.distanceKm,
    required this.durationMinutes,
    required this.points,
    this.tramLineCode,
    this.legColor,
    this.intermediateStops = const [],
  });

  bool get isWalk => type == TransitLegType.walk;
  bool get isTram => type == TransitLegType.tramRide;
  bool get isBus => type == TransitLegType.busRide;
}

class TransitJourneyResult {
  final String destinationName;
  final double totalDistanceKm;
  final int totalDurationMinutes;
  final List<TransitLeg> legs;
  final String? noticeMessage;
  final bool isTramAvailable;

  const TransitJourneyResult({
    required this.destinationName,
    required this.totalDistanceKm,
    required this.totalDurationMinutes,
    required this.legs,
    this.noticeMessage,
    this.isTramAvailable = true,
  });

  List<LatLng> get allPoints {
    final List<LatLng> points = [];
    for (final leg in legs) {
      points.addAll(leg.points);
    }
    return points;
  }
}
