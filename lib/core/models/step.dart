import 'maneuver.dart';
import 'voice_instruction.dart';
import 'location_point.dart';

/// Individual navigation step within a route leg
class Step {
  /// Geometry of the step as GeoJSON
  final List<LocationPoint> geometry;

  /// Distance of this step in meters
  final double distance;

  /// Expected duration of this step in seconds
  final double duration;

  /// Maneuver information for this step
  final Maneuver maneuver;

  /// Voice instructions for this step
  final List<VoiceInstruction> voiceInstructions;

  /// Human-readable name for this step (road name, etc.)
  final String name;

  /// Mode of transportation for this step
  final String mode;

  /// Speed limit for this step (if available)
  final double? speedLimit;

  /// Intersections along this step
  final List<Intersection> intersections;

  /// Step index within the leg
  final int index;

  const Step({
    required this.geometry,
    required this.distance,
    required this.duration,
    required this.maneuver,
    required this.voiceInstructions,
    required this.name,
    required this.mode,
    this.speedLimit,
    required this.intersections,
    required this.index,
  });

  /// Creates a step from Mapbox Directions API response
  factory Step.fromMapbox(
    Map<String, dynamic> json,
    int stepIndex,
    int legIndex,
  ) {
    // Parse geometry
    final geometry = json['geometry'] as Map<String, dynamic>?;
    List<LocationPoint> points = [];

    if (geometry != null && geometry['coordinates'] != null) {
      final coordinates = geometry['coordinates'] as List;
      for (final coord in coordinates) {
        points.add(
          LocationPoint(
            latitude: (coord as List)[1] as double,
            longitude: coord[0] as double,
            timestamp: DateTime.now(),
          ),
        );
      }
    }

    // Parse intersections
    final intersections = <Intersection>[];
    if (json['intersections'] != null) {
      for (final intersection in json['intersections'] as List) {
        intersections.add(
          Intersection.fromMapbox(intersection as Map<String, dynamic>),
        );
      }
    }

    // Parse voice instructions
    final voiceInstructions = <VoiceInstruction>[];
    if (json['voiceInstructions'] != null) {
      for (final instruction in json['voiceInstructions'] as List) {
        voiceInstructions.add(
          VoiceInstruction.fromMapbox(instruction as Map<String, dynamic>),
        );
      }
    }

    return Step(
      geometry: points,
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
      duration: (json['duration'] as num?)?.toDouble() ?? 0.0,
      maneuver: Maneuver.fromMapbox(json, stepIndex, legIndex),
      voiceInstructions: voiceInstructions,
      name: json['name'] as String? ?? '',
      mode: json['mode'] as String? ?? 'driving',
      speedLimit: (json['speedLimit'] as num?)?.toDouble(),
      intersections: intersections,
      index: stepIndex,
    );
  }

  /// Gets the starting point of this step
  LocationPoint get startPoint {
    return geometry.isNotEmpty ? geometry.first : maneuver.location;
  }

  /// Gets the ending point of this step
  LocationPoint get endPoint {
    return geometry.isNotEmpty ? geometry.last : maneuver.location;
  }

  /// Gets the distance traveled along this step for a given location
  double getDistanceTraveled(LocationPoint currentLocation) {
    if (geometry.isEmpty) return 0.0;

    double totalDistance = 0.0;
    double minDistance = double.infinity;

    for (int i = 0; i < geometry.length - 1; i++) {
      final start = geometry[i];
      final end = geometry[i + 1];
      final segmentDistance = start.distanceTo(end);

      // Check if current location is on this segment
      final distanceToStart = currentLocation.distanceTo(start);
      final distanceToEnd = currentLocation.distanceTo(end);

      // Simple check - if sum of distances is close to segment length, point is on segment
      final totalDist = distanceToStart + distanceToEnd;
      if ((totalDist - segmentDistance).abs() < 10.0) {
        // 10m tolerance
        if (distanceToStart < minDistance) {
          minDistance = distanceToStart;
          return totalDistance + distanceToStart;
        }
      }

      totalDistance += segmentDistance;
    }

    return totalDistance;
  }

  /// Gets the remaining distance in this step from a given location
  double getRemainingDistance(LocationPoint currentLocation) {
    final traveled = getDistanceTraveled(currentLocation);
    return (distance - traveled).clamp(0.0, distance);
  }

  /// Checks if a location is on this step geometry
  bool isLocationOnStep(LocationPoint location, {double tolerance = 20.0}) {
    for (int i = 0; i < geometry.length - 1; i++) {
      final start = geometry[i];
      final end = geometry[i + 1];
      final distanceToStart = location.distanceTo(start);
      final distanceToEnd = location.distanceTo(end);
      final segmentDistance = start.distanceTo(end);

      final totalDist = distanceToStart + distanceToEnd;
      if ((totalDist - segmentDistance).abs() < tolerance) {
        return true;
      }
    }
    return false;
  }

  @override
  String toString() {
    return 'Step(index: $index, name: $name, distance: ${distance.toStringAsFixed(0)}m, maneuver: $maneuver)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Step &&
          runtimeType == other.runtimeType &&
          index == other.index &&
          name == other.name &&
          distance == other.distance;

  @override
  int get hashCode => Object.hash(index, name, distance);
}

/// Intersection information within a step
class Intersection {
  /// Location of the intersection
  final LocationPoint location;

  /// Bearings of incoming roads
  final List<double> bearings;

  /// Entry flags for each bearing
  final List<bool> entries;

  /// Class of road for each bearing
  final List<String> classes;

  /// Traffic light information
  final bool? hasTrafficLight;

  /// Intersection in/out classifications
  final int? inClassification;
  final int? outClassification;

  const Intersection({
    required this.location,
    required this.bearings,
    required this.entries,
    required this.classes,
    this.hasTrafficLight,
    this.inClassification,
    this.outClassification,
  });

  factory Intersection.fromMapbox(Map<String, dynamic> json) {
    final location = json['location'] as List;
    return Intersection(
      location: LocationPoint(
        latitude: location[1] as double,
        longitude: location[0] as double,
        timestamp: DateTime.now(),
      ),
      bearings: (json['bearings'] as List)
          .map((e) => (e as num).toDouble())
          .toList(),
      entries: (json['entry'] as List).map((e) => e as bool).toList(),
      classes: (json['classes'] as List?)?.cast<String>() ?? [],
      hasTrafficLight: json['trafficLight'] as bool?,
      inClassification: json['in'] as int?,
      outClassification: json['out'] as int?,
    );
  }

  @override
  String toString() {
    return 'Intersection(location: $location, bearings: $bearings, hasLight: $hasTrafficLight)';
  }
}
