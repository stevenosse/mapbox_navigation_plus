// ignore_for_file: unused_field

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;
import 'package:mapbox_navigation_plus/src/core/constants.dart';
import 'package:turf/turf.dart' as turf;
import '../../core/interfaces/map_controller_interface.dart';
import '../../core/models/route_model.dart';
import '../../core/models/location_point.dart';
import '../../core/models/route_progress.dart';
import '../../core/models/map_marker.dart';
import '../../core/models/route_style_config.dart';
import '../../core/models/location_puck_config.dart';

/// Mapbox Maps implementation of MapControllerInterface
class MapboxMapController implements MapControllerInterface, TickerProvider {
  final mb.MapboxMap _mapboxMap;

  /// Get access to the underlying MapboxMap for advanced usage
  mb.MapboxMap get mapboxMap => _mapboxMap;

  /// Point annotation manager for custom markers
  mb.PointAnnotationManager? pointAnnotationManager;

  // Layer and source IDs for route visualization
  static const String _routeSourceId = 'route_source';
  static const String _routeLayerId = 'route_layer';
  static const String _routeCasingLayerId = 'route_casing_layer';

  bool _isFollowingLocation = true;
  LocationPoint? _currentLocation;
  LocationPoint? _lastLocation;

  LocationPuckConfig? _locationPuckConfig;

  // Multiple routes management
  final Map<String, String> _multipleRouteIds = {};
  String? _highlightedRouteId;

  MapboxMapController(this._mapboxMap) {
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    await _createDataSources();
    await _createLayers();
  }

  Future<void> _createDataSources() async {
    await _mapboxMap.style.addSource(
      mb.GeoJsonSource(
        id: _routeSourceId,
        data: '{"type":"FeatureCollection","features":[]}',
        lineMetrics: true,
      ),
    );
  }

  Future<void> _createLayers() async {
    // Create casing layer (wider, white background)
    final routeCasingLayer = mb.LineLayer(
      id: _routeCasingLayerId,
      sourceId: _routeSourceId,
    );

    // Create main route layer (narrower, colored)
    final routeLayer = mb.LineLayer(
      id: _routeLayerId,
      sourceId: _routeSourceId,
    );

    try {
      // Add casing layer first (below main route)
      await _mapboxMap.style.addLayerAt(
        routeCasingLayer,
        mb.LayerPosition(below: 'mapbox-location-indicator-layer'),
      );

      // Add main route layer above casing
      await _mapboxMap.style.addLayerAt(
        routeLayer,
        mb.LayerPosition(above: _routeCasingLayerId),
      );
    } catch (e) {
      // Fallback if positioning fails
      await _mapboxMap.style.addLayer(routeCasingLayer);
      await _mapboxMap.style.addLayer(routeLayer);
    }

    // Style the casing layer (wider, white)
    await _mapboxMap.style.setStyleLayerProperty(
      _routeCasingLayerId,
      'line-color',
      '#FFFFFF',
    );
    await _mapboxMap.style.setStyleLayerProperty(
      _routeCasingLayerId,
      'line-width',
      18.0, // Wider than main route
    );
    await _mapboxMap.style.setStyleLayerProperty(
      _routeCasingLayerId,
      'line-opacity',
      0.9,
    );

    // Style the main route layer
    await _mapboxMap.style.setStyleLayerProperty(
      _routeLayerId,
      'line-color',
      '#3366CC',
    );
    await _mapboxMap.style.setStyleLayerProperty(
      _routeLayerId,
      'line-width',
      14.0,
    );
    await _mapboxMap.style.setStyleLayerProperty(
      _routeLayerId,
      'line-opacity',
      0.8,
    );
  }

  // Helper to apply common line style properties
  Future<void> _applyLineStyle(String layerId, RouteLineStyle style) async {
    // Apply styles to the casing layer (wider, white)
    await _mapboxMap.style.setStyleLayerProperty(
      _routeCasingLayerId,
      'line-color',
      '#FFFFFF',
    );
    await _mapboxMap.style.setStyleLayerProperty(
      _routeCasingLayerId,
      'line-width',
      style.width + 4.0, // Casing is wider than main route
    );
    await _mapboxMap.style.setStyleLayerProperty(
      _routeCasingLayerId,
      'line-opacity',
      0.9,
    );
    await _mapboxMap.style.setStyleLayerProperty(
      _routeCasingLayerId,
      'line-cap',
      style.capStyle.value,
    );
    await _mapboxMap.style.setStyleLayerProperty(
      _routeCasingLayerId,
      'line-join',
      style.joinStyle.value,
    );

    // Apply styles to the main route layer
    await _mapboxMap.style.setStyleLayerProperty(
      layerId,
      'line-color',
      style.colorHex,
    );
    await _mapboxMap.style.setStyleLayerProperty(
      layerId,
      'line-width',
      style.width,
    );
    await _mapboxMap.style.setStyleLayerProperty(
      layerId,
      'line-opacity',
      style.opacity,
    );
    await _mapboxMap.style.setStyleLayerProperty(
      layerId,
      'line-cap',
      style.capStyle.value,
    );
    await _mapboxMap.style.setStyleLayerProperty(
      layerId,
      'line-join',
      style.joinStyle.value,
    );
  }

  Future<void> _updateGeoJsonSource(String sourceId, String json) async {
    await _mapboxMap.style.getSource(sourceId).then((source) async {
      if (source is mb.GeoJsonSource) {
        await source.updateGeoJSON(json);
      }
    });
  }

  @override
  Future<void> drawRoute({
    required RouteModel route,
    RouteStyleConfig? styleConfig,
    bool showOriginPin = false,
  }) async {
    try {
      final config = styleConfig ?? RouteStyleConfig.defaultConfig;
      final routeStyle = config.routeLineStyle;

      final coordinates = route.geometry
          .map((point) => '[${point.longitude},${point.latitude}]')
          .join(',');

      final routeGeoJson =
          '{"type":"Feature","geometry":{"type":"LineString","coordinates":[$coordinates]},"properties":{}}';

      await _updateGeoJsonSource(_routeSourceId, routeGeoJson);

      await _applyLineStyle(_routeLayerId, routeStyle);

      final markers = <MapMarker>[
        MapMarker.origin(position: route.origin),
        MapMarker.destination(position: route.destination),
      ];

      for (int i = 0; i < route.waypoints.length; i++) {
        markers.add(
          MapMarker.waypoint(position: route.waypoints[i], index: i + 1),
        );
      }

      await addMarkers(markers, showOriginPin: showOriginPin);
    } catch (e) {
      throw Exception('Failed to draw route: $e');
    }
  }

  @override
  Future<void> updateProgressLine({
    required RouteProgress progress,
    RouteStyleConfig? styleConfig,
  }) async {
    try {
      final config = styleConfig ?? RouteStyleConfig.defaultConfig;
      final remainingStyle = config.remainingLineStyle;

      final route = progress.route;
      final geometry = route.geometry;

      if (geometry.isEmpty) return;

      final traveledIndices = _getTraveledGeometryIndices(
        geometry,
        progress.distanceTraveled,
        route.distance,
      );

      final remainingGeometry = traveledIndices.isEmpty
          ? geometry
          : geometry.sublist(traveledIndices.last);

      if (remainingGeometry.isNotEmpty) {
        final remainingLineString = mb.LineString(
          coordinates: remainingGeometry
              .map((point) => mb.Position(point.longitude, point.latitude))
              .toList(),
        );
        final remainingFeature = mb.Feature(
          id: 'remaining',
          geometry: remainingLineString,
          properties: {
            'color': remainingStyle.colorHex,
            'width': remainingStyle.width,
            'opacity': remainingStyle.opacity,
          },
        );

        final remainingJson = jsonEncode(
          mb.FeatureCollection(features: [remainingFeature]).toJson(),
        );
        await _updateGeoJsonSource(_routeSourceId, remainingJson);

        await _applyLineStyle(_routeLayerId, remainingStyle);
      }
    } catch (e) {
      throw Exception('Failed to update progress line: $e');
    }
  }

  @override
  Future<void> addMarkers(
    List<MapMarker> markers, {
    bool showOriginPin = false,
  }) async {
    try {
      if (pointAnnotationManager == null) {
        return;
      }

      final pointAnnotations = <mb.PointAnnotationOptions>[];
      for (final marker in markers) {
        final icon = switch (marker.type) {
          MarkerType.origin when showOriginPin =>
            marker.iconImage ?? kDefaultLocationPin,
          MarkerType.destination => marker.iconImage ?? kDefaultArrivalMarker,
          _ => null,
        };
        if (icon == null) continue;

        final bytes = await rootBundle.load(icon);
        pointAnnotations.add(
          mb.PointAnnotationOptions(
            geometry: mb.Point(
              coordinates: mb.Position(
                marker.position.longitude,
                marker.position.latitude,
              ),
            ),
            image: bytes.buffer.asUint8List(),
          ),
        );
      }

      if (pointAnnotations.isNotEmpty) {
        await pointAnnotationManager!.createMulti(pointAnnotations);
      }
    } catch (e) {
      throw Exception('Failed to add markers: $e');
    }
  }

  @override
  Future<void> clearMarkers() async {
    try {
      await pointAnnotationManager!.deleteAll();
    } catch (e) {
      throw Exception('Failed to clear markers: $e');
    }
  }

  @override
  Future<void> moveCamera({
    required LocationPoint center,
    double? zoom,
    double? bearing,
    double? pitch,
    double? heading,
    CameraAnimation? animation,
  }) async {
    try {
      final cameraOptions = mb.CameraOptions(
        center: mb.Point(
          coordinates: mb.Position(center.longitude, center.latitude),
        ),
        zoom: zoom?.toDouble(),
        bearing: bearing?.toDouble(),
        pitch: pitch?.toDouble(),
      );

      if (animation != null) {
        await _mapboxMap.flyTo(
          cameraOptions,
          mb.MapAnimationOptions(duration: animation.duration.inMilliseconds),
        );
      } else {
        await _mapboxMap.setCamera(cameraOptions);
      }
    } catch (e) {
      throw Exception('Failed to move camera: $e');
    }
  }

  @override
  Future<void> centerOnLocation({
    required LocationPoint location,
    double zoom = 16.0,
    bool followLocation = false,
  }) async {
    _currentLocation = location;
    _isFollowingLocation = followLocation;

    await moveCamera(
      center: location,
      zoom: zoom,
      bearing: location.heading,
      animation: const CameraAnimation(
        duration: Duration(milliseconds: 800),
        type: AnimationType.easeInOut,
      ),
    );
  }

  @override
  Future<void> setLocationFollowMode(bool follow) async {
    _isFollowingLocation = follow;

    if (follow && _currentLocation != null) {
      await centerOnLocation(location: _currentLocation!, followLocation: true);
    }
  }

  @override
  Future<void> clearRoute() async {
    try {
      await _mapboxMap.style.getSource(_routeSourceId).then((source) async {
        if (source is mb.GeoJsonSource) {
          await source.updateGeoJSON(
            '{"type":"FeatureCollection","features":[]}',
          );
        }
      });

      await clearMarkers();
    } catch (e) {
      throw Exception('Failed to clear route: $e');
    }
  }

  @override
  Future<void> clear() async {
    await clearRoute();
    await clearMarkers();
  }

  @override
  bool get isFollowingLocation => _isFollowingLocation;

  List<int> _getTraveledGeometryIndices(
    List<LocationPoint> geometry,
    double distanceTraveled,
    double totalDistance,
  ) {
    if (geometry.isEmpty || totalDistance <= 0) return [];

    final progressRatio = (distanceTraveled / totalDistance).clamp(0.0, 1.0);
    final targetIndex = (geometry.length * progressRatio).round();

    return List.generate(targetIndex.clamp(0, geometry.length), (i) => i);
  }

  /// Updates the custom location puck position and heading
  @override
  Future<void> updateLocationPuck(LocationPoint location) async {
    try {
      _currentLocation = location;
      _lastLocation = _lastLocation ?? location;

      double heading = location.heading ?? 0.0;
      if (heading == 0.0 && _lastLocation != null) {
        heading = _calculateHeading(_lastLocation!, location);
      }

      _lastLocation = location;
    } catch (e) {
      throw Exception('Failed to update location puck: $e');
    }
  }

  /// Sets the location puck to idle state with car marker and background
  @override
  Future<void> setIdleLocationPuck() async {
    try {
      final mapboxMap = _mapboxMap;
      final config = _locationPuckConfig ?? LocationPuckThemes.defaultTheme;

      Uint8List? customLocationPuckBytes;
      Uint8List? customLocationPuckBackgroundBytes;

      // Load idle image
      try {
        final imageData = await rootBundle.load(
          config.idleImagePath ?? kDefaultLocationPuck,
        );
        customLocationPuckBytes = imageData.buffer.asUint8List();
      } catch (e) {
        debugPrint('Failed to load idle location puck image: $e');
        return;
      }

      // Load background image for idle state if accuracy circle is enabled
      if (config.showAccuracyCircle) {
        try {
          final shadowData = await rootBundle.load(
            kDefaultLocationPuckBackground,
          );
          customLocationPuckBackgroundBytes = shadowData.buffer.asUint8List();
        } catch (e) {
          debugPrint('Failed to load idle location puck background: $e');
        }
      }

      // Create idle location puck with configuration
      final locationPuck = mb.LocationPuck(
        locationPuck2D: mb.LocationPuck2D(
          topImage: customLocationPuckBytes,
          bearingImage: customLocationPuckBytes,
          shadowImage: customLocationPuckBackgroundBytes,
          opacity: config.opacity,
        ),
      );

      // Update location puck settings
      final locationSettings = mb.LocationComponentSettings(
        enabled: true,
        locationPuck: locationPuck,
        pulsingEnabled: false,
        puckBearing: mb.PuckBearing.HEADING,
        puckBearingEnabled: true,
      );

      await mapboxMap.location.updateSettings(locationSettings);
    } catch (e) {
      throw Exception('Failed to set idle location puck: $e');
    }
  }

  /// Sets the location puck to navigation state with navigation marker (no background)
  @override
  Future<void> setNavigationLocationPuck() async {
    try {
      final mapboxMap = _mapboxMap;
      final config = _locationPuckConfig ?? LocationPuckThemes.defaultTheme;

      Uint8List? customLocationPuckBytes;

      try {
        final imageData = await rootBundle.load(
          config.navigationImagePath ?? kDefaultNavigationLocationPuck,
        );
        customLocationPuckBytes = imageData.buffer.asUint8List();
      } catch (e) {
        debugPrint('Failed to load navigation location puck image: $e');
        return;
      }

      final locationPuck = mb.LocationPuck(
        locationPuck2D: mb.LocationPuck2D(
          bearingImage: customLocationPuckBytes,
          opacity: config.opacity,
        ),
      );

      // Update location puck settings
      final locationSettings = mb.LocationComponentSettings(
        enabled: true,
        locationPuck: locationPuck,
        pulsingEnabled: false,
        puckBearing: mb.PuckBearing.HEADING,
        puckBearingEnabled: true,
        showAccuracyRing: true,
      );

      await mapboxMap.location.updateSettings(locationSettings);
    } catch (e) {
      throw Exception('Failed to set navigation location puck: $e');
    }
  }

  /// Calculates heading between two points
  double _calculateHeading(LocationPoint from, LocationPoint to) {
    final double deltaLon = to.longitude - from.longitude;
    final double y =
        math.sin(deltaLon * math.pi / 180) *
        math.cos(to.latitude * math.pi / 180);
    final double x =
        math.cos(from.latitude * math.pi / 180) *
            math.sin(to.latitude * math.pi / 180) -
        math.sin(from.latitude * math.pi / 180) *
            math.cos(to.latitude * math.pi / 180) *
            math.cos(deltaLon * math.pi / 180);

    double bearing = math.atan2(y, x) * 180 / math.pi;
    return (bearing + 360) % 360;
  }

  /// Clears all multiple routes from the map
  @override
  Future<void> clearMultipleRoutes() async {
    try {
      for (final entry in _multipleRouteIds.entries) {
        final routeId = entry.key;
        final layerId = entry.value;
        final sourceId = '${_routeSourceId}_multiple_$routeId';

        try {
          await _mapboxMap.style.removeStyleLayer(layerId);
        } catch (e) {
          // Layer might not exist, continue
        }

        try {
          await _mapboxMap.style.removeStyleSource(sourceId);
        } catch (e) {
          // Source might not exist, continue
        }
      }

      _multipleRouteIds.clear();
      _highlightedRouteId = null;
    } catch (e) {
      throw Exception('Failed to clear multiple routes: $e');
    }
  }

  /// Draws multiple routes on the map with different colors
  @override
  Future<void> drawMultipleRoutes({
    required List<RouteModel> routes,
    List<Color>? colors,
    RouteStyleConfig? baseStyleConfig,
  }) async {
    try {
      if (routes.isEmpty) return;

      await clearMultipleRoutes();

      final routeColors =
          colors ??
          [
            const Color(0xFF3366CC), // Blue
            const Color(0xFF00AA00), // Green
            const Color(0xFFFF6600), // Orange
            const Color(0xFFCC00CC), // Purple
            const Color(0xFF00CCCC), // Cyan
          ];

      final baseConfig = baseStyleConfig ?? RouteStyleConfig.defaultConfig;

      for (int i = 0; i < routes.length; i++) {
        final route = routes[i];
        final routeId = route.id;
        final color = routeColors[i % routeColors.length];

        final sourceId = '${_routeSourceId}_multiple_$routeId';
        final layerId = '${_routeLayerId}_multiple_$routeId';
        final coordinates = route.geometry
            .map((point) => '[${point.longitude},${point.latitude}]')
            .join(',');

        final routeGeoJson =
            '{"type":"Feature","geometry":{"type":"LineString","coordinates":[$coordinates]},"properties":{"routeId":"$routeId"}}';

        await _mapboxMap.style.addSource(
          mb.GeoJsonSource(id: sourceId, data: routeGeoJson),
        );

        final routeLayer = mb.LineLayer(id: layerId, sourceId: sourceId);

        try {
          await _mapboxMap.style.addLayerAt(
            routeLayer,
            mb.LayerPosition(below: 'mapbox-location-indicator-layer'),
          );
        } catch (e) {
          await _mapboxMap.style.addLayer(routeLayer);
        }

        await _mapboxMap.style.setStyleLayerProperty(
          layerId,
          'line-color',
          '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
        );
        await _mapboxMap.style.setStyleLayerProperty(
          layerId,
          'line-width',
          baseConfig.routeLineStyle.width,
        );
        await _mapboxMap.style.setStyleLayerProperty(
          layerId,
          'line-opacity',
          i == 0 ? 1.0 : 0.8,
        );
        await _mapboxMap.style.setStyleLayerProperty(
          layerId,
          'line-cap',
          baseConfig.routeLineStyle.capStyle.value,
        );
        await _mapboxMap.style.setStyleLayerProperty(
          layerId,
          'line-join',
          baseConfig.routeLineStyle.joinStyle.value,
        );

        _multipleRouteIds[routeId] = layerId;
      }

      if (routes.isNotEmpty) {
        final firstRoute = routes.first;
        final markers = <MapMarker>[
          MapMarker.origin(position: firstRoute.origin),
          MapMarker.destination(position: firstRoute.destination),
        ];

        for (int i = 0; i < firstRoute.waypoints.length; i++) {
          markers.add(
            MapMarker.waypoint(position: firstRoute.waypoints[i], index: i + 1),
          );
        }

        await addMarkers(markers);
      }
    } catch (e) {
      throw Exception('Failed to draw multiple routes: $e');
    }
  }

  /// Highlights a specific route from multiple routes
  @override
  Future<void> highlightRoute(String routeId) async {
    try {
      if (!_multipleRouteIds.containsKey(routeId)) {
        throw Exception('Route ID $routeId not found in multiple routes');
      }

      final config = RouteStyleConfig.defaultConfig;

      for (final entry in _multipleRouteIds.entries) {
        final currentRouteId = entry.key;
        final layerId = entry.value;

        try {
          if (currentRouteId == routeId) {
            await _mapboxMap.style.setStyleLayerProperty(
              layerId,
              'line-color',
              config.routeLineStyle.colorHex,
            );
            await _mapboxMap.style.setStyleLayerProperty(
              layerId,
              'line-width',
              config.routeLineStyle.width + 2.0,
            );
            await _mapboxMap.style.setStyleLayerProperty(
              layerId,
              'line-opacity',
              1.0,
            );
          } else {
            await _mapboxMap.style.setStyleLayerProperty(
              layerId,
              'line-color',
              '#888888',
            );
            await _mapboxMap.style.setStyleLayerProperty(
              layerId,
              'line-width',
              config.routeLineStyle.width,
            );
            await _mapboxMap.style.setStyleLayerProperty(
              layerId,
              'line-opacity',
              0.7,
            );
          }
        } catch (e) {
          // Layer might not exist, continue
        }
      }

      _highlightedRouteId = routeId;
    } catch (e) {
      throw Exception('Failed to highlight route: $e');
    }
  }

  @override
  void setFollowingLocation(bool follow) {
    final wasFollowing = _isFollowingLocation;
    _isFollowingLocation = follow;

    if (follow && !wasFollowing && _currentLocation != null) {
      centerOnLocation(location: _currentLocation!, followLocation: true);
    }
  }

  @override
  Future<double> zoomIn() async {
    try {
      final currentCamera = await _mapboxMap.getCameraState();
      final newZoom = (currentCamera.zoom + 1.0).clamp(1.0, 22.0);

      await _mapboxMap.flyTo(
        mb.CameraOptions(zoom: newZoom),
        mb.MapAnimationOptions(duration: 300),
      );

      return newZoom;
    } catch (e) {
      throw Exception('Failed to zoom in: $e');
    }
  }

  @override
  Future<double> zoomOut() async {
    try {
      final currentCamera = await _mapboxMap.getCameraState();
      final newZoom = (currentCamera.zoom - 1.0).clamp(1.0, 22.0);

      await _mapboxMap.flyTo(
        mb.CameraOptions(zoom: newZoom),
        mb.MapAnimationOptions(duration: 300),
      );

      return newZoom;
    } catch (e) {
      throw Exception('Failed to zoom out: $e');
    }
  }

  @override
  Future<double> getCurrentZoom() async {
    try {
      final camera = await _mapboxMap.getCameraState();
      return camera.zoom;
    } catch (e) {
      throw Exception('Failed to get current zoom: $e');
    }
  }

  /// Configures the location puck appearance
  @override
  Future<void> configureLocationPuck(LocationPuckConfig config) async {
    _locationPuckConfig = config;

    if (_currentLocation != null) {
      await updateLocationPuck(_currentLocation!);
    }
  }

  double _lastKnownDistanceProgress = 0.0;

  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);

  /// Updates the route on the map with the current location
  @override
  Future<void> updateRoute({
    required RouteModel route,
    required LocationPoint location,
  }) async {
    try {
      final totalRouteLength = List.generate(
        route.geometry.length - 1,
        (i) => turf.distance(
          turf.Point(
            coordinates: turf.Position(
              route.geometry[i].longitude,
              route.geometry[i].latitude,
            ),
          ),
          turf.Point(
            coordinates: turf.Position(
              route.geometry[i + 1].longitude,
              route.geometry[i + 1].latitude,
            ),
          ),
          turf.Unit.meters,
        ),
      ).reduce((a, b) => a + b);

      final nearestPoint = turf.nearestPointOnLine(
        turf.LineString(
          coordinates: route.geometry
              .map((point) => turf.Position(point.longitude, point.latitude))
              .toList(),
        ),
        turf.Point(
          coordinates: turf.Position(location.longitude, location.latitude),
        ),
        turf.Unit.meters,
      );

      final distanceTraveled =
          double.tryParse(nearestPoint.properties!['location'].toString()) ??
          0.0;
      final targetProgress = (distanceTraveled / totalRouteLength).clamp(
        0.0,
        1.0,
      );

      final controller = AnimationController(
        duration: const Duration(milliseconds: 4000),
        vsync: this,
      );
      final animation = Tween(
        begin: _lastKnownDistanceProgress,
        end: targetProgress,
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));

      animation.addListener(() async {
        final value = animation.value;
        final trimValue = jsonEncode([0.0, value]);

        Future.wait([
          _mapboxMap.style.setStyleLayerProperty(
            _routeLayerId,
            'line-trim-offset',
            trimValue,
          ),
          _mapboxMap.style.setStyleLayerProperty(
            _routeCasingLayerId,
            'line-trim-offset',
            trimValue,
          ),
        ]);
      });

      controller.addStatusListener((status) {
        if (status == AnimationStatus.completed) controller.dispose();
      });

      _lastKnownDistanceProgress = targetProgress;
      controller.forward();
    } catch (e) {
      throw Exception('Failed to update route: $e');
    }
  }

  /// Dispose resources
  void dispose() {}
}
