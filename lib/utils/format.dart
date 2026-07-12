/// Display formatting for distances, durations, pace, speed.
class Fmt {
  Fmt._();

  /// "8.42 km" / "950 m".
  static String distance(double meters) {
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(2)} km';
    return '${meters.round()} m';
  }

  /// "1:04:32" / "24:07".
  static String duration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$m:$ss';
  }

  /// "5:32 /km", or "--" when not moving yet.
  static String pace(double? secondsPerKm) {
    if (secondsPerKm == null || secondsPerKm <= 0 || !secondsPerKm.isFinite) {
      return '--';
    }
    final m = secondsPerKm ~/ 60;
    final s = (secondsPerKm % 60).round().toString().padLeft(2, '0');
    return '$m:$s /km';
  }

  /// "24.3 km/h".
  static String speed(double metersPerSecond) =>
      '${(metersPerSecond * 3.6).toStringAsFixed(1)} km/h';

  /// "132 m" elevation.
  static String elevation(double meters) => '${meters.round()} m';
}
