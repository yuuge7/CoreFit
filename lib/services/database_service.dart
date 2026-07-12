import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';

import '../models/activity.dart';
import '../models/activity_summary.dart';
import '../models/challenge.dart';
import '../models/gear.dart';

/// Local persistence, backed by Hive CE. No cloud, no accounts.
///
/// Records are stored as JSON strings rather than Hive type adapters:
/// - no codegen / adapter registration to maintain,
/// - the on-disk format IS the export format, so export/import is a
///   straight dump/load with zero mapping code.
///
/// Two-box layout for activities:
/// - [_activities] is a *lazy* box holding full activities including GPS
///   tracks. Values stay on disk until explicitly read.
/// - [_index] is a regular (in-memory) box of [ActivitySummary] records.
///   All list/stats/challenge queries run against this, so scanning years of
///   history never touches track-point data.
class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  static const _activitiesBoxName = 'activities';
  static const _indexBoxName = 'activity_index';
  static const _challengesBoxName = 'challenges';
  static const _gearBoxName = 'gear';
  static const _settingsBoxName = 'settings';

  /// Bumped when the export schema changes; import can migrate on it.
  static const exportSchemaVersion = 1;

  late LazyBox<String> _activities;
  late Box<String> _index;
  late Box<String> _challenges;
  late Box<String> _gear;
  late Box<String> _settings;

  bool _initialized = false;

  /// Call once before runApp.
  Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();
    _activities = await Hive.openLazyBox<String>(_activitiesBoxName);
    _index = await Hive.openBox<String>(_indexBoxName);
    _challenges = await Hive.openBox<String>(_challengesBoxName);
    _gear = await Hive.openBox<String>(_gearBoxName);
    _settings = await Hive.openBox<String>(_settingsBoxName);
    _seedDefaultChallenges();
    _initialized = true;
  }

  // ---------------------------------------------------------------- activities

  /// Persists the full activity and refreshes its summary in the index.
  Future<void> saveActivity(Activity activity) async {
    activity.recalculateStats();
    await _activities.put(activity.id, jsonEncode(activity.toJson()));
    await _index.put(activity.id, jsonEncode(activity.toSummary().toJson()));
  }

  /// Loads one full activity (with GPS track) from disk.
  Future<Activity?> getActivity(String id) async {
    final raw = await _activities.get(id);
    if (raw == null) return null;
    return Activity.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> deleteActivity(String id) async {
    await _activities.delete(id);
    await _index.delete(id);
  }

  /// All summaries, newest first.
  List<ActivitySummary> get allSummaries {
    final summaries = _index.values
        .map((raw) =>
            ActivitySummary.fromJson(jsonDecode(raw) as Map<String, dynamic>))
        .toList();
    summaries.sort((a, b) => b.startTime.compareTo(a.startTime));
    return summaries;
  }

  /// Summaries with startTime in [start, end), newest first. This is the
  /// workhorse for the stats tab's month/year pagination and for challenge
  /// progress.
  List<ActivitySummary> summariesInRange(DateTime start, DateTime end) =>
      allSummaries
          .where((s) =>
              !s.startTime.toLocal().isBefore(start) &&
              s.startTime.toLocal().isBefore(end))
          .toList();

  List<ActivitySummary> summariesForMonth(int year, int month) =>
      summariesInRange(DateTime(year, month), DateTime(year, month + 1));

  List<ActivitySummary> summariesForYear(int year) =>
      summariesInRange(DateTime(year), DateTime(year + 1));

  // ---------------------------------------------------------------- challenges

  List<Challenge> get challenges => _challenges.values
      .map((raw) => Challenge.fromJson(jsonDecode(raw) as Map<String, dynamic>))
      .toList();

  Future<void> saveChallenge(Challenge challenge) =>
      _challenges.put(challenge.id, jsonEncode(challenge.toJson()));

  /// Built-in defaults are archived instead of deleted so they never get
  /// re-seeded on next launch.
  Future<void> deleteChallenge(Challenge challenge) async {
    if (challenge.isCustom) {
      await _challenges.delete(challenge.id);
    } else {
      challenge.archived = true;
      await saveChallenge(challenge);
    }
  }

  void _seedDefaultChallenges() {
    for (final challenge in Challenge.defaults()) {
      if (!_challenges.containsKey(challenge.id)) {
        _challenges.put(challenge.id, jsonEncode(challenge.toJson()));
      }
    }
  }

  // ---------------------------------------------------------------------- gear

  List<Gear> get allGear => _gear.values
      .map((raw) => Gear.fromJson(jsonDecode(raw) as Map<String, dynamic>))
      .toList();

  Future<void> saveGear(Gear gear) =>
      _gear.put(gear.id, jsonEncode(gear.toJson()));

  Future<void> deleteGear(String id) => _gear.delete(id);

  // ------------------------------------------------------------------ settings

  bool get healthSyncEnabled => _settings.get('healthSync') == 'true';

  Future<void> setHealthSyncEnabled(bool value) =>
      _settings.put('healthSync', value.toString());

  // ------------------------------------------------------------- export/import

  /// Serializes the entire database into one JSON-encodable map. A later
  /// phase writes this to Downloads; the data layer is already complete.
  Future<Map<String, dynamic>> exportData() async {
    final activities = <Map<String, dynamic>>[];
    for (final key in _activities.keys) {
      final raw = await _activities.get(key);
      if (raw != null) {
        activities.add(jsonDecode(raw) as Map<String, dynamic>);
      }
    }
    return {
      'schemaVersion': exportSchemaVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'activities': activities,
      'challenges': challenges.map((c) => c.toJson()).toList(),
      'gear': allGear.map((g) => g.toJson()).toList(),
    };
  }

  /// Merges an export back in. Records win by id (imported data overwrites
  /// local records with the same id, everything else is untouched), so
  /// importing the same file twice is harmless.
  Future<ImportResult> importData(Map<String, dynamic> data) async {
    final version = data['schemaVersion'] as int? ?? 1;
    if (version > exportSchemaVersion) {
      throw FormatException(
        'Export schema v$version is newer than this app supports '
        '(v$exportSchemaVersion).',
      );
    }

    var activityCount = 0;
    for (final entry in data['activities'] as List<dynamic>? ?? []) {
      final activity =
          Activity.fromJson(Map<String, dynamic>.from(entry as Map));
      await saveActivity(activity);
      activityCount++;
    }

    var challengeCount = 0;
    for (final entry in data['challenges'] as List<dynamic>? ?? []) {
      final challenge =
          Challenge.fromJson(Map<String, dynamic>.from(entry as Map));
      await saveChallenge(challenge);
      challengeCount++;
    }

    var gearCount = 0;
    for (final entry in data['gear'] as List<dynamic>? ?? []) {
      final gear = Gear.fromJson(Map<String, dynamic>.from(entry as Map));
      await saveGear(gear);
      gearCount++;
    }

    return ImportResult(
      activities: activityCount,
      challenges: challengeCount,
      gear: gearCount,
    );
  }
}

class ImportResult {
  const ImportResult({
    required this.activities,
    required this.challenges,
    required this.gear,
  });

  final int activities;
  final int challenges;
  final int gear;
}
