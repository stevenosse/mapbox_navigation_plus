import 'package:geolocator/geolocator.dart';
import 'package:mapbox_navigation/src/models/waypoint.dart';
import 'route_data.dart';
import 'navigation_step.dart';

/// Enumeration of possible navigation states
enum NavigationStatus {
  /// Navigation has not started yet
  idle,

  /// Route is being calculated
  calculating,

  /// Navigation is active and in progress
  navigating,

  /// Navigation has been paused
  paused,

  /// Destination has been reached
  arrived,

  /// Navigation encountered an error
  error,
}

/// Represents the current state of navigation
class NavigationState {
  /// Current navigation status
  final NavigationStatus status;

  /// The active route being navigated
  final RouteData? route;

  /// Current user position
  final Waypoint? currentPosition;

  /// Current active navigation step
  final NavigationStep? currentStep;

  /// Next navigation step
  final NavigationStep? nextStep;

  /// Distance remaining to destination in meters
  final double remainingDistance;

  /// Time remaining to destination in seconds
  final double remainingDuration;

  /// Progress through current step (0.0 to 1.0)
  final double stepProgress;

  /// Overall route progress (0.0 to 1.0)
  final double routeProgress;

  /// Current speed in m/s
  final double currentSpeed;

  /// Current heading/bearing in degrees
  final double currentBearing;

  /// Whether the user is off the route
  final bool isOffRoute;

  /// Distance from the route in meters (if off route)
  final double distanceFromRoute;

  /// Error message if status is error
  final String? errorMessage;

  const NavigationState({
    this.status = NavigationStatus.idle,
    this.route,
    this.currentPosition,
    this.currentStep,
    this.nextStep,
    this.remainingDistance = 0.0,
    this.remainingDuration = 0.0,
    this.stepProgress = 0.0,
    this.routeProgress = 0.0,
    this.currentSpeed = 0.0,
    this.currentBearing = 0.0,
    this.isOffRoute = false,
    this.distanceFromRoute = 0.0,
    this.errorMessage,
  });

  /// Creates an initial idle state
  factory NavigationState.idle() {
    return const NavigationState(status: NavigationStatus.idle);
  }

  /// Creates a calculating state
  factory NavigationState.calculating() {
    return const NavigationState(status: NavigationStatus.calculating);
  }

  /// Creates an error state
  factory NavigationState.error(String message) {
    return NavigationState(
      status: NavigationStatus.error,
      errorMessage: message,
    );
  }

  /// Creates a navigating state with updated position and route data
  factory NavigationState.navigating({
    required RouteData route,
    required Waypoint currentPosition,
    double currentSpeed = 0.0,
    double currentBearing = 0.0,
  }) {
    final currentStep = route.currentStep;
    final nextStep = route.nextStep;

    // Calculate remaining distance and duration
    final remainingDistance = route.getRemainingDistance(currentPosition);
    final remainingDuration = route.getRemainingDuration(currentPosition);

    // Calculate step progress
    final stepProgress = currentStep != null
        ? route.getStepProgress(currentPosition, currentStep)
        : 0.0;

    // Calculate overall route progress
    final routeProgress = route.totalDistance > 0
        ? 1.0 - (remainingDistance / route.totalDistance)
        : 0.0;

    // Check if off route (simplified - within 50m tolerance)
    final isOffRoute =
        _calculateDistanceFromRoute(currentPosition, route) > 50.0;
    final distanceFromRoute =
        _calculateDistanceFromRoute(currentPosition, route);

    return NavigationState(
      status: NavigationStatus.navigating,
      route: route,
      currentPosition: currentPosition,
      currentStep: currentStep,
      nextStep: nextStep,
      remainingDistance: remainingDistance,
      remainingDuration: remainingDuration,
      stepProgress: stepProgress,
      routeProgress: routeProgress.clamp(0.0, 1.0),
      currentSpeed: currentSpeed,
      currentBearing: currentBearing,
      isOffRoute: isOffRoute,
      distanceFromRoute: distanceFromRoute,
    );
  }

  /// Creates an arrived state
  factory NavigationState.arrived(RouteData route, Waypoint finalPosition) {
    return NavigationState(
      status: NavigationStatus.arrived,
      route: route,
      currentPosition: finalPosition,
      routeProgress: 1.0,
      stepProgress: 1.0,
    );
  }

  /// Calculates the minimum distance from current position to the route
  static double _calculateDistanceFromRoute(
      Waypoint position, RouteData route) {
    if (route.geometry.isEmpty) return 0.0;

    double minDistance = double.infinity;

    // Find the closest point on the route geometry
    for (final routePoint in route.geometry) {
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        routePoint.latitude,
        routePoint.longitude,
      );
      if (distance < minDistance) {
        minDistance = distance;
      }
    }

    return minDistance;
  }

  /// Checks if the user has arrived at the destination
  bool get hasArrived {
    if (route == null || currentPosition == null) return false;

    final distanceToDestination = Geolocator.distanceBetween(
      currentPosition!.latitude,
      currentPosition!.longitude,
      route!.destination.latitude,
      route!.destination.longitude,
    );

    return distanceToDestination < 20.0; // Within 20 meters
  }

  /// Checks if the current step should be advanced
  bool get shouldAdvanceStep {
    if (currentStep == null || currentPosition == null) return false;

    final distanceToStepEnd = Geolocator.distanceBetween(
      currentPosition!.latitude,
      currentPosition!.longitude,
      currentStep!.endLocation.latitude,
      currentStep!.endLocation.longitude,
    );

    return distanceToStepEnd < 30.0; // Within 30 meters of step end
  }

  /// Creates a copy of this state with updated properties
  NavigationState copyWith({
    NavigationStatus? status,
    RouteData? route,
    Waypoint? currentPosition,
    NavigationStep? currentStep,
    NavigationStep? nextStep,
    double? remainingDistance,
    double? remainingDuration,
    double? stepProgress,
    double? routeProgress,
    double? currentSpeed,
    double? currentBearing,
    bool? isOffRoute,
    double? distanceFromRoute,
    String? errorMessage,
  }) {
    return NavigationState(
      status: status ?? this.status,
      route: route ?? this.route,
      currentPosition: currentPosition ?? this.currentPosition,
      currentStep: currentStep ?? this.currentStep,
      nextStep: nextStep ?? this.nextStep,
      remainingDistance: remainingDistance ?? this.remainingDistance,
      remainingDuration: remainingDuration ?? this.remainingDuration,
      stepProgress: stepProgress ?? this.stepProgress,
      routeProgress: routeProgress ?? this.routeProgress,
      currentSpeed: currentSpeed ?? this.currentSpeed,
      currentBearing: currentBearing ?? this.currentBearing,
      isOffRoute: isOffRoute ?? this.isOffRoute,
      distanceFromRoute: distanceFromRoute ?? this.distanceFromRoute,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  String toString() {
    return 'NavigationState(status: $status, progress: ${(routeProgress * 100).toStringAsFixed(1)}%, remaining: ${remainingDistance.toStringAsFixed(0)}m)';
  }
}
