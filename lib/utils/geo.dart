import 'dart:math' as math;

import '../models/track_point.dart';

/// Pure geo math. No plugin dependencies so it stays trivially testable.
class Geo {
  Geo._();

  static const double _earthRadiusMeters = 6371000.0;

  /// Great-circle distance between two coordinates in meters (haversine).
  static double distanceBetween(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.pow(math.sin(dLng / 2), 2);
    return _earthRadiusMeters * 2 * math.asin(math.sqrt(a.toDouble()));
  }

  /// Total length of a recorded path in meters.
  static double pathDistance(List<TrackPoint> points) {
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += distanceBetween(
        points[i - 1].latitude,
        points[i - 1].longitude,
        points[i].latitude,
        points[i].longitude,
      );
    }
    return total;
  }

  /// Sum of positive elevation deltas in meters.
  ///
  /// [noiseThreshold] ignores tiny GPS altitude jitter between consecutive
  /// points so gain isn't massively inflated on flat routes.
  static double elevationGain(
    List<TrackPoint> points, {
    double noiseThreshold = 1.5,
  }) {
    var gain = 0.0;
    double? lastElevation;
    for (final point in points) {
      final elevation = point.elevation;
      if (elevation == null) continue;
      if (lastElevation != null) {
        final delta = elevation - lastElevation;
        if (delta > noiseThreshold) {
          gain += delta;
          lastElevation = elevation;
        } else if (delta < -noiseThreshold) {
          lastElevation = elevation;
        }
      } else {
        lastElevation = elevation;
      }
    }
    return gain;
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180.0;
}
