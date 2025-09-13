import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../models/navigation_state.dart';
import '../models/route_data.dart';
import '../models/navigation_step.dart';
import '../services/location_service.dart';
import '../services/mapbox_directions_api.dart';
import '../services/route_visualization_service.dart';
import '../services/voice_instruction_service.dart';
import '../services/navigation_service_factory.dart';
import '../controllers/navigation_controller.dart';
import '../controllers/camera_controller.dart';
import '../models/voice_settings.dart';
import '../utils/voice_utils.dart';
import '../utils/logger.dart';
import '../widgets/speed_limit_widget.dart';
import '../localization/navigation_localizations.dart';
import 'navigation_instruction_widget.dart';
import 'navigation_status_widget.dart';
import 'navigation_controls_widget.dart';

/// Callback for navigation events
typedef NavigationCallback = void Function(NavigationState state);
typedef StepCallback = void Function(NavigationStep step);
typedef ErrorCallback = void Function(String error);
typedef MapReadyCallback = void Function(
    NavigationController navigationController);
typedef VoiceInstructionCallback = void Function(String instruction);

/// Main 3D navigation widget with Mapbox integration
class MapboxNavigationView extends StatefulWidget {
  /// Mapbox access token
  final String accessToken;

  /// Initial camera position
  final CameraOptions? initialCameraPosition;

  /// Map style URI
  final String? styleUri;

  /// Navigation callbacks
  final NavigationCallback? onNavigationStateChanged;
  final StepCallback? onStepChanged;
  final ErrorCallback? onError;
  final MapReadyCallback? onMapReady;

  /// Custom instruction widget builder
  final Widget Function(NavigationStep step)? instructionBuilder;

  /// Whether to show default instruction overlay
  final bool showInstructions;

  /// Navigation simulation speed (m/s) for testing
  final double simulationSpeed;

  /// Whether to enable traffic data for routes (uses driving-traffic profile)
  final bool enableTrafficData;

  /// Voice instruction settings (null to disable voice)
  final VoiceSettings? voiceSettings;

  /// Callback for voice instruction events
  final VoiceInstructionCallback? onVoiceInstruction;

  /// Language for instructions
  final String language;

  /// Custom navigation controls widget
  final NavigationControlsWidget? customNavigationControls;

  /// Custom navigation instruction widget
  final NavigationInstructionWidget? customInstructionWidget;

  /// Custom navigation status widget
  final NavigationStatusWidget? customStatusWidget;

  /// Whether to show default navigation controls
  final bool showNavigationControls;

  /// Whether to show default status widget
  final bool showStatusWidget;

  /// Navigation controls style
  final NavigationControlsStyle? navigationControlsStyle;

  /// Navigation status style
  final NavigationStatusStyle? navigationStatusStyle;

  /// Navigation instruction style
  final NavigationInstructionStyle? navigationInstructionStyle;

  /// Whether to show the speed limit widget
  final bool showSpeedLimit;

  /// Custom speed limit widget
  final SpeedLimitWidget? customSpeedLimitWidget;

  final SpeedUnit speedUnit;

  const MapboxNavigationView({
    super.key,
    required this.accessToken,
    this.initialCameraPosition,
    this.styleUri,
    this.onNavigationStateChanged,
    this.onStepChanged,
    this.onError,
    this.onMapReady,
    this.instructionBuilder,
    this.showInstructions = true,
    this.simulationSpeed = 10.0,
    this.enableTrafficData = false,
    this.voiceSettings,
    this.onVoiceInstruction,
    this.language = 'en',
    this.speedUnit = SpeedUnit.kmh,
    this.customNavigationControls,
    this.customInstructionWidget,
    this.customStatusWidget,
    this.showNavigationControls = true,
    this.showStatusWidget = true,
    this.navigationControlsStyle,
    this.navigationStatusStyle,
    this.navigationInstructionStyle,
    this.showSpeedLimit = false,
    this.customSpeedLimitWidget,
  });

  @override
  State<MapboxNavigationView> createState() => _MapboxNavigationViewState();
}

class _MapboxNavigationViewState extends State<MapboxNavigationView> {
  static const Logger _logger = NavigationLoggers.general;

  MapboxMap? _mapboxMap;
  LocationService? _locationService;
  MapboxDirectionsAPI? _directionsAPI;
  NavigationController? _navigationController;
  CameraController? _cameraController;
  RouteVisualizationService? _routeVisualizationService;
  VoiceInstructionService? _voiceService;

  NavigationState _currentState = NavigationState.idle();
  NavigationStep? _currentStep;
  bool _isVoiceEnabled = false;

  String? _lastRouteHash;

  // Speed limit data from route annotations
  int? _currentSpeedLimit;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  @override
  void dispose() {
    _navigationController?.dispose().catchError((_) {});
    _locationService?.dispose().catchError((_) {});
    _directionsAPI?.dispose();
    _routeVisualizationService?.dispose().catchError((_) {});
    _voiceService?.dispose().catchError((_) {});
    super.dispose();
  }

  /// Initializes all navigation services using factory
  void _initializeServices() {
    _locationService = NavigationServiceFactory.createLocationService();
    _directionsAPI = NavigationServiceFactory.createDirectionsAPI(
      accessToken: widget.accessToken,
      language: widget.language,
    );

    // Initialize voice service if settings are provided
    if (widget.voiceSettings != null) {
      _voiceService = NavigationServiceFactory.createVoiceService()
        ..initialize(widget.voiceSettings!);
      _isVoiceEnabled = widget.voiceSettings!.enabled;
    }
  }

  /// Initializes navigation controllers after map is ready
  Future<void> _initializeControllers() async {
    if (_mapboxMap == null) return;

    _cameraController = NavigationServiceFactory.createCameraController();
    _cameraController!.initialize(_mapboxMap!);

    _routeVisualizationService =
        NavigationServiceFactory.createRouteVisualizationService();
    await _routeVisualizationService!.initialize(_mapboxMap!);

    _navigationController = NavigationServiceFactory.createNavigationController(
      locationService: _locationService!,
      directionsAPI: _directionsAPI!,
      cameraController: _cameraController!,
      voiceService: _voiceService,
      navigationStartBuilder: _createLocalizedNavigationStart,
      arrivalAnnouncementBuilder: _createLocalizedArrival,
    );

    // Set up route visualization callback for location-based updates
    _navigationController!
        .setRouteVisualizationCallback(_onRouteVisualizationUpdate);

    // Set traffic data preference for the navigation controller
    if (widget.enableTrafficData) {
      _navigationController!.enableTrafficDataByDefault = true;
    }

    // Listen to navigation state changes
    _navigationController!.stateStream.listen(
      (state) {
        if (mounted) {
          setState(() {
            _currentState = state;
          });

          _updateSpeedLimitData();
          widget.onNavigationStateChanged?.call(state);

          // Update route visualization based on navigation state
          _handleNavigationStateChanged(state);
        }
      },
      onError: (error) {
        widget.onError?.call(error.toString());
      },
    );

    // Listen to step changes
    _navigationController!.stepStream.listen(
      (step) {
        if (mounted) {
          setState(() {
            _currentStep = step;
          });

          _updateSpeedLimitData();
          widget.onStepChanged?.call(step);

          // Update route progress visualization
          _updateRouteProgress();
        }
      },
    );

    // Listen to voice instructions if service is available
    if (_voiceService != null && widget.onVoiceInstruction != null) {
      _voiceService!.instructionStream.listen(
        (instruction) {
          widget.onVoiceInstruction?.call(instruction);
        },
      );

      // Listen to voice errors and forward them
      _voiceService!.errorStream.listen(
        (error) {
          widget.onError?.call(error.toString());
        },
      );
    }

    // Notify that map and navigation controller are ready
    widget.onMapReady?.call(_navigationController!);
  }

  /// Handles navigation state changes and updates route visualization
  Future<void> _handleNavigationStateChanged(NavigationState state) async {
    if (_routeVisualizationService == null || _navigationController == null)
      return;

    switch (state.status) {
      case NavigationStatus.navigating:
        await _updateRouteProgress();

        if (state.route != null) {
          final currentRouteHash = state.route!.hashCode.toString();

          if (_lastRouteHash != currentRouteHash) {
            _lastRouteHash = currentRouteHash;

            final currentStepIndex = _navigationController!.currentStepIndex;
            final currentPosition = state.currentPosition?.toPosition();
            await _routeVisualizationService!.drawRoute(
              state.route!,
              currentStepIndex: currentStepIndex,
              currentPosition: currentPosition,
            );
          } else {
            final currentStepIndex = _navigationController!.currentStepIndex;
            final currentPosition = state.currentPosition?.toPosition();

            if (currentStepIndex != null && currentPosition != null) {
              await _routeVisualizationService!.updateRouteProgress(
                state.route!,
                currentStepIndex,
                currentPosition: currentPosition,
                forceUpdate: true, // Force update for real-time tracing
              );
            }
          }
        }
        break;
      case NavigationStatus.idle:
      case NavigationStatus.arrived:
        // Clear the route when navigation is idle or arrived
        await _routeVisualizationService!.clearRoute();
        _lastRouteHash = null; // Reset route hash
        break;
      case NavigationStatus.calculating:
      case NavigationStatus.paused:
      case NavigationStatus.error:
        break;
    }
  }

  /// Updates route progress visualization during navigation
  Future<void> _updateRouteProgress() async {
    if (_routeVisualizationService == null ||
        _navigationController == null ||
        _navigationController!.currentRoute == null) {
      return;
    }

    final currentStepIndex = _navigationController!.currentStepIndex;
    final currentPosition = _currentState.currentPosition?.toPosition();

    if (currentStepIndex != null) {
      await _routeVisualizationService!.updateRouteProgress(
        _navigationController!.currentRoute!,
        currentStepIndex,
        currentPosition: currentPosition,
      );
    }
  }

  /// Provides access to the navigation controller for external control
  NavigationController? get navigationController => _navigationController;

  /// Gets the current navigation state (read-only)
  NavigationState get currentState => _currentState;

  /// Gets the current navigation step (read-only)
  NavigationStep? get currentStep => _currentStep;

  /// Gets the route visualization service for advanced route management
  RouteVisualizationService? get routeVisualizationService =>
      _routeVisualizationService;

  /// Whether traffic data is enabled for this navigator
  bool get isTrafficDataEnabled => widget.enableTrafficData;

  /// Whether voice instructions are enabled
  bool get isVoiceEnabled => _voiceService?.isEnabled ?? false;

  /// Gets the voice service for advanced voice management
  VoiceInstructionService? get voiceService => _voiceService;

  /// Creates localized navigation start announcement
  String _createLocalizedNavigationStart(
      {String? destinationName, double? totalDistance}) {
    final localizations = Localizations.of(context, NavigationLocalizations);

    return VoiceUtils.createNavigationStartAnnouncement(
      destinationName: destinationName,
      totalDistance: totalDistance,
      navigationStarting:
          localizations?.navigationStarting ?? 'Starting navigation',
      totalDistanceLabel: localizations?.totalDistanceLabel ?? 'Total distance',
      yourDestination: localizations?.yourDestination ?? 'your destination',
    );
  }

  /// Creates localized arrival announcement
  String _createLocalizedArrival({String? destinationName}) {
    final localizations = Localizations.of(context, NavigationLocalizations);

    return VoiceUtils.createArrivalAnnouncement(
      destinationName: destinationName,
      youHaveArrived: localizations?.youHaveArrived ??
          'You have arrived at your destination',
    );
  }

  /// Updates speed limit data based on current route and position
  void _updateSpeedLimitData() {
    if (_currentState.route == null || _currentStep == null) {
      _currentSpeedLimit = null;
      return;
    }

    final route = _currentState.route!;
    int? previousSpeedLimit = _currentSpeedLimit;

    // Extract speed limit from traffic annotations if available
    if (route.trafficAnnotations != null &&
        route.trafficAnnotations!.isNotEmpty) {
      _currentSpeedLimit =
          _extractSpeedLimitFromAnnotations(route.trafficAnnotations!);
    }

    // Fallback to inferring speed limit based on road type and area
    _currentSpeedLimit ??= _inferSpeedLimitFromContext();

    // If speed limit changed, trigger UI update
    if (previousSpeedLimit != _currentSpeedLimit) {
      if (mounted) {
        setState(() {});
      }
    }

    // Update current speed from location service
    if (_currentState.currentPosition != null) {}
  }

  /// Extracts speed limit from Mapbox traffic annotations
  int? _extractSpeedLimitFromAnnotations(List<TrafficAnnotation> annotations) {
    if (annotations.isEmpty) return null;

    // Filter annotations with valid speed data
    final validSpeeds = annotations
        .where(
            (annotation) => annotation.speed != null && annotation.speed! > 0)
        .toList();

    if (validSpeeds.isEmpty) return null;

    // Strategy 1: Use maximum observed speed as potential speed limit indicator
    // This works on the assumption that in free-flow conditions,
    // traffic speeds approach the posted speed limit
    final maxSpeed = validSpeeds
        .map((annotation) => annotation.speed!)
        .reduce((a, b) => a > b ? a : b);

    // Strategy 2: Look for segments with low congestion (free-flow conditions)
    final freeFlowSpeeds = validSpeeds
        .where((annotation) =>
            annotation.congestion == 'low' ||
            annotation.congestion == 'unknown')
        .map((annotation) => annotation.speed!)
        .toList();

    double targetSpeed;
    if (freeFlowSpeeds.isNotEmpty) {
      // Use average of free-flow speeds as it's more reliable
      targetSpeed =
          freeFlowSpeeds.reduce((a, b) => a + b) / freeFlowSpeeds.length;
    } else {
      // Fallback to max speed, but adjust for congestion
      targetSpeed = maxSpeed * 1.2; // Assume traffic is 20% slower than limit
    }

    // Convert km/h to mph and round to nearest 5 mph increment
    // (common for speed limit posting)
    final speedLimitMph = (targetSpeed * 0.621371).round();
    final roundedLimit = ((speedLimitMph + 2) ~/ 5) * 5;

    // Apply reasonable bounds for different road types
    if (roundedLimit >= 65) {
      return 70; // Highway speed
    } else if (roundedLimit >= 50) {
      return 55; // Major arterial
    } else if (roundedLimit >= 35) {
      return 45; // Urban arterial
    } else if (roundedLimit >= 25) {
      return 35; // Collector road
    } else {
      return 25; // Residential/local
    }
  }

  /// Infers speed limit based on road context, maneuver type, and location
  int? _inferSpeedLimitFromContext() {
    if (_currentStep == null) return null;

    final instruction = _currentStep!.instruction.toLowerCase();
    final maneuver = _currentStep!.maneuver.toLowerCase();

    // Highway/freeway detection
    if (instruction.contains('highway') ||
        instruction.contains('freeway') ||
        instruction.contains('interstate') ||
        instruction.contains('motorway')) {
      return 70; // 70 mph typical highway speed
    }

    // Major road detection
    if (instruction.contains('boulevard') ||
        instruction.contains('avenue') ||
        maneuver.contains('merge') ||
        maneuver.contains('fork')) {
      return 45; // 45 mph typical major road
    }

    // Residential/local road detection
    if (instruction.contains('street') ||
        instruction.contains('road') ||
        instruction.contains('drive') ||
        instruction.contains('lane')) {
      return 25; // 25 mph typical residential
    }

    // Turn/intersection areas - lower speeds
    if (maneuver.contains('turn') ||
        maneuver.contains('continue') ||
        instruction.contains('turn')) {
      return 35; // 35 mph typical for turns
    }

    // Default urban speed limit
    return 30;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MapWidget(
          key: const ValueKey('mapbox_map'),
          cameraOptions: widget.initialCameraPosition ??
              CameraOptions(
                center: Point(
                  coordinates: Position(-122.4194, 37.7749),
                ),
                zoom: 12.0,
              ),
          styleUri: widget.styleUri ?? MapboxStyles.MAPBOX_STREETS,
          textureView: true,
          onMapCreated: _onMapCreated,
          onStyleLoadedListener: _onStyleLoaded,
        ),
        if (widget.showNavigationControls)
          NavigationControlsPositioned(
            navigationController: _navigationController,
            voiceService: _voiceService,
            isVoiceEnabled: _isVoiceEnabled,
            style: widget.navigationControlsStyle,
            customWidget: widget.customNavigationControls,
            onVoiceToggle: (enabled) {
              setState(() {
                _isVoiceEnabled = enabled;
              });
              _navigationController?.setVoiceEnabled(enabled);
            },
            onZoomIn: () {
              final currentZoom = _cameraController?.currentZoom ?? 10.0;
              _cameraController?.setZoom(currentZoom + 1.0);
            },
            onZoomOut: () {
              final currentZoom = _cameraController?.currentZoom ?? 10.0;
              _cameraController?.setZoom(currentZoom - 1.0);
            },
            onRecalculateRoute: () {
              final currentPosition =
                  _currentState.currentPosition?.toPosition();
              _navigationController?.recalculateRoute(
                currentPosition: currentPosition,
              );
            },
            onPauseResumeNavigation: () {
              if (_navigationController?.isPaused == true) {
                _navigationController?.resumeNavigation();
              } else {
                _navigationController?.pauseNavigation();
              }
              setState(() {});
            },
            isPaused: _navigationController?.isPaused ?? false,
          ),
        if (widget.showStatusWidget)
          StatusWidgetPositioned(
            navigationState: _currentState,
            style: widget.navigationStatusStyle,
            customWidget: widget.customStatusWidget,
          ),
        if (_currentStep != null && widget.showInstructions)
          InstructionWidgetPositioned(
            currentStep: _currentStep!,
            remainingDistance: _currentState.remainingDistance,
            remainingTime: Duration(seconds: _currentState.remainingDuration),
            style: widget.navigationInstructionStyle,
            customWidget: widget.customInstructionWidget,
          ),
        if (widget.showSpeedLimit && _currentSpeedLimit != null)
          SpeedLimitWidgetPositioned(
            speedLimit: _currentSpeedLimit,
            unit: widget.speedUnit,
            customWidget: widget.customSpeedLimitWidget,
          ),
      ],
    );
  }

  /// Handles map creation
  void _onMapCreated(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;

    // Configure map settings asynchronously
    _configureMap();
  }

  /// Handles map style loaded event - initialize route layers after style is ready
  void _onStyleLoaded(StyleLoadedEventData data) {
    _initializeControllers();
  }

  /// Configures map settings
  Future<void> _configureMap() async {
    if (_mapboxMap == null) return;

    Uint8List? customLocationPuckBytes;
    Uint8List? customLocationPuckBackgroundBytes;

    try {
      final ByteData data = await rootBundle
          .load('packages/mapbox_navigation/assets/location-puck.png');
      customLocationPuckBytes = data.buffer.asUint8List();
    } catch (e) {
      _logger.warning('Failed to load custom location puck', e);
    }

    final locationPuck = LocationPuck(
      locationPuck2D: customLocationPuckBytes != null
          ? LocationPuck2D(
              topImage: customLocationPuckBytes,
              bearingImage: customLocationPuckBytes,
              shadowImage: customLocationPuckBackgroundBytes,
              opacity: 1.0,
            )
          : DefaultLocationPuck2D(),
    );

    await _mapboxMap!.location.updateSettings(
      LocationComponentSettings(
        enabled: true,
        puckBearingEnabled: true,
        locationPuck: locationPuck,
        layerAbove: null,
      ),
    );
  }

  /// Handles route visualization updates triggered by location changes
  void _onRouteVisualizationUpdate(
      RouteData route, int stepIndex, geo.Position? position) {
    if (_routeVisualizationService == null) return;

    // Fire-and-forget route update (no await to avoid blocking)
    _routeVisualizationService!.updateRouteProgress(
      route,
      stepIndex,
      currentPosition: position,
      forceUpdate: false, // Only update when necessary
    );
  }
}

class NavigationControlsPositioned extends StatelessWidget {
  final NavigationController? navigationController;
  final VoiceInstructionService? voiceService;
  final bool isVoiceEnabled;
  final NavigationControlsStyle? style;
  final NavigationControlsWidget? customWidget;
  final void Function(bool enabled) onVoiceToggle;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onRecalculateRoute;
  final VoidCallback onPauseResumeNavigation;
  final bool isPaused;

  const NavigationControlsPositioned({
    super.key,
    required this.navigationController,
    required this.voiceService,
    required this.isVoiceEnabled,
    required this.style,
    required this.customWidget,
    required this.onVoiceToggle,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onRecalculateRoute,
    required this.onPauseResumeNavigation,
    required this.isPaused,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      top: 0,
      bottom: 0,
      child: customWidget ??
          NavigationControlsWidget(
            navigationController: navigationController,
            voiceService: voiceService,
            isVoiceEnabled: isVoiceEnabled,
            style: style,
            onVoiceToggle: onVoiceToggle,
            onZoomIn: onZoomIn,
            onZoomOut: onZoomOut,
            onRecalculateRoute: onRecalculateRoute,
            onPauseResumeNavigation: onPauseResumeNavigation,
            isPaused: isPaused,
          ),
    );
  }
}

class StatusWidgetPositioned extends StatelessWidget {
  final NavigationState navigationState;
  final NavigationStatusStyle? style;
  final NavigationStatusWidget? customWidget;

  const StatusWidgetPositioned({
    super.key,
    required this.navigationState,
    required this.style,
    required this.customWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 16,
      left: 0,
      right: 0,
      child: Center(
        child: customWidget ??
            NavigationStatusWidget(
              navigationState: navigationState,
              style: style,
            ),
      ),
    );
  }
}

class InstructionWidgetPositioned extends StatelessWidget {
  final NavigationStep currentStep;
  final double? remainingDistance;
  final Duration? remainingTime;
  final NavigationInstructionStyle? style;
  final NavigationInstructionWidget? customWidget;

  const InstructionWidgetPositioned({
    super.key,
    required this.currentStep,
    required this.remainingDistance,
    required this.remainingTime,
    required this.style,
    required this.customWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: -50,
      left: 0,
      right: 0,
      child: customWidget ??
          NavigationInstructionWidget(
            currentStep: currentStep,
            remainingDistance: remainingDistance,
            remainingTime: remainingTime?.inSeconds,
            style: style,
          ),
    );
  }
}

class SpeedLimitWidgetPositioned extends StatelessWidget {
  final int? speedLimit;
  final SpeedUnit unit;
  final SpeedLimitWidget? customWidget;

  const SpeedLimitWidgetPositioned({
    super.key,
    required this.speedLimit,
    required this.unit,
    required this.customWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 80,
      left: 16,
      child: customWidget ??
          SpeedLimitWidget(
            speedLimit: speedLimit,
            unit: unit,
            isVisible: speedLimit != null,
          ),
    );
  }
}
