import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// OSM serves tiles up to z19; zooming further only upscales pixels.
const double mapMinZoom = 3;
const double mapMaxZoom = 19;

/// Pan, pinch, double-tap zoom — everything except rotation, which has no
/// compass to reset it and mostly triggers by accident mid-pinch.
const int mapInteractionFlags = InteractiveFlag.all & ~InteractiveFlag.rotate;

TileLayer osmTileLayer() => TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'dev.ionel.corefit',
    );

/// Interactive map of a recorded route, with zoom and fit-to-route buttons.
/// [onExpand], when set, adds a button for opening a full-screen view.
class RouteMap extends StatefulWidget {
  const RouteMap({
    super.key,
    required this.route,
    required this.color,
    this.onExpand,
  });

  final List<LatLng> route;
  final Color color;
  final VoidCallback? onExpand;

  @override
  State<RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<RouteMap> {
  final _controller = MapController();

  CameraFit get _routeFit => CameraFit.coordinates(
        coordinates: widget.route,
        padding: const EdgeInsets.all(32),
        maxZoom: 17,
      );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCameraFit: _routeFit,
            minZoom: mapMinZoom,
            maxZoom: mapMaxZoom,
            interactionOptions:
                const InteractionOptions(flags: mapInteractionFlags),
          ),
          children: [
            osmTileLayer(),
            PolylineLayer(
              polylines: [
                Polyline(
                  points: widget.route,
                  strokeWidth: 4,
                  color: widget.color,
                ),
              ],
            ),
          ],
        ),
        Positioned(
          top: 8,
          right: 8,
          child: MapZoomControls(
            controller: _controller,
            onRecenter: () => _controller.fitCamera(_routeFit),
            onExpand: widget.onExpand,
          ),
        ),
      ],
    );
  }
}

/// Vertical stack of map buttons. Pinch works too, but buttons are the only
/// one-handed way to zoom and are discoverable.
class MapZoomControls extends StatelessWidget {
  const MapZoomControls({
    super.key,
    required this.controller,
    this.onRecenter,
    this.onExpand,
  });

  final MapController controller;
  final VoidCallback? onRecenter;
  final VoidCallback? onExpand;

  void _zoomBy(double delta) {
    final camera = controller.camera;
    controller.move(
      camera.center,
      (camera.zoom + delta).clamp(mapMinZoom, mapMaxZoom),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Zoom in',
            icon: const Icon(Icons.add),
            onPressed: () => _zoomBy(1),
          ),
          IconButton(
            tooltip: 'Zoom out',
            icon: const Icon(Icons.remove),
            onPressed: () => _zoomBy(-1),
          ),
          if (onRecenter != null)
            IconButton(
              tooltip: 'Fit route',
              icon: const Icon(Icons.center_focus_strong_outlined),
              onPressed: onRecenter,
            ),
          if (onExpand != null)
            IconButton(
              tooltip: 'Full screen',
              icon: const Icon(Icons.fullscreen),
              onPressed: onExpand,
            ),
        ],
      ),
    );
  }
}
