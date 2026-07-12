import 'activity_summary.dart';
import 'activity_type.dart';

/// How long one challenge period lasts. Challenges are recurring: a monthly
/// challenge automatically applies to whichever month you're looking at.
enum ChallengeTimeframe {
  weekly,
  monthly,
  yearly;

  String get label => switch (this) {
        ChallengeTimeframe.weekly => 'Weekly',
        ChallengeTimeframe.monthly => 'Monthly',
        ChallengeTimeframe.yearly => 'Yearly',
      };

  String toJson() => name;

  static ChallengeTimeframe fromJson(String value) =>
      ChallengeTimeframe.values.byName(value);
}

/// What gets summed toward the target.
enum ChallengeMetric {
  /// Target in meters.
  distance,

  /// Target in seconds of moving time.
  movingTime,

  /// Target is a number of completed activities.
  activityCount;

  String get label => switch (this) {
        ChallengeMetric.distance => 'Distance',
        ChallengeMetric.movingTime => 'Moving time',
        ChallengeMetric.activityCount => 'Activities',
      };

  String toJson() => name;

  static ChallengeMetric fromJson(String value) =>
      ChallengeMetric.values.byName(value);
}

/// A time-bound goal, either built-in ([isCustom] == false) or user-created.
///
/// Progress is never stored — it is computed on demand from activity
/// summaries via [progressFrom], so editing/importing/deleting activities can
/// never desync a challenge. This also gives historical navigation for free:
/// pass any reference date to [periodBounds]/[progressFrom] to see how a past
/// week/month/year did against the same target.
class Challenge {
  Challenge({
    required this.id,
    required this.title,
    required this.metric,
    required this.targetValue,
    required this.timeframe,
    required this.createdAt,
    this.description,
    this.activityType,
    this.isCustom = true,
    this.archived = false,
  });

  final String id;
  String title;
  String? description;

  /// Null means every activity type counts.
  ActivityType? activityType;

  ChallengeMetric metric;

  /// Meters, seconds, or a count — depending on [metric].
  double targetValue;

  ChallengeTimeframe timeframe;

  /// False for the built-in defaults seeded on first launch. Defaults can be
  /// archived but not deleted; custom challenges can be fully deleted.
  final bool isCustom;

  final DateTime createdAt;

  /// Hidden from the challenges screen without losing the definition.
  bool archived;

  /// The [start, end) window of the period containing [reference].
  /// Weeks start on Monday. Bounds are in local time so "this month" matches
  /// the calendar on the phone.
  ({DateTime start, DateTime end}) periodBounds(DateTime reference) {
    final local = reference.toLocal();
    switch (timeframe) {
      case ChallengeTimeframe.weekly:
        final monday = DateTime(local.year, local.month, local.day)
            .subtract(Duration(days: local.weekday - 1));
        return (start: monday, end: monday.add(const Duration(days: 7)));
      case ChallengeTimeframe.monthly:
        return (
          start: DateTime(local.year, local.month),
          end: DateTime(local.year, local.month + 1),
        );
      case ChallengeTimeframe.yearly:
        return (
          start: DateTime(local.year),
          end: DateTime(local.year + 1),
        );
    }
  }

  /// Sums the metric over activities inside the period containing
  /// [reference] (defaults to now). Pass a past date to evaluate an earlier
  /// period.
  double progressFrom(
    Iterable<ActivitySummary> summaries, {
    DateTime? reference,
  }) {
    final bounds = periodBounds(reference ?? DateTime.now());
    var total = 0.0;
    for (final summary in summaries) {
      if (activityType != null && summary.type != activityType) continue;
      final local = summary.startTime.toLocal();
      if (local.isBefore(bounds.start) || !local.isBefore(bounds.end)) {
        continue;
      }
      total += switch (metric) {
        ChallengeMetric.distance => summary.distanceMeters,
        ChallengeMetric.movingTime => summary.movingTimeSeconds.toDouble(),
        ChallengeMetric.activityCount => 1,
      };
    }
    return total;
  }

  /// 0.0–1.0, clamped.
  double completionRatio(
    Iterable<ActivitySummary> summaries, {
    DateTime? reference,
  }) {
    if (targetValue <= 0) return 0;
    return (progressFrom(summaries, reference: reference) / targetValue)
        .clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        if (description != null) 'description': description,
        if (activityType != null) 'activityType': activityType!.toJson(),
        'metric': metric.toJson(),
        'targetValue': targetValue,
        'timeframe': timeframe.toJson(),
        'isCustom': isCustom,
        'createdAt': createdAt.toUtc().millisecondsSinceEpoch,
        'archived': archived,
      };

  factory Challenge.fromJson(Map<String, dynamic> json) => Challenge(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        activityType: json['activityType'] == null
            ? null
            : ActivityType.fromJson(json['activityType'] as String),
        metric: ChallengeMetric.fromJson(json['metric'] as String),
        targetValue: (json['targetValue'] as num).toDouble(),
        timeframe: ChallengeTimeframe.fromJson(json['timeframe'] as String),
        isCustom: json['isCustom'] as bool? ?? true,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          json['createdAt'] as int,
          isUtc: true,
        ),
        archived: json['archived'] as bool? ?? false,
      );

  /// Built-in challenges seeded on first launch. Fixed ids keep seeding
  /// idempotent across app restarts and survive export/import round-trips.
  static List<Challenge> defaults() {
    final now = DateTime.now().toUtc();
    return [
      Challenge(
        id: 'default-run-50k-monthly',
        title: 'Run 50 km this month',
        activityType: ActivityType.running,
        metric: ChallengeMetric.distance,
        targetValue: 50000,
        timeframe: ChallengeTimeframe.monthly,
        isCustom: false,
        createdAt: now,
      ),
      Challenge(
        id: 'default-ride-200k-monthly',
        title: 'Ride 200 km this month',
        activityType: ActivityType.cycling,
        metric: ChallengeMetric.distance,
        targetValue: 200000,
        timeframe: ChallengeTimeframe.monthly,
        isCustom: false,
        createdAt: now,
      ),
      Challenge(
        id: 'default-active-5h-weekly',
        title: '5 active hours this week',
        metric: ChallengeMetric.movingTime,
        targetValue: 5 * 3600,
        timeframe: ChallengeTimeframe.weekly,
        isCustom: false,
        createdAt: now,
      ),
      Challenge(
        id: 'default-100-activities-yearly',
        title: '100 activities this year',
        metric: ChallengeMetric.activityCount,
        targetValue: 100,
        timeframe: ChallengeTimeframe.yearly,
        isCustom: false,
        createdAt: now,
      ),
    ];
  }
}
