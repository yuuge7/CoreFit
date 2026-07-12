import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/activity_summary.dart';
import '../models/activity_type.dart';
import '../services/database_service.dart';
import '../utils/activity_ui.dart';
import '../utils/format.dart';

enum _StatsMode { month, year }

/// Aggregated stats with Previous/Next navigation through past periods.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  _StatsMode _mode = _StatsMode.month;

  /// First day of the shown period (month or year).
  late DateTime _anchor;

  ActivityType? _typeFilter;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _anchor = DateTime(now.year, now.month);
  }

  bool get _atCurrentPeriod {
    final now = DateTime.now();
    return switch (_mode) {
      _StatsMode.month =>
        _anchor.year == now.year && _anchor.month == now.month,
      _StatsMode.year => _anchor.year == now.year,
    };
  }

  void _shift(int direction) {
    setState(() {
      _anchor = switch (_mode) {
        _StatsMode.month => DateTime(_anchor.year, _anchor.month + direction),
        _StatsMode.year => DateTime(_anchor.year + direction),
      };
    });
  }

  void _setMode(_StatsMode mode) {
    setState(() {
      _mode = mode;
      final now = DateTime.now();
      _anchor = switch (mode) {
        _StatsMode.month => DateTime(now.year, now.month),
        _StatsMode.year => DateTime(now.year),
      };
    });
  }

  List<ActivitySummary> get _summaries {
    final db = DatabaseService.instance;
    final all = switch (_mode) {
      _StatsMode.month => db.summariesForMonth(_anchor.year, _anchor.month),
      _StatsMode.year => db.summariesForYear(_anchor.year),
    };
    if (_typeFilter == null) return all;
    return all.where((s) => s.type == _typeFilter).toList();
  }

  String get _periodLabel => switch (_mode) {
        _StatsMode.month => DateFormat('MMMM yyyy').format(_anchor),
        _StatsMode.year => '${_anchor.year}',
      };

  /// Distance in km per bucket: day-of-month or month-of-year.
  List<double> get _buckets {
    final count = switch (_mode) {
      _StatsMode.month => DateTime(_anchor.year, _anchor.month + 1, 0).day,
      _StatsMode.year => 12,
    };
    final buckets = List<double>.filled(count, 0);
    for (final s in _summaries) {
      final local = s.startTime.toLocal();
      final index = switch (_mode) {
        _StatsMode.month => local.day - 1,
        _StatsMode.year => local.month - 1,
      };
      buckets[index] += s.distanceMeters / 1000;
    }
    return buckets;
  }

  @override
  Widget build(BuildContext context) {
    final summaries = _summaries;
    final totalDistance = summaries.fold(0.0, (s, a) => s + a.distanceMeters);
    final totalTime = summaries.fold(0, (s, a) => s + a.movingTimeSeconds);
    final totalElevation =
        summaries.fold(0.0, (s, a) => s + a.elevationGainMeters);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stats'),
        actions: [
          SegmentedButton<_StatsMode>(
            segments: const [
              ButtonSegment(value: _StatsMode.month, label: Text('Month')),
              ButtonSegment(value: _StatsMode.year, label: Text('Year')),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => _setMode(s.first),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Previous',
                onPressed: () => _shift(-1),
              ),
              Text(_periodLabel, style: Theme.of(context).textTheme.titleLarge),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Next',
                onPressed: _atCurrentPeriod ? null : () => _shift(1),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: _typeFilter == null,
                onSelected: (_) => setState(() => _typeFilter = null),
              ),
              for (final type in ActivityType.values)
                ChoiceChip(
                  avatar: Icon(type.icon, size: 18, color: type.color),
                  label: Text(type.label),
                  selected: _typeFilter == type,
                  onSelected: (_) => setState(() => _typeFilter = type),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _TotalStat('Distance', Fmt.distance(totalDistance)),
                  _TotalStat('Time', Fmt.duration(totalTime)),
                  _TotalStat('Elevation', Fmt.elevation(totalElevation)),
                  _TotalStat('Count', '${summaries.length}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Distance (km)',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: summaries.isEmpty
                ? const Center(child: Text('No activities in this period'))
                : _DistanceChart(
                    buckets: _buckets,
                    mode: _mode,
                    color: _typeFilter?.color ??
                        Theme.of(context).colorScheme.primary,
                  ),
          ),
        ],
      ),
    );
  }
}

class _DistanceChart extends StatelessWidget {
  const _DistanceChart({
    required this.buckets,
    required this.mode,
    required this.color,
  });

  final List<double> buckets;
  final _StatsMode mode;
  final Color color;

  @override
  Widget build(BuildContext context) {
    const monthLabels = [
      'J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D', // ignore: require_trailing_commas
    ];
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        gridData: const FlGridData(drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 36),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                final label = switch (mode) {
                  // Day numbers get crowded; label every 5th day.
                  _StatsMode.month =>
                    (i + 1) % 5 == 0 || i == 0 ? '${i + 1}' : '',
                  _StatsMode.year => monthLabels[i],
                };
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, _, rod, _) => BarTooltipItem(
              '${rod.toY.toStringAsFixed(1)} km',
              const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < buckets.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: buckets[i],
                  color: color,
                  width: mode == _StatsMode.month ? 5 : 14,
                  borderRadius: BorderRadius.circular(2),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TotalStat extends StatelessWidget {
  const _TotalStat(this.label, this.value);

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
