import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';

/// Represents a single navigation step/instruction in the route
class NavigationStep {
  /// The instruction text for this step
  final String instruction;
  
  /// The maneuver type (e.g., 'turn', 'merge', 'arrive')
  final String maneuver;
  
  /// The direction modifier (e.g., 'left', 'right', 'straight')
  final String? modifier;
  
  /// The distance to travel for this step in meters
  final double distance;
  
  /// The estimated duration for this step in seconds
  final double duration;
  
  /// The coordinate where this step begins
  final Position startLocation;
  
  /// The coordinate where this step ends
  final Position endLocation;
  
  /// The geometry coordinates for this step
  final List<Position> geometry;
  
  /// Whether this step has been completed
  bool isCompleted;
  
  /// Whether this is the current active step
  bool isActive;

  NavigationStep({
    required this.instruction,
    required this.maneuver,
    this.modifier,
    required this.distance,
    required this.duration,
    required this.startLocation,
    required this.endLocation,
    required this.geometry,
    this.isCompleted = false,
    this.isActive = false,
  });

  /// Creates a NavigationStep from Mapbox Directions API response
  factory NavigationStep.fromMapboxStep(Map<String, dynamic> step) {
    final maneuver = step['maneuver'] as Map<String, dynamic>;
    final geometry = step['geometry'] as Map<String, dynamic>;
    final coordinates = geometry['coordinates'] as List<dynamic>;
    
    // Convert coordinates to Position objects
    final geometryPositions = coordinates.map((coord) {
      final coordList = coord as List<dynamic>;
      return Position(
        longitude: coordList[0].toDouble(),
        latitude: coordList[1].toDouble(),
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    }).toList();
    
    return NavigationStep(
      instruction: maneuver['instruction'] as String? ?? '',
      maneuver: maneuver['type'] as String? ?? 'unknown',
      modifier: maneuver['modifier'] as String?,
      distance: (step['distance'] as num?)?.toDouble() ?? 0.0,
      duration: (step['duration'] as num?)?.toDouble() ?? 0.0,
      startLocation: geometryPositions.first,
      endLocation: geometryPositions.last,
      geometry: geometryPositions,
    );
  }

  /// Checks if the user should advance to the next step
  bool shouldAdvanceStep(Position currentPosition, {double threshold = 30.0}) {
    final distanceToEnd = Geolocator.distanceBetween(
      currentPosition.latitude,
      currentPosition.longitude,
      endLocation.latitude,
      endLocation.longitude,
    );
    
    return distanceToEnd <= threshold;
  }
  
  /// Calculates progress through this step (0.0 to 1.0)
  double calculateProgress(Position currentPosition) {
    final totalDistance = Geolocator.distanceBetween(
      startLocation.latitude,
      startLocation.longitude,
      endLocation.latitude,
      endLocation.longitude,
    );
    
    if (totalDistance == 0) return 1.0;
    
    final distanceFromStart = Geolocator.distanceBetween(
      startLocation.latitude,
      startLocation.longitude,
      currentPosition.latitude,
      currentPosition.longitude,
    );
    
    return (distanceFromStart / totalDistance).clamp(0.0, 1.0);
  }
  
  /// Gets the bearing for this step
  double getBearing() {
    return Geolocator.bearingBetween(
      startLocation.latitude,
      startLocation.longitude,
      endLocation.latitude,
      endLocation.longitude,
    );
  }

  /// Calculates the remaining distance from current position to the end of this step
  double getRemainingDistance(Position currentPosition) {
    // If we have detailed geometry, find the closest point and calculate distance along the path
    if (geometry.length > 1) {
      return _calculateDistanceAlongPath(currentPosition);
    }
    
    // Fallback to straight line distance
    return Geolocator.distanceBetween(
      currentPosition.latitude,
      currentPosition.longitude,
      endLocation.latitude,
      endLocation.longitude,
    );
  }

  /// Calculates distance along the step's path from current position to end
  double _calculateDistanceAlongPath(Position currentPosition) {
    if (geometry.isEmpty) return 0.0;
    
    // Find the closest point on the path
    int closestIndex = 0;
    double minDistance = double.infinity;
    
    for (int i = 0; i < geometry.length; i++) {
      final distance = Geolocator.distanceBetween(
        currentPosition.latitude,
        currentPosition.longitude,
        geometry[i].latitude,
        geometry[i].longitude,
      );
      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
      }
    }
    
    // Calculate remaining distance from closest point to end
    double remainingDistance = 0.0;
    for (int i = closestIndex; i < geometry.length - 1; i++) {
      remainingDistance += Geolocator.distanceBetween(
        geometry[i].latitude,
        geometry[i].longitude,
        geometry[i + 1].latitude,
        geometry[i + 1].longitude,
      );
    }
    
    return remainingDistance;
  }
  
  /// Checks if the user is on the correct path for this step
  bool isOnPath(Position currentPosition, {double tolerance = 50.0}) {
    if (geometry.isEmpty) {
      // Fallback to straight line distance check
      final distanceToLine = _distanceToLine(
        currentPosition,
        startLocation,
        endLocation,
      );
      return distanceToLine <= tolerance;
    }
    
    // Check distance to closest point on geometry
    double minDistance = double.infinity;
    for (final point in geometry) {
      final distance = Geolocator.distanceBetween(
        currentPosition.latitude,
        currentPosition.longitude,
        point.latitude,
        point.longitude,
      );
      if (distance < minDistance) {
        minDistance = distance;
      }
    }
    
    return minDistance <= tolerance;
  }
  
  /// Calculates perpendicular distance from point to line segment
  double _distanceToLine(Position point, Position lineStart, Position lineEnd) {
    // Convert to radians for calculation
    final lat1 = lineStart.latitude * (math.pi / 180);
    final lon1 = lineStart.longitude * (math.pi / 180);
    final lat2 = lineEnd.latitude * (math.pi / 180);
    final lat3 = point.latitude * (math.pi / 180);
    final lon3 = point.longitude * (math.pi / 180);
    
    // Calculate cross track distance
    final dLon13 = lon3 - lon1;
    
    final crossTrackDistance = math.asin(
      math.sin(lat3 - lat1) * math.cos(lat2) +
      math.cos(lat3) * math.sin(lat2) * math.cos(dLon13)
    ).abs();
    
    // Convert back to meters (approximate)
    return crossTrackDistance * 6371000; // Earth radius in meters
  }

  /// Creates a copy of this step with updated properties
  NavigationStep copyWith({
    String? instruction,
    String? maneuver,
    String? modifier,
    double? distance,
    double? duration,
    Position? startLocation,
    Position? endLocation,
    List<Position>? geometry,
    bool? isCompleted,
    bool? isActive,
  }) {
    return NavigationStep(
      instruction: instruction ?? this.instruction,
      maneuver: maneuver ?? this.maneuver,
      modifier: modifier ?? this.modifier,
      distance: distance ?? this.distance,
      duration: duration ?? this.duration,
      startLocation: startLocation ?? this.startLocation,
      endLocation: endLocation ?? this.endLocation,
      geometry: geometry ?? this.geometry,
      isCompleted: isCompleted ?? this.isCompleted,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  String toString() {
    return 'NavigationStep(instruction: $instruction, maneuver: $maneuver, distance: ${distance.toStringAsFixed(0)}m)';
  }
}