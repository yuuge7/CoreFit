import 'package:flutter/material.dart';

import '../models/activity_type.dart';

/// UI concerns for activity types live here so the models stay Flutter-free.
extension ActivityTypeUi on ActivityType {
  IconData get icon => switch (this) {
        ActivityType.running => Icons.directions_run,
        ActivityType.walking => Icons.directions_walk,
        ActivityType.cycling => Icons.directions_bike,
        ActivityType.hiking => Icons.hiking,
      };

  Color get color => switch (this) {
        ActivityType.running => Colors.deepOrange,
        ActivityType.walking => Colors.teal,
        ActivityType.cycling => Colors.indigoAccent,
        ActivityType.hiking => Colors.green,
      };

  /// Cycling shows speed; foot activities show pace.
  bool get usesPace => this != ActivityType.cycling;
}
