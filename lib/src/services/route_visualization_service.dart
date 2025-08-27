import 'dart:convert';
import 'dart:math';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../models/route_data.dart';
import '../models/waypoint.dart';
import '../utils/route_utils.dart';
import '../utils/constants.dart' as nav_constants;

/// Service for drawing and managing route visualization on Mapbox map
class RouteVisualizationService {
  static const String _routeSourceId = 'navigation-route-source';
  static const String _routeLayerId = 'navigation-route-layer';
  static const String _routeBorderLayerId = 'navigation-route-border-layer';

  MapboxMap? _mapboxMap;
  RouteData? _currentRoute;
  bool _isInitialized = false;

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
      _currentRoute = route;

      // Convert route to GeoJSON with traffic data
      final routeGeoJsonString = RouteUtils.routeToGeoJson(route);
      final routeGeoJson = json.decode(routeGeoJsonString);

      // Update the full route source (for traveled portion)
      await _mapboxMap!.style.setStyleSourceProperty(
        _routeSourceId,
        'data',
        routeGeoJson,
      );

      // Create remaining route geometry based on current position or step progress
      final remainingRouteGeoJson = _createRemainingRouteGeoJson(
          route, currentStepIndex, currentPosition);

      // Update the remaining route source
      await _mapboxMap!.style.setStyleSourceProperty(
        '$_routeSourceId-remaining',
        'data',
        remainingRouteGeoJson,
      );

      // Update layer styling based on traffic data
      await _updateRouteLayerStyling(route);
    } catch (e) {
      throw RouteVisualizationException('Failed to draw route: $e');
    }
  }

  /// Updates route progress during navigation
  Future<void> updateRouteProgress(RouteData route, int currentStepIndex,
      {geo.Position? currentPosition}) async {
    if (!_isInitialized || _mapboxMap == null) return;

    try {
      // Update only the remaining route portion for better performance
      final remainingRouteGeoJson = _createRemainingRouteGeoJson(
          route, currentStepIndex, currentPosition);

      await _mapboxMap!.style.setStyleSourceProperty(
        '$_routeSourceId-remaining',
        'data',
        remainingRouteGeoJson,
      );
    } catch (e) {
      throw RouteVisualizationException('Failed to update route progress: $e');
    }
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

    final coordinates = remainingGeometry
        .map((waypoint) => [
              waypoint.longitude,
              waypoint.latitude,
            ])
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
      final distance = _calculateDistance(
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

  /// Simple distance calculation between two points (Haversine formula)
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // Earth's radius in meters

    final double dLat = (lat2 - lat1) * (3.14159265359 / 180);
    final double dLon = (lon2 - lon1) * (3.14159265359 / 180);

    final double a = (dLat / 2) * (dLat / 2) +
        (lat1 * (3.14159265359 / 180)) *
            (lat2 * (3.14159265359 / 180)) *
            (dLon / 2) *
            (dLon / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
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
          lineWidth: 5.0,
          lineCap: LineCap.ROUND,
          lineJoin: LineJoin.ROUND,
          lineOpacity: 0.6,
        ),
      );

      // 3. Remaining route (bright blue)
      await _mapboxMap!.style.addLayer(
        LineLayer(
          id: _routeLayerId,
          sourceId: '$_routeSourceId-remaining',
          lineColor:
              nav_constants.RouteVisualizationConstants.routeDefaultColor,
          lineWidth: 5.0,
          lineCap: LineCap.ROUND,
          lineJoin: LineJoin.ROUND,
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

  /// Disposes of the service and cleans up resources
  Future<void> dispose() async {
    if (_isInitialized && _mapboxMap != null) {
      await clearRoute();
    }
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
