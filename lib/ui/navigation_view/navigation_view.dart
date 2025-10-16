import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;
import 'mapbox_map_controller.dart';
import '../../core/interfaces/map_controller_interface.dart';
import '../../core/models/location_point.dart';
import '../../core/models/route_progress.dart';
import '../../core/models/route_result.dart';
import '../widgets/route_selection_widget.dart';

class NavigationView extends StatefulWidget {
  final MapControllerInterface? controller;
  final String mapboxAccessToken;
  final String? styleUrl;
  final LocationPoint? initialCenter;
  final double initialZoom;
  final bool enableLocation;
  final RouteProgress? routeProgress;
  final void Function(MapboxMapController)? onMapCreated;
  final VoidCallback? onFollowingLocationStopped;

  // Route selection parameters
  final List<RouteResult>? availableRoutes;
  final bool showRouteSelection;
  final Function(RouteResult)? onRouteSelected;
  final VoidCallback? onRouteSelectionCancelled;

  const NavigationView({
    super.key,
    this.controller,
    required this.mapboxAccessToken,
    this.styleUrl,
    this.initialCenter,
    this.initialZoom = 16.0,
    this.enableLocation = true,
    this.routeProgress,
    this.onMapCreated,
    this.availableRoutes,
    this.showRouteSelection = false,
    this.onRouteSelected,
    this.onRouteSelectionCancelled,
    this.onFollowingLocationStopped,
  });

  @override
  State<NavigationView> createState() => _NavigationViewState();
}

class _NavigationViewState extends State<NavigationView> {
  MapboxMapController? _mapController;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        mb.MapWidget(
          key: ValueKey('map_widget_${widget.mapboxAccessToken.hashCode}'),
          styleUri: widget.styleUrl ?? mb.MapboxStyles.STANDARD,
          cameraOptions: mb.CameraOptions(
            center: widget.initialCenter != null
                ? mb.Point(
                    coordinates: mb.Position(
                      widget.initialCenter!.longitude,
                      widget.initialCenter!.latitude,
                    ),
                  )
                : null,
            zoom: widget.initialZoom,
          ),
          onMapCreated: (mb.MapboxMap mapboxMap) {
            _mapController = MapboxMapController(mapboxMap);
            widget.onMapCreated?.call(_mapController!);
          },
          onStyleLoadedListener: (data) async {
            await _setupLocationPuck();
            await _setupCustomMarkers();
          },
          onScrollListener: (scrollEvent) {
            _mapController?.setFollowingLocation(false);
            widget.onFollowingLocationStopped?.call();
          },
          onZoomListener: (zoomChanged) {
            _mapController?.setFollowingLocation(false);
            widget.onFollowingLocationStopped?.call();
          },
        ),

        // Route selection overlay
        if (widget.showRouteSelection &&
            widget.availableRoutes != null &&
            widget.onRouteSelected != null)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: RouteSelectionWidget(
              routes: widget.availableRoutes!,
              onRouteSelected: widget.onRouteSelected!,
              onCancel: widget.onRouteSelectionCancelled,
            ),
          ),
      ],
    );
  }

  // Setup custom markers using AnnotationManager
  Future<void> _setupCustomMarkers() async {
    if (_mapController == null) return;

    try {
      final mapboxMap = _mapController!.mapboxMap;

      // Create point annotation manager
      final pointAnnotationManager = await mapboxMap.annotations
          .createPointAnnotationManager();

      // Store the annotation manager for later use
      _mapController!.pointAnnotationManager = pointAnnotationManager;
    } catch (e) {
      debugPrint('Error setting up custom markers: $e');
    }
  }

  Future<void> _setupLocationPuck() async {
    if (_mapController == null) return;

    try {
      await _mapController!.setIdleLocationPuck();
    } catch (e) {
      debugPrint('Error setting up location puck: $e');
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
