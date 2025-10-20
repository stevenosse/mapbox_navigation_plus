import 'dart:async';

import 'core/interfaces/nav_controller.dart';
import 'core/interfaces/location_provider.dart';
import 'core/interfaces/routing_engine.dart';
import 'core/interfaces/route_progress_tracker.dart';
import 'core/interfaces/voice_guidance.dart';
import 'core/interfaces/map_controller_interface.dart';
import 'core/models/location_point.dart';
import 'core/models/route_model.dart';
import 'core/models/route_progress.dart';
import 'core/models/maneuver.dart';
import 'core/models/navigation_state.dart';
import 'core/models/voice_instruction.dart';
import 'core/models/route_style_config.dart';
import 'core/models/routing_options.dart';
import 'core/models/location_puck_config.dart';
import 'core/models/destination_pin_config.dart';

/// Main navigation controller that orchestrates all navigation components
class NavigationController implements NavController {
  // Core services
  @override
  final RoutingEngine routingEngine;

  @override
  final LocationProvider locationProvider;

  @override
  final RouteProgressTracker progressTracker;

  @override
  final VoiceGuidance voiceGuidance;

  @override
  final MapControllerInterface mapController;

  // Route styling configuration
  RouteStyleConfig _routeStyleConfig = RouteStyleConfig.defaultConfig;

  // Location puck and destination pin configurations
  LocationPuckConfig _locationPuckConfig = LocationPuckThemes.defaultTheme;
  DestinationPinConfig _destinationPinConfig =
      DestinationPinConfig.defaultConfig;

  // State management
  NavigationState _currentState = NavigationState.idle;
  RouteModel? _currentRoute;
  RouteProgress? _currentProgress;

  // Stream controllers
  final StreamController<NavigationState> _stateController =
      StreamController<NavigationState>.broadcast();
  final StreamController<RouteProgress> _progressController =
      StreamController<RouteProgress>.broadcast();
  final StreamController<Maneuver> _upcomingManeuverController =
      StreamController<Maneuver>.broadcast();
  final StreamController<String> _instructionController =
      StreamController<String>.broadcast();
  final StreamController<NavigationError> _errorController =
      StreamController<NavigationError>.broadcast();

  // Listeners
  final Set<NavigationEventListener> _listeners = {};

  // Subscriptions
  StreamSubscription? _locationSubscription;
  StreamSubscription? _progressSubscription;
  StreamSubscription? _maneuverSubscription;
  StreamSubscription? _deviationSubscription;
  StreamSubscription? _arrivalSubscription;

  NavigationController({
    required this.routingEngine,
    required this.locationProvider,
    required this.progressTracker,
    required this.voiceGuidance,
    required this.mapController,
    RouteStyleConfig? routeStyleConfig,
    LocationPuckConfig? locationPuckConfig,
    DestinationPinConfig? destinationPinConfig,
  }) : _routeStyleConfig = routeStyleConfig ?? RouteStyleConfig.defaultConfig,
       _locationPuckConfig =
           locationPuckConfig ?? LocationPuckThemes.defaultTheme,
       _destinationPinConfig =
           destinationPinConfig ?? DestinationPinConfig.defaultConfig;

  /// Updates the route style configuration
  void updateRouteStyleConfig(RouteStyleConfig config) {
    _routeStyleConfig = config;
    // If we have a current route, redraw it with the new style
    if (_currentRoute != null) {
      mapController.drawRoute(
        route: _currentRoute!,
        styleConfig: _routeStyleConfig,
      );
    }
  }

  /// Gets the current route style configuration
  RouteStyleConfig get routeStyleConfig => _routeStyleConfig;

  /// Updates the location puck configuration
  void updateLocationPuckConfig(LocationPuckConfig config) {
    _locationPuckConfig = config;
    // Apply the new configuration to the map controller
    mapController.configureLocationPuck(config);
  }

  /// Gets the current location puck configuration
  LocationPuckConfig get locationPuckConfig => _locationPuckConfig;

  /// Updates the destination pin configuration
  void updateDestinationPinConfig(DestinationPinConfig config) {
    _destinationPinConfig = config;
    // Apply the new configuration to the map controller
    mapController.configureDestinationPin(config);
  }

  /// Gets the current destination pin configuration
  DestinationPinConfig get destinationPinConfig => _destinationPinConfig;

  /// Shows destination pin at the specified location
  Future<void> showDestinationPin(LocationPoint location) async {
    await mapController.showDestinationPin(location);
  }

  /// Hides the destination pin
  Future<void> hideDestinationPin() async {
    await mapController.hideDestinationPin();
  }

  // Stream getters
  @override
  Stream<NavigationState> get stateStream => _stateController.stream;

  @override
  Stream<RouteProgress> get progressStream => _progressController.stream;

  @override
  Stream<Maneuver> get upcomingManeuverStream =>
      _upcomingManeuverController.stream;

  @override
  Stream<String> get instructionStream => _instructionController.stream;

  @override
  Stream<NavigationError> get errorStream => _errorController.stream;

  // State getters
  @override
  NavigationState get currentState => _currentState;

  @override
  RouteModel? get currentRoute => _currentRoute;

  @override
  RouteProgress? get currentProgress => _currentProgress;

  @override
  DateTime? get eta => _currentProgress?.eta;

  @override
  double? get remainingDistance => _currentProgress?.distanceRemaining;

  @override
  double? get remainingDuration => _currentProgress?.durationRemaining;

  /// Checks if navigation is currently active (navigating, paused, or deviated)
  bool get isNavigationActive =>
      _currentState == NavigationState.navigating ||
      _currentState == NavigationState.paused ||
      _currentState == NavigationState.deviated;

  /// Initialize location updates to get current position before navigation starts
  @override
  Future<void> initializeLocation() async {
    try {
      // Start location provider if not already started
      await locationProvider.start();

      // Set up location subscription if not already set up
      _locationSubscription ??= locationProvider.locationStream.listen(
        _onLocationUpdate,
      );

      // Try to get initial location immediately
      final initialLocation = await locationProvider.getCurrentLocation();
      if (initialLocation != null) {
        _onLocationUpdate(initialLocation);
      }
    } catch (e) {
      final error = NavigationError(
        type: NavigationErrorType.locationUnavailable,
        message: 'Failed to initialize location: $e',
        originalError: e,
      );
      _errorController.add(error);
    }
  }

  @override
  Future<NavigationResult> startNavigation({
    required LocationPoint origin,
    required LocationPoint destination,
    List<LocationPoint>? waypoints,
    RoutingOptions? options,
    RouteStyleConfig? routeStyle,
  }) async {
    try {
      mapController.setFollowingLocation(true);
      _updateState(NavigationState.routing);

      // Calculate route
      final route = await routingEngine.getRoute(
        origin: origin,
        destination: destination,
        waypoints: waypoints,
        options: options,
      );

      return await startNavigationWithRoute(
        route: route,
        routeStyle: routeStyle,
      );
    } catch (e) {
      final error = NavigationError(
        type: NavigationErrorType.routingFailed,
        message: 'Failed to calculate route: $e',
        originalError: e,
      );

      _updateState(NavigationState.error);
      _errorController.add(error);

      return NavigationResult.failure(error);
    }
  }

  @override
  Future<NavigationResult> startNavigationWithRoute({
    required RouteModel route,
    RouteStyleConfig? routeStyle,
  }) async {
    try {
      _currentRoute = route;
      mapController.setFollowingLocation(true);
      _updateState(NavigationState.navigating);

      await mapController.setNavigationLocationPuck();

      // Draw route on map
      await mapController.drawRoute(
        route: route,
        styleConfig: routeStyle ?? _routeStyleConfig,
      );

      await showDestinationPin(route.destination);

      if (_locationSubscription == null) {
        await locationProvider.start();
        _locationSubscription = locationProvider.locationStream.listen(
          _onLocationUpdate,
        );
      }

      await progressTracker.startTracking(
        route: route,
        locationStream: locationProvider.locationStream,
      );

      _progressSubscription = progressTracker.progressStream.listen(
        _onProgressUpdate,
      );
      _maneuverSubscription = progressTracker.upcomingManeuverStream.listen(
        _onManeuverUpdate,
      );
      _deviationSubscription = progressTracker.deviationStream.listen(
        _onDeviationDetected,
      );
      _arrivalSubscription = progressTracker.arrivalStream.listen(
        (_) => _onArrival(),
      );

      await mapController.centerOnLocation(
        location: route.origin,
        zoom: 20.0,
        followLocation: true,
      );

      return NavigationResult.success(route);
    } catch (e) {
      final error = NavigationError(
        type: NavigationErrorType.configurationError,
        message: 'Failed to start navigation: $e',
        originalError: e,
      );

      _updateState(NavigationState.error);
      _errorController.add(error);

      return NavigationResult.failure(error);
    }
  }

  @override
  Future<void> stopNavigation() async {
    try {
      _updateState(NavigationState.idle);

      // Reset location puck to default image when navigation ends
      await mapController.setIdleLocationPuck();

      // Stop location updates
      await _locationSubscription?.cancel();
      _locationSubscription = null;

      // Stop progress tracking
      await progressTracker.stopTracking();

      // Cancel all subscriptions
      await _progressSubscription?.cancel();
      await _maneuverSubscription?.cancel();
      await _deviationSubscription?.cancel();
      await _arrivalSubscription?.cancel();

      _progressSubscription = null;
      _maneuverSubscription = null;
      _deviationSubscription = null;
      _arrivalSubscription = null;

      // Stop voice guidance
      await voiceGuidance.stop();

      // Clear route from map
      await mapController.clearRoute();

      // Hide destination pin
      await hideDestinationPin();

      // Reset camera to bird's eye view when navigation ends
      final currentLocation = locationProvider.currentLocation;
      if (currentLocation != null) {
        await mapController.moveCamera(
          center: currentLocation,
          zoom: 17.0,
          bearing: 0.0, // Reset bearing to north
          pitch: 0.0, // Reset pitch to bird's eye view
          animation: const CameraAnimation(
            duration: Duration(milliseconds: 800),
            type: AnimationType.easeInOut,
          ),
        );
      }

      // Reset state
      _currentRoute = null;
      _currentProgress = null;

      for (final listener in _listeners) {
        listener.onNavigationStateChanged(_currentState);
      }
    } catch (e) {
      final error = NavigationError(
        type: NavigationErrorType.configurationError,
        message: 'Failed to stop navigation: $e',
        originalError: e,
      );

      _errorController.add(error);
    }
  }

  @override
  Future<void> pauseNavigation() async {
    if (_currentState == NavigationState.navigating) {
      _updateState(NavigationState.paused);
      await voiceGuidance.pause();
    }
  }

  @override
  Future<void> resumeNavigation() async {
    if (_currentState == NavigationState.paused) {
      _updateState(NavigationState.navigating);
      await voiceGuidance.resume();
    }
  }

  @override
  Future<void> recenterMap() async {
    if (_currentProgress != null) {
      await mapController.centerOnLocation(
        location: _currentProgress!.currentLocation,
        zoom: 20,
        followLocation: true,
      );
    }
  }

  @override
  Future<void> resumeFollowing() async {
    mapController.setFollowingLocation(true);

    final currentLocation = locationProvider.currentLocation;
    if (currentLocation != null) {
      await mapController.centerOnLocation(
        location: currentLocation,
        followLocation: true,
      );
    }
  }

  @override
  Future<void> reroute() async {
    if (_currentRoute == null || _currentProgress == null) return;

    try {
      _updateState(NavigationState.deviated);

      final newRoute = await routingEngine.reroute(
        currentLocation: _currentProgress!.currentLocation,
        originalRoute: _currentRoute!,
      );

      _currentRoute = newRoute;

      await progressTracker.stopTracking();
      await progressTracker.startTracking(
        route: newRoute,
        locationStream: locationProvider.locationStream,
      );

      await mapController.drawRoute(
        route: newRoute,
        styleConfig: _routeStyleConfig,
      );

      _updateState(NavigationState.navigating);
    } catch (e) {
      final error = NavigationError(
        type: NavigationErrorType.routingFailed,
        message: 'Failed to reroute: $e',
        originalError: e,
      );

      _errorController.add(error);
      _updateState(NavigationState.navigating);
    }
  }

  @override
  Future<void> setVoiceGuidanceEnabled(bool enabled) async {
    if (enabled) {
      await voiceGuidance.setEnabled(true);
    } else {
      await voiceGuidance.setEnabled(false);
    }
  }

  @override
  Future<void> setLocationFollowing(bool follow) async {
    await mapController.setLocationFollowMode(follow);
  }

  @override
  void addNavigationListener(NavigationEventListener listener) {
    _listeners.add(listener);
  }

  @override
  void removeNavigationListener(NavigationEventListener listener) {
    _listeners.remove(listener);
  }

  // Private methods
  void _updateState(NavigationState newState) {
    if (_currentState != newState) {
      _currentState = newState;
      _stateController.add(newState);

      for (final listener in _listeners) {
        listener.onNavigationStateChanged(newState);
      }
    }
  }

  void _onLocationUpdate(LocationPoint location) {
    mapController.updateLocationPuck(location);
  }

  void _onProgressUpdate(RouteProgress progress) {
    _currentProgress = progress;
    _progressController.add(progress);

    // Update map progress line
    mapController.updateProgressLine(
      progress: progress,
      styleConfig: _routeStyleConfig,
    );

    for (final listener in _listeners) {
      listener.onRouteProgressChanged(progress);
    }
  }

  void _onManeuverUpdate(Maneuver maneuver) {
    _upcomingManeuverController.add(maneuver);

    if (voiceGuidance.isEnabled) {
      final instruction = VoiceInstruction(
        announcement: maneuver.instruction,
        distanceAlongGeometry: maneuver.distanceToManeuver,
        triggerDistance: maneuver.distanceToManeuver,
      );
      voiceGuidance.speak(instruction);
    }

    for (final listener in _listeners) {
      listener.onUpcomingManeuver(maneuver);
    }
  }

  void _onDeviationDetected(RouteDeviation deviation) {
    reroute();
  }

  void _onArrival() {
    _updateState(NavigationState.arrived);

    // Speak arrival message
    if (voiceGuidance.isEnabled) {
      voiceGuidance.speak(
        VoiceInstruction(
          announcement: 'You have arrived at your destination',
          distanceAlongGeometry: 0.0,
        ),
      );
    }

    for (final listener in _listeners) {
      listener.onArrival();
    }
  }

  /// Dispose resources
  void dispose() {
    stopNavigation();

    _stateController.close();
    _progressController.close();
    _upcomingManeuverController.close();
    _instructionController.close();
    _errorController.close();

    _listeners.clear();
  }
}
