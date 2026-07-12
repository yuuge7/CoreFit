import 'activity_type.dart';

/// A piece of equipment (shoes, bike, ...) that can be attached to activities.
///
/// Activities reference gear by [id] only; total distance per gear is derived
/// by summing matching activity summaries, so it never goes stale.
class Gear {
  Gear({
    required this.id,
    required this.name,
    required this.createdAt,
    Set<ActivityType>? activityTypes,
    this.retired = false,
  }) : activityTypes = activityTypes ?? {};

  final String id;
  String name;
  final DateTime createdAt;

  /// Which activity types this gear is offered for on the save screen.
  /// Empty set = offered for all types.
  final Set<ActivityType> activityTypes;

  /// Retired gear stays referenced by old activities but is hidden from the
  /// save screen picker.
  bool retired;

  bool appliesTo(ActivityType type) =>
      activityTypes.isEmpty || activityTypes.contains(type);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toUtc().millisecondsSinceEpoch,
        'activityTypes': activityTypes.map((t) => t.toJson()).toList(),
        'retired': retired,
      };

  factory Gear.fromJson(Map<String, dynamic> json) => Gear(
        id: json['id'] as String,
        name: json['name'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          json['createdAt'] as int,
          isUtc: true,
        ),
        activityTypes: (json['activityTypes'] as List<dynamic>? ?? [])
            .map((t) => ActivityType.fromJson(t as String))
            .toSet(),
        retired: json['retired'] as bool? ?? false,
      );
}
