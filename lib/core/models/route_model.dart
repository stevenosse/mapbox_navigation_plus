import 'dart:convert';
import 'dart:developer';
import 'dart:math' as math;

import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;
import 'leg.dart';
import 'location_point.dart';

/// Complete navigation route with multiple legs
class RouteModel {
  /// Legs that make up this route
  final List<Leg> legs;

  /// Total route distance in meters
  final double distance;

  /// Total expected duration in seconds
  final double duration;

  /// Route geometry as list of LocationPoint
  final List<LocationPoint> geometry;

  /// Route weight (often same as duration but can include other factors)
  final double weight;

  /// Route name or summary
  final String summary;

  /// Route origin
  final LocationPoint origin;

  /// Route destination
  final LocationPoint destination;

  /// Waypoints (if any)
  final List<LocationPoint> waypoints;

  /// Route creation timestamp
  final DateTime createdAt;

  /// Route ID for tracking
  final String id;

  /// Additional Mapbox-specific fields
  final String? weightName;
  final String? code;
  final String? uuid;

  RouteModel({
    required this.legs,
    required this.distance,
    required this.duration,
    required this.geometry,
    required this.weight,
    required this.summary,
    required this.origin,
    required this.destination,
    this.waypoints = const [],
    required this.createdAt,
    String? id,
    this.weightName,
    this.code,
    this.uuid,
  }) : id = id ?? _generateRouteId();

  /// Creates a route from Mapbox Directions API response
  factory RouteModel.fromMapbox(Map<String, dynamic> json, {String? id}) {
    log(jsonEncode(json));

    // Get the main route data from routes array
    Map<String, dynamic> routeData;
    if (json['routes'] is List && (json['routes'] as List).isNotEmpty) {
      routeData = (json['routes'] as List)[0] as Map<String, dynamic>;
    } else {
      // Fallback: assume json is the route data
      routeData = json;
    }

    // Parse legs from route data
    final legs = <Leg>[];
    if (routeData['legs'] != null) {
      for (int i = 0; i < (routeData['legs'] as List).length; i++) {
        legs.add(
          Leg.fromMapbox(
            (routeData['legs'] as List)[i] as Map<String, dynamic>,
            i,
          ),
        );
      }
    }

    // Parse geometry from route level - handle the actual Mapbox response structure
    final geometry = <LocationPoint>[];
    if (routeData['geometry'] != null) {
      final geometryData = routeData['geometry'];
      if (geometryData is Map<String, dynamic> &&
          geometryData['coordinates'] != null) {
        final coordinates = geometryData['coordinates'] as List;
        for (final coord in coordinates) {
          // Mapbox returns [longitude, latitude] but LocationPoint expects lat, lng order
          geometry.add(
            LocationPoint(
              latitude: (coord as List)[1] as double, // latitude is index 1
              longitude: (coord)[0] as double, // longitude is index 0
              timestamp: DateTime.now(),
            ),
          );
        }
      } else if (geometryData is String) {
        // Handle encoded polyline
        geometry.addAll(_decodePolyline(geometryData));
      }
    }

    // Parse origin and destination from the route data
    // Mapbox API structure: routes[0].legs[0].start/end for coordinates
    LocationPoint origin, destination;

    if (legs.isNotEmpty) {
      // Get origin from first leg's start location
      final firstLeg = legs.first;
      origin = firstLeg.startLocation;

      // Get destination from last leg's end location
      final lastLeg = legs.last;
      destination = lastLeg.endLocation;
    } else {
      // Fallback: create origin/destination from geometry
      if (geometry.isNotEmpty) {
        origin = geometry.first;
        destination = geometry.last;
      } else {
        // Last resort: create default points
        origin = LocationPoint(
          latitude: 0.0,
          longitude: 0.0,
          timestamp: DateTime.now(),
        );
        destination = LocationPoint(
          latitude: 0.0,
          longitude: 0.0,
          timestamp: DateTime.now(),
        );
      }
    }

    return RouteModel(
      legs: legs,
      distance: (routeData['distance'] as num?)?.toDouble() ?? 0.0,
      duration: (routeData['duration'] as num?)?.toDouble() ?? 0.0,
      geometry: geometry,
      weight:
          (routeData['weight'] as num?)?.toDouble() ??
          routeData['duration']?.toDouble() ??
          0.0,
      summary: routeData['summary'] as String? ?? '',
      origin: origin,
      destination: destination,
      createdAt: DateTime.now(),
      id: id,
      weightName: routeData['weight_name'] as String?,
      code: routeData['code'] as String?,
      uuid: routeData['uuid'] as String?,
    );
  }

  /// Gets the current leg based on location and progress
  Leg? getCurrentLeg(
    LocationPoint currentLocation,
    double totalDistanceTraveled,
  ) {
    if (legs.isEmpty) return null;

    double accumulatedDistance = 0.0;

    for (final leg in legs) {
      if (totalDistanceTraveled <= accumulatedDistance + leg.distance) {
        return leg;
      }
      accumulatedDistance += leg.distance;
    }

    // If we've traveled beyond all legs, return the last one
    return legs.last;
  }

  /// Gets total distance traveled along the route
  double calculateDistanceTraveled(LocationPoint currentLocation) {
    if (legs.isEmpty) return 0.0;

    double totalDistance = 0.0;
    for (final leg in legs) {
      if (leg.isLocationOnLeg(currentLocation)) {
        return totalDistance + leg.calculateDistanceTraveled(currentLocation);
      }
      totalDistance += leg.distance;
    }

    // If not found on any leg, we've likely completed the route
    return distance;
  }

  /// Gets remaining distance to destination
  double getRemainingDistance(LocationPoint currentLocation) {
    final traveled = calculateDistanceTraveled(currentLocation);
    return (distance - traveled).clamp(0.0, distance);
  }

  /// Gets remaining duration to destination
  double getRemainingDuration(LocationPoint currentLocation) {
    final traveled = calculateDistanceTraveled(currentLocation);
    if (distance <= 0) return 0.0;

    final progressRatio = traveled / distance;
    return (duration * (1.0 - progressRatio)).clamp(0.0, duration);
  }

  /// Gets estimated time of arrival
  DateTime getETA(LocationPoint currentLocation) {
    final remainingDuration = getRemainingDuration(currentLocation);
    return DateTime.now().add(Duration(seconds: remainingDuration.round()));
  }

  /// Checks if location is on this route
  bool isLocationOnRoute(LocationPoint location, {double tolerance = 50.0}) {
    for (final leg in legs) {
      if (leg.isLocationOnLeg(location, tolerance: tolerance)) {
        return true;
      }
    }
    return false;
  }

  /// Gets the closest point on the route to a given location
  LocationPoint getClosestPoint(LocationPoint location) {
    LocationPoint closestPoint = geometry.isNotEmpty ? geometry.first : origin;
    double minDistance = location.distanceTo(closestPoint);

    for (final point in geometry) {
      final distance = location.distanceTo(point);
      if (distance < minDistance) {
        minDistance = distance;
        closestPoint = point;
      }
    }

    return closestPoint;
  }

  /// Gets distance from route at a given location
  double getDistanceFromRoute(LocationPoint location) {
    if (geometry.isEmpty) return location.distanceTo(origin);

    double minDistance = double.infinity;
    for (int i = 0; i < geometry.length - 1; i++) {
      final start = geometry[i];
      final end = geometry[i + 1];

      // Simple point-to-line distance calculation
      final distance = _pointToLineDistance(location, start, end);
      if (distance < minDistance) {
        minDistance = distance;
      }
    }

    return minDistance;
  }

  /// Converts to Mapbox LineString for map display
  mb.LineString toMapboxLineString() {
    return mb.LineString(
      coordinates: geometry
          .map((point) => mb.Position(point.longitude, point.latitude))
          .toList(),
    );
  }

  @override
  String toString() {
    return 'Route(id: $id, distance: ${distance.toStringAsFixed(0)}m, duration: ${(duration / 60).toStringAsFixed(1)}min, legs: ${legs.length})';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RouteModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  /// Generates a unique route ID
  static String _generateRouteId() {
    return 'route_${DateTime.now().millisecondsSinceEpoch}_${(math.Random().nextDouble() * 10000).toInt()}';
  }

  /// Decodes a polyline string (Google polyline encoding)
  static List<LocationPoint> _decodePolyline(String encoded) {
    final points = <LocationPoint>[];
    int index = 0;
    final int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(
        LocationPoint(
          latitude: lat / 1e5,
          longitude: lng / 1e5,
          timestamp: DateTime.now(),
        ),
      );
    }

    return points;
  }

  /// Point-to-line distance calculation
  static double _pointToLineDistance(
    LocationPoint point,
    LocationPoint lineStart,
    LocationPoint lineEnd,
  ) {
    final A = point.latitude - lineStart.latitude;
    final B = point.longitude - lineStart.longitude;
    final C = lineEnd.latitude - lineStart.latitude;
    final D = lineEnd.longitude - lineStart.longitude;

    final dot = A * C + B * D;
    final lenSq = C * C + D * D;
    double param = -1.0;

    if (lenSq != 0) {
      param = dot / lenSq;
    }

    LocationPoint closestPoint;
    if (param < 0) {
      closestPoint = lineStart;
    } else if (param > 1) {
      closestPoint = lineEnd;
    } else {
      closestPoint = LocationPoint(
        latitude: lineStart.latitude + param * C,
        longitude: lineStart.longitude + param * D,
        timestamp: DateTime.now(),
      );
    }

    return point.distanceTo(closestPoint);
  }
}
