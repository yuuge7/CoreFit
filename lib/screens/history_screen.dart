import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/database_service.dart';
import '../utils/activity_ui.dart';
import '../utils/format.dart';
import 'activity_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  Widget build(BuildContext context) {
    final summaries = DatabaseService.instance.allSummaries;

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: summaries.isEmpty
          ? const Center(child: Text('No activities yet — go record one!'))
          : ListView.builder(
              itemCount: summaries.length,
              itemBuilder: (context, i) {
                final s = summaries[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: s.type.color.withValues(alpha: 0.2),
                    child: Icon(s.type.icon, color: s.type.color),
                  ),
                  title: Text(s.title),
                  subtitle: Text(
                    DateFormat('d MMM yyyy').format(s.startTime.toLocal()),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(Fmt.distance(s.distanceMeters)),
                      Text(
                        Fmt.duration(s.movingTimeSeconds),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ActivityDetailScreen(activityId: s.id),
                      ),
                    );
                    setState(() {}); // Refresh after possible delete.
                  },
                );
              },
            ),
    );
  }
}
