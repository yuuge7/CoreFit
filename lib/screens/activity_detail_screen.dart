import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../models/activity.dart';
import '../services/database_service.dart';
import '../utils/activity_ui.dart';
import '../utils/format.dart';

/// Full activity view — loads the GPS track lazily from the activities box.
class ActivityDetailScreen extends StatelessWidget {
  const ActivityDetailScreen({super.key, required this.activityId});

  final String activityId;

  Future<void> _delete(BuildContext context) async {
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
    await DatabaseService.instance.deleteActivity(activityId);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Activity?>(
      future: DatabaseService.instance.getActivity(activityId),
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
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _delete(context),
              ),
            ],
          ),
          body: ListView(
            children: [
              SizedBox(
                height: 260,
                child: route.length >= 2
                    ? FlutterMap(
                        options: MapOptions(
                          initialCameraFit: CameraFit.coordinates(
                            coordinates: route,
                            padding: const EdgeInsets.all(24),
                          ),
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.none,
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'dev.ionel.corefit',
                          ),
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: route,
                                strokeWidth: 4,
                                color: activity.type.color,
                              ),
                            ],
                          ),
                        ],
                      )
                    : Container(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: const Center(child: Text('No GPS track')),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
