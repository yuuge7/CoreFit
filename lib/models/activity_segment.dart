import '../utils/geo.dart';
import 'track_point.dart';

/// One continuous stretch of movement between a start/resume and a pause/stop.
///
/// Pause/resume is modeled structurally: an activity is a list of segments,
/// and paused time is simply the gap between one segment's [endTime] and the
/// next segment's [startTime]. Moving time and distance are therefore only
/// ever accumulated inside segments — nothing is counted while paused.
class ActivitySegment {
  ActivitySegment({
    required this.startTime,
    this.endTime,
    List<TrackPoint>? points,
  }) : points = points ?? [];

  final DateTime startTime;

  /// Null while this segment is still actively recording.
  DateTime? endTime;

  final List<TrackPoint> points;

  bool get isActive => endTime == null;

  Duration get duration =>
      (endTime ?? DateTime.now()).difference(startTime);

  double get distanceMeters => Geo.pathDistance(points);

  double get elevationGainMeters => Geo.elevationGain(points);

  Map<String, dynamic> toJson() => {
        'start': startTime.toUtc().millisecondsSinceEpoch,
        if (endTime != null) 'end': endTime!.toUtc().millisecondsSinceEpoch,
        'points': points.map((p) => p.toJson()).toList(),
      };

  factory ActivitySegment.fromJson(Map<String, dynamic> json) =>
      ActivitySegment(
        startTime: DateTime.fromMillisecondsSinceEpoch(
          json['start'] as int,
          isUtc: true,
        ),
        endTime: json['end'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                json['end'] as int,
                isUtc: true,
              ),
        points: (json['points'] as List<dynamic>? ?? [])
            .map((p) => TrackPoint.fromJson(Map<String, dynamic>.from(p as Map)))
            .toList(),
      );
}
