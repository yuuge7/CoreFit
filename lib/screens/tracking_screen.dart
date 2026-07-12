import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/tracking_service.dart';
import '../utils/activity_ui.dart';
import '../utils/format.dart';
import 'save_activity_screen.dart';

/// Live recording: map on top, stats + controls below.
class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final _mapController = MapController();
  bool _mapReady = false;

  static const _fallbackCenter = LatLng(45.9432, 24.9668);

  Future<void> _finish() async {
    final tracking = TrackingService.instance;
    if (tracking.distanceMeters < 10) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard activity?'),
          content: const Text('Almost no distance was recorded.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep recording'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (discard == true) {
        await tracking.discard();
        if (mounted) Navigator.of(context).pop();
      }
      return;
    }

    final activity = await tracking.finish();
    if (activity == null || !mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => SaveActivityScreen(activity: activity)),
    );
  }

  Future<bool> _confirmExit() async {
    final tracking = TrackingService.instance;
    if (!tracking.isActive) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop recording?'),
        content: const Text('Leaving will discard this activity.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continue'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (leave == true) {
      await tracking.discard();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final tracking = TrackingService.instance;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmExit() && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: ListenableBuilder(
        listenable: tracking,
        builder: (context, _) {
          final activity = tracking.activity;
          final type = activity?.type;
          final points = tracking.allPoints;
          final route = [
            for (final p in points) LatLng(p.latitude, p.longitude),
          ];
          final last = tracking.lastPosition;
          final current = last != null
              ? LatLng(last.latitude, last.longitude)
              : (route.isNotEmpty ? route.last : null);

          if (_mapReady && current != null && tracking.isRecording) {
            _mapController.move(current, _mapController.camera.zoom);
          }

          return Scaffold(
            appBar: AppBar(
              title: Text(type?.label ?? 'Recording'),
              backgroundColor: type?.color.withValues(alpha: 0.3),
            ),
            body: Column(
              children: [
                Expanded(
                  flex: 3,
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: current ?? _fallbackCenter,
                      initialZoom: 16,
                      onMapReady: () => _mapReady = true,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'dev.ionel.corefit',
                      ),
                      if (route.length >= 2)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: route,
                              strokeWidth: 4,
                              color: type?.color ?? Colors.deepOrange,
                            ),
                          ],
                        ),
                      if (current != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: current,
                              width: 20,
                              height: 20,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.blueAccent,
                                  border: Border.all(color: Colors.white, width: 3),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        if (tracking.isPaused)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('PAUSED — GPS off, time not counting'),
                          ),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _LiveStat(
                              label: 'Time',
                              value: Fmt.duration(tracking.movingTimeSeconds),
                            ),
                            _LiveStat(
                              label: 'Distance',
                              value: Fmt.distance(tracking.distanceMeters),
                            ),
                            _LiveStat(
                              label: (type?.usesPace ?? true) ? 'Pace' : 'Speed',
                              value: (type?.usesPace ?? true)
                                  ? Fmt.pace(tracking.avgPaceSecondsPerKm)
                                  : Fmt.speed(tracking.avgSpeedMps),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.tonalIcon(
                                icon: Icon(tracking.isPaused ? Icons.play_arrow : Icons.pause),
                                label: Text(tracking.isPaused ? 'Resume' : 'Pause'),
                                onPressed: () => tracking.isPaused
                                    ? tracking.resume()
                                    : tracking.pause(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
                                icon: const Icon(Icons.stop),
                                label: const Text('Finish'),
                                onPressed: _finish,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LiveStat extends StatelessWidget {
  const _LiveStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
