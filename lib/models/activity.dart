import 'activity_segment.dart';
import 'activity_summary.dart';
import 'activity_type.dart';

/// A recorded workout.
///
/// Pause/resume: the activity owns a list of [ActivitySegment]s. Recording
/// appends points to the last (open) segment; pausing closes it; resuming
/// opens a new one. Distance/moving time come only from segment content, so
/// paused time never leaks into stats.
///
/// Stats ([distanceMeters], [movingTimeSeconds], [elevationGainMeters]) are
/// cached on the object and persisted, so history/stats screens never have to
/// re-walk thousands of track points. Call [recalculateStats] before saving.
class Activity {
  Activity({
    required this.id,
    required this.type,
    required this.startTime,
    this.endTime,
    List<ActivitySegment>? segments,
    this.distanceMeters = 0,
    this.movingTimeSeconds = 0,
    this.elevationGainMeters = 0,
    String? title,
    this.description,
    this.perceivedExertion,
    this.gearId,
  })  : segments = segments ?? [],
        title = title ?? '${type.label} activity';

  final String id;

  /// Mutable so a saved activity can be re-labelled (e.g. walk recorded as
  /// a run); the GPS track doesn't depend on it.
  ActivityType type;
  final DateTime startTime;
  DateTime? endTime;
  final List<ActivitySegment> segments;

  // Cached stats — recomputed from segments via [recalculateStats].
  double distanceMeters;
  int movingTimeSeconds;
  double elevationGainMeters;

  // Post-activity metadata from the save screen.
  String title;
  String? description;

  /// 1–10, null until set on the save screen.
  int? perceivedExertion;

  /// References a [Gear.id]; gear itself lives in its own box.
  String? gearId;

  bool get isFinished => endTime != null;

  /// Wall-clock duration including paused time.
  int get elapsedTimeSeconds =>
      (endTime ?? DateTime.now()).difference(startTime).inSeconds;

  double get avgSpeedMps =>
      movingTimeSeconds > 0 ? distanceMeters / movingTimeSeconds : 0;

  double? get avgPaceSecondsPerKm =>
      distanceMeters > 0 ? movingTimeSeconds / (distanceMeters / 1000) : null;

  /// Recomputes cached stats from segment data. Cheap enough to call on every
  /// pause/finish; not meant to run per GPS fix (live tracking will accumulate
  /// incrementally and only reconcile here).
  void recalculateStats() {
    distanceMeters =
        segments.fold(0.0, (sum, s) => sum + s.distanceMeters);
    movingTimeSeconds =
        segments.fold(0, (sum, s) => sum + s.duration.inSeconds);
    elevationGainMeters =
        segments.fold(0.0, (sum, s) => sum + s.elevationGainMeters);
  }

  ActivitySummary toSummary() => ActivitySummary(
        id: id,
        type: type,
        startTime: startTime,
        distanceMeters: distanceMeters,
        movingTimeSeconds: movingTimeSeconds,
        elapsedTimeSeconds: elapsedTimeSeconds,
        elevationGainMeters: elevationGainMeters,
        title: title,
        perceivedExertion: perceivedExertion,
        gearId: gearId,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.toJson(),
        'startTime': startTime.toUtc().millisecondsSinceEpoch,
        if (endTime != null)
          'endTime': endTime!.toUtc().millisecondsSinceEpoch,
        'segments': segments.map((s) => s.toJson()).toList(),
        'distanceMeters': distanceMeters,
        'movingTimeSeconds': movingTimeSeconds,
        'elevationGainMeters': elevationGainMeters,
        'title': title,
        if (description != null) 'description': description,
        if (perceivedExertion != null) 'perceivedExertion': perceivedExertion,
        if (gearId != null) 'gearId': gearId,
      };

  factory Activity.fromJson(Map<String, dynamic> json) => Activity(
        id: json['id'] as String,
        type: ActivityType.fromJson(json['type'] as String),
        startTime: DateTime.fromMillisecondsSinceEpoch(
          json['startTime'] as int,
          isUtc: true,
        ),
        endTime: json['endTime'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                json['endTime'] as int,
                isUtc: true,
              ),
        segments: (json['segments'] as List<dynamic>? ?? [])
            .map((s) =>
                ActivitySegment.fromJson(Map<String, dynamic>.from(s as Map)))
            .toList(),
        distanceMeters: (json['distanceMeters'] as num? ?? 0).toDouble(),
        movingTimeSeconds: json['movingTimeSeconds'] as int? ?? 0,
        elevationGainMeters:
            (json['elevationGainMeters'] as num? ?? 0).toDouble(),
        title: json['title'] as String?,
        description: json['description'] as String?,
        perceivedExertion: json['perceivedExertion'] as int?,
        gearId: json['gearId'] as String?,
      );
}
