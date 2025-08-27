import '../models/waypoint.dart';
import 'constants.dart';

/// Utility functions for validating navigation data and parameters
class ValidationUtils {
  /// Validates if coordinates are within valid ranges
  static bool isValidCoordinate(double latitude, double longitude) {
    return latitude >= -90.0 &&
        latitude <= 90.0 &&
        longitude >= -180.0 &&
        longitude <= 180.0;
  }

  /// Validates if a waypoint has valid coordinates
  static bool isValidWaypoint(Waypoint waypoint) {
    return isValidCoordinate(waypoint.latitude, waypoint.longitude);
  }

  /// Validates if a list of waypoints is valid for routing
  static bool isValidWaypointList(List<Waypoint> waypoints) {
    if (waypoints.length < 2) return false;
    return waypoints.every((waypoint) => isValidWaypoint(waypoint));
  }

  /// Validates if zoom level is within acceptable range
  static bool isValidZoom(double zoom) {
    return zoom >= NavigationConstants.minZoom &&
        zoom <= NavigationConstants.maxZoom;
  }

  /// Validates if pitch is within acceptable range
  static bool isValidPitch(double pitch) {
    return pitch >= NavigationConstants.minPitch &&
        pitch <= NavigationConstants.maxPitch;
  }

  /// Validates if bearing is within valid range (0-360 degrees)
  static bool isValidBearing(double bearing) {
    return bearing >= 0.0 && bearing <= 360.0;
  }

  /// Validates if distance is a positive value
  static bool isValidDistance(double distance) {
    return distance >= 0.0 && distance.isFinite;
  }

  /// Validates if duration is a positive value
  static bool isValidDuration(double duration) {
    return duration >= 0.0 && duration.isFinite;
  }

  /// Validates if speed is within reasonable range
  static bool isValidSpeed(double speed) {
    return speed >= 0.0 && speed <= 200.0; // 200 m/s = 720 km/h
  }

  /// Validates if accuracy is within acceptable range
  static bool isValidAccuracy(double accuracy) {
    return accuracy >= 0.0 && accuracy <= 1000.0; // Max 1km accuracy
  }

  /// Validates if Mapbox access token format is correct
  static bool isValidMapboxToken(String token) {
    if (token.isEmpty) return false;
    // Mapbox tokens typically start with 'pk.' or 'sk.'
    return token.startsWith('pk.') || token.startsWith('sk.');
  }

  /// Validates if a string is not null or empty
  static bool isValidString(String? value) {
    return value != null && value.trim().isNotEmpty;
  }

  /// Validates if progress is between 0 and 1
  static bool isValidProgress(double progress) {
    return progress >= 0.0 && progress <= 1.0;
  }

  /// Validates if two coordinates are different (not the same point)
  static bool areCoordinatesDifferent(
      double lat1, double lon1, double lat2, double lon2) {
    const double tolerance = 0.000001; // ~0.1 meters
    return (lat1 - lat2).abs() > tolerance || (lon1 - lon2).abs() > tolerance;
  }

  /// Validates if a route profile is supported
  static bool isValidRouteProfile(String profile) {
    const validProfiles = [
      NavigationConstants.drivingProfile,
      NavigationConstants.walkingProfile,
      NavigationConstants.cyclingProfile,
    ];
    return validProfiles.contains(profile);
  }

  /// Validates if simulation speed is within reasonable range
  static bool isValidSimulationSpeed(double speed) {
    return speed > 0.0 && speed <= 100.0; // Max 100 m/s for simulation
  }

  /// Validates if animation duration is reasonable
  static bool isValidAnimationDuration(int duration) {
    return duration >= 0 && duration <= 10000; // Max 10 seconds
  }
}
