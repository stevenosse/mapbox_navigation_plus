import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
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
  final List<RouteModel>? alternativeRoutes;
  final String? highlightedRouteId;
  final double? pitch;
  final double? zoom;
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
    this.alternativeRoutes,
    this.highlightedRouteId,
    this.pitch,
    this.zoom,
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
    if (oldWidget.routePreview != widget.routePreview ||
        oldWidget.alternativeRoutes != widget.alternativeRoutes) {
      _handleRoutePreview();
    }
    if (oldWidget.highlightedRouteId != widget.highlightedRouteId) {
      _handleRouteHighlighting();
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
      await _mapController!.clearRoute();
      await _mapController!.clearMultipleRoutes();

      final List<RouteModel> allRoutes = [];

      if (widget.routePreview != null) {
        allRoutes.add(widget.routePreview!);
      }

      if (widget.alternativeRoutes != null) {
        allRoutes.addAll(widget.alternativeRoutes!);
      }

      if (allRoutes.isNotEmpty) {
        await _mapController!.drawMultipleRoutes(routes: allRoutes);
        await _handleRouteHighlighting();
      }
    } catch (e) {
      debugPrint('Error handling route preview: $e');
    }
  }

  Future<void> _handleRouteHighlighting() async {
    if (_mapController == null) return;

    try {
      if (widget.highlightedRouteId != null) {
        await _mapController!.highlightRoute(widget.highlightedRouteId!);
      } else if (widget.routePreview != null) {
        await _mapController!.highlightRoute(widget.routePreview!.id);
      }
    } catch (e) {
      debugPrint('Error handling route highlighting: $e');
    }
  }

  mb.GeometryObject _calculateCombinedGeometryBounds() {
    final List<RouteModel> allRoutes = [];

    if (widget.routePreview != null) {
      allRoutes.add(widget.routePreview!);
    }

    if (widget.alternativeRoutes != null &&
        widget.alternativeRoutes!.isNotEmpty) {
      allRoutes.addAll(widget.alternativeRoutes!);
    }

    if (allRoutes.isEmpty) {
      return mb.Point(coordinates: mb.Position(0, 0));
    }

    final firstGeometry = allRoutes.first.geometry;
    if (firstGeometry.isEmpty) {
      return mb.Point(coordinates: mb.Position(0, 0));
    }

    double minLat = firstGeometry.first.latitude;
    double maxLat = firstGeometry.first.latitude;
    double minLon = firstGeometry.first.longitude;
    double maxLon = firstGeometry.first.longitude;

    for (final route in allRoutes) {
      for (final point in route.geometry) {
        minLat = math.min(minLat, point.latitude);
        maxLat = math.max(maxLat, point.latitude);
        minLon = math.min(minLon, point.longitude);
        maxLon = math.max(maxLon, point.longitude);
      }
    }

    // Add padding to bounds (15% of the route extent for multiple routes)
    final latPadding = (maxLat - minLat) * 0.15;
    final lonPadding = (maxLon - minLon) * 0.15;

    minLat -= latPadding;
    maxLat += latPadding;
    minLon -= lonPadding;
    maxLon += lonPadding;

    return mb.Polygon(
      coordinates: [
        [
          mb.Position(minLon, minLat), // southwest
          mb.Position(maxLon, minLat), // southeast
          mb.Position(maxLon, maxLat), // northeast
          mb.Position(minLon, maxLat), // northwest
          mb.Position(minLon, minLat), // close the polygon
        ],
      ],
    );
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
          viewport: () {
            final shouldShowOverViewVP =
                (widget.routePreview != null ||
                widget.alternativeRoutes != null &&
                    widget.alternativeRoutes!.isNotEmpty);
            final isFollowingLocation =
                _mapController?.isFollowingLocation == true;

            if (!isFollowingLocation) {
              return null;
            }
            return shouldShowOverViewVP
                ? mb.OverviewViewportState(
                    geometry: _calculateCombinedGeometryBounds(),
                  )
                : mb.FollowPuckViewportState(
                    zoom: isNavigationActive ? (widget.zoom ?? 20) : 18.5,
                    bearing: mb.FollowPuckViewportStateBearingHeading(),
                    pitch: isNavigationActive ? (widget.pitch ?? 70.0) : 0.0,
                  );
          }(),
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
