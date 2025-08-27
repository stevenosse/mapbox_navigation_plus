import 'package:geolocator/geolocator.dart' as geo;

/// A custom waypoint model that provides a cleaner interface for coordinate management
/// while reducing dependency on external Position objects.
class Waypoint {
  /// The latitude coordinate in decimal degrees
  final double latitude;

  /// The longitude coordinate in decimal degrees
  final double longitude;

  /// Optional altitude in meters above sea level
  final double? altitude;

  /// Optional accuracy of the position in meters
  final double? accuracy;

  /// Optional heading in degrees (0-360, where 0 is north)
  final double? heading;

  /// Optional speed in meters per second
  final double? speed;

  /// Optional timestamp when this waypoint was recorded
  final DateTime? timestamp;

  /// Optional name or description for this waypoint
  final String? name;

  /// Creates a new Waypoint with the specified coordinates
  const Waypoint({
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.accuracy,
    this.heading,
    this.speed,
    this.timestamp,
    this.name,
  });

  /// Creates a Waypoint from a Geolocator Position object
  factory Waypoint.fromPosition(geo.Position position, {String? name}) {
    return Waypoint(
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: position.altitude,
      accuracy: position.accuracy,
      heading: position.heading,
      speed: position.speed,
      timestamp: position.timestamp,
      name: name,
    );
  }

  /// Creates a Waypoint from latitude and longitude coordinates
  factory Waypoint.fromCoordinates(
    double latitude,
    double longitude, {
    double? altitude,
    String? name,
  }) {
    return Waypoint(
      latitude: latitude,
      longitude: longitude,
      altitude: altitude,
      name: name,
    );
  }

  /// Creates a Waypoint from a Map (useful for JSON parsing)
  factory Waypoint.fromMap(Map<String, dynamic> map) {
    return Waypoint(
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      altitude:
          map['altitude'] != null ? (map['altitude'] as num).toDouble() : null,
      accuracy:
          map['accuracy'] != null ? (map['accuracy'] as num).toDouble() : null,
      heading:
          map['heading'] != null ? (map['heading'] as num).toDouble() : null,
      speed: map['speed'] != null ? (map['speed'] as num).toDouble() : null,
      timestamp:
          map['timestamp'] != null ? DateTime.parse(map['timestamp']) : null,
      name: map['name'],
    );
  }

  /// Converts this Waypoint to a Geolocator Position object
  geo.Position toPosition() {
    return geo.Position(
      longitude: longitude,
      latitude: latitude,
      timestamp: timestamp ?? DateTime.now(),
      accuracy: accuracy ?? 0.0,
      altitude: altitude ?? 0.0,
      altitudeAccuracy: 0.0,
      heading: heading ?? 0.0,
      headingAccuracy: 0.0,
      speed: speed ?? 0.0,
      speedAccuracy: 0.0,
    );
  }

  /// Converts this Waypoint to a Map (useful for JSON serialization)
  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      if (altitude != null) 'altitude': altitude,
      if (accuracy != null) 'accuracy': accuracy,
      if (heading != null) 'heading': heading,
      if (speed != null) 'speed': speed,
      if (timestamp != null) 'timestamp': timestamp!.toIso8601String(),
      if (name != null) 'name': name,
    };
  }

  /// Calculates the distance in meters between this waypoint and another
  double distanceTo(Waypoint other) {
    return geo.Geolocator.distanceBetween(
      latitude,
      longitude,
      other.latitude,
      other.longitude,
    );
  }

  /// Calculates the bearing in degrees from this waypoint to another
  double bearingTo(Waypoint other) {
    return geo.Geolocator.bearingBetween(
      latitude,
      longitude,
      other.latitude,
      other.longitude,
    );
  }

  /// Creates a copy of this waypoint with optional parameter overrides
  Waypoint copyWith({
    double? latitude,
    double? longitude,
    double? altitude,
    double? accuracy,
    double? heading,
    double? speed,
    DateTime? timestamp,
    String? name,
  }) {
    return Waypoint(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitude: altitude ?? this.altitude,
      accuracy: accuracy ?? this.accuracy,
      heading: heading ?? this.heading,
      speed: speed ?? this.speed,
      timestamp: timestamp ?? this.timestamp,
      name: name ?? this.name,
    );
  }

  /// Checks if this waypoint is within a specified radius of another waypoint
  bool isWithinRadius(Waypoint other, double radiusInMeters) {
    return distanceTo(other) <= radiusInMeters;
  }

  /// Returns a formatted string representation of the coordinates
  String get coordinatesString =>
      '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Waypoint &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.altitude == altitude &&
        other.accuracy == accuracy &&
        other.heading == heading &&
        other.speed == speed &&
        other.timestamp == timestamp &&
        other.name == name;
  }

  @override
  int get hashCode {
    return Object.hash(
      latitude,
      longitude,
      altitude,
      accuracy,
      heading,
      speed,
      timestamp,
      name,
    );
  }

  @override
  String toString() {
    final buffer = StringBuffer('Waypoint(');
    buffer.write('lat: ${latitude.toStringAsFixed(6)}, ');
    buffer.write('lng: ${longitude.toStringAsFixed(6)}');
    if (altitude != null)
      buffer.write(', alt: ${altitude!.toStringAsFixed(1)}m');
    if (name != null) buffer.write(', name: "$name"');
    buffer.write(')');
    return buffer.toString();
  }
}

/// Extension methods for working with lists of waypoints
extension WaypointListExtensions on List<Waypoint> {
  /// Calculates the total distance of a route through all waypoints
  double get totalDistance {
    if (length < 2) return 0.0;
    double total = 0.0;
    for (int i = 0; i < length - 1; i++) {
      total += this[i].distanceTo(this[i + 1]);
    }
    return total;
  }

  /// Finds the waypoint closest to a given position
  Waypoint? closestTo(Waypoint target) {
    if (isEmpty) return null;
    return reduce(
        (a, b) => a.distanceTo(target) < b.distanceTo(target) ? a : b);
  }

  /// Converts all waypoints to Position objects
  List<geo.Position> toPositions() {
    return map((waypoint) => waypoint.toPosition()).toList();
  }
}
