/// A single GPS fix recorded during an activity.
///
/// JSON keys are deliberately short (`lat`, `lng`, `ele`, `t`, ...) because an
/// activity can contain thousands of points and these dominate export size.
/// Timestamps are epoch milliseconds (UTC) for the same reason.
class TrackPoint {
  const TrackPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.elevation,
    this.speed,
    this.accuracy,
  });

  final double latitude;
  final double longitude;
  final DateTime timestamp;

  /// Altitude in meters, if the fix provided one.
  final double? elevation;

  /// Instantaneous speed in m/s as reported by the GPS fix.
  final double? speed;

  /// Horizontal accuracy radius in meters. Useful for filtering bad fixes.
  final double? accuracy;

  Map<String, dynamic> toJson() => {
        'lat': latitude,
        'lng': longitude,
        't': timestamp.toUtc().millisecondsSinceEpoch,
        if (elevation != null) 'ele': elevation,
        if (speed != null) 'spd': speed,
        if (accuracy != null) 'acc': accuracy,
      };

  factory TrackPoint.fromJson(Map<String, dynamic> json) => TrackPoint(
        latitude: (json['lat'] as num).toDouble(),
        longitude: (json['lng'] as num).toDouble(),
        timestamp:
            DateTime.fromMillisecondsSinceEpoch(json['t'] as int, isUtc: true),
        elevation: (json['ele'] as num?)?.toDouble(),
        speed: (json['spd'] as num?)?.toDouble(),
        accuracy: (json['acc'] as num?)?.toDouble(),
      );
}
