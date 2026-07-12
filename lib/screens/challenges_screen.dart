import 'package:flutter/material.dart';

import '../models/challenge.dart';
import '../services/database_service.dart';
import '../utils/activity_ui.dart';
import '../utils/format.dart';
import 'challenge_edit_screen.dart';

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  Future<void> _openEditor([Challenge? existing]) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChallengeEditScreen(existing: existing),
      ),
    );
    setState(() {});
  }

  Future<void> _remove(Challenge challenge) async {
    final isCustom = challenge.isCustom;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isCustom ? 'Delete challenge?' : 'Archive challenge?'),
        content: Text(
          isCustom
              ? '"${challenge.title}" will be deleted.'
              : 'Built-in challenges are hidden, not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(isCustom ? 'Delete' : 'Archive'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await DatabaseService.instance.deleteChallenge(challenge);
    setState(() {});
  }

  String _progressLabel(Challenge c, double progress) {
    switch (c.metric) {
      case ChallengeMetric.distance:
        return '${Fmt.distance(progress)} / ${Fmt.distance(c.targetValue)}';
      case ChallengeMetric.movingTime:
        return '${Fmt.duration(progress.round())} / ${Fmt.duration(c.targetValue.round())}';
      case ChallengeMetric.activityCount:
        return '${progress.round()} / ${c.targetValue.round()} activities';
    }
  }

  String _daysLeftLabel(Challenge c) {
    final bounds = c.periodBounds(DateTime.now());
    final left = bounds.end.difference(DateTime.now()).inDays;
    return left == 0 ? 'ends today' : '$left days left';
  }

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService.instance;
    final challenges = db.challenges.where((c) => !c.archived).toList()
      ..sort((a, b) => a.timeframe.index.compareTo(b.timeframe.index));
    final summaries = db.allSummaries;

    return Scaffold(
      appBar: AppBar(title: const Text('Challenges')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        child: const Icon(Icons.add),
      ),
      body: challenges.isEmpty
          ? const Center(child: Text('No challenges — add one with +'))
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: challenges.length,
              itemBuilder: (context, i) {
                final c = challenges[i];
                final progress = c.progressFrom(summaries);
                final ratio = c.completionRatio(summaries);
                final done = ratio >= 1.0;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              c.activityType?.icon ?? Icons.all_inclusive,
                              color: c.activityType?.color,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                c.title,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            if (done)
                              const Icon(Icons.emoji_events, color: Colors.amber),
                            PopupMenuButton<String>(
                              onSelected: (action) => switch (action) {
                                'edit' => _openEditor(c),
                                _ => _remove(c),
                              },
                              itemBuilder: (context) => [
                                if (c.isCustom)
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                PopupMenuItem(
                                  value: 'remove',
                                  child: Text(c.isCustom ? 'Delete' : 'Archive'),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: ratio,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                          color: done ? Colors.amber : c.activityType?.color,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_progressLabel(c, progress)),
                            Text(
                              '${c.timeframe.label} · ${_daysLeftLabel(c)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
