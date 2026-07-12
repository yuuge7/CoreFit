import 'activity_type.dart';

/// Lightweight projection of an [Activity] without the GPS track.
///
/// Full activities (with thousands of track points) live in a lazy box and are
/// only loaded when viewing a single activity's detail/map. Everything else —
/// history lists, monthly/yearly stats, challenge progress — reads these
/// summaries, which are kept in a small always-in-memory index box. This is
/// what makes historical querying cheap.
class ActivitySummary {
  const ActivitySummary({
    required this.id,
    required this.type,
    required this.startTime,
    required this.distanceMeters,
    required this.movingTimeSeconds,
    required this.elapsedTimeSeconds,
    required this.elevationGainMeters,
    required this.title,
    this.perceivedExertion,
    this.gearId,
  });

  final String id;
  final ActivityType type;
  final DateTime startTime;
  final double distanceMeters;
  final int movingTimeSeconds;
  final int elapsedTimeSeconds;
  final double elevationGainMeters;
  final String title;

  /// 1–10 slider value, if set on the save screen.
  final int? perceivedExertion;
  final String? gearId;

  /// Average moving speed in m/s.
  double get avgSpeedMps =>
      movingTimeSeconds > 0 ? distanceMeters / movingTimeSeconds : 0;

  /// Average pace in seconds per kilometer, or null when no distance yet.
  double? get avgPaceSecondsPerKm =>
      distanceMeters > 0 ? movingTimeSeconds / (distanceMeters / 1000) : null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.toJson(),
        'startTime': startTime.toUtc().millisecondsSinceEpoch,
        'distanceMeters': distanceMeters,
        'movingTimeSeconds': movingTimeSeconds,
        'elapsedTimeSeconds': elapsedTimeSeconds,
        'elevationGainMeters': elevationGainMeters,
        'title': title,
        if (perceivedExertion != null) 'perceivedExertion': perceivedExertion,
        if (gearId != null) 'gearId': gearId,
      };

  factory ActivitySummary.fromJson(Map<String, dynamic> json) =>
      ActivitySummary(
        id: json['id'] as String,
        type: ActivityType.fromJson(json['type'] as String),
        startTime: DateTime.fromMillisecondsSinceEpoch(
          json['startTime'] as int,
          isUtc: true,
        ),
        distanceMeters: (json['distanceMeters'] as num).toDouble(),
        movingTimeSeconds: json['movingTimeSeconds'] as int,
        elapsedTimeSeconds: json['elapsedTimeSeconds'] as int,
        elevationGainMeters: (json['elevationGainMeters'] as num).toDouble(),
        title: json['title'] as String,
        perceivedExertion: json['perceivedExertion'] as int?,
        gearId: json['gearId'] as String?,
      );
}
