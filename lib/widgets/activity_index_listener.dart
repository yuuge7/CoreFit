import 'package:flutter/widgets.dart';

import '../services/database_service.dart';

/// Rebuilds a home tab whenever any activity is saved, edited, deleted or
/// imported. The tabs live in an IndexedStack and the shell never rebuilds
/// them, so without this they keep showing whatever they saw at startup.
mixin ActivityIndexListener<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    DatabaseService.instance.activityIndexChanged.addListener(_onIndexChanged);
  }

  @override
  void dispose() {
    DatabaseService.instance.activityIndexChanged
        .removeListener(_onIndexChanged);
    super.dispose();
  }

  void _onIndexChanged() {
    if (mounted) setState(() {});
  }
}
