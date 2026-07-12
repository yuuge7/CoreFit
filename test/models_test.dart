import 'package:corefit/models/activity.dart';
import 'package:corefit/models/activity_segment.dart';
import 'package:corefit/models/activity_summary.dart';
import 'package:corefit/models/activity_type.dart';
import 'package:corefit/models/challenge.dart';
import 'package:corefit/models/gear.dart';
import 'package:corefit/models/track_point.dart';
import 'package:corefit/utils/geo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Geo', () {
    test('haversine distance is roughly correct', () {
      // ~111.19 km per degree of latitude at the equator.
      final d = Geo.distanceBetween(0, 0, 1, 0);
      expect(d, closeTo(111195, 200));
    });

    test('elevation gain ignores jitter below threshold, sums real climbs',
        () {
      final t = DateTime.utc(2026);
      TrackPoint p(double ele) => TrackPoint(
            latitude: 0,
            longitude: 0,
            timestamp: t,
            elevation: ele,
          );
      // 100 -> 100.5 (jitter, ignored) -> 110 (+9.5 from 100) -> 105 -> 112 (+7)
      final points = [p(100), p(100.5), p(110), p(105), p(112)];
      expect(Geo.elevationGain(points), closeTo(17, 0.01));
    });
  });

  group('Activity pause/resume', () {
    test('moving time excludes paused gaps, elapsed includes them', () {
      final start = DateTime.utc(2026, 7, 11, 8);
      final activity = Activity(
        id: 'a1',
        type: ActivityType.running,
        startTime: start,
        endTime: start.add(const Duration(minutes: 30)),
        segments: [
          // 10 min moving, then 10 min paused, then 10 min moving.
          ActivitySegment(
            startTime: start,
            endTime: start.add(const Duration(minutes: 10)),
          ),
          ActivitySegment(
            startTime: start.add(const Duration(minutes: 20)),
            endTime: start.add(const Duration(minutes: 30)),
          ),
        ],
      );
      activity.recalculateStats();

      expect(activity.movingTimeSeconds, 20 * 60);
      expect(activity.elapsedTimeSeconds, 30 * 60);
    });

    test('distance sums only segment content', () {
      final start = DateTime.utc(2026, 7, 11, 8);
      TrackPoint p(double lat, int minute) => TrackPoint(
            latitude: lat,
            longitude: 0,
            timestamp: start.add(Duration(minutes: minute)),
          );
      final activity = Activity(
        id: 'a2',
        type: ActivityType.cycling,
        startTime: start,
        segments: [
          ActivitySegment(
            startTime: start,
            endTime: start.add(const Duration(minutes: 5)),
            points: [p(0, 0), p(0.01, 5)],
          ),
          // Gap between segments (paused, rider moved in a car, etc.) —
          // must NOT count toward distance.
          ActivitySegment(
            startTime: start.add(const Duration(minutes: 15)),
            endTime: start.add(const Duration(minutes: 20)),
            points: [p(0.05, 15), p(0.06, 20)],
          ),
        ],
      );
      activity.recalculateStats();

      // Two 0.01-degree hops (~1112 m each); the 0.04-degree pause gap
      // (~4448 m) is excluded.
      expect(activity.distanceMeters, closeTo(2 * 1112, 20));
    });
  });

  group('JSON round-trips', () {
    test('Activity survives toJson/fromJson', () {
      final start = DateTime.utc(2026, 7, 11, 8);
      final activity = Activity(
        id: 'a3',
        type: ActivityType.hiking,
        startTime: start,
        endTime: start.add(const Duration(hours: 2)),
        segments: [
          ActivitySegment(
            startTime: start,
            endTime: start.add(const Duration(hours: 2)),
            points: [
              TrackPoint(
                latitude: 45.5,
                longitude: 25.5,
                timestamp: start,
                elevation: 800,
                speed: 1.4,
                accuracy: 5,
              ),
            ],
          ),
        ],
        title: 'Morning hike',
        description: 'Foggy',
        perceivedExertion: 7,
        gearId: 'boots-1',
      );
      activity.recalculateStats();

      final restored = Activity.fromJson(activity.toJson());

      expect(restored.id, activity.id);
      expect(restored.type, activity.type);
      expect(restored.startTime, activity.startTime);
      expect(restored.endTime, activity.endTime);
      expect(restored.title, 'Morning hike');
      expect(restored.description, 'Foggy');
      expect(restored.perceivedExertion, 7);
      expect(restored.gearId, 'boots-1');
      expect(restored.segments.single.points.single.elevation, 800);
      expect(restored.movingTimeSeconds, activity.movingTimeSeconds);
    });

    test('Challenge and Gear survive round-trips', () {
      final challenge = Challenge(
        id: 'c1',
        title: 'Ride 100 km',
        activityType: ActivityType.cycling,
        metric: ChallengeMetric.distance,
        targetValue: 100000,
        timeframe: ChallengeTimeframe.weekly,
        createdAt: DateTime.utc(2026),
      );
      final restoredChallenge = Challenge.fromJson(challenge.toJson());
      expect(restoredChallenge.activityType, ActivityType.cycling);
      expect(restoredChallenge.metric, ChallengeMetric.distance);
      expect(restoredChallenge.timeframe, ChallengeTimeframe.weekly);
      expect(restoredChallenge.isCustom, isTrue);

      final gear = Gear(
        id: 'g1',
        name: 'Trail shoes',
        createdAt: DateTime.utc(2026),
        activityTypes: {ActivityType.running, ActivityType.hiking},
      );
      final restoredGear = Gear.fromJson(gear.toJson());
      expect(restoredGear.activityTypes,
          {ActivityType.running, ActivityType.hiking});
      expect(restoredGear.appliesTo(ActivityType.hiking), isTrue);
      expect(restoredGear.appliesTo(ActivityType.cycling), isFalse);
    });
  });

  group('Challenge periods and progress', () {
    ActivitySummary summary({
      required String id,
      required DateTime startTime,
      ActivityType type = ActivityType.running,
      double distance = 10000,
      int movingTime = 3600,
    }) =>
        ActivitySummary(
          id: id,
          type: type,
          startTime: startTime,
          distanceMeters: distance,
          movingTimeSeconds: movingTime,
          elapsedTimeSeconds: movingTime,
          elevationGainMeters: 0,
          title: id,
        );

    test('weekly bounds start on Monday', () {
      final challenge = Challenge(
        id: 'c2',
        title: 'w',
        metric: ChallengeMetric.distance,
        targetValue: 1,
        timeframe: ChallengeTimeframe.weekly,
        createdAt: DateTime.utc(2026),
      );
      // 2026-07-11 is a Saturday; its week starts Monday 2026-07-06.
      final bounds = challenge.periodBounds(DateTime(2026, 7, 11, 15));
      expect(bounds.start, DateTime(2026, 7, 6));
      expect(bounds.end, DateTime(2026, 7, 13));
    });

    test('progress filters by type and period, supports past reference', () {
      final challenge = Challenge(
        id: 'c3',
        title: 'Run 50 km monthly',
        activityType: ActivityType.running,
        metric: ChallengeMetric.distance,
        targetValue: 50000,
        timeframe: ChallengeTimeframe.monthly,
        createdAt: DateTime.utc(2026),
      );
      final summaries = [
        summary(id: 'july-run', startTime: DateTime(2026, 7, 5, 9)),
        summary(id: 'july-ride', startTime: DateTime(2026, 7, 6, 9), type: ActivityType.cycling),
        summary(id: 'june-run', startTime: DateTime(2026, 6, 20, 9), distance: 20000),
      ];

      expect(
        challenge.progressFrom(summaries, reference: DateTime(2026, 7, 15)),
        10000, // only july-run: ride is wrong type, june is wrong period
      );
      expect(
        challenge.progressFrom(summaries, reference: DateTime(2026, 6, 15)),
        20000, // historical navigation: June's period sees june-run
      );
      expect(
        challenge.completionRatio(summaries, reference: DateTime(2026, 6, 15)),
        closeTo(0.4, 1e-9),
      );
    });

    test('activityCount metric counts activities', () {
      final challenge = Challenge(
        id: 'c4',
        title: 'count',
        metric: ChallengeMetric.activityCount,
        targetValue: 10,
        timeframe: ChallengeTimeframe.yearly,
        createdAt: DateTime.utc(2026),
      );
      final summaries = [
        summary(id: '1', startTime: DateTime(2026, 1, 10)),
        summary(id: '2', startTime: DateTime(2026, 7, 10), type: ActivityType.hiking),
        summary(id: '3', startTime: DateTime(2025, 12, 31)),
      ];
      expect(
        challenge.progressFrom(summaries, reference: DateTime(2026, 7, 11)),
        2,
      );
    });
  });
}
