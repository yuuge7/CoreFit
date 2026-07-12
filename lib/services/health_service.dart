import 'package:health/health.dart';

import '../models/activity.dart' as models;
import '../models/activity_type.dart';

/// Writes completed workouts to Google Health Connect via the `health`
/// package. Write-only: this app never reads health data.
class HealthService {
  HealthService._();

  static final HealthService instance = HealthService._();

  final Health _health = Health();
  bool _configured = false;

  static const _types = [HealthDataType.WORKOUT];
  static const _permissions = [HealthDataAccess.WRITE];

  Future<void> _configure() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  /// True when Health Connect is usable and write permission is granted
  /// (requests it if needed).
  Future<bool> ensureAuthorized() async {
    await _configure();
    final granted =
        await _health.hasPermissions(_types, permissions: _permissions);
    if (granted == true) return true;
    return await _health.requestAuthorization(
      _types,
      permissions: _permissions,
    );
  }

  static HealthWorkoutActivityType _workoutType(ActivityType type) =>
      switch (type) {
        ActivityType.running => HealthWorkoutActivityType.RUNNING,
        ActivityType.walking => HealthWorkoutActivityType.WALKING,
        ActivityType.cycling => HealthWorkoutActivityType.BIKING,
        ActivityType.hiking => HealthWorkoutActivityType.HIKING,
      };

  /// Writes one finished activity as a Health Connect exercise session.
  /// Returns false (never throws) on failure — sync is best-effort and must
  /// not block saving locally.
  Future<bool> syncActivity(models.Activity activity) async {
    final end = activity.endTime;
    if (end == null) return false;
    try {
      if (!await ensureAuthorized()) return false;
      return await _health.writeWorkoutData(
        activityType: _workoutType(activity.type),
        start: activity.startTime,
        end: end,
        totalDistance: activity.distanceMeters.round(),
        totalDistanceUnit: HealthDataUnit.METER,
        title: activity.title,
      );
    } catch (_) {
      return false;
    }
  }
}
