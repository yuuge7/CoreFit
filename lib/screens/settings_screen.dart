import 'package:flutter/material.dart';

import '../services/database_service.dart';
import '../services/export_service.dart';
import '../services/health_service.dart';
import 'gear_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleHealthSync(bool enable) async {
    final db = DatabaseService.instance;
    if (!enable) {
      await db.setHealthSyncEnabled(false);
      setState(() {});
      return;
    }
    setState(() => _busy = true);
    final authorized = await HealthService.instance.ensureAuthorized();
    await db.setHealthSyncEnabled(authorized);
    setState(() => _busy = false);
    if (!authorized) {
      _toast('Health Connect permission not granted');
    }
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final path = await ExportService.instance.exportToFile();
      if (path != null) _toast('Exported to $path');
    } catch (e) {
      _toast('Export failed: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    setState(() => _busy = true);
    try {
      final result = await ExportService.instance.importFromFile();
      if (result != null) {
        _toast(
          'Imported ${result.activities} activities, '
          '${result.challenges} challenges, ${result.gear} gear',
        );
      }
    } on FormatException catch (e) {
      _toast('Import failed: ${e.message}');
    } catch (e) {
      _toast('Import failed: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Ecosystem'),
          SwitchListTile(
            secondary: const Icon(Icons.favorite_outline),
            title: const Text('Sync to Health Connect'),
            subtitle: const Text('Write completed workouts as exercise sessions'),
            value: db.healthSyncEnabled,
            onChanged: _busy ? null : _toggleHealthSync,
          ),
          const _SectionHeader('Data'),
          ListTile(
            leading: const Icon(Icons.upload_outlined),
            title: const Text('Export all data'),
            subtitle: const Text('One JSON file with activities, challenges, gear'),
            enabled: !_busy,
            onTap: _export,
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Import data'),
            subtitle: const Text('Merge a previous export (same ids overwrite)'),
            enabled: !_busy,
            onTap: _import,
          ),
          const _SectionHeader('Equipment'),
          ListTile(
            leading: const Icon(Icons.checkroom),
            title: const Text('Manage gear'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const GearScreen()),
            ),
          ),
          const _SectionHeader('About'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('CoreFit'),
            subtitle: Text('Personal, offline fitness tracking. '
                'All data stays on this device.'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
