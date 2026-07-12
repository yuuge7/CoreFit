/// Supported activity profiles.
enum ActivityType {
  running,
  walking,
  cycling,
  hiking;

  String get label => switch (this) {
        ActivityType.running => 'Running',
        ActivityType.walking => 'Walking',
        ActivityType.cycling => 'Cycling',
        ActivityType.hiking => 'Hiking',
      };

  /// Serialized as the enum name so exported JSON stays human-readable.
  String toJson() => name;

  static ActivityType fromJson(String value) => ActivityType.values.byName(value);
}
