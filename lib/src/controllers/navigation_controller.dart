import 'dart:async';

import 'package:geolocator/geolocator.dart' as geo;
import '../models/navigation_state.dart';
import '../models/route_data.dart';
import '../models/navigation_step.dart';
import '../models/waypoint.dart';
import '../services/location_service.dart';
import '../services/mapbox_directions_api.dart';
import '../services/voice_instruction_service.dart';
import '../controllers/camera_controller.dart';
import '../models/voice_settings.dart';
import '../utils/constants.dart' as nav_constants;
import '../utils/error_handling.dart';
import '../utils/validation_utils.dart';

/// Callback for creating localized navigation start announcement
typedef NavigationStartBuilder = String Function(
    {String? destinationName, double? totalDistance});

/// Callback for creating localized arrival announcement
typedef ArrivalAnnouncementBuilder = String Function({String? destinationName});

/// Callback for route visualization updates
typedef RouteVisualizationCallback = void Function(RouteData route, int stepIndex, geo.Position? position);

/// Controller that manages the overall navigation process
class NavigationController {
  final LocationService _locationService;
  final MapboxDirectionsAPI _directionsAPI;
  final CameraController _cameraController;
  final VoiceInstructionService? _voiceService;

  // Navigation state
  NavigationState _currentState = NavigationState.idle();
  RouteData? _currentRoute;
  StreamSubscription<geo.Position>? _locationSubscription;

  // Traffic data preference
  bool enableTrafficDataByDefault = false;

  // Voice settings
  VoiceSettings? _voiceSettings;

  // Route visualization callback
  RouteVisualizationCallback? _routeVisualizationCallback;

  // Route recalculation optimization
  DateTime? _lastRecalculationTime;
  geo.Position? _lastKnownGoodPosition;
  int _consecutiveOffRouteCount = 0;
  static const int _offRouteThreshold = 3; // Must be off-route for 3 consecutive updates
  static const Duration _recalculationCooldown = Duration(seconds: 5);
  
  // State update optimization
  geo.Position? _lastStateUpdatePosition;
  DateTime? _lastStateUpdateTime;
  static const double _minStateUpdateDistance = 2.0; // meters
  static const Duration _minStateUpdateInterval = Duration(milliseconds: 500);
  
  // Visualization update optimization
  geo.Position? _lastVisualizationPosition;
  DateTime? _lastVisualizationTime;
  static const double _minVisualizationUpdateDistance = 1.0; // meters
  static const Duration _minVisualizationUpdateInterval = Duration(milliseconds: 100);

  // Stream controllers for state updates
  final StreamController<NavigationState> _stateController =
      StreamController<NavigationState>.broadcast();
  final StreamController<NavigationStep> _stepController =
      StreamController<NavigationStep>.broadcast();

  NavigationController({
    required LocationService locationService,
    required MapboxDirectionsAPI directionsAPI,
    required CameraController cameraController,
    VoiceInstructionService? voiceService,
    NavigationStartBuilder? navigationStartBuilder,
    ArrivalAnnouncementBuilder? arrivalAnnouncementBuilder,
  })  : _locationService = locationService,
        _directionsAPI = directionsAPI,
        _cameraController = cameraController,
        _voiceService = voiceService;

  /// Sets the route visualization callback
  void setRouteVisualizationCallback(RouteVisualizationCallback? callback) {
    _routeVisualizationCallback = callback;
  }

  /// Current navigation state
  NavigationState get currentState => _currentState;

  /// Current route data
  RouteData? get currentRoute => _currentRoute;

  /// Stream of navigation state changes
  Stream<NavigationState> get stateStream => _stateController.stream;

  /// Stream of step changes
  Stream<NavigationStep> get stepStream => _stepController.stream;

  /// Whether navigation is currently active
  bool get isNavigating => _currentState.status == NavigationStatus.navigating;

  /// Whether navigation has arrived at destination
  bool get hasArrived => _currentState.status == NavigationStatus.arrived;

  /// Whether navigation is currently paused
  bool get isPaused => _currentState.status == NavigationStatus.paused;

  /// Whether voice instructions are enabled
  bool get isVoiceEnabled => _voiceService?.isEnabled ?? false;

  /// Current voice settings
  VoiceSettings? get voiceSettings => _voiceSettings;

  /// Gets the current step index in the route
  int? get currentStepIndex {
    if (_currentRoute == null) return null;

    final currentStep = _currentRoute!.currentStep;
    if (currentStep == null) return null;

    return _currentRoute!.steps.indexOf(currentStep);
  }

  /// Updates voice settings
  Future<void> updateVoiceSettings(VoiceSettings settings) async {
    _voiceSettings = settings;
    await _voiceService?.updateSettings(settings);
  }

  /// Enables or disables voice instructions
  Future<void> setVoiceEnabled(bool enabled) async {
    if (_voiceSettings != null) {
      await updateVoiceSettings(_voiceSettings!.copyWith(enabled: enabled));
    }
  }

  /// Check TTS availability and configuration (for debugging)
  Future<Map<String, dynamic>?> checkVoiceTTSAvailability() async {
    return await _voiceService?.checkTTSAvailability();
  }

  /// Starts navigation from origin to destination
  Future<void> startNavigation({
    required Waypoint origin,
    required Waypoint destination,
    List<Waypoint>? stops,
    String profile = 'driving',
    bool? enableTrafficData,
    VoiceSettings? voiceSettings,
  }) async {
    if (_currentState.status != NavigationStatus.idle) {
      throw NavigationStateException.alreadyStarted();
    }

    // Validate input parameters
    ValidationUtils.validateRouteRequest(
      origin: origin,
      destination: destination,
      waypoints: stops,
      profile: profile,
    );

    await ErrorHandler.safeExecute(
      () async {
        _updateState(NavigationState.calculating());

        final useTrafficData = enableTrafficData ?? enableTrafficDataByDefault;
        final route = await _directionsAPI.getRoute(
          origin: origin,
          destination: destination,
          waypoints: stops,
          profile: profile,
          includeTrafficData: useTrafficData,
        );

        _currentRoute = route;
        
        // Clear route calculation cache for new route
        route.clearCache();

        // Initialize voice service if settings provided
        if (voiceSettings != null) {
          _voiceSettings = voiceSettings;
          await _voiceService?.initialize(voiceSettings);
        }

        // Start location tracking
        await _startLocationTracking();

        // Enable navigation camera mode
        _cameraController.enableNavigationMode();

        // Announce navigation start with localized text
        if (_voiceService != null && _voiceService!.isEnabled) {
          await _voiceService!.announceNavigationStart(
            destinationName: destination.name,
            totalDistance: route.totalDistance,
          );
        }

        // Update state to navigating
        _updateState(NavigationState.navigating(
          route: route,
          currentPosition: route.origin,
        ));

        // Emit first step
        if (route.steps.isNotEmpty) {
          _stepController.add(route.steps.first);
        }
      },
      context: 'Starting navigation',
      fallback: (error) {
        _updateState(NavigationState.error(
          'Failed to start navigation: ${error.toString()}',
        ));
        throw error;
      },
    );
  }

  /// Pauses navigation (stops location tracking but keeps route)
  Future<void> pauseNavigation() async {
    if (_currentState.status != NavigationStatus.navigating) return;

    await _stopLocationTracking();
    _updateState(_currentState.copyWith(status: NavigationStatus.paused));
  }

  /// Resumes navigation from paused state
  Future<void> resumeNavigation() async {
    if (_currentState.status != NavigationStatus.paused) return;

    await _startLocationTracking();
    _updateState(_currentState.copyWith(status: NavigationStatus.navigating));
  }

  /// Stops navigation and cleans up resources
  Future<void> stopNavigation() async {
    await _stopLocationTracking();
    _cameraController.disableNavigationMode();

    _currentRoute = null;
    _updateState(NavigationState.idle());
  }

  /// Simulates navigation with a predefined route (for testing)
  Future<void> startSimulation({
    required RouteData route,
    Duration stepInterval = const Duration(seconds: 3),
  }) async {
    _currentRoute = route;

    // Enable navigation camera mode
    _cameraController.enableNavigationMode();

    // Start simulation
    _updateState(NavigationState.navigating(
      route: route,
      currentPosition: route.origin,
    ));

    // Simulate step progression
    for (int i = 0; i < route.steps.length; i++) {
      if (!isNavigating) break;

      final step = route.steps[i];
      _stepController.add(step);

      _updateState(NavigationState.navigating(
        route: route,
        currentPosition: Waypoint.fromPosition(step.endLocation),
      ));

      // Update camera
      await _cameraController.updateCamera(
        userPosition: step.endLocation,
        route: route,
      );

      await Future.delayed(stepInterval);
    }

    // Mark as arrived
    _updateState(NavigationState.arrived(
      route,
      route.destination,
    ));
  }

  /// Updates route visualization without recalculating (silent progress update)
  Future<void> updateRouteVisualization({
    required geo.Position currentPosition,
    int? currentStepIndex,
  }) async {
    if (_currentRoute == null) return;

    try {
      // Update camera position for smooth tracking
      await _cameraController.updateCamera(
        userPosition: currentPosition,
        userBearing:
            currentPosition.heading >= 0 ? currentPosition.heading : null,
        route: _currentRoute,
      );

      // Update navigation state without changing route
      _updateState(NavigationState.navigating(
        route: _currentRoute!,
        currentPosition: Waypoint.fromPosition(currentPosition),
      ));
    } catch (e) {
      // Silently handle visualization update errors
    }
  }

  /// Recalculates route from current position to destination (silent by default)
  Future<void> recalculateRoute({
    geo.Position? currentPosition,
    String profile = 'driving',
    bool? enableTrafficData,
    bool announceRecalculation = false,
  }) async {
    if (_currentRoute == null) return;

    final position =
        currentPosition ?? _currentState.currentPosition?.toPosition();
    if (position == null) return;

    try {
      _updateState(_currentState.copyWith(
        status: NavigationStatus.calculating,
      ));

      final useTrafficData = enableTrafficData ?? enableTrafficDataByDefault;
      final newRoute = await _directionsAPI.getRoute(
        origin: Waypoint.fromPosition(position),
        destination: _currentRoute!.destination,
        profile: profile,
        includeTrafficData: useTrafficData,
      );

      _currentRoute = newRoute;
      
      // Clear route calculation cache when route changes
      newRoute.clearCache();

      // Only announce route recalculation if explicitly requested
      if (announceRecalculation) {
        await _voiceService?.announceRouteRecalculation();
      }

      _updateState(NavigationState.navigating(
        route: newRoute,
        currentPosition: Waypoint.fromPosition(position),
      ));

      // Emit first step of new route
      if (newRoute.steps.isNotEmpty) {
        _stepController.add(newRoute.steps.first);
      }
    } catch (e) {
      _updateState(_currentState.copyWith(
        status: NavigationStatus.error,
      ));
    }
  }

  /// Automatically recalculates route if traffic conditions have significantly changed
  Future<bool> checkAndRecalculateForTraffic({
    geo.Position? currentPosition,
    double timeSavingsThreshold = 300.0,
  }) async {
    if (_currentRoute == null || !_currentRoute!.hasTrafficData) {
      return false;
    }

    final position =
        currentPosition ?? _currentState.currentPosition?.toPosition();
    if (position == null) return false;

    try {
      // Get an updated route with current traffic data
      final updatedRoute = await _directionsAPI.getTrafficOptimizedRoute(
        origin: Waypoint.fromPosition(position),
        destination: _currentRoute!.destination,
      );

      // Compare routes and decide if recalculation is worthwhile
      final currentDuration = _currentRoute!.totalDuration;
      final updatedDuration = updatedRoute.totalDuration;
      final timeSavings = currentDuration - updatedDuration;

      if (timeSavings >= timeSavingsThreshold) {
        await recalculateRoute(
          currentPosition: position,
          profile: 'driving-traffic',
          enableTrafficData: true,
          announceRecalculation: false,
        );
        return true;
      }

      return false;
    } catch (e) {
      // Silently fail traffic-based recalculation
      return false;
    }
  }

  /// Starts location tracking and updates navigation state
  Future<void> _startLocationTracking() async {
    await _locationService.startLocationTracking();

    _locationSubscription = _locationService.positionStream.listen(
      _handleLocationUpdate,
      onError: (error) {
        _updateState(NavigationState.error(
          'Location tracking error: $error',
        ));
      },
    );
  }

  /// Stops location tracking
  Future<void> _stopLocationTracking() async {
    await _locationSubscription?.cancel();
    _locationSubscription = null;
    _locationService.stopLocationTracking();
  }

  /// Handles location updates during navigation
  Future<void> _handleLocationUpdate(geo.Position position) async {
    if (!isNavigating || _currentRoute == null) return;
    
    // Validate position before processing
    if (!_isValidPosition(position)) {
      // Skip invalid positions but don't stop navigation
      return;
    }

    final route = _currentRoute!;
    final currentStep = route.currentStep;

    if (currentStep == null) {
      // All steps completed, check if arrived
      final distanceToDestination =
          Waypoint.fromPosition(position).distanceTo(route.destination);

      if (distanceToDestination <=
          nav_constants.NavigationConstants.arrivalThreshold) {
        // Announce arrival with localized text
        if (_voiceService != null && _voiceService!.isEnabled) {
          await _voiceService!.announceArrival(
            destinationName: route.destination.name,
          );
        }

        _updateState(
            NavigationState.arrived(route, Waypoint.fromPosition(position)));
      }
      return;
    }

    // Get current step and check for advancement
    final distanceToStepEnd = Waypoint.fromPosition(position)
        .distanceTo(Waypoint.fromPosition(currentStep.endLocation));

    if (distanceToStepEnd <=
        nav_constants.NavigationConstants.stepAdvanceThreshold) {
      await _advanceToNextStep(position);
      return;
    }

    // Check if user is off route with improved tolerance
    if (!currentStep.isOnPath(position)) {
      // Check distance to route before declaring off-route
      final distanceToRoute = _calculateDistanceToRoute(position, currentStep);
      
      if (distanceToRoute > nav_constants.NavigationConstants.offRouteThreshold) {
        await _handleOffRoute(position);
        return;
      } else {
        // User is slightly off but within tolerance, reset counter
        _consecutiveOffRouteCount = 0;
      }
    } else {
      // User is on route, reset off-route counter
      _consecutiveOffRouteCount = 0;
      _lastKnownGoodPosition = position;
    }

    // Announce step
    if (_voiceService != null && _voiceService!.isEnabled) {
      await _voiceService!.announceStep(
        step: currentStep,
        currentPosition: position,
      );
    }

    // Update navigation progress
    _updateNavigationProgress(position);
  }

  /// Advances to the next navigation step
  Future<void> _advanceToNextStep(geo.Position position) async {
    if (_currentRoute == null) return;

    final route = _currentRoute!;
    final currentStep = route.currentStep;
    if (currentStep == null) return;

    // Mark current step as completed
    final updatedSteps = route.steps.map((step) {
      if (step == currentStep) {
        return step.copyWith(isCompleted: true);
      }
      return step;
    }).toList();

    _currentRoute = route.copyWith(steps: updatedSteps);

    // Emit next step if available
    final nextStep = _currentRoute!.nextStep;
    if (nextStep != null) {
      _stepController.add(nextStep);

      // Update camera to follow the new step
      await _cameraController.followStep(nextStep);
    } else {
      // No more steps, we've arrived
      _updateState(NavigationState.arrived(
        _currentRoute!,
        Waypoint.fromPosition(position),
      ));
      return;
    }

    // Update navigation progress
    _updateNavigationProgress(position);
  }

  /// Handles when user goes off the planned route
  Future<void> _handleOffRoute(geo.Position position) async {
    // Implement throttling to prevent excessive recalculations
    final now = DateTime.now();
    if (_lastRecalculationTime != null) {
      final timeSinceLastRecalc = now.difference(_lastRecalculationTime!);
      if (timeSinceLastRecalc < _recalculationCooldown) {
        // Too soon to recalculate, just update visualization
        await updateRouteVisualization(
          currentPosition: position,
          currentStepIndex: currentStepIndex,
        );
        return;
      }
    }

    // Check if we're consistently off-route (not just GPS noise)
    _consecutiveOffRouteCount++;
    if (_consecutiveOffRouteCount < _offRouteThreshold) {
      // Not consistently off-route yet, wait for more confirmations
      await updateRouteVisualization(
        currentPosition: position,
        currentStepIndex: currentStepIndex,
      );
      return;
    }

    // Reset counter and proceed with recalculation
    _consecutiveOffRouteCount = 0;
    _lastRecalculationTime = now;

    // Determine if we should use traffic data for recalculation
    final useTraffic = _currentRoute?.hasTrafficData == true;

    // Recalculate route from current position
    await recalculateRoute(
      currentPosition: position,
      profile: useTraffic ? 'driving-traffic' : 'driving',
      enableTrafficData: useTraffic,
    );

    // Update camera with 3D viewing settings for better navigation visibility
    await _cameraController.updateCameraWith3D(
      userPosition: position,
      userBearing: position.heading >= 0 ? position.heading : 180.0,
      route: _currentRoute,
    );

    _updateState(NavigationState.navigating(
      route: _currentRoute!,
      currentPosition: Waypoint.fromPosition(position),
    ));
  }

  /// Updates navigation progress and state based on location changes
  void _updateNavigationProgress(geo.Position position) {
    if (_currentRoute == null) return;

    // Only update state if position has changed significantly (optimization)
    final shouldUpdateState = _shouldUpdateNavigationState(position);
    
    if (shouldUpdateState) {
      // Update navigation state with new position-based calculations
      _updateState(NavigationState.navigating(
        route: _currentRoute!,
        currentPosition: Waypoint.fromPosition(position),
        currentSpeed: position.speed,
        currentBearing: position.heading >= 0 ? position.heading : 0.0,
      ));
    }

    // Always update camera for smooth tracking (non-blocking)
    _cameraController.updateCamera(
      userPosition: position,
      userBearing: position.heading >= 0 ? position.heading : null,
      route: _currentRoute,
    );

    // Trigger route visualization update based on location change
    final stepIndex = currentStepIndex;
    if (_routeVisualizationCallback != null && stepIndex != null) {
      // Only call visualization callback if position changed enough
      if (_shouldTriggerVisualizationUpdate(position)) {
        _routeVisualizationCallback!(_currentRoute!, stepIndex, position);
        _lastVisualizationPosition = position;
        _lastVisualizationTime = DateTime.now();
      }
    }
  }

  /// Updates the current navigation state and notifies listeners
  void _updateState(NavigationState newState) {
    _currentState = newState;
    _stateController.add(newState);
  }

  /// Calculates minimum distance from position to route geometry
  double _calculateDistanceToRoute(
      geo.Position position, NavigationStep step) {
    if (step.geometry.isEmpty) {
      return double.infinity;
    }

    double minDistance = double.infinity;
    for (final point in step.geometry) {
      final distance = geo.Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        point.latitude,
        point.longitude,
      );
      if (distance < minDistance) {
        minDistance = distance;
      }
    }
    return minDistance;
  }
  
  /// Determines if navigation state should be updated based on position changes
  bool _shouldUpdateNavigationState(geo.Position position) {
    final now = DateTime.now();
    
    // First update
    if (_lastStateUpdatePosition == null || _lastStateUpdateTime == null) {
      _lastStateUpdatePosition = position;
      _lastStateUpdateTime = now;
      return true;
    }
    
    // Check time since last update
    final timeSinceLastUpdate = now.difference(_lastStateUpdateTime!);
    if (timeSinceLastUpdate < _minStateUpdateInterval) {
      return false; // Too soon
    }
    
    // Check distance since last update
    final distance = geo.Geolocator.distanceBetween(
      _lastStateUpdatePosition!.latitude,
      _lastStateUpdatePosition!.longitude,
      position.latitude,
      position.longitude,
    );
    
    if (distance < _minStateUpdateDistance) {
      return false; // Not moved enough
    }
    
    _lastStateUpdatePosition = position;
    _lastStateUpdateTime = now;
    return true;
  }
  
  /// Determines if route visualization should be updated
  bool _shouldTriggerVisualizationUpdate(geo.Position position) {
    final now = DateTime.now();
    
    // First update
    if (_lastVisualizationPosition == null || _lastVisualizationTime == null) {
      return true;
    }
    
    // Check time since last update
    final timeSinceLastUpdate = now.difference(_lastVisualizationTime!);
    if (timeSinceLastUpdate < _minVisualizationUpdateInterval) {
      return false; // Too soon
    }
    
    // Check distance since last update
    final distance = geo.Geolocator.distanceBetween(
      _lastVisualizationPosition!.latitude,
      _lastVisualizationPosition!.longitude,
      position.latitude,
      position.longitude,
    );
    
    return distance >= _minVisualizationUpdateDistance;
  }
  
  /// Validates if a position is reasonable for navigation
  bool _isValidPosition(geo.Position position) {
    // Check latitude bounds
    if (position.latitude.abs() > 90) {
      return false;
    }
    
    // Check longitude bounds
    if (position.longitude.abs() > 180) {
      return false;
    }
    
    // Check for NaN or infinite values
    if (position.latitude.isNaN || position.latitude.isInfinite ||
        position.longitude.isNaN || position.longitude.isInfinite) {
      return false;
    }
    
    // Check for suspicious (0,0) coordinates
    if (position.latitude == 0 && position.longitude == 0) {
      // Unless we were already near (0,0)
      if (_lastKnownGoodPosition != null) {
        final distance = geo.Geolocator.distanceBetween(
          _lastKnownGoodPosition!.latitude,
          _lastKnownGoodPosition!.longitude,
          0,
          0,
        );
        // If suddenly at (0,0) from far away, it's an error
        if (distance > 100000) { // 100km
          return false;
        }
      }
    }
    
    // Check for unrealistic jumps (teleportation)
    if (_lastKnownGoodPosition != null) {
      final distance = geo.Geolocator.distanceBetween(
        _lastKnownGoodPosition!.latitude,
        _lastKnownGoodPosition!.longitude,
        position.latitude,
        position.longitude,
      );
      
      // Check time since last position
      final timeDiff = position.timestamp.difference(_lastKnownGoodPosition!.timestamp);
      if (timeDiff.inSeconds > 0) {
        final speed = distance / timeDiff.inSeconds; // meters per second
        
        // If speed is unrealistic (> 500 m/s ~ 1800 km/h), position is invalid
        if (speed > 500) {
          return false;
        }
      }
    }
    
    return true;
  }

  /// Disposes resources and closes streams
  Future<void> dispose() async {
    await _stopLocationTracking();
    await _voiceService?.dispose();

    // Close stream controllers if not already closed
    if (!_stateController.isClosed) {
      await _stateController.close();
    }
    if (!_stepController.isClosed) {
      await _stepController.close();
    }
  }
}
