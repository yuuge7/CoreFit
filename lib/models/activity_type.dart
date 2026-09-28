/// Supported activity profiles.
///
/// Declaration order is display order in every picker. Persisted by name,
/// never by index, so reordering is safe.
enum ActivityType {
  walking,
  running,
  cycling,
  hiking;

  String get label => switch (this) {
        ActivityType.walking => 'Walking',
        ActivityType.running => 'Running',
        ActivityType.cycling => 'Cycling',
        ActivityType.hiking => 'Hiking',
      };

  /// Serialized as the enum name so exported JSON stays human-readable.
  String toJson() => name;

  static ActivityType fromJson(String value) => ActivityType.values.byName(value);
}
