import 'package:flutter/material.dart';

import '../models/activity_type.dart';
import '../services/database_service.dart';
import '../services/tracking_service.dart';
import '../utils/activity_ui.dart';
import '../utils/format.dart';
import '../widgets/activity_index_listener.dart';
import 'tracking_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with ActivityIndexListener {
  ActivityType _selectedType = ActivityType.walking;

  Future<void> _start() async {
    final tracking = TrackingService.instance;
    try {
      await tracking.start(_selectedType);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TrackingScreen()),
    );
    // Refresh week stats after returning from a recording.
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService.instance;
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final week = db.summariesInRange(monday, monday.add(const Duration(days: 7)));
    final weekDistance = week.fold(0.0, (s, a) => s + a.distanceMeters);
    final weekTime = week.fold(0, (s, a) => s + a.movingTimeSeconds);

    return Scaffold(
      appBar: AppBar(title: const Text('CoreFit')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _WeekStat(label: 'This week', value: Fmt.distance(weekDistance)),
                    _WeekStat(label: 'Time', value: Fmt.duration(weekTime)),
                    _WeekStat(label: 'Activities', value: '${week.length}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Activity', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final type in ActivityType.values)
                  ChoiceChip(
                    avatar: Icon(
                      type.icon,
                      color: _selectedType == type ? Colors.white : type.color,
                    ),
                    label: Text(type.label),
                    selected: _selectedType == type,
                    selectedColor: type.color,
                    onSelected: (_) => setState(() => _selectedType = type),
                  ),
              ],
            ),
            const Spacer(),
            SizedBox(
              height: 72,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _selectedType.color,
                  textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                icon: const Icon(Icons.play_arrow, size: 32),
                label: const Text('START'),
                onPressed: _start,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _WeekStat extends StatelessWidget {
  const _WeekStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleLarge),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
