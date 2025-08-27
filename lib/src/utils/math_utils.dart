import 'dart:math';
import 'package:geolocator/geolocator.dart' as geo;
import '../models/waypoint.dart';

/// Mathematical utility functions for navigation calculations
class MathUtils {
  // Earth's radius in meters
  static const double earthRadiusMeters = 6371000.0;

  // Mathematical constants
  static const double pi = 3.14159265359;
  static const double degreesToRadians = pi / 180.0;

  /// Calculates distance between two points using Haversine formula
  /// Returns distance in meters
  static double calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    final dLat = (lat2 - lat1) * degreesToRadians;
    final dLon = (lon2 - lon1) * degreesToRadians;

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * degreesToRadians) *
            cos(lat2 * degreesToRadians) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadiusMeters * c;
  }

  /// Calculates distance between two Waypoint objects
  static double calculateDistanceBetweenWaypoints(
      Waypoint point1, Waypoint point2) {
    return calculateDistance(
        point1.latitude, point1.longitude, point2.latitude, point2.longitude);
  }

  /// Calculates distance between two Position objects
  static double calculateDistanceBetweenPositions(
      geo.Position pos1, geo.Position pos2) {
    return calculateDistance(
        pos1.latitude, pos1.longitude, pos2.latitude, pos2.longitude);
  }

  /// Calculates bearing between two points
  /// Returns bearing in degrees (0-360)
  static double calculateBearing(
      double lat1, double lon1, double lat2, double lon2) {
    final dLon = (lon2 - lon1) * degreesToRadians;
    final lat1Rad = lat1 * degreesToRadians;
    final lat2Rad = lat2 * degreesToRadians;

    final y = sin(dLon) * cos(lat2Rad);
    final x =
        cos(lat1Rad) * sin(lat2Rad) - sin(lat1Rad) * cos(lat2Rad) * cos(dLon);

    final bearingRad = atan2(y, x);
    final bearingDeg = bearingRad * 180.0 / pi;

    return (bearingDeg + 360) % 360;
  }

  /// Calculates bearing between two Waypoint objects
  static double calculateBearingBetweenWaypoints(Waypoint from, Waypoint to) {
    return calculateBearing(
        from.latitude, from.longitude, to.latitude, to.longitude);
  }

  /// Calculates bearing between two Position objects
  static double calculateBearingBetweenPositions(
      geo.Position from, geo.Position to) {
    return calculateBearing(
        from.latitude, from.longitude, to.latitude, to.longitude);
  }

  /// Interpolates between two points at a given ratio (0.0 to 1.0)
  /// Returns the interpolated latitude and longitude
  static ({double latitude, double longitude}) interpolate(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
    double ratio,
  ) {
    final clampedRatio = ratio.clamp(0.0, 1.0);
    return (
      latitude: lat1 + (lat2 - lat1) * clampedRatio,
      longitude: lon1 + (lon2 - lon1) * clampedRatio,
    );
  }

  /// Interpolates between two Waypoint objects
  static Waypoint interpolateBetweenWaypoints(
    Waypoint point1,
    Waypoint point2,
    double ratio,
  ) {
    final result = interpolate(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
      ratio,
    );

    return Waypoint(
      latitude: result.latitude,
      longitude: result.longitude,
    );
  }

  /// Converts speed from m/s to km/h
  static double msToKmh(double speedMs) {
    return speedMs * 3.6;
  }

  /// Converts speed from km/h to m/s
  static double kmhToMs(double speedKmh) {
    return speedKmh / 3.6;
  }

  /// Converts duration from seconds to human-readable string
  static String formatDuration(double durationSeconds) {
    final hours = (durationSeconds / 3600).floor();
    final minutes = ((durationSeconds % 3600) / 60).floor();
    final seconds = (durationSeconds % 60).floor();

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  /// Converts distance in meters to human-readable string
  static String formatDistance(double distanceMeters) {
    if (distanceMeters >= 1000) {
      final km = distanceMeters / 1000;
      return '${km.toStringAsFixed(km >= 10 ? 0 : 1)} km';
    } else {
      return '${distanceMeters.round()} m';
    }
  }

  /// Normalizes an angle to 0-360 degrees
  static double normalizeAngle(double angle) {
    return ((angle % 360) + 360) % 360;
  }

  /// Calculates the shortest angular difference between two bearings
  static double angleDifference(double angle1, double angle2) {
    final diff = (angle2 - angle1 + 540) % 360 - 180;
    return diff.abs();
  }

  /// Determines if a point is within a certain radius of another point
  static bool isWithinRadius(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
    double radiusMeters,
  ) {
    return calculateDistance(lat1, lon1, lat2, lon2) <= radiusMeters;
  }

  /// Clamps a value between min and max
  static double clamp(double value, double min, double max) {
    return value < min ? min : (value > max ? max : value);
  }

  /// Linear interpolation between two values
  static double lerp(double start, double end, double t) {
    return start + (end - start) * t.clamp(0.0, 1.0);
  }
}
