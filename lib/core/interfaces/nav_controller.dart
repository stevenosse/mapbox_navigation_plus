import 'dart:async';

import 'package:mapbox_navigation_plus/core/models/location_point.dart';
import 'package:mapbox_navigation_plus/core/models/route_model.dart';
import 'package:mapbox_navigation_plus/core/models/route_result.dart';
import 'package:mapbox_navigation_plus/core/models/route_progress.dart';
import 'package:mapbox_navigation_plus/core/models/maneuver.dart';
import 'package:mapbox_navigation_plus/core/models/navigation_state.dart';
import 'package:mapbox_navigation_plus/core/models/routing_options.dart';
import 'package:mapbox_navigation_plus/core/interfaces/routing_engine.dart';
import 'package:mapbox_navigation_plus/core/interfaces/location_provider.dart';
import 'package:mapbox_navigation_plus/core/interfaces/route_progress_tracker.dart';
import 'package:mapbox_navigation_plus/core/interfaces/voice_guidance.dart';
import 'package:mapbox_navigation_plus/core/interfaces/map_controller_interface.dart';

/// Main navigation controller interface that orchestrates all navigation components
abstract class NavController {
  /// Core services (can be injected for customization)
  RoutingEngine get routingEngine;
  LocationProvider get locationProvider;
  RouteProgressTracker get progressTracker;
  VoiceGuidance get voiceGuidance;
  MapControllerInterface get mapController;

  /// Navigation state streams
  Stream<NavigationState> get stateStream;
  Stream<RouteProgress> get progressStream;
  Stream<Maneuver> get upcomingManeuverStream;
  Stream<String> get instructionStream;
  Stream<NavigationError> get errorStream;

  /// Current navigation state
  NavigationState get currentState;

  /// Current route and progress
  RouteModel? get currentRoute;
  RouteProgress? get currentProgress;

  /// Initialize location updates to get current position before navigation starts
  Future<void> initializeLocation();

  /// Starts navigation with a route
  Future<NavigationResult> startNavigation({
    required LocationPoint origin,
    required LocationPoint destination,
    List<LocationPoint>? waypoints,
    RoutingOptions? options,
  });

  /// Starts navigation with a pre-calculated route
  Future<NavigationResult> startNavigationWithRoute({
    required RouteModel route,
  });

  /// Requests multiple routes with different optimization criteria
  /// Returns a list of RouteResult objects that can be displayed on the map
  /// for user selection before starting navigation
  Future<List<RouteResult>> requestMultipleRoutes({
    required LocationPoint origin,
    required LocationPoint destination,
    required List<RouteType> routeTypes,
    List<LocationPoint>? waypoints,
    RoutingOptions? baseOptions,
  });

  /// Stops navigation
  Future<void> stopNavigation();

  /// Pauses navigation (keeps route but stops tracking)
  Future<void> pauseNavigation();

  /// Resumes navigation
  Future<void> resumeNavigation();

  /// Re-centers map on current location
  Future<void> recenterMap();

  /// Triggers manual re-routing
  Future<void> reroute();

  /// Gets estimated time of arrival
  DateTime? get eta;

  /// Gets remaining distance in meters
  double? get remainingDistance;

  /// Gets remaining duration in seconds
  double? get remainingDuration;

  /// Enables/disables voice guidance
  Future<void> setVoiceGuidanceEnabled(bool enabled);

  /// Enables/disables location following
  Future<void> setLocationFollowing(bool follow);

  /// Adds navigation event listener
  void addNavigationListener(NavigationEventListener listener);

  /// Removes navigation event listener
  void removeNavigationListener(NavigationEventListener listener);
}

/// Navigation event listener interface
abstract class NavigationEventListener {
  void onNavigationStateChanged(NavigationState state);
  void onRouteProgressChanged(RouteProgress progress);
  void onUpcomingManeuver(Maneuver maneuver);
  void onInstruction(String instruction);
  void onError(NavigationError error);
  void onArrival();
}

/// Navigation result
class NavigationResult {
  final bool success;
  final NavigationError? error;
  final String? message;

  const NavigationResult({required this.success, this.error, this.message});

  factory NavigationResult.success() => const NavigationResult(success: true);

  factory NavigationResult.failure(NavigationError error, [String? message]) =>
      NavigationResult(success: false, error: error, message: message);
}

/// Navigation error types
enum NavigationErrorType {
  routingFailed,
  locationPermissionDenied,
  locationUnavailable,
  networkError,
  invalidRoute,
  configurationError,
  unknown,
}

/// Navigation error details
class NavigationError {
  final NavigationErrorType type;
  final String message;
  final dynamic originalError;

  const NavigationError({
    required this.type,
    required this.message,
    this.originalError,
  });
}
