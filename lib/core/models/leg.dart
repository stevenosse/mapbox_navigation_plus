import 'step.dart';
import 'location_point.dart';

/// A leg of a route (typically between waypoints)
class Leg {
  /// Steps that make up this leg
  final List<Step> steps;

  /// Total distance of this leg in meters
  final double distance;

  /// Total expected duration of this leg in seconds
  final double duration;

  /// Summary description of this leg (e.g., "I-95 North")
  final String summary;

  /// Start location of this leg
  final LocationPoint startLocation;

  /// End location of this leg
  final LocationPoint endLocation;

  /// Leg index within the route
  final int index;

  const Leg({
    required this.steps,
    required this.distance,
    required this.duration,
    required this.summary,
    required this.startLocation,
    required this.endLocation,
    required this.index,
  });

  /// Creates a leg from Mapbox Directions API response
  factory Leg.fromMapbox(Map<String, dynamic> json, int legIndex) {
    // Parse steps
    final steps = <Step>[];
    if (json['steps'] != null) {
      for (int i = 0; i < (json['steps'] as List).length; i++) {
        steps.add(Step.fromMapbox((json['steps'] as List)[i] as Map<String, dynamic>, i, legIndex));
      }
    }

    // Parse start and end locations with null checks
    final startLocationData = json['start'];
    final endLocationData = json['end'];

    LocationPoint startLocation, endLocation;

    if (startLocationData is List && startLocationData.length >= 2) {
      startLocation = LocationPoint(
        latitude: (startLocationData[1] as num).toDouble(),
        longitude: (startLocationData[0] as num).toDouble(),
        timestamp: DateTime.now(),
      );
    } else {
      // Fallback: use first step's start or geometry
      startLocation = steps.isNotEmpty
          ? steps.first.startPoint
          : LocationPoint(latitude: 0.0, longitude: 0.0, timestamp: DateTime.now());
    }

    if (endLocationData is List && endLocationData.length >= 2) {
      endLocation = LocationPoint(
        latitude: (endLocationData[1] as num).toDouble(),
        longitude: (endLocationData[0] as num).toDouble(),
        timestamp: DateTime.now(),
      );
    } else {
      // Fallback: use last step's end or geometry
      endLocation = steps.isNotEmpty
          ? steps.last.endPoint
          : LocationPoint(latitude: 0.0, longitude: 0.0, timestamp: DateTime.now());
    }

    return Leg(
      steps: steps,
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
      duration: (json['duration'] as num?)?.toDouble() ?? 0.0,
      summary: json['summary'] as String? ?? '',
      startLocation: startLocation,
      endLocation: endLocation,
      index: legIndex,
    );
  }

  /// Gets the current step based on location and progress
  Step? getCurrentStep(LocationPoint currentLocation, double distanceTraveledInLeg) {
    if (steps.isEmpty) return null;

    double accumulatedDistance = 0.0;

    for (final step in steps) {
      if (distanceTraveledInLeg <= accumulatedDistance + step.distance) {
        return step;
      }
      accumulatedDistance += step.distance;
    }

    // If we've traveled beyond all steps, return the last one
    return steps.last;
  }

  /// Gets the next step after current step
  Step? getNextStep(Step currentStep) {
    final currentIndex = steps.indexOf(currentStep);
    if (currentIndex >= 0 && currentIndex < steps.length - 1) {
      return steps[currentIndex + 1];
    }
    return null;
  }

  /// Gets the upcoming maneuver based on current location
  Step? getUpcomingStep(LocationPoint currentLocation, double distanceTraveledInLeg) {
    final currentStep = getCurrentStep(currentLocation, distanceTraveledInLeg);
    if (currentStep == null) return null;

    // If current step has a maneuver and we're close to it, return next step
    final distanceRemainingInStep = currentStep.getRemainingDistance(currentLocation);
    if (distanceRemainingInStep < 50.0) { // Within 50m of maneuver
      return getNextStep(currentStep);
    }

    return currentStep;
  }

  /// Calculates total distance traveled in this leg
  double calculateDistanceTraveled(LocationPoint currentLocation) {
    if (steps.isEmpty) return 0.0;

    double totalDistance = 0.0;
    for (final step in steps) {
      if (step.isLocationOnStep(currentLocation)) {
        return totalDistance + step.getDistanceTraveled(currentLocation);
      }
      totalDistance += step.distance;
    }

    // If not found on any step, we've likely completed the leg
    return distance;
  }

  /// Calculates remaining distance in this leg
  double getRemainingDistance(LocationPoint currentLocation) {
    final traveled = calculateDistanceTraveled(currentLocation);
    return (distance - traveled).clamp(0.0, distance);
  }

  /// Calculates remaining duration in this leg
  double getRemainingDuration(LocationPoint currentLocation) {
    final traveled = calculateDistanceTraveled(currentLocation);
    if (distance <= 0) return 0.0;

    final progressRatio = traveled / distance;
    return (duration * (1.0 - progressRatio)).clamp(0.0, duration);
  }

  /// Checks if location is on this leg
  bool isLocationOnLeg(LocationPoint location, {double tolerance = 50.0}) {
    for (final step in steps) {
      if (step.isLocationOnStep(location, tolerance: tolerance)) {
        return true;
      }
    }
    return false;
  }

  /// Gets all geometry points for this leg
  List<LocationPoint> get geometry {
    final points = <LocationPoint>[];
    for (final step in steps) {
      points.addAll(step.geometry);
    }
    return points;
  }

  @override
  String toString() {
    return 'Leg(index: $index, summary: $summary, distance: ${distance.toStringAsFixed(0)}m, steps: ${steps.length})';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Leg &&
          runtimeType == other.runtimeType &&
          index == other.index &&
          distance == other.distance &&
          duration == other.duration;

  @override
  int get hashCode => Object.hash(index, distance, duration);
}