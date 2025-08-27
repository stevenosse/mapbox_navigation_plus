import 'dart:convert';
import '../models/route_data.dart';
import '../models/waypoint.dart';
import 'constants.dart' as nav_constants;

/// Utility functions for route management and visualization
class RouteUtils {
  /// Converts a RouteData to GeoJSON format for map visualization
  static String routeToGeoJson(RouteData route) {
    final geoJson = route.hasTrafficData
        ? route.toGeoJsonWithTraffic()
        : {
            'type': 'FeatureCollection',
            'features': [route.toGeoJson()]
          };

    return json.encode(geoJson);
  }

  /// Converts a simple route geometry to GeoJSON LineString
  static String geometryToGeoJson(
    List<Waypoint> geometry, {
    Map<String, dynamic>? properties,
  }) {
    final coordinates = geometry
        .map((waypoint) => [
              waypoint.longitude,
              waypoint.latitude,
            ])
        .toList();

    final geoJson = {
      'type': 'Feature',
      'geometry': {
        'type': 'LineString',
        'coordinates': coordinates,
      },
      'properties': properties ?? {},
    };

    return json.encode({
      'type': 'FeatureCollection',
      'features': [geoJson],
    });
  }

  /// Gets the appropriate traffic color for a congestion level
  static int getTrafficColor(String congestionLevel) {
    switch (congestionLevel.toLowerCase()) {
      case 'severe':
        return nav_constants.RouteVisualizationConstants.trafficSevereColor;
      case 'heavy':
        return nav_constants.RouteVisualizationConstants.trafficHeavyColor;
      case 'moderate':
        return nav_constants.RouteVisualizationConstants.trafficModerateColor;
      case 'low':
        return nav_constants.RouteVisualizationConstants.trafficLightColor;
      case 'unknown':
      default:
        return nav_constants.RouteVisualizationConstants.routeDefaultColor;
    }
  }

  /// Gets traffic color based on numeric congestion value (0-100)
  static int getTrafficColorNumeric(int congestionNumeric) {
    if (congestionNumeric >= 80) {
      return nav_constants.RouteVisualizationConstants.trafficSevereColor;
    } else if (congestionNumeric >= 60) {
      return nav_constants.RouteVisualizationConstants.trafficHeavyColor;
    } else if (congestionNumeric >= 40) {
      return nav_constants.RouteVisualizationConstants.trafficModerateColor;
    } else if (congestionNumeric >= 20) {
      return nav_constants.RouteVisualizationConstants.trafficLightColor;
    } else {
      return nav_constants.RouteVisualizationConstants.routeDefaultColor;
    }
  }

  /// Calculates the total travel time with traffic consideration
  static double calculateTrafficAdjustedDuration(RouteData route) {
    if (!route.hasTrafficData) {
      return route.totalDuration;
    }

    // Sum up individual segment durations from traffic annotations
    return route.trafficAnnotations!
        .fold(0.0, (sum, annotation) => sum + annotation.duration);
  }

  /// Gets a human-readable traffic description for the route
  static String getTrafficDescription(RouteData route) {
    if (!route.hasTrafficData) {
      return 'No traffic data available';
    }

    final annotations = route.trafficAnnotations!;
    final severeCongestion =
        annotations.where((a) => a.congestion == 'severe').length;
    final heavyCongestion =
        annotations.where((a) => a.congestion == 'heavy').length;
    final totalSegments = annotations.length;

    if (severeCongestion > totalSegments * 0.3) {
      return 'Heavy traffic expected';
    } else if (heavyCongestion > totalSegments * 0.4) {
      return 'Moderate traffic expected';
    } else {
      return 'Light traffic conditions';
    }
  }

  /// Compares two routes and returns which one is faster considering traffic
  static RouteData getFasterRoute(RouteData route1, RouteData route2) {
    final duration1 = calculateTrafficAdjustedDuration(route1);
    final duration2 = calculateTrafficAdjustedDuration(route2);

    return duration1 <= duration2 ? route1 : route2;
  }

  /// Determines if a route recalculation is recommended based on traffic changes
  static bool shouldRecalculateRoute(
    RouteData currentRoute,
    RouteData newRoute, {
    double timeSavingsThreshold = 300.0, // 5 minutes in seconds
    double distanceSavingsThreshold = 1000.0, // 1 km in meters
  }) {
    final currentDuration = calculateTrafficAdjustedDuration(currentRoute);
    final newDuration = calculateTrafficAdjustedDuration(newRoute);

    final timeSavings = currentDuration - newDuration;
    final distanceSavings = currentRoute.totalDistance - newRoute.totalDistance;

    return timeSavings >= timeSavingsThreshold ||
        distanceSavings >= distanceSavingsThreshold;
  }

  /// Creates a simplified GeoJSON for route overview (fewer points)
  static String routeToSimplifiedGeoJson(RouteData route,
      {int maxPoints = 50}) {
    final geometry = route.geometry;
    if (geometry.length <= maxPoints) {
      return routeToGeoJson(route);
    }

    // Sample points evenly across the route
    final simplifiedGeometry = <Waypoint>[];
    final step = geometry.length / maxPoints;

    for (int i = 0; i < maxPoints; i++) {
      final index = (i * step).round();
      if (index < geometry.length) {
        simplifiedGeometry.add(geometry[index]);
      }
    }

    // Always include the last point
    if (simplifiedGeometry.last != geometry.last) {
      simplifiedGeometry.add(geometry.last);
    }

    final simplifiedRoute = route.copyWith(geometry: simplifiedGeometry);
    return routeToGeoJson(simplifiedRoute);
  }

  /// Validates if a route has valid geometry
  static bool isValidRoute(RouteData route) {
    return route.geometry.length >= 2 &&
        route.steps.isNotEmpty &&
        route.totalDistance > 0 &&
        route.totalDuration > 0;
  }

  /// Calculates the bounding box for a route
  static Map<String, double> getRouteBoundingBox(RouteData route) {
    if (route.geometry.isEmpty) {
      return {
        'minLat': 0.0,
        'maxLat': 0.0,
        'minLng': 0.0,
        'maxLng': 0.0,
      };
    }

    double minLat = route.geometry.first.latitude;
    double maxLat = route.geometry.first.latitude;
    double minLng = route.geometry.first.longitude;
    double maxLng = route.geometry.first.longitude;

    for (final waypoint in route.geometry) {
      minLat = waypoint.latitude < minLat ? waypoint.latitude : minLat;
      maxLat = waypoint.latitude > maxLat ? waypoint.latitude : maxLat;
      minLng = waypoint.longitude < minLng ? waypoint.longitude : minLng;
      maxLng = waypoint.longitude > maxLng ? waypoint.longitude : maxLng;
    }

    return {
      'minLat': minLat,
      'maxLat': maxLat,
      'minLng': minLng,
      'maxLng': maxLng,
    };
  }

  /// Estimates the average speed for a route segment based on traffic data
  static double estimateAverageSpeed(List<TrafficAnnotation> annotations) {
    if (annotations.isEmpty) return 50.0; // Default speed in km/h

    final validSpeeds = annotations
        .where(
            (annotation) => annotation.speed != null && annotation.speed! > 0)
        .map((annotation) => annotation.speed!)
        .toList();

    if (validSpeeds.isEmpty) return 50.0;

    return validSpeeds.reduce((a, b) => a + b) / validSpeeds.length;
  }
}
