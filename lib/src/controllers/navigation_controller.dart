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

/// Callback for creating localized voice instructions
typedef VoiceInstructionBuilder = String Function({
  required String baseInstruction,
  required double remainingDistance,
  String? maneuverType,
});

/// Callback for creating localized navigation start announcement
typedef NavigationStartBuilder = String Function({String? destinationName, double? totalDistance});

/// Callback for creating localized arrival announcement
typedef ArrivalAnnouncementBuilder = String Function({String? destinationName});

/// Controller that manages the overall navigation process
class NavigationController {
  final LocationService _locationService;
  final MapboxDirectionsAPI _directionsAPI;
  final CameraController _cameraController;
  final VoiceInstructionService? _voiceService;
  final VoiceInstructionBuilder? _voiceInstructionBuilder;
  final NavigationStartBuilder? _navigationStartBuilder;
  final ArrivalAnnouncementBuilder? _arrivalAnnouncementBuilder;

  // Navigation state
  NavigationState _currentState = NavigationState.idle();
  RouteData? _currentRoute;
  StreamSubscription<geo.Position>? _locationSubscription;

  // Traffic data preference
  bool enableTrafficDataByDefault = false;

  // Voice settings
  VoiceSettings? _voiceSettings;

  // Using shared constants from NavigationConstants

  // Stream controllers for state updates
  final StreamController<NavigationState> _stateController = StreamController<NavigationState>.broadcast();
  final StreamController<NavigationStep> _stepController = StreamController<NavigationStep>.broadcast();

  NavigationController({
    required LocationService locationService,
    required MapboxDirectionsAPI directionsAPI,
    required CameraController cameraController,
    VoiceInstructionService? voiceService,
    VoiceInstructionBuilder? voiceInstructionBuilder,
    NavigationStartBuilder? navigationStartBuilder,
    ArrivalAnnouncementBuilder? arrivalAnnouncementBuilder,
  })  : _locationService = locationService,
        _directionsAPI = directionsAPI,
        _cameraController = cameraController,
        _voiceService = voiceService,
        _voiceInstructionBuilder = voiceInstructionBuilder,
        _navigationStartBuilder = navigationStartBuilder,
        _arrivalAnnouncementBuilder = arrivalAnnouncementBuilder;

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

  /// Test method to check if voice instructions are working
  Future<void> testVoiceAnnouncement([String? message]) async {
    await _voiceService?.testAnnouncement(message);
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

    await ErrorHandler.safeExecute(
      () async {
        // Update state to calculating
        _updateState(NavigationState.calculating());

        // Get route from Mapbox Directions API with traffic data if requested
        final useTrafficData = enableTrafficData ?? enableTrafficDataByDefault;
        final route = await _directionsAPI.getRouteFromWaypoints(
          origin: origin,
          destination: destination,
          waypoints: stops,
          profile: profile,
          includeTrafficData: useTrafficData,
        );

        _currentRoute = route;

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
          if (_navigationStartBuilder != null) {
            final localizedAnnouncement = _navigationStartBuilder!(
              destinationName: destination.name,
              totalDistance: route.totalDistance,
            );
            await _voiceService!.testAnnouncement(localizedAnnouncement);
          } else {
            await _voiceService!.announceNavigationStart(
              destinationName: destination.name,
              totalDistance: route.totalDistance,
            );
          }
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

  /// Starts navigation from origin to destination using Position objects (backward compatibility)
  Future<void> startNavigationFromPositions({
    required geo.Position origin,
    required geo.Position destination,
    List<geo.Position>? waypoints,
    String profile = 'driving',
    bool? enableTrafficData,
  }) async {
    return startNavigation(
      origin: Waypoint.fromPosition(origin),
      destination: Waypoint.fromPosition(destination),
      stops: waypoints?.map((pos) => Waypoint.fromPosition(pos)).toList(),
      profile: profile,
      enableTrafficData: enableTrafficData,
    );
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

  /// Recalculates route from current position to destination
  Future<void> recalculateRoute({
    geo.Position? currentPosition,
    String profile = 'driving',
    bool? enableTrafficData,
  }) async {
    if (_currentRoute == null) return;

    final position = currentPosition ?? _currentState.currentPosition?.toPosition();
    if (position == null) return;

    try {
      _updateState(_currentState.copyWith(
        status: NavigationStatus.calculating,
      ));

      final useTrafficData = enableTrafficData ?? enableTrafficDataByDefault;
      final newRoute = await _directionsAPI.getRouteFromWaypoints(
        origin: Waypoint.fromPosition(position),
        destination: _currentRoute!.destination,
        profile: profile,
        includeTrafficData: useTrafficData,
      );

      _currentRoute = newRoute;

      // Announce route recalculation
      await _voiceService?.announceRouteRecalculation();

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
    double timeSavingsThreshold = 300.0, // 5 minutes
  }) async {
    if (_currentRoute == null || !_currentRoute!.hasTrafficData) {
      return false;
    }

    final position = currentPosition ?? _currentState.currentPosition?.toPosition();
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

    final route = _currentRoute!;
    final currentStep = route.currentStep;

    if (currentStep == null) {
      // All steps completed, check if arrived
      final distanceToDestination = Waypoint.fromPosition(position).distanceTo(route.destination);

      if (distanceToDestination <= nav_constants.NavigationConstants.arrivalThreshold) {
        // Announce arrival with localized text
        if (_voiceService != null && _voiceService!.isEnabled) {
          if (_arrivalAnnouncementBuilder != null) {
            final localizedAnnouncement = _arrivalAnnouncementBuilder!(
              destinationName: route.destination.name,
            );
            await _voiceService!.testAnnouncement(localizedAnnouncement);
          } else {
            await _voiceService!.announceArrival(destinationName: route.destination.name);
          }
        }

        _updateState(NavigationState.arrived(route, Waypoint.fromPosition(position)));
      }
      return;
    }

    // Get current step and check for advancement
    final distanceToStepEnd =
        Waypoint.fromPosition(position).distanceTo(Waypoint.fromPosition(currentStep.endLocation));

    if (distanceToStepEnd <= nav_constants.NavigationConstants.stepAdvanceThreshold) {
      await _advanceToNextStep(position);
      return;
    }

    // Check if user is off route
    if (!currentStep.isOnPath(position)) {
      await _handleOffRoute(position);
      return;
    }

    // Announce step with localized instructions
    if (_voiceService != null && _voiceService!.isEnabled) {
      if (_voiceInstructionBuilder != null) {
        // Use localized voice instruction builder
        final remainingDistance = currentStep.getRemainingDistance(position);
        final localizedInstruction = _voiceInstructionBuilder!(
          baseInstruction: currentStep.instruction,
          remainingDistance: remainingDistance,
          maneuverType: currentStep.maneuver,
        );

        await _voiceService!.testAnnouncement(localizedInstruction);
      } else {
        // Fallback to default announceStep
        await _voiceService!.announceStep(
          step: currentStep,
          currentPosition: position,
        );
      }
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

  /// Updates navigation progress and state
  void _updateNavigationProgress(geo.Position position) {
    if (_currentRoute == null) return;

    final route = _currentRoute!;

    _updateState(NavigationState.navigating(
      route: route,
      currentPosition: Waypoint.fromPosition(position),
    ));

    // Update camera position
    _cameraController.updateCamera(
      userPosition: position,
      userBearing: position.heading >= 0 ? position.heading : null,
      route: _currentRoute,
    );
  }

  /// Updates the current navigation state and notifies listeners
  void _updateState(NavigationState newState) {
    _currentState = newState;
    _stateController.add(newState);
  }

  /// Disposes resources and closes streams
  void dispose() {
    _stopLocationTracking();
    _voiceService?.dispose();
    _stateController.close();
    _stepController.close();
  }
}
