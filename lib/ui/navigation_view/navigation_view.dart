import 'package:flutter/material.dart';
import 'dart:async';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;
import 'mapbox_map_controller.dart';
import '../../core/interfaces/map_controller_interface.dart';
import '../../core/models/location_point.dart';
import '../../core/models/navigation_state.dart';
import '../../core/models/route_model.dart';
import '../../navigation_controller.dart';

class NavigationView extends StatefulWidget {
  final MapControllerInterface? controller;
  final NavigationController? navigationController;
  final String mapboxAccessToken;
  final String? styleUrl;
  final LocationPoint? initialCenter;
  final double initialZoom;
  final bool enableLocation;
  final RouteModel? routePreview;
  final void Function(MapboxMapController)? onMapCreated;
  final VoidCallback? onFollowingLocationStopped;

  const NavigationView({
    super.key,
    this.controller,
    this.navigationController,
    required this.mapboxAccessToken,
    this.styleUrl,
    this.initialCenter,
    this.initialZoom = 16.0,
    this.enableLocation = true,
    this.routePreview,
    this.onMapCreated,
    this.onFollowingLocationStopped,
  });

  @override
  State<NavigationView> createState() => _NavigationViewState();
}

class _NavigationViewState extends State<NavigationView> {
  MapboxMapController? _mapController;
  StreamSubscription<NavigationState>? _stateSubscription;
  bool _isNavigationActive = false;

  bool get isNavigationActive => _isNavigationActive;

  @override
  void initState() {
    super.initState();
    _setupNavigationStateListener();
  }

  @override
  void didUpdateWidget(NavigationView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigationController != widget.navigationController) {
      _stateSubscription?.cancel();
      _setupNavigationStateListener();
    }
    if (oldWidget.routePreview != widget.routePreview) {
      _handleRoutePreview();
    }
  }

  void _setupNavigationStateListener() {
    if (widget.navigationController != null) {
      _isNavigationActive = widget.navigationController!.isNavigationActive;

      _stateSubscription = widget.navigationController!.stateStream.listen((
        state,
      ) {
        if (mounted) {
          setState(() {
            _isNavigationActive =
                widget.navigationController!.isNavigationActive;
          });
        }
      });
    }
  }

  Future<void> _handleRoutePreview() async {
    if (_mapController == null) return;

    try {
      if (widget.routePreview != null) {
        await _mapController!.drawRoute(route: widget.routePreview!);
      } else {
        await _mapController!.clearRoute();
      }
    } catch (e) {
      debugPrint('Error handling route preview: $e');
    }
  }

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
          viewport: _mapController?.isFollowingLocation == true
              ? widget.routePreview != null
                    ? mb.OverviewViewportState(
                        geometry: widget.routePreview!
                            .calculateRouteGeometryBounds(),
                      )
                    : mb.FollowPuckViewportState(
                        zoom: isNavigationActive ? 20 : 18.5,
                        bearing: mb.FollowPuckViewportStateBearingHeading(),
                        pitch: isNavigationActive ? 70.0 : 0.0,
                      )
              : null,
          onStyleLoadedListener: (data) async {
            await _setupLocationPuck();
            await _setupCustomMarkers();
            await _handleRoutePreview();
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
      ],
    );
  }

  // Setup custom markers using AnnotationManager
  Future<void> _setupCustomMarkers() async {
    if (_mapController == null) return;

    try {
      final mapboxMap = _mapController!.mapboxMap;
      final pointAnnotationManager = await mapboxMap.annotations
          .createPointAnnotationManager();

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
    _stateSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }
}
