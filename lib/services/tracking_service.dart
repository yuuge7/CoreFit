import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' hide ActivityType;
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:uuid/uuid.dart';

import '../models/activity.dart';
import '../models/activity_segment.dart';
import '../models/activity_type.dart';
import '../models/track_point.dart';
import '../utils/geo.dart';

enum TrackingState { idle, recording, paused }

/// Records one activity at a time from the GPS stream.
///
/// Battery strategy:
/// - Per-activity-type `distanceFilter` (below): no GPS callbacks — and no
///   wakeups — while stationary or between filter steps.
/// - Pausing *cancels* the position stream entirely; GPS is off while paused.
/// - Background recording uses geolocator's Android foreground service
///   (notification while tracking) instead of a separate always-on service —
///   the service exists only for the duration of the recording.
/// - Fixes worse than [_maxAccuracyMeters] are dropped, which also prevents
///   indoor GPS noise from inflating distance.
class TrackingService extends ChangeNotifier {
  TrackingService._();

  static final TrackingService instance = TrackingService._();

  static const _uuid = Uuid();

  /// Horizontal accuracy cutoff — fixes worse than this are ignored.
  static const _maxAccuracyMeters = 35.0;

  TrackingState _state = TrackingState.idle;
  Activity? _activity;
  StreamSubscription<Position>? _positionSub;
  Timer? _ticker;

  // Live-updated stats; reconciled by recalculateStats on pause/finish.
  double _liveDistance = 0;
  TrackPoint? _lastPoint;
  Position? _lastRawPosition;

  TrackingState get state => _state;
  bool get isRecording => _state == TrackingState.recording;
  bool get isPaused => _state == TrackingState.paused;
  bool get isActive => _state != TrackingState.idle;

  Activity? get activity => _activity;
  double get distanceMeters => _liveDistance;
  Position? get lastPosition => _lastRawPosition;

  int get movingTimeSeconds {
    final activity = _activity;
    if (activity == null) return 0;
    return activity.segments
        .fold(0, (sum, s) => sum + s.duration.inSeconds);
  }

  /// Current average pace over moving time, seconds per km.
  double? get avgPaceSecondsPerKm =>
      _liveDistance > 0 ? movingTimeSeconds / (_liveDistance / 1000) : null;

  double get avgSpeedMps =>
      movingTimeSeconds > 0 ? _liveDistance / movingTimeSeconds : 0;

  /// Route so far, for the live map polyline.
  List<TrackPoint> get allPoints => [
        for (final segment in _activity?.segments ?? <ActivitySegment>[])
          ...segment.points,
      ];

  /// Distance filter in meters per activity type. Coarser filters mean fewer
  /// GPS callbacks (better battery) at the cost of route detail; faster
  /// activities can afford coarser filters without losing shape.
  static int _distanceFilterFor(ActivityType type) => switch (type) {
        ActivityType.running => 5,
        ActivityType.walking => 5,
        ActivityType.cycling => 10,
        ActivityType.hiking => 8,
      };

  /// Throws with a user-readable message when permissions are missing.
  Future<void> _ensurePermissions() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('Location services are disabled. Enable GPS first.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Location permission denied. Grant it in Settings.');
    }
    // Android 13+: the foreground-service notification needs this; tracking
    // works without it but the user wouldn't see the recording notification.
    await ph.Permission.notification.request();
  }

  Future<void> start(ActivityType type) async {
    if (_state != TrackingState.idle) return;
    await _ensurePermissions();

    final now = DateTime.now().toUtc();
    _activity = Activity(
      id: _uuid.v4(),
      type: type,
      startTime: now,
      segments: [ActivitySegment(startTime: now)],
    );
    _liveDistance = 0;
    _lastPoint = null;
    _state = TrackingState.recording;

    await _subscribe(type);
    _startTicker();
    notifyListeners();
  }

  Future<void> _subscribe(ActivityType type) async {
    final settings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: _distanceFilterFor(type),
      intervalDuration: const Duration(seconds: 2),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'CoreFit is recording',
        notificationText: 'Activity tracking in progress',
        notificationChannelName: 'Activity tracking',
        enableWakeLock: true,
      ),
    );
    _positionSub =
        Geolocator.getPositionStream(locationSettings: settings).listen(
      _onPosition,
      onError: (Object _) {
        // GPS hiccup (tunnel, signal loss). Keep the session; points resume
        // when the stream recovers.
      },
    );
  }

  void _onPosition(Position position) {
    final activity = _activity;
    if (activity == null || _state != TrackingState.recording) return;
    _lastRawPosition = position;

    final accuracy = position.accuracy;
    if (accuracy > _maxAccuracyMeters) return;

    final point = TrackPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: position.timestamp.toUtc(),
      elevation: position.altitude,
      speed: position.speed,
      accuracy: accuracy,
    );

    final segment = activity.segments.last;
    final last = _lastPoint;
    // Only accumulate distance within the current segment — a fresh segment
    // after resume starts its own chain, so the pause gap is never counted.
    if (last != null && segment.points.isNotEmpty) {
      _liveDistance += Geo.distanceBetween(
        last.latitude,
        last.longitude,
        point.latitude,
        point.longitude,
      );
    }
    segment.points.add(point);
    _lastPoint = point;
    notifyListeners();
  }

  /// Closes the current segment and shuts GPS off until resume.
  Future<void> pause() async {
    if (_state != TrackingState.recording) return;
    _activity!.segments.last.endTime = DateTime.now().toUtc();
    await _positionSub?.cancel();
    _positionSub = null;
    _stopTicker();
    _state = TrackingState.paused;
    _reconcileStats();
    notifyListeners();
  }

  /// Opens a new segment and re-subscribes to GPS.
  Future<void> resume() async {
    final activity = _activity;
    if (_state != TrackingState.paused || activity == null) return;
    activity.segments.add(
      ActivitySegment(startTime: DateTime.now().toUtc()),
    );
    _lastPoint = null; // Break the distance chain across the pause gap.
    _state = TrackingState.recording;
    await _subscribe(activity.type);
    _startTicker();
    notifyListeners();
  }

  /// Stops recording and returns the finished activity (not yet persisted —
  /// the save screen decides that). Returns null if nothing was recorded.
  Future<Activity?> finish() async {
    final activity = _activity;
    if (activity == null) return null;

    final now = DateTime.now().toUtc();
    if (activity.segments.isNotEmpty &&
        activity.segments.last.endTime == null) {
      activity.segments.last.endTime = now;
    }
    activity.endTime = now;
    activity.recalculateStats();

    await _positionSub?.cancel();
    _positionSub = null;
    _stopTicker();
    _state = TrackingState.idle;
    _activity = null;
    _lastPoint = null;
    _lastRawPosition = null;
    notifyListeners();
    return activity;
  }

  /// Abandons the current recording without returning it.
  Future<void> discard() async {
    await finish();
  }

  void _reconcileStats() {
    final activity = _activity;
    if (activity == null) return;
    activity.recalculateStats();
    _liveDistance = activity.distanceMeters;
  }

  // Once-a-second UI tick for the moving-time display. Display only — a
  // missed tick (Doze, backgrounded UI) costs nothing because times derive
  // from segment timestamps, not from tick counting.
  void _startTicker() {
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      notifyListeners();
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }
}
