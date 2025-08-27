import 'dart:convert';
import 'dart:math';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../models/route_data.dart';
import '../models/waypoint.dart';
import '../utils/route_utils.dart';
import '../utils/constants.dart' as nav_constants;
import '../utils/math_utils.dart';

/// Service for drawing and managing route visualization on Mapbox map
class RouteVisualizationService {
  static const String _routeSourceId = 'navigation-route-source';
  static const String _routeLayerId = 'navigation-route-layer';
  static const String _routeBorderLayerId = 'navigation-route-border-layer';

  MapboxMap? _mapboxMap;
  RouteData? _currentRoute;
  bool _isInitialized = false;

  // Cache for optimization
  Map<String, dynamic>? _cachedFullRouteGeoJson;
  int? _lastStepIndex;
  String? _lastRouteHash;

  /// Initializes the service with a Mapbox map instance
  Future<void> initialize(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    _isInitialized = true;
    await _setupRouteLayers();
  }

  /// Draws a route with traffic-aware styling
  Future<void> drawRoute(RouteData route,
      {int? currentStepIndex, geo.Position? currentPosition}) async {
    if (!_isInitialized || _mapboxMap == null) return;

    try {
      final routeHash = _generateRouteHash(route);
      final bool isNewRoute = _lastRouteHash != routeHash;

      _currentRoute = route;
      _lastRouteHash = routeHash;

      // Only regenerate full route GeoJSON if route changed
      if (isNewRoute || _cachedFullRouteGeoJson == null) {
        final routeGeoJsonString = RouteUtils.routeToGeoJson(route);
        _cachedFullRouteGeoJson = json.decode(routeGeoJsonString);

        // Update the full route source (for traveled portion)
        await _mapboxMap!.style.setStyleSourceProperty(
          _routeSourceId,
          'data',
          _cachedFullRouteGeoJson!,
        );

        // Update layer styling based on traffic data for new routes
        await _updateRouteLayerStyling(route);
      }

      // Always update remaining route (this changes frequently during navigation)
      await _updateRemainingRoute(route, currentStepIndex, currentPosition);
    } catch (e) {
      throw RouteVisualizationException('Failed to draw route: $e');
    }
  }

  /// Updates route progress during navigation
  Future<void> updateRouteProgress(RouteData route, int currentStepIndex,
      {geo.Position? currentPosition, bool forceUpdate = false}) async {
    if (!_isInitialized || _mapboxMap == null) return;

    try {
      await _updateRemainingRoute(route, currentStepIndex, currentPosition,
          forceUpdate: forceUpdate);
    } catch (e) {
      throw RouteVisualizationException('Failed to update route progress: $e');
    }
  }

  /// Helper method to update remaining route with caching
  Future<void> _updateRemainingRoute(
      RouteData route, int? currentStepIndex, geo.Position? currentPosition,
      {bool forceUpdate = false}) async {
    // Skip update if step hasn't changed and position is close to last cached position
    if (!forceUpdate &&
        _shouldSkipRemainingRouteUpdate(currentStepIndex, currentPosition)) {
      return;
    }

    final remainingRouteGeoJson =
        _createRemainingRouteGeoJson(route, currentStepIndex, currentPosition);

    _lastStepIndex = currentStepIndex;
    _lastUpdatePosition = currentPosition;
    _lastUpdateTime = DateTime.now();

    await _mapboxMap!.style.setStyleSourceProperty(
      '$_routeSourceId-remaining',
      'data',
      remainingRouteGeoJson,
    );
  }

  // Performance optimization - track last update position
  geo.Position? _lastUpdatePosition;
  DateTime? _lastUpdateTime;

  /// Determines if remaining route update can be skipped
  bool _shouldSkipRemainingRouteUpdate(
      int? currentStepIndex, geo.Position? currentPosition) {
    // Always update if no cache or step changed significantly
    if (_lastStepIndex == null || currentStepIndex != _lastStepIndex) {
      return false;
    }

    // Skip if not enough time has passed (throttle updates for performance)
    final now = DateTime.now();
    if (_lastUpdateTime != null) {
      final timeDiff = now.difference(_lastUpdateTime!).inMilliseconds;
      if (timeDiff <
          nav_constants.RouteVisualizationConstants.routeUpdateIntervalMs) {
        return true; // Skip this update
      }
    }

    // Skip if position hasn't moved significantly (avoid redundant updates)
    if (currentPosition != null && _lastUpdatePosition != null) {
      final distance = MathUtils.calculateDistance(
        _lastUpdatePosition!.latitude,
        _lastUpdatePosition!.longitude,
        currentPosition.latitude,
        currentPosition.longitude,
      );

      // Skip update if moved less than 0.5 meters (very sensitive for ultra-smooth tracing)
      if (distance < 0.5) {
        return true;
      }
    }

    return false; // Proceed with update
  }

  /// Creates GeoJSON for the remaining portion of the route
  Map<String, dynamic> _createRemainingRouteGeoJson(
      RouteData route, int? currentStepIndex, geo.Position? currentPosition) {
    if (currentStepIndex == null || currentStepIndex >= route.steps.length) {
      // Show full route if no progress or completed
      return json.decode(RouteUtils.routeToGeoJson(route));
    }

    // Determine the split point for the route
    int startGeometryIndex;

    if (currentPosition != null) {
      // Use current position for more accurate route splitting
      startGeometryIndex =
          _findClosestGeometryIndex(route.geometry, currentPosition);
    } else {
      // Fallback to using step start position
      final remainingSteps = route.steps.skip(currentStepIndex).toList();
      if (remainingSteps.isEmpty) {
        return {'type': 'FeatureCollection', 'features': []};
      }

      final firstRemainingStep = remainingSteps.first;
      startGeometryIndex = _findClosestGeometryIndex(
          route.geometry, firstRemainingStep.startLocation);
    }

    // Create remaining geometry from the actual route geometry
    final remainingGeometry = route.geometry.skip(startGeometryIndex).toList();

    if (remainingGeometry.isEmpty) {
      return {'type': 'FeatureCollection', 'features': []};
    }

    // Start coordinates with current position for perfect alignment with user puck
    final coordinates = <List<double>>[];

    // Insert user's current position as the first point for perfect alignment
    if (currentPosition != null) {
      coordinates.add([currentPosition.longitude, currentPosition.latitude]);
    }

    // Add remaining route geometry
    coordinates.addAll(remainingGeometry
        .map((waypoint) => [waypoint.longitude, waypoint.latitude])
        .toList());

    return {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'geometry': {
            'type': 'LineString',
            'coordinates': coordinates,
          },
          'properties': {
            'route_id': route.hashCode.toString(),
            'remaining': true,
          },
        }
      ],
    };
  }

  /// Finds the closest point in route geometry to a given position
  int _findClosestGeometryIndex(
      List<Waypoint> geometry, geo.Position targetPosition) {
    if (geometry.isEmpty) return 0;

    double minDistance = double.infinity;
    int closestIndex = 0;

    for (int i = 0; i < geometry.length; i++) {
      final waypoint = geometry[i];
      final distance = MathUtils.calculateDistance(
        waypoint.latitude,
        waypoint.longitude,
        targetPosition.latitude,
        targetPosition.longitude,
      );

      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
      }
    }

    return closestIndex;
  }

  /// Clears the current route from the map
  Future<void> clearRoute() async {
    if (!_isInitialized || _mapboxMap == null) return;

    try {
      // Clear both route sources by providing empty GeoJSON
      const emptyGeoJson = {'type': 'FeatureCollection', 'features': []};

      await _mapboxMap!.style
          .setStyleSourceProperty(_routeSourceId, 'data', emptyGeoJson);
      await _mapboxMap!.style.setStyleSourceProperty(
          '$_routeSourceId-remaining', 'data', emptyGeoJson);

      _currentRoute = null;
    } catch (e) {
      throw RouteVisualizationException('Failed to clear route: $e');
    }
  }

  /// Updates route with new data (for recalculation scenarios)
  Future<void> updateRoute(RouteData newRoute) async {
    await drawRoute(newRoute);
  }

  /// Sets up the initial route layers on the map
  Future<void> _setupRouteLayers() async {
    if (_mapboxMap == null) return;

    try {
      // Add empty GeoJSON sources for routes
      const emptyGeoJson = {'type': 'FeatureCollection', 'features': []};

      // Route source for the main route
      await _mapboxMap!.style.addSource(
        GeoJsonSource(id: _routeSourceId, data: jsonEncode(emptyGeoJson)),
      );

      // Separate source for the remaining route (progress visualization)
      await _mapboxMap!.style.addSource(
        GeoJsonSource(
            id: '$_routeSourceId-remaining', data: jsonEncode(emptyGeoJson)),
      );

      // Add layers in the correct order (bottom to top)
      // Note: Layers are rendered in the order they are added, with later layers on top

      // 1. Route border layer (wider, dark outline)
      await _mapboxMap!.style.addLayer(
        LineLayer(
          id: _routeBorderLayerId,
          sourceId: _routeSourceId,
          lineColor: nav_constants.RouteVisualizationConstants.routeBorderColor,
          lineWidth: nav_constants.RouteVisualizationConstants.routeBorderWidth,
          lineCap: LineCap.ROUND,
          lineJoin: LineJoin.ROUND,
          lineOpacity: 0.7,
        ),
      );

      // 2. Traveled route (dimmed/gray)
      await _mapboxMap!.style.addLayer(
        LineLayer(
          id: '$_routeLayerId-traveled',
          sourceId: _routeSourceId,
          lineColor:
              nav_constants.RouteVisualizationConstants.routeTraveledColor,
          lineWidth:
              nav_constants.RouteVisualizationConstants.routeTraveledWidth,
          lineCap: LineCap.ROUND,
          lineJoin: LineJoin.ROUND,
          lineOpacity: 0.7,
        ),
      );

      // 3. Remaining route (bright blue, thick like production apps)
      await _mapboxMap!.style.addLayer(
        LineLayer(
          id: _routeLayerId,
          sourceId: '$_routeSourceId-remaining',
          lineColor:
              nav_constants.RouteVisualizationConstants.routeDefaultColor,
          lineWidth:
              nav_constants.RouteVisualizationConstants.routeRemainingWidth,
          lineCap: LineCap.ROUND,
          lineJoin: LineJoin.ROUND,
          lineOpacity: nav_constants.RouteVisualizationConstants.routeOpacity,
        ),
      );

      // Ensure location puck stays on top by refreshing location settings
      await _refreshLocationPuck();
    } catch (e) {
      // If layer positioning fails, add without positioning
      try {
        await _setupRouteLayersSimple();
        await _refreshLocationPuck();
      } catch (fallbackError) {
        throw RouteVisualizationException(
            'Failed to setup route layers: $e, fallback also failed: $fallbackError');
      }
    }
  }

  /// Refreshes the location puck to ensure it appears on top of route layers
  Future<void> _refreshLocationPuck() async {
    if (_mapboxMap == null) return;

    try {
      // Get current location settings
      final currentSettings = await _mapboxMap!.location.getSettings();

      // Re-apply the settings to refresh the location layer positioning
      await _mapboxMap!.location.updateSettings(currentSettings);
    } catch (e) {
      // Silently ignore location puck refresh errors
      // This is a best-effort attempt to keep the puck visible
    }
  }

  /// Fallback method for setting up route layers without positioning
  Future<void> _setupRouteLayersSimple() async {
    if (_mapboxMap == null) return;

    const emptyGeoJson = {'type': 'FeatureCollection', 'features': []};

    await _mapboxMap!.style.addSource(
      GeoJsonSource(id: _routeSourceId, data: jsonEncode(emptyGeoJson)),
    );

    await _mapboxMap!.style.addSource(
      GeoJsonSource(
          id: '$_routeSourceId-remaining', data: jsonEncode(emptyGeoJson)),
    );

    await _mapboxMap!.style.addLayer(
      LineLayer(
        id: _routeBorderLayerId,
        sourceId: _routeSourceId,
        lineColor: nav_constants.RouteVisualizationConstants.routeBorderColor,
        lineWidth: nav_constants.RouteVisualizationConstants.routeBorderWidth,
        lineCap: LineCap.ROUND,
        lineJoin: LineJoin.ROUND,
        lineOpacity: 0.7,
      ),
    );

    await _mapboxMap!.style.addLayer(
      LineLayer(
        id: '$_routeLayerId-traveled',
        sourceId: _routeSourceId,
        lineColor: nav_constants.RouteVisualizationConstants.routeTraveledColor,
        lineWidth: nav_constants.RouteVisualizationConstants.routeTraveledWidth,
        lineCap: LineCap.ROUND,
        lineJoin: LineJoin.ROUND,
        lineOpacity: 0.6,
      ),
    );

    await _mapboxMap!.style.addLayer(
      LineLayer(
        id: _routeLayerId,
        sourceId: '$_routeSourceId-remaining',
        lineColor: nav_constants.RouteVisualizationConstants.routeDefaultColor,
        lineWidth: 5.0,
        lineCap: LineCap.ROUND,
        lineJoin: LineJoin.ROUND,
      ),
    );
  }

  /// Updates route layer styling based on traffic data
  Future<void> _updateRouteLayerStyling(RouteData route) async {
    if (_mapboxMap == null) return;

    try {
      // Update line color based on traffic data
      final lineColorExpression = _createTrafficColorExpression(route);

      await _mapboxMap!.style.setStyleLayerProperty(
        _routeLayerId,
        'line-color',
        lineColorExpression,
      );

      // Update line width based on zoom
      await _mapboxMap!.style.setStyleLayerProperty(
        _routeLayerId,
        'line-width',
        _createLineWidthExpression(),
      );
    } catch (e) {
      throw RouteVisualizationException('Failed to update route styling: $e');
    }
  }

  /// Creates a traffic-aware color expression for the route line
  dynamic _createTrafficColorExpression(RouteData route) {
    if (route.trafficAnnotations == null || route.trafficAnnotations!.isEmpty) {
      return nav_constants.RouteVisualizationConstants.routeDefaultColor;
    }

    // Create a Mapbox expression for traffic-based coloring
    // Uses the 'congestion' property from the GeoJSON feature properties
    return [
      'case',
      // Severe traffic - dark red
      [
        '==',
        ['get', 'congestion'],
        'severe'
      ],
      _colorToHex(nav_constants.RouteVisualizationConstants.trafficSevereColor),
      // Heavy traffic - red-orange
      [
        '==',
        ['get', 'congestion'],
        'heavy'
      ],
      _colorToHex(nav_constants.RouteVisualizationConstants.trafficHeavyColor),
      // Moderate traffic - yellow
      [
        '==',
        ['get', 'congestion'],
        'moderate'
      ],
      _colorToHex(
          nav_constants.RouteVisualizationConstants.trafficModerateColor),
      // Light traffic - green
      [
        '==',
        ['get', 'congestion'],
        'low'
      ],
      _colorToHex(nav_constants.RouteVisualizationConstants.trafficLightColor),
      // Default color for unknown or no traffic data
      _colorToHex(nav_constants.RouteVisualizationConstants.routeDefaultColor)
    ];
  }

  /// Creates zoom-based line width expression
  dynamic _createLineWidthExpression() {
    // For now, use static width - expressions can be added later
    return 8.0;
  }

  /// Converts a color integer to hex string format for Mapbox
  String _colorToHex(int colorInt) {
    return '#${colorInt.toRadixString(16).padLeft(8, '0').substring(2)}';
  }

  /// Generates a hash for route to detect changes
  String _generateRouteHash(RouteData route) {
    // Simple hash based on route geometry and traffic data
    final buffer = StringBuffer();
    buffer.write('${route.totalDistance}_${route.totalDuration}');

    // Add first few and last few geometry points
    if (route.geometry.isNotEmpty) {
      final geometryToHash = [
        ...route.geometry.take(3),
        ...route.geometry.skip(max(0, route.geometry.length - 3)),
      ];

      for (final point in geometryToHash) {
        buffer.write(
            '_${point.latitude.toStringAsFixed(6)}_${point.longitude.toStringAsFixed(6)}');
      }
    }

    return buffer.toString().hashCode.toString();
  }

  /// Clears cache
  void _clearCache() {
    _cachedFullRouteGeoJson = null;
    _lastStepIndex = null;
    _lastRouteHash = null;
  }

  /// Disposes of the service and cleans up resources
  Future<void> dispose() async {
    if (_isInitialized && _mapboxMap != null) {
      await clearRoute();
    }
    _clearCache();
    _mapboxMap = null;
    _currentRoute = null;
    _isInitialized = false;
  }

  /// Gets the currently visualized route
  RouteData? get currentRoute => _currentRoute;

  /// Whether the service is properly initialized
  bool get isInitialized => _isInitialized;
}

/// Exception thrown by route visualization operations
class RouteVisualizationException implements Exception {
  final String message;

  const RouteVisualizationException(this.message);

  @override
  String toString() => 'RouteVisualizationException: $message';
}
