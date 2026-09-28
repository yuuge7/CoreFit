import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../models/activity.dart';
import '../services/database_service.dart';
import '../utils/activity_ui.dart';
import '../utils/format.dart';
import '../widgets/route_map.dart';
import 'route_map_screen.dart';
import 'save_activity_screen.dart';

/// Full activity view — loads the GPS track lazily from the activities box.
class ActivityDetailScreen extends StatefulWidget {
  const ActivityDetailScreen({super.key, required this.activityId});

  final String activityId;

  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  late Future<Activity?> _activity = _load();

  Future<Activity?> _load() =>
      DatabaseService.instance.getActivity(widget.activityId);

  Future<void> _edit(Activity activity) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SaveActivityScreen(activity: activity, isEditing: true),
      ),
    );
    if (saved != true || !mounted) return;
    setState(() => _activity = _load());
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Changes saved')));
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete activity?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await DatabaseService.instance.deleteActivity(widget.activityId);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Activity?>(
      future: _activity,
      builder: (context, snapshot) {
        final activity = snapshot.data;
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (activity == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Activity not found')),
          );
        }

        final route = [
          for (final segment in activity.segments)
            for (final p in segment.points) LatLng(p.latitude, p.longitude),
        ];
        final gearName = activity.gearId == null
            ? null
            : DatabaseService.instance.allGear
                .where((g) => g.id == activity.gearId)
                .map((g) => g.name)
                .firstOrNull;

        return Scaffold(
          appBar: AppBar(
            title: Text(activity.title),
            actions: [
              IconButton(
                tooltip: 'Edit',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _edit(activity),
              ),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline),
                onPressed: _delete,
              ),
            ],
          ),
          // Map sits outside the scroll view so its pan/pinch gestures never
          // compete with list scrolling.
          body: Column(
            children: [
              SizedBox(
                height: 300,
                child: route.length >= 2
                    ? RouteMap(
                        route: route,
                        color: activity.type.color,
                        onExpand: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RouteMapScreen(
                              title: activity.title,
                              route: route,
                              color: activity.type.color,
                            ),
                          ),
                        ),
                      )
                    : Container(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: const Center(child: Text('No GPS track')),
                      ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: [
                        Icon(activity.type.icon, color: activity.type.color),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('EEE, d MMM yyyy · HH:mm')
                              .format(activity.startTime.toLocal()),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 24,
                      runSpacing: 16,
                      children: [
                        _DetailStat('Distance', Fmt.distance(activity.distanceMeters)),
                        _DetailStat('Moving time', Fmt.duration(activity.movingTimeSeconds)),
                        _DetailStat('Elapsed', Fmt.duration(activity.elapsedTimeSeconds)),
                        _DetailStat(
                          activity.type.usesPace ? 'Avg pace' : 'Avg speed',
                          activity.type.usesPace
                              ? Fmt.pace(activity.avgPaceSecondsPerKm)
                              : Fmt.speed(activity.avgSpeedMps),
                        ),
                        _DetailStat('Elevation', Fmt.elevation(activity.elevationGainMeters)),
                        if (activity.perceivedExertion != null)
                          _DetailStat('Exertion', '${activity.perceivedExertion}/10'),
                        if (gearName != null) _DetailStat('Gear', gearName),
                      ],
                    ),
                    if (activity.description != null) ...[
                      const SizedBox(height: 16),
                      Text('Notes', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text(activity.description!),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DetailStat extends StatelessWidget {
  const _DetailStat(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}
