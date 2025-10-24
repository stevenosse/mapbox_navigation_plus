import 'dart:math' as math;

/// Represents a geographic location point
class LocationPoint {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? heading;
  final double? speed;
  final DateTime timestamp;
  final double? altitude;

  const LocationPoint({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.heading,
    this.speed,
    required this.timestamp,
    this.altitude,
  });

  /// Creates a LocationPoint with current timestamp
  LocationPoint.withCurrentTime({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.heading,
    this.speed,
    this.altitude,
  }) : timestamp = DateTime.now();

  /// Creates a LocationPoint from latitude and longitude
  factory LocationPoint.fromLatLng(double latitude, double longitude) {
    return LocationPoint.withCurrentTime(
      latitude: latitude,
      longitude: longitude,
    );
  }

  /// Calculates distance to another point in meters using Haversine formula
  double distanceTo(LocationPoint other) {
    const double earthRadius = 6371000; // Earth's radius in meters

    final double lat1Rad = _toRadians(latitude);
    final double lat2Rad = _toRadians(other.latitude);
    final double deltaLatRad = _toRadians(other.latitude - latitude);
    final double deltaLonRad = _toRadians(other.longitude - longitude);

    final double a =
        (deltaLatRad / 2).sin() * (deltaLatRad / 2).sin() +
        lat1Rad.cos() *
            lat2Rad.cos() *
            (deltaLonRad / 2).sin() *
            (deltaLonRad / 2).sin();

    final double c = 2 * a.sqrt().asin();

    return earthRadius * c;
  }

  /// Calculates bearing to another point in degrees
  double bearingTo(LocationPoint other) {
    final double lat1Rad = _toRadians(latitude);
    final double lat2Rad = _toRadians(other.latitude);
    final double deltaLonRad = _toRadians(other.longitude - longitude);

    final double y = deltaLonRad.sin() * lat2Rad.cos();
    final double x =
        lat1Rad.cos() * lat2Rad.sin() -
        lat1Rad.sin() * lat2Rad.cos() * deltaLonRad.cos();

    final double bearingRad = y.atan2(x);
    double bearingDeg = _toDegrees(bearingRad);

    // Normalize to 0-360 degrees
    if (bearingDeg < 0) bearingDeg += 360;

    return bearingDeg;
  }

  /// Helper method to convert degrees to radians
  double _toRadians(double degrees) => degrees * (3.14159265359 / 180.0);

  /// Helper method to convert radians to degrees
  double _toDegrees(double radians) => radians * (180.0 / 3.14159265359);

  @override
  String toString() {
    return 'LocationPoint(lat: $latitude, lng: $longitude, accuracy: $accuracy, heading: $heading, speed: $speed)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocationPoint &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode;
}

/// Extension for double math operations
extension DoubleMath on double {
  double sin() => math.sin(this);
  double cos() => math.cos(this);
  double atan2(double x) => math.atan2(this, x);
  double asin() => math.asin(this);
  double sqrt() => math.sqrt(this);
}
