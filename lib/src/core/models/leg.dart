import 'step.dart';
import 'location_point.dart';
import 'maneuver.dart';

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
        steps.add(
          Step.fromMapbox(
            (json['steps'] as List)[i] as Map<String, dynamic>,
            i,
            legIndex,
          ),
        );
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
          : LocationPoint(
              latitude: 0.0,
              longitude: 0.0,
              timestamp: DateTime.now(),
            );
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
          : LocationPoint(
              latitude: 0.0,
              longitude: 0.0,
              timestamp: DateTime.now(),
            );
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
  Step? getCurrentStep(
    LocationPoint currentLocation,
    double distanceTraveledInLeg,
  ) {
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

  /// Gets the upcoming maneuver based on current location with enhanced look-ahead logic
  Step? getUpcomingStep(
    LocationPoint currentLocation,
    double distanceTraveledInLeg, {
    double currentSpeed = 0.0, // m/s
    bool useDynamicThresholds = true,
  }) {
    final currentStep = getCurrentStep(currentLocation, distanceTraveledInLeg);
    if (currentStep == null) return null;

    final distanceRemainingInStep = currentStep.getRemainingDistance(
      currentLocation,
    );

    // Calculate dynamic thresholds based on speed and context
    final thresholds = _calculateDynamicThresholds(
      currentSpeed,
      currentStep,
      useDynamicThresholds,
    );

    // Enhanced look-ahead logic for complex maneuver sequences
    final lookaheadAnalysis = _analyzeUpcomingManeuvers(
      currentStep,
      distanceRemainingInStep,
    );

    // Priority 1: Emergency detection for very close maneuvers
    if (distanceRemainingInStep < thresholds.immediateThreshold) {
      return getNextStep(currentStep);
    }

    // Priority 2: Handle complex maneuver sequences
    if (lookaheadAnalysis.shouldAdvanceToNext) {
      return lookaheadAnalysis.targetStep;
    }

    // Priority 3: Standard announcement timing with dynamic thresholds
    if (distanceRemainingInStep >= thresholds.minAnnouncementDistance &&
        distanceRemainingInStep <= thresholds.maxAnnouncementDistance) {
      return currentStep;
    }

    // Priority 4: Check for advance announcement in complex scenarios
    if (distanceRemainingInStep > thresholds.maxAnnouncementDistance) {
      final nextStep = getNextStep(currentStep);
      if (nextStep != null &&
          _shouldAnnounceEarly(
            currentStep,
            nextStep,
            distanceRemainingInStep,
          )) {
        return currentStep; // Announce current maneuver now, next one will be announced soon
      }
    }

    return currentStep;
  }

  /// Calculates dynamic distance thresholds based on speed and step complexity
  _DynamicThresholds _calculateDynamicThresholds(
    double speed,
    Step currentStep,
    bool useDynamicThresholds,
  ) {
    if (!useDynamicThresholds) {
      // Fallback to original static thresholds
      return _DynamicThresholds(
        immediateThreshold: 30.0,
        minAnnouncementDistance: 30.0,
        maxAnnouncementDistance: 300.0,
      );
    }

    // Base calculation: 2-3 seconds reaction time at current speed
    double immediateThreshold = speed * 2.0;
    double minAnnouncementDistance = speed * 3.0; // 3 seconds minimum
    double maxAnnouncementDistance = speed * 15.0; // 15 seconds maximum

    // Apply complexity multipliers
    if (_isComplexStep(currentStep)) {
      minAnnouncementDistance *= 1.5; // 50% more distance for complex maneuvers
      maxAnnouncementDistance *= 1.3; // 30% more for complex maneuvers
    }

    // Apply bounds for safety
    immediateThreshold = immediateThreshold.clamp(20.0, 100.0);
    minAnnouncementDistance = minAnnouncementDistance.clamp(50.0, 200.0);
    maxAnnouncementDistance = maxAnnouncementDistance.clamp(200.0, 800.0);

    return _DynamicThresholds(
      immediateThreshold: immediateThreshold,
      minAnnouncementDistance: minAnnouncementDistance,
      maxAnnouncementDistance: maxAnnouncementDistance,
    );
  }

  /// Analyzes upcoming maneuvers for complex sequences
  _LookaheadAnalysis _analyzeUpcomingManeuvers(
    Step currentStep,
    double distanceRemaining,
  ) {
    final nextStep = getNextStep(currentStep);
    if (nextStep == null) {
      return _LookaheadAnalysis(shouldAdvanceToNext: false);
    }

    // Check for immediate follow-up maneuvers
    if (distanceRemaining + nextStep.distance < 100.0) {
      // Very close maneuvers - announce next one immediately
      return _LookaheadAnalysis(
        shouldAdvanceToNext: true,
        targetStep: nextStep,
      );
    }

    // Check for complex sequences (roundabouts, highway exits, etc.)
    if (_isComplexManeuverSequence(currentStep, nextStep)) {
      final combinedDistance = distanceRemaining + nextStep.distance;
      if (combinedDistance < 200.0) {
        return _LookaheadAnalysis(
          shouldAdvanceToNext: true,
          targetStep: nextStep,
        );
      }
    }

    return _LookaheadAnalysis(shouldAdvanceToNext: false);
  }

  /// Determines if a step is complex (requires extra preparation time)
  bool _isComplexStep(Step step) {
    switch (step.maneuver.type) {
      case ManeuverType.roundabout:
      case ManeuverType.exitRotary:
      case ManeuverType.exitRoundabout:
        return true;
      case ManeuverType.offRamp:
      case ManeuverType.fork:
        return true;
      case ManeuverType.merge:
        return step.maneuver.modifier == ManeuverModifier.sharpLeft ||
            step.maneuver.modifier == ManeuverModifier.sharpRight;
      case ManeuverType.turn:
        return step.maneuver.modifier == ManeuverModifier.uTurn ||
            step.maneuver.modifier == ManeuverModifier.sharpLeft ||
            step.maneuver.modifier == ManeuverModifier.sharpRight;
      default:
        return false;
    }
  }

  /// Checks if two steps form a complex maneuver sequence
  bool _isComplexManeuverSequence(Step currentStep, Step nextStep) {
    // Highway exit followed by immediate turn
    if (currentStep.maneuver.type == ManeuverType.offRamp &&
        nextStep.maneuver.type == ManeuverType.turn) {
      return true;
    }

    // Roundabout followed by immediate turn
    if ((currentStep.maneuver.type == ManeuverType.roundabout ||
            currentStep.maneuver.type == ManeuverType.exitRoundabout) &&
        nextStep.maneuver.type == ManeuverType.turn) {
      return true;
    }

    // Fork followed by merge
    if (currentStep.maneuver.type == ManeuverType.fork &&
        nextStep.maneuver.type == ManeuverType.merge) {
      return true;
    }

    return false;
  }

  /// Determines if current maneuver should be announced early due to close next maneuver
  bool _shouldAnnounceEarly(
    Step currentStep,
    Step nextStep,
    double distanceRemaining,
  ) {
    final combinedDistance = distanceRemaining + nextStep.distance;

    // If next maneuver is very close, announce current one early
    if (combinedDistance <= 150.0) {
      return true;
    }

    // If current maneuver is complex and next one follows quickly
    if (_isComplexStep(currentStep) && combinedDistance <= 250.0) {
      return true;
    }

    return false;
  }

  /// Enhanced upcoming step method for backward compatibility
  Step? getUpcomingStepBasic(
    LocationPoint currentLocation,
    double distanceTraveledInLeg,
  ) {
    return getUpcomingStep(
      currentLocation,
      distanceTraveledInLeg,
      useDynamicThresholds: false,
    );
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

/// Helper class for dynamic distance thresholds
class _DynamicThresholds {
  final double immediateThreshold;
  final double minAnnouncementDistance;
  final double maxAnnouncementDistance;

  const _DynamicThresholds({
    required this.immediateThreshold,
    required this.minAnnouncementDistance,
    required this.maxAnnouncementDistance,
  });
}

/// Helper class for lookahead maneuver analysis
class _LookaheadAnalysis {
  final bool shouldAdvanceToNext;
  final Step? targetStep;

  const _LookaheadAnalysis({
    required this.shouldAdvanceToNext,
    this.targetStep,
  });
}
