import 'dart:convert';
import 'dart:math' as math;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../models/route_data.dart';
import '../models/waypoint.dart';
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

      // Update both traveled and remaining portions of the route
      await _updateRouteSplit(route, currentStepIndex, currentPosition);

      // Update layer styling if needed
      if (isNewRoute) {
        await _updateRouteLayerStyling(route);
      }
    } catch (e) {
      throw RouteVisualizationException('Failed to draw route: $e');
    }
  }

  /// Updates route progress during navigation
  Future<void> updateRouteProgress(RouteData route, int currentStepIndex,
      {geo.Position? currentPosition, bool forceUpdate = false}) async {
    if (!_isInitialized || _mapboxMap == null) return;

    try {
      // Skip update if not needed
      if (!forceUpdate &&
          !_shouldUpdateRoute(currentStepIndex, currentPosition)) {
        return;
      }

      await _updateRouteSplit(route, currentStepIndex, currentPosition);
    } catch (e) {
      throw RouteVisualizationException('Failed to update route progress: $e');
    }
  }

  /// Updates both traveled and remaining portions of the route
  Future<void> _updateRouteSplit(RouteData route, int? currentStepIndex,
      geo.Position? currentPosition) async {
    if (currentStepIndex == null || currentPosition == null) {
      // No progress yet, show full route as remaining
      final fullRouteGeoJson = _createFullRouteGeoJson(route);

      // Clear traveled route
      await _mapboxMap!.style.setStyleSourceProperty(
        _routeSourceId,
        'data',
        {'type': 'FeatureCollection', 'features': []},
      );

      // Set full route as remaining
      await _mapboxMap!.style.setStyleSourceProperty(
        '$_routeSourceId-remaining',
        'data',
        fullRouteGeoJson,
      );
      return;
    }

    // Find the exact split point on the route
    final splitPoint =
        _findSplitPoint(route, currentPosition, currentStepIndex);

    // Create traveled portion (everything behind the user)
    final traveledGeoJson = _createTraveledRouteGeoJson(
        route, splitPoint.geometryIndex, currentPosition);

    // Create remaining portion (everything ahead of the user)
    final remainingGeoJson = _createRemainingRouteGeoJson(
        route,
        splitPoint.geometryIndex,
        currentPosition,
        splitPoint.projectedPosition);

    // Update both sources
    await _mapboxMap!.style.setStyleSourceProperty(
      _routeSourceId,
      'data',
      traveledGeoJson,
    );

    await _mapboxMap!.style.setStyleSourceProperty(
      '$_routeSourceId-remaining',
      'data',
      remainingGeoJson,
    );

    // Cache update info
    _lastStepIndex = currentStepIndex;
    _lastUpdatePosition = currentPosition;
    _lastUpdateTime = DateTime.now();
  }

  // Performance optimization - track last update position
  geo.Position? _lastUpdatePosition;
  DateTime? _lastUpdateTime;

  /// Determines if route update is needed
  bool _shouldUpdateRoute(
      int? currentStepIndex, geo.Position? currentPosition) {
    // Always update if no cache or step changed
    if (_lastStepIndex == null || currentStepIndex != _lastStepIndex) {
      return true;
    }

    // Check time throttling
    final now = DateTime.now();
    if (_lastUpdateTime != null) {
      final timeDiff = now.difference(_lastUpdateTime!).inMilliseconds;
      if (timeDiff <
          nav_constants.RouteVisualizationConstants.routeUpdateIntervalMs) {
        return false; // Too soon
      }
    }

    // Check distance threshold
    if (currentPosition != null && _lastUpdatePosition != null) {
      final distance = MathUtils.calculateDistance(
        _lastUpdatePosition!.latitude,
        _lastUpdatePosition!.longitude,
        currentPosition.latitude,
        currentPosition.longitude,
      );

      // Update if moved more than 1 meter
      if (distance > 1.0) {
        return true;
      }
    }

    return false;
  }

  /// Finds the exact split point between traveled and remaining route
  _RouteSplitPoint _findSplitPoint(
      RouteData route, geo.Position currentPosition, int currentStepIndex) {
    // Find the closest point on the route geometry to the user
    double minDistance = double.infinity;
    int closestIndex = 0;
    geo.Position? projectedPosition;

    for (int i = 0; i < route.geometry.length - 1; i++) {
      final segmentStart = route.geometry[i];
      final segmentEnd = route.geometry[i + 1];

      // Project user position onto this segment
      final projection = _projectPointOntoSegment(
        currentPosition,
        segmentStart,
        segmentEnd,
      );

      final distance = MathUtils.calculateDistance(
        currentPosition.latitude,
        currentPosition.longitude,
        projection.latitude,
        projection.longitude,
      );

      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
        projectedPosition = projection;
      }
    }

    return _RouteSplitPoint(
      geometryIndex: closestIndex,
      projectedPosition: projectedPosition ?? currentPosition,
    );
  }

  /// Creates GeoJSON for the full route
  Map<String, dynamic> _createFullRouteGeoJson(RouteData route) {
    final coordinates = route.geometry
        .map((waypoint) => [waypoint.longitude, waypoint.latitude])
        .toList();

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
          },
        }
      ],
    };
  }

  /// Creates GeoJSON for the traveled portion of the route
  Map<String, dynamic> _createTraveledRouteGeoJson(
      RouteData route, int splitIndex, geo.Position currentPosition) {
    if (splitIndex <= 0) {
      // No traveled portion yet
      return {'type': 'FeatureCollection', 'features': []};
    }

    // Get all points up to the split point
    final traveledPoints = route.geometry.take(splitIndex + 1).toList();

    // Add user's current position as the last point
    final coordinates = <List<double>>[];
    coordinates.addAll(traveledPoints
        .map((waypoint) => [waypoint.longitude, waypoint.latitude])
        .toList());
    coordinates.add([currentPosition.longitude, currentPosition.latitude]);

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
            'traveled': true,
          },
        }
      ],
    };
  }

  /// Creates GeoJSON for the remaining portion of the route
  Map<String, dynamic> _createRemainingRouteGeoJson(
      RouteData route,
      int splitIndex,
      geo.Position currentPosition,
      geo.Position? projectedPosition) {
    // Get remaining points from the split
    final remainingPoints = route.geometry.skip(splitIndex + 1).toList();

    if (remainingPoints.isEmpty) {
      // User is at the end of the route
      return {'type': 'FeatureCollection', 'features': []};
    }

    // Start from user's current position for perfect connection
    final coordinates = <List<double>>[];
    coordinates.add([currentPosition.longitude, currentPosition.latitude]);

    // If we have a projected position that's different, add it for smooth transition
    if (projectedPosition != null &&
        (projectedPosition.longitude != currentPosition.longitude ||
            projectedPosition.latitude != currentPosition.latitude)) {
      coordinates
          .add([projectedPosition.longitude, projectedPosition.latitude]);
    }

    // Add all remaining route points
    coordinates.addAll(remainingPoints
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

  /// Projects a point onto a line segment
  geo.Position _projectPointOntoSegment(
      geo.Position point, Waypoint segmentStart, Waypoint segmentEnd) {
    // Convert to local coordinate system for projection
    final dx = segmentEnd.longitude - segmentStart.longitude;
    final dy = segmentEnd.latitude - segmentStart.latitude;

    if (dx == 0 && dy == 0) {
      // Segment start and end are the same point
      return geo.Position(
        latitude: segmentStart.latitude,
        longitude: segmentStart.longitude,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    }

    // Calculate projection factor (0 = start, 1 = end)
    final t = ((point.longitude - segmentStart.longitude) * dx +
            (point.latitude - segmentStart.latitude) * dy) /
        (dx * dx + dy * dy);

    // Clamp t to [0, 1] to keep projection on the segment
    final clampedT = t.clamp(0.0, 1.0);

    // Calculate projected position
    final projectedLat = segmentStart.latitude + clampedT * dy;
    final projectedLng = segmentStart.longitude + clampedT * dx;

    return geo.Position(
      latitude: projectedLat,
      longitude: projectedLng,
      timestamp: point.timestamp,
      accuracy: point.accuracy,
      altitude: point.altitude,
      altitudeAccuracy: point.altitudeAccuracy,
      heading: point.heading,
      headingAccuracy: point.headingAccuracy,
      speed: point.speed,
      speedAccuracy: point.speedAccuracy,
    );
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

      // Route source for the full/traveled route
      await _mapboxMap!.style.addSource(
        GeoJsonSource(id: _routeSourceId, data: jsonEncode(emptyGeoJson)),
      );

      // Separate source for the remaining route (progress visualization)
      await _mapboxMap!.style.addSource(
        GeoJsonSource(
            id: '$_routeSourceId-remaining', data: jsonEncode(emptyGeoJson)),
      );

      // Add layers in the correct order (bottom to top)
      // The Mapbox SDK renders layers in the order they are added

      // 1. Route border layer (wider, dark outline) - bottommost
      await _mapboxMap!.style.addLayer(
        LineLayer(
          id: _routeBorderLayerId,
          sourceId: _routeSourceId,
          lineColor: nav_constants.RouteVisualizationConstants.routeBorderColor,
          lineWidth: nav_constants.RouteVisualizationConstants.routeBorderWidth,
          lineCap: LineCap.ROUND,
          lineJoin: LineJoin.ROUND,
          lineOpacity: 0.5,
        ),
      );

      // 2. Traveled route (dimmed/gray) - middle layer
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
          lineOpacity: 0.4,
        ),
      );

      // 3. Remaining route (bright blue) - top route layer
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

      // Force location puck to top
      await _ensureLocationPuckOnTop();
    } catch (e) {
      // If layer positioning fails, add without specific ordering
      try {
        await _setupRouteLayersSimple();
        await _ensureLocationPuckOnTop();
      } catch (fallbackError) {
        throw RouteVisualizationException(
            'Failed to setup route layers: $e, fallback also failed: $fallbackError');
      }
    }
  }

  /// Ensures the location puck stays on top of all route layers
  Future<void> _ensureLocationPuckOnTop() async {
    if (_mapboxMap == null) return;

    try {
      // Get current location settings
      final currentSettings = await _mapboxMap!.location.getSettings();

      // Force the location puck to render on top by updating settings
      // with explicit layer positioning
      await _mapboxMap!.location.updateSettings(
        LocationComponentSettings(
          enabled: currentSettings.enabled,
          pulsingEnabled: currentSettings.pulsingEnabled,
          puckBearingEnabled: currentSettings.puckBearingEnabled,
          showAccuracyRing: currentSettings.showAccuracyRing,
          locationPuck: currentSettings.locationPuck,
          layerAbove:
              _routeLayerId, // Explicitly place above our top route layer
          layerBelow: null, // No layer above the puck
        ),
      );
    } catch (e) {
      // Fall back to simple refresh if explicit positioning fails
      try {
        final currentSettings = await _mapboxMap!.location.getSettings();
        await _mapboxMap!.location.updateSettings(currentSettings);
      } catch (refreshError) {
        // Silently ignore - location puck positioning is best-effort
      }
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
        ...route.geometry.skip(math.max(0, route.geometry.length - 3)),
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

/// Data class for route split point
class _RouteSplitPoint {
  final int geometryIndex;
  final geo.Position projectedPosition;

  _RouteSplitPoint({
    required this.geometryIndex,
    required this.projectedPosition,
  });
}

/// Exception thrown by route visualization operations
class RouteVisualizationException implements Exception {
  final String message;

  const RouteVisualizationException(this.message);

  @override
  String toString() => 'RouteVisualizationException: $message';
}
