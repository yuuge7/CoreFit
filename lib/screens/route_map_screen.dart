import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../widgets/route_map.dart';

/// Full-screen, freely zoomable view of an activity's route.
class RouteMapScreen extends StatelessWidget {
  const RouteMapScreen({
    super.key,
    required this.title,
    required this.route,
    required this.color,
  });

  final String title;
  final List<LatLng> route;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: RouteMap(route: route, color: color),
    );
  }
}
