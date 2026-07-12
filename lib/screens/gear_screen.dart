import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/activity_type.dart';
import '../models/gear.dart';
import '../services/database_service.dart';
import '../utils/activity_ui.dart';
import '../utils/format.dart';

class GearScreen extends StatefulWidget {
  const GearScreen({super.key});

  @override
  State<GearScreen> createState() => _GearScreenState();
}

class _GearScreenState extends State<GearScreen> {
  /// Lifetime distance per gear, derived from the summary index.
  double _distanceFor(String gearId) => DatabaseService.instance.allSummaries
      .where((s) => s.gearId == gearId)
      .fold(0.0, (sum, s) => sum + s.distanceMeters);

  Future<void> _edit([Gear? existing]) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final types = {...existing?.activityTypes ?? <ActivityType>{}};

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'New gear' : 'Edit gear'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: existing == null,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  for (final type in ActivityType.values)
                    FilterChip(
                      avatar: Icon(type.icon, size: 18),
                      label: Text(type.label),
                      selected: types.contains(type),
                      onSelected: (on) => setDialogState(() {
                        on ? types.add(type) : types.remove(type);
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'No selection = usable for all types',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved != true || name.text.trim().isEmpty) return;
    final gear = existing ??
        Gear(
          id: const Uuid().v4(),
          name: '',
          createdAt: DateTime.now().toUtc(),
        );
    gear.name = name.text.trim();
    gear.activityTypes
      ..clear()
      ..addAll(types);
    await DatabaseService.instance.saveGear(gear);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final gear = DatabaseService.instance.allGear
      ..sort((a, b) => a.name.compareTo(b.name));

    return Scaffold(
      appBar: AppBar(title: const Text('Gear')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(),
        child: const Icon(Icons.add),
      ),
      body: gear.isEmpty
          ? const Center(child: Text('No gear yet — add shoes or a bike with +'))
          : ListView(
              children: [
                for (final g in gear)
                  ListTile(
                    leading: Icon(
                      g.activityTypes.length == 1
                          ? g.activityTypes.first.icon
                          : Icons.checkroom,
                    ),
                    title: Text(
                      g.name,
                      style: g.retired
                          ? const TextStyle(
                              decoration: TextDecoration.lineThrough)
                          : null,
                    ),
                    subtitle: Text(
                      '${Fmt.distance(_distanceFor(g.id))} total'
                      '${g.retired ? ' · retired' : ''}',
                    ),
                    onTap: () => _edit(g),
                    trailing: IconButton(
                      tooltip: g.retired ? 'Unretire' : 'Retire',
                      icon: Icon(
                        g.retired ? Icons.restore : Icons.archive_outlined,
                      ),
                      onPressed: () async {
                        g.retired = !g.retired;
                        await DatabaseService.instance.saveGear(g);
                        setState(() {});
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}
