import 'package:geolocator/geolocator.dart' as geo;
import '../models/waypoint.dart';

/// Utilities for converting between Position and Waypoint objects
class CoordinateUtils {
  /// Converts a Position to a Waypoint
  static Waypoint positionToWaypoint(geo.Position position, {String? name}) {
    return Waypoint(
      latitude: position.latitude,
      longitude: position.longitude,
      name: name,
      altitude: position.altitude,
    );
  }

  /// Converts a Waypoint to a Position with default values
  static geo.Position waypointToPosition(
    Waypoint waypoint, {
    DateTime? timestamp,
    double accuracy = 5.0,
    double speed = 0.0,
    double heading = 0.0,
  }) {
    return geo.Position(
      latitude: waypoint.latitude,
      longitude: waypoint.longitude,
      timestamp: timestamp ?? DateTime.now(),
      accuracy: accuracy,
      altitude: waypoint.altitude ?? 0.0,
      altitudeAccuracy: 5.0,
      heading: heading,
      headingAccuracy: 5.0,
      speed: speed,
      speedAccuracy: 1.0,
    );
  }

  /// Converts a list of Positions to Waypoints
  static List<Waypoint> positionsToWaypoints(List<geo.Position> positions) {
    return positions.map((pos) => positionToWaypoint(pos)).toList();
  }

  /// Converts a list of Waypoints to Positions
  static List<geo.Position> waypointsToPositions(List<Waypoint> waypoints) {
    return waypoints.map((wp) => waypointToPosition(wp)).toList();
  }

  /// Creates a Waypoint from latitude/longitude coordinates
  static Waypoint createWaypoint({
    required double latitude,
    required double longitude,
    String? name,
    double? altitude,
  }) {
    return Waypoint(
      latitude: latitude,
      longitude: longitude,
      name: name,
      altitude: altitude,
    );
  }

  /// Creates a Position from coordinates with current timestamp
  static geo.Position createPosition({
    required double latitude,
    required double longitude,
    double accuracy = 5.0,
    double? altitude,
    double speed = 0.0,
    double heading = 0.0,
    DateTime? timestamp,
  }) {
    return geo.Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: timestamp ?? DateTime.now(),
      accuracy: accuracy,
      altitude: altitude ?? 0.0,
      altitudeAccuracy: 5.0,
      heading: heading,
      headingAccuracy: 5.0,
      speed: speed,
      speedAccuracy: 1.0,
    );
  }

  /// Extracts just the coordinate information as a simple record
  static ({double latitude, double longitude}) extractCoordinates(
      dynamic point) {
    if (point is geo.Position) {
      return (latitude: point.latitude, longitude: point.longitude);
    } else if (point is Waypoint) {
      return (latitude: point.latitude, longitude: point.longitude);
    } else {
      throw ArgumentError('Unsupported coordinate type: ${point.runtimeType}');
    }
  }

  /// Checks if two coordinate objects represent the same location
  static bool areCoordinatesEqual(dynamic point1, dynamic point2,
      {double tolerance = 0.000001}) {
    final coord1 = extractCoordinates(point1);
    final coord2 = extractCoordinates(point2);

    return (coord1.latitude - coord2.latitude).abs() < tolerance &&
        (coord1.longitude - coord2.longitude).abs() < tolerance;
  }

  /// Validates that coordinate objects have valid lat/lng values
  static bool isValidCoordinate(dynamic point) {
    try {
      final coord = extractCoordinates(point);
      return coord.latitude >= -90.0 &&
          coord.latitude <= 90.0 &&
          coord.longitude >= -180.0 &&
          coord.longitude <= 180.0;
    } catch (e) {
      return false;
    }
  }
}
