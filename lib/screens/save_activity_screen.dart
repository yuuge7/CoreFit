import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/activity.dart';
import '../models/gear.dart';
import '../services/database_service.dart';
import '../services/health_service.dart';
import '../utils/activity_ui.dart';
import '../utils/format.dart';

/// Post-activity save screen: title, notes, perceived exertion, gear.
class SaveActivityScreen extends StatefulWidget {
  const SaveActivityScreen({super.key, required this.activity});

  final Activity activity;

  @override
  State<SaveActivityScreen> createState() => _SaveActivityScreenState();
}

class _SaveActivityScreenState extends State<SaveActivityScreen> {
  late final TextEditingController _title;
  final _description = TextEditingController();
  int _exertion = 5;
  bool _exertionSet = false;
  String? _gearId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: _defaultTitle());
  }

  String _defaultTitle() {
    final hour = widget.activity.startTime.toLocal().hour;
    final part = switch (hour) {
      >= 5 && < 12 => 'Morning',
      >= 12 && < 17 => 'Afternoon',
      >= 17 && < 21 => 'Evening',
      _ => 'Night',
    };
    return '$part ${widget.activity.type.label}';
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  List<Gear> get _availableGear => DatabaseService.instance.allGear
      .where((g) => !g.retired && g.appliesTo(widget.activity.type))
      .toList();

  Future<void> _addGear() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New gear'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Pegasus 41'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final gear = Gear(
      id: const Uuid().v4(),
      name: name,
      createdAt: DateTime.now().toUtc(),
      activityTypes: {widget.activity.type},
    );
    await DatabaseService.instance.saveGear(gear);
    setState(() => _gearId = gear.id);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final activity = widget.activity;
    activity.title = _title.text.trim().isEmpty ? _defaultTitle() : _title.text.trim();
    activity.description =
        _description.text.trim().isEmpty ? null : _description.text.trim();
    activity.perceivedExertion = _exertionSet ? _exertion : null;
    activity.gearId = _gearId;

    final db = DatabaseService.instance;
    await db.saveActivity(activity);

    var healthOk = true;
    if (db.healthSyncEnabled) {
      healthOk = await HealthService.instance.syncActivity(activity);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          healthOk
              ? 'Activity saved'
              : 'Saved locally — Health Connect sync failed',
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  Future<void> _discard() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard activity?'),
        content: const Text('The recording will be permanently lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final activity = widget.activity;
    final gear = _availableGear;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Save activity'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Icon(activity.type.icon, color: activity.type.color, size: 32),
                  _SummaryStat('Distance', Fmt.distance(activity.distanceMeters)),
                  _SummaryStat('Time', Fmt.duration(activity.movingTimeSeconds)),
                  _SummaryStat(
                    activity.type.usesPace ? 'Pace' : 'Speed',
                    activity.type.usesPace
                        ? Fmt.pace(activity.avgPaceSecondsPerKm)
                        : Fmt.speed(activity.avgSpeedMps),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _description,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Description / notes',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Perceived exertion: ${_exertionSet ? _exertion : 'not set'}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Slider(
            value: _exertion.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            label: '$_exertion',
            onChanged: (v) => setState(() {
              _exertion = v.round();
              _exertionSet = true;
            }),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: _gearId,
                  decoration: const InputDecoration(
                    labelText: 'Gear',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    for (final g in gear)
                      DropdownMenuItem(value: g.id, child: Text(g.name)),
                  ],
                  onChanged: (v) => setState(() => _gearId = v),
                ),
              ),
              IconButton(
                tooltip: 'Add gear',
                icon: const Icon(Icons.add),
                onPressed: _addGear,
              ),
            ],
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Save'),
            onPressed: _saving ? null : _save,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _saving ? null : _discard,
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleMedium),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
