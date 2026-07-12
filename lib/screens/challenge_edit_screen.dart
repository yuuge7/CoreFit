import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/activity_type.dart';
import '../models/challenge.dart';
import '../services/database_service.dart';
import '../utils/activity_ui.dart';

/// Create or edit a custom challenge.
class ChallengeEditScreen extends StatefulWidget {
  const ChallengeEditScreen({super.key, this.existing});

  final Challenge? existing;

  @override
  State<ChallengeEditScreen> createState() => _ChallengeEditScreenState();
}

class _ChallengeEditScreenState extends State<ChallengeEditScreen> {
  late final TextEditingController _title;
  late final TextEditingController _target;
  ActivityType? _type;
  ChallengeMetric _metric = ChallengeMetric.distance;
  ChallengeTimeframe _timeframe = ChallengeTimeframe.monthly;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _title = TextEditingController(text: existing?.title ?? '');
    _type = existing?.activityType;
    _metric = existing?.metric ?? ChallengeMetric.distance;
    _timeframe = existing?.timeframe ?? ChallengeTimeframe.monthly;
    _target = TextEditingController(
      text: existing == null ? '' : _displayTarget(existing),
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _target.dispose();
    super.dispose();
  }

  /// Target is edited in friendly units (km / hours / count) and stored in
  /// base units (m / s / count).
  static String _displayTarget(Challenge c) => switch (c.metric) {
        ChallengeMetric.distance =>
          (c.targetValue / 1000).toStringAsFixed(0),
        ChallengeMetric.movingTime =>
          (c.targetValue / 3600).toStringAsFixed(0),
        ChallengeMetric.activityCount => c.targetValue.toStringAsFixed(0),
      };

  String get _targetUnit => switch (_metric) {
        ChallengeMetric.distance => 'km',
        ChallengeMetric.movingTime => 'hours',
        ChallengeMetric.activityCount => 'activities',
      };

  double? get _targetBaseUnits {
    final raw = double.tryParse(_target.text.replaceAll(',', '.'));
    if (raw == null || raw <= 0) return null;
    return switch (_metric) {
      ChallengeMetric.distance => raw * 1000,
      ChallengeMetric.movingTime => raw * 3600,
      ChallengeMetric.activityCount => raw,
    };
  }

  Future<void> _save() async {
    final target = _targetBaseUnits;
    final title = _title.text.trim();
    if (title.isEmpty || target == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and a positive target are required')),
      );
      return;
    }

    final existing = widget.existing;
    final challenge = Challenge(
      id: existing?.id ?? const Uuid().v4(),
      title: title,
      activityType: _type,
      metric: _metric,
      targetValue: target,
      timeframe: _timeframe,
      isCustom: existing?.isCustom ?? true,
      createdAt: existing?.createdAt ?? DateTime.now().toUtc(),
      archived: existing?.archived ?? false,
    );
    await DatabaseService.instance.saveChallenge(challenge);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'New challenge' : 'Edit challenge'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          Text('Activity type', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Any'),
                selected: _type == null,
                onSelected: (_) => setState(() => _type = null),
              ),
              for (final type in ActivityType.values)
                ChoiceChip(
                  avatar: Icon(type.icon, size: 18, color: type.color),
                  label: Text(type.label),
                  selected: _type == type,
                  onSelected: (_) => setState(() => _type = type),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Metric', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<ChallengeMetric>(
            segments: [
              for (final m in ChallengeMetric.values)
                ButtonSegment(value: m, label: Text(m.label)),
            ],
            selected: {_metric},
            onSelectionChanged: (s) => setState(() => _metric = s.first),
          ),
          const SizedBox(height: 24),
          Text('Timeframe', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<ChallengeTimeframe>(
            segments: [
              for (final t in ChallengeTimeframe.values)
                ButtonSegment(value: t, label: Text(t.label)),
            ],
            selected: {_timeframe},
            onSelectionChanged: (s) => setState(() => _timeframe = s.first),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _target,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Target',
              suffixText: _targetUnit,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Save challenge'),
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
