import 'route_model.dart';
import 'leg.dart';
import 'step.dart';
import 'maneuver.dart';
import 'location_point.dart';

/// Tracks progress along a navigation route
class RouteProgress {
  /// Current location
  final LocationPoint currentLocation;

  /// Current route
  final RouteModel route;

  /// Current leg index
  final int currentLegIndex;

  /// Current step index
  final int currentStepIndex;

  /// Total distance traveled along the route (meters)
  final double distanceTraveled;

  /// Remaining distance to destination (meters)
  final double distanceRemaining;

  /// Traveled duration along the route (seconds)
  final double durationTraveled;

  /// Remaining duration to destination (seconds)
  final double durationRemaining;

  /// Current leg
  Leg get currentLeg => route.legs[currentLegIndex];

  /// Current step
  Step get currentStep => currentLeg.steps[currentStepIndex];

  /// Upcoming maneuver
  Maneuver? get upcomingManeuver => currentStep.maneuver;

  /// Distance to next maneuver (meters)
  final double distanceToNextManeuver;

  /// Distance traveled in current leg (meters)
  final double distanceTraveledInCurrentLeg;

  /// Distance remaining in current leg (meters)
  final double distanceRemainingInCurrentLeg;

  /// Distance traveled in current step (meters)
  final double distanceTraveledInCurrentStep;

  /// Distance remaining in current step (meters)
  final double distanceRemainingInCurrentStep;

  /// Progress along the route (0.0 to 1.0)
  double get routeProgress =>
      route.distance > 0 ? distanceTraveled / route.distance : 0.0;

  /// Progress along current leg (0.0 to 1.0)
  double get legProgress => currentLeg.distance > 0
      ? distanceTraveledInCurrentLeg / currentLeg.distance
      : 0.0;

  /// Progress along current step (0.0 to 1.0)
  double get stepProgress => currentStep.distance > 0
      ? distanceTraveledInCurrentStep / currentStep.distance
      : 0.0;

  /// Estimated time of arrival
  DateTime get eta =>
      DateTime.now().add(Duration(seconds: durationRemaining.round()));

  /// Current road name
  String get currentRoadName =>
      currentStep.name.isNotEmpty ? currentStep.name : currentLeg.summary;

  /// Whether user is on the route
  final bool isOnRoute;

  /// Distance from route (if off route)
  final double distanceFromRoute;

  const RouteProgress({
    required this.currentLocation,
    required this.route,
    required this.currentLegIndex,
    required this.currentStepIndex,
    required this.distanceTraveled,
    required this.distanceRemaining,
    required this.durationTraveled,
    required this.durationRemaining,
    required this.distanceToNextManeuver,
    required this.distanceTraveledInCurrentLeg,
    required this.distanceRemainingInCurrentLeg,
    required this.distanceTraveledInCurrentStep,
    required this.distanceRemainingInCurrentStep,
    this.isOnRoute = true,
    this.distanceFromRoute = 0.0,
  });

  /// Creates route progress from current location and route
  factory RouteProgress.fromLocationAndRoute({
    required LocationPoint currentLocation,
    required RouteModel route,
    required DateTime startTime,
  }) {
    // Find current leg and step
    Leg? currentLeg;
    Step? currentStep;
    int currentLegIndex = 0;
    int currentStepIndex = 0;

    double totalDistanceTraveled = 0.0;
    double totalDurationTraveled = 0.0;

    // Find which leg and step we're currently on
    for (int legIndex = 0; legIndex < route.legs.length; legIndex++) {
      final leg = route.legs[legIndex];

      if (leg.isLocationOnLeg(currentLocation)) {
        currentLeg = leg;
        currentLegIndex = legIndex;

        // Find current step within this leg
        for (int stepIndex = 0; stepIndex < leg.steps.length; stepIndex++) {
          final step = leg.steps[stepIndex];

          if (step.isLocationOnStep(currentLocation)) {
            currentStep = step;
            currentStepIndex = stepIndex;
            break;
          }
        }
        break;
      }

      totalDistanceTraveled += leg.distance;
      totalDurationTraveled += leg.duration;
    }

    // Default to first leg and step if not found
    currentLeg ??= route.legs.isNotEmpty
        ? route.legs.first
        : Leg(
            steps: [],
            distance: 0.0,
            duration: 0.0,
            summary: '',
            startLocation: route.origin,
            endLocation: route.destination,
            index: 0,
          );
    currentStep ??= currentLeg.steps.isNotEmpty
        ? currentLeg.steps.first
        : Step(
            geometry: [],
            distance: 0.0,
            duration: 0.0,
            maneuver: Maneuver(
              type: ManeuverType.depart,
              instruction: 'Depart',
              distanceToManeuver: 0.0,
              location: currentLocation,
              stepIndex: 0,
              legIndex: 0,
            ),
            voiceInstructions: [],
            name: '',
            mode: 'driving',
            intersections: [],
            index: 0,
          );

    // Calculate distances
    final distanceTraveledInCurrentLeg = currentLeg.calculateDistanceTraveled(
      currentLocation,
    );
    final distanceRemainingInCurrentLeg = currentLeg.getRemainingDistance(
      currentLocation,
    );
    final distanceTraveledInCurrentStep = currentStep.getDistanceTraveled(
      currentLocation,
    );
    final distanceRemainingInCurrentStep = currentStep.getRemainingDistance(
      currentLocation,
    );

    // Calculate distance to next maneuver
    final upcomingStep = currentLeg.getUpcomingStep(
      currentLocation,
      distanceTraveledInCurrentLeg,
    );
    double distanceToNextManeuver = 0.0;

    if (upcomingStep != null) {
      if (upcomingStep == currentStep) {
        distanceToNextManeuver = distanceRemainingInCurrentStep;
      } else {
        distanceToNextManeuver =
            distanceRemainingInCurrentStep +
            upcomingStep.maneuver.distanceToManeuver;
      }
    } else {
      distanceToNextManeuver = distanceRemainingInCurrentStep;
    }

    final distanceRemaining = route.getRemainingDistance(currentLocation);
    final durationRemaining = route.getRemainingDuration(currentLocation);

    final isOnRoute = route.isLocationOnRoute(currentLocation);
    final distanceFromRoute = isOnRoute
        ? 0.0
        : route.getDistanceFromRoute(currentLocation);

    return RouteProgress(
      currentLocation: currentLocation,
      route: route,
      currentLegIndex: currentLegIndex,
      currentStepIndex: currentStepIndex,
      distanceTraveled: totalDistanceTraveled + distanceTraveledInCurrentLeg,
      distanceRemaining: distanceRemaining,
      durationTraveled:
          totalDurationTraveled +
          (DateTime.now().difference(startTime).inSeconds.toDouble()),
      durationRemaining: durationRemaining,
      distanceToNextManeuver: distanceToNextManeuver,
      distanceTraveledInCurrentLeg: distanceTraveledInCurrentLeg,
      distanceRemainingInCurrentLeg: distanceRemainingInCurrentLeg,
      distanceTraveledInCurrentStep: distanceTraveledInCurrentStep,
      distanceRemainingInCurrentStep: distanceRemainingInCurrentStep,
      isOnRoute: isOnRoute,
      distanceFromRoute: distanceFromRoute,
    );
  }

  /// Gets formatted distance remaining
  String get formattedDistanceRemaining {
    return _formatDistance(distanceRemaining);
  }

  /// Gets formatted distance to next maneuver
  String get formattedDistanceToNextManeuver {
    return _formatDistance(distanceToNextManeuver);
  }

  /// Gets formatted ETA
  String get formattedETA {
    final now = DateTime.now();
    final arrivalTime = eta;
    final difference = arrivalTime.difference(now);

    if (difference.inHours > 0) {
      return '${arrivalTime.hour.toString().padLeft(2, '0')}:${arrivalTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${difference.inMinutes} min';
    }
  }

  /// Formats distance for display
  String _formatDistance(double distance) {
    if (distance < 1000) {
      return '${distance.round()} m';
    } else {
      final km = distance / 1000;
      return '${km.toStringAsFixed(1)} km';
    }
  }

  /// Gets instruction for current maneuver
  String get currentInstruction {
    if (distanceToNextManeuver < 50.0) {
      return upcomingManeuver?.instruction ?? 'Continue';
    } else {
      return 'Continue on $currentRoadName';
    }
  }

  /// Gets short instruction for current maneuver
  String get shortInstruction {
    if (distanceToNextManeuver < 200.0) {
      return upcomingManeuver?.shortInstruction ?? 'Continue';
    } else {
      return currentRoadName;
    }
  }

  @override
  String toString() {
    return 'RouteProgress('
        'progress: ${(routeProgress * 100).toStringAsFixed(1)}%, '
        'remaining: $formattedDistanceRemaining, '
        'ETA: $formattedETA, '
        'current: $currentStepIndex/${currentLeg.steps.length})';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RouteProgress &&
          runtimeType == other.runtimeType &&
          currentLocation == other.currentLocation &&
          route == other.route &&
          currentLegIndex == other.currentLegIndex &&
          currentStepIndex == other.currentStepIndex;

  @override
  int get hashCode =>
      Object.hash(currentLocation, route, currentLegIndex, currentStepIndex);
}
