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
    if (token.isEmpty || token.length < 10) return false;
    // Mapbox tokens typically start with 'pk.' or 'sk.'
    return token.startsWith('pk.') || token.startsWith('sk.');
  }

  /// Throws ArgumentError if token is invalid
  static void validateMapboxToken(String token) {
    if (!isValidMapboxToken(token)) {
      throw ArgumentError('Invalid Mapbox access token format. Must start with pk. or sk. and be at least 10 characters long.');
    }
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
      NavigationConstants.drivingTrafficProfile,
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

  /// Validates coordinates and throws ArgumentError if invalid
  static void validateCoordinates(double latitude, double longitude, {String? context}) {
    if (!isValidCoordinate(latitude, longitude)) {
      throw ArgumentError(
        'Invalid coordinates: lat=$latitude, lng=$longitude. '
        'Latitude must be between -90 and 90, longitude between -180 and 180.'
        '${context != null ? ' Context: $context' : ''}',
      );
    }
  }

  /// Validates waypoint and throws ArgumentError if invalid
  static void validateWaypoint(Waypoint waypoint, {String? context}) {
    validateCoordinates(waypoint.latitude, waypoint.longitude, context: context);
  }

  /// Validates route parameters
  static void validateRouteRequest({
    required Waypoint origin,
    required Waypoint destination,
    List<Waypoint>? waypoints,
    String? profile,
  }) {
    validateWaypoint(origin, context: 'origin');
    validateWaypoint(destination, context: 'destination');
    
    if (!areCoordinatesDifferent(
      origin.latitude, origin.longitude,
      destination.latitude, destination.longitude,
    )) {
      throw ArgumentError('Origin and destination must be different locations');
    }

    if (waypoints != null) {
      for (int i = 0; i < waypoints.length; i++) {
        validateWaypoint(waypoints[i], context: 'waypoint[$i]');
      }
    }

    if (profile != null && !isValidRouteProfile(profile)) {
      throw ArgumentError('Invalid route profile: $profile');
    }
  }
}
