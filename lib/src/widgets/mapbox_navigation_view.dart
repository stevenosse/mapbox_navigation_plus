import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../models/navigation_state.dart';
import '../models/navigation_step.dart';
import '../services/location_service.dart';
import '../services/mapbox_directions_api.dart';
import '../services/route_visualization_service.dart';
import '../services/voice_instruction_service.dart';
import '../controllers/navigation_controller.dart';
import '../controllers/camera_controller.dart';
import '../models/voice_settings.dart';
import '../utils/maneuver_utils.dart';
import '../utils/formatting_utils.dart';
import '../utils/voice_utils.dart';
import '../utils/constants.dart' as nav_constants;
import '../localization/navigation_localizations.dart';

/// Callback for navigation events
typedef NavigationCallback = void Function(NavigationState state);
typedef StepCallback = void Function(NavigationStep step);
typedef ErrorCallback = void Function(String error);
typedef MapReadyCallback = void Function(NavigationController navigationController);
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
  });

  @override
  State<MapboxNavigationView> createState() => _MapboxNavigationViewState();
}

class _MapboxNavigationViewState extends State<MapboxNavigationView> {
  MapboxMap? _mapboxMap;
  LocationService? _locationService;
  MapboxDirectionsAPI? _directionsAPI;
  NavigationController? _navigationController;
  CameraController? _cameraController;
  RouteVisualizationService? _routeVisualizationService;
  VoiceInstructionService? _voiceService;

  NavigationState _currentState = NavigationState.idle();
  NavigationStep? _currentStep;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  @override
  void dispose() {
    _navigationController?.dispose();
    _locationService?.dispose();
    _routeVisualizationService?.dispose();
    _voiceService?.dispose();
    super.dispose();
  }

  /// Initializes all navigation services
  void _initializeServices() {
    _locationService = LocationService();
    _directionsAPI = MapboxDirectionsAPI(accessToken: widget.accessToken, language: widget.language);

    // Initialize voice service if settings are provided
    if (widget.voiceSettings != null) {
      _voiceService = VoiceInstructionService()..initialize(widget.voiceSettings!);
    }
  }

  /// Initializes navigation controllers after map is ready
  Future<void> _initializeControllers() async {
    if (_mapboxMap == null) return;

    _cameraController = CameraController();
    _cameraController!.initialize(_mapboxMap!);

    _routeVisualizationService = RouteVisualizationService();
    await _routeVisualizationService!.initialize(_mapboxMap!);

    _navigationController = NavigationController(
      locationService: _locationService!,
      directionsAPI: _directionsAPI!,
      cameraController: _cameraController!,
      voiceService: _voiceService,
      voiceInstructionBuilder: _createLocalizedVoiceInstruction,
      navigationStartBuilder: _createLocalizedNavigationStart,
      arrivalAnnouncementBuilder: _createLocalizedArrival,
    );

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
    if (_routeVisualizationService == null || _navigationController == null) return;

    switch (state.status) {
      case NavigationStatus.navigating:
        // Draw the route when navigation starts or route is recalculated
        if (state.route != null) {
          final currentStepIndex = _navigationController!.currentStepIndex;
          final currentPosition = state.currentPosition?.toPosition();
          await _routeVisualizationService!.drawRoute(
            state.route!,
            currentStepIndex: currentStepIndex,
            currentPosition: currentPosition,
          );
        }
        break;
      case NavigationStatus.idle:
      case NavigationStatus.arrived:
        // Clear the route when navigation is idle or arrived
        await _routeVisualizationService!.clearRoute();
        break;
      case NavigationStatus.calculating:
      case NavigationStatus.paused:
      case NavigationStatus.error:
        // Keep existing route visible during these states
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
  RouteVisualizationService? get routeVisualizationService => _routeVisualizationService;

  /// Whether traffic data is enabled for this navigator
  bool get isTrafficDataEnabled => widget.enableTrafficData;

  /// Whether voice instructions are enabled
  bool get isVoiceEnabled => _voiceService?.isEnabled ?? false;

  /// Gets the voice service for advanced voice management
  VoiceInstructionService? get voiceService => _voiceService;

  /// Creates localized voice instruction for the navigation controller
  String _createLocalizedVoiceInstruction({
    required String baseInstruction,
    required double remainingDistance,
    String? maneuverType,
  }) {
    final localizations = Localizations.of(context, NavigationLocalizations);
    
    return VoiceUtils.createVoiceInstruction(
      baseInstruction: baseInstruction,
      remainingDistance: remainingDistance,
      maneuverType: maneuverType,
      // Pass localized strings or fallback to English
      turnLeftNow: localizations?.turnLeftNow ?? 'Turn left now',
      turnRightNow: localizations?.turnRightNow ?? 'Turn right now',
      mergeNow: localizations?.mergeNow ?? 'Merge now',
      takeTheExit: localizations?.takeTheExit ?? 'Take the exit now',
      enterRoundabout: localizations?.enterRoundabout ?? 'Enter the roundabout',
      prepareToTurnLeft: localizations?.prepareToTurnLeft ?? 'Prepare to turn left',
      prepareToTurnRight: localizations?.prepareToTurnRight ?? 'Prepare to turn right',
      prepareToMerge: localizations?.prepareToMerge ?? 'Prepare to merge',
      prepareToExit: localizations?.prepareToExit ?? 'Prepare to exit',
      prepareToEnterRoundabout: localizations?.prepareToEnterRoundabout ?? 'Prepare to enter the roundabout',
      prepareTo: localizations?.prepareTo ?? 'Prepare to',
      inDistance: localizations?.inDistance ?? 'In',
    );
  }

  /// Creates localized navigation start announcement
  String _createLocalizedNavigationStart({String? destinationName, double? totalDistance}) {
    final localizations = Localizations.of(context, NavigationLocalizations);
    
    return VoiceUtils.createNavigationStartAnnouncement(
      destinationName: destinationName,
      totalDistance: totalDistance,
      navigationStarting: localizations?.navigationStarting ?? 'Starting navigation',
      totalDistanceLabel: localizations?.totalDistanceLabel ?? 'Total distance',
      yourDestination: localizations?.yourDestination ?? 'your destination',
    );
  }

  /// Creates localized arrival announcement
  String _createLocalizedArrival({String? destinationName}) {
    final localizations = Localizations.of(context, NavigationLocalizations);
    
    return VoiceUtils.createArrivalAnnouncement(
      destinationName: destinationName,
      youHaveArrived: localizations?.youHaveArrived ?? 'You have arrived at your destination',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Mapbox Map
        MapWidget(
          key: const ValueKey('mapbox_map'),
          cameraOptions: widget.initialCameraPosition ??
              CameraOptions(
                center: Point(
                  coordinates: Position(-122.4194, 37.7749), // San Francisco
                ),
                zoom: 12.0,
              ),
          styleUri: widget.styleUri ?? MapboxStyles.MAPBOX_STREETS,
          textureView: true,
          onMapCreated: _onMapCreated,
          onStyleLoadedListener: _onStyleLoaded,
        ),

        // Navigation Instructions Overlay
        if (widget.showInstructions && _currentStep != null) _buildInstructionOverlay(),

        // Navigation Status Overlay
        _buildStatusOverlay(),
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
      final ByteData data = await rootBundle.load('packages/mapbox_navigation/assets/location-puck.png');
      customLocationPuckBytes = data.buffer.asUint8List();
    } catch (e) {
      debugPrint('Failed to create custom location puck: $e');
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
        layerAbove: null, // This might help keep location puck on top
      ),
    );
  }

  /// Builds the instruction overlay widget
  Widget _buildInstructionOverlay() {
    if (_currentStep == null) return const SizedBox.shrink();

    if (widget.instructionBuilder != null) {
      return Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        child: widget.instructionBuilder!(_currentStep!),
      );
    }

    // Default instruction overlay
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: Card(
        elevation: 8,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    ManeuverUtils.getManeuverIcon(_currentStep!.maneuver),
                    size: nav_constants.NavigationConstants.largeIconSize,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _getInstructionText(),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_currentState.status == NavigationStatus.navigating && _currentState.currentPosition != null)
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.green,
                          ),
                        ),
                      Text(
                        _getDistanceText(),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(width: nav_constants.NavigationConstants.defaultPadding),
                  Text(
                    FormattingUtils.formatDuration(_currentStep!.duration),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the navigation status overlay
  Widget _buildStatusOverlay() {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 16,
      left: 16,
      right: 16,
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Status text
              Expanded(
                child: Text(
                  _getStatusText(_currentState.status),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),

              // Progress info
              if (_currentState.status == NavigationStatus.navigating) ...[
                Text(
                  FormattingUtils.formatDistance(_currentState.remainingDistance),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: nav_constants.NavigationConstants.smallPadding),
                Text(
                  FormattingUtils.formatDuration(_currentState.remainingDuration),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  /// Gets the status text for the current navigation state
  String _getStatusText(NavigationStatus status) {
    final localizations = Localizations.of(context, NavigationLocalizations);
    
    // Fallback to English if localization is not available
    if (localizations == null) {
      switch (status) {
        case NavigationStatus.idle:
          return 'Ready to navigate';
        case NavigationStatus.calculating:
          return 'Calculating route...';
        case NavigationStatus.navigating:
          return 'Navigating';
        case NavigationStatus.paused:
          return 'Navigation paused';
        case NavigationStatus.arrived:
          return 'Arrived at destination';
        case NavigationStatus.error:
          return 'Navigation error';
      }
    }
    
    switch (status) {
      case NavigationStatus.idle:
        return localizations.readyToNavigate;
      case NavigationStatus.calculating:
        return localizations.calculatingRoute;
      case NavigationStatus.navigating:
        return localizations.navigating;
      case NavigationStatus.paused:
        return localizations.navigationPaused;
      case NavigationStatus.arrived:
        return localizations.arrivedAtDestination;
      case NavigationStatus.error:
        return localizations.navigationError;
    }
  }

  /// Gets the distance text for the current instruction
  String _getDistanceText() {
    if (_currentStep == null) return '';

    // If we have current position and are navigating, calculate remaining distance
    if (_currentState.currentPosition != null && _currentState.status == NavigationStatus.navigating) {
      final currentPos = _currentState.currentPosition!.toPosition();
      final remainingDistance = _currentStep!.getRemainingDistance(currentPos);

      // Only show remaining distance if it's reasonable (not negative or way off)
      if (remainingDistance >= 0 && remainingDistance <= _currentStep!.distance * 1.2) {
        return FormattingUtils.formatDistance(remainingDistance);
      }
    }

    // Fallback to step's total distance
    return FormattingUtils.formatDistance(_currentStep!.distance);
  }

  /// Gets the dynamic instruction text based on remaining distance
  String _getInstructionText() {
    if (_currentStep == null) return '';

    String baseInstruction = _currentStep!.instruction;

    // If we have current position and are navigating, enhance instruction with distance context
    if (_currentState.currentPosition != null && _currentState.status == NavigationStatus.navigating) {
      final currentPos = _currentState.currentPosition!.toPosition();
      final remainingDistance = _currentStep!.getRemainingDistance(currentPos);

      if (remainingDistance >= 0 && remainingDistance <= _currentStep!.distance * 1.2) {
        return _enhanceInstructionWithDistance(baseInstruction, remainingDistance);
      }
    }

    return baseInstruction;
  }

  /// Enhances instruction text based on remaining distance
  String _enhanceInstructionWithDistance(String instruction, double remainingDistance) {
    final localizations = Localizations.of(context, NavigationLocalizations);
    final lowerInstruction = instruction.toLowerCase();

    // For very close distances (under 50m), add urgency
    if (remainingDistance <= 50) {
      if (lowerInstruction.contains('turn left')) {
        return localizations?.turnLeftNow ?? 'Turn left now';
      } else if (lowerInstruction.contains('turn right')) {
        return localizations?.turnRightNow ?? 'Turn right now';
      } else if (lowerInstruction.contains('continue')) {
        return instruction; // Keep continue instructions as-is when close
      } else if (lowerInstruction.contains('merge')) {
        return localizations?.mergeNow ?? 'Merge now';
      } else if (lowerInstruction.contains('exit')) {
        return localizations?.takeTheExit ?? 'Take the exit';
      } else {
        final getReadyText = localizations?.getReady ?? 'Get ready';
        return '$getReadyText - $instruction';
      }
    }

    // For medium distances (50m-200m), add preparation context
    if (remainingDistance <= 200) {
      if (lowerInstruction.contains('turn left')) {
        return localizations?.prepareToTurnLeft ?? 'Prepare to turn left';
      } else if (lowerInstruction.contains('turn right')) {
        return localizations?.prepareToTurnRight ?? 'Prepare to turn right';
      } else if (lowerInstruction.contains('merge')) {
        return localizations?.prepareToMerge ?? 'Prepare to merge';
      } else if (lowerInstruction.contains('exit')) {
        return localizations?.prepareToExit ?? 'Prepare to exit';
      } else if (lowerInstruction.contains('turn')) {
        final prepareToText = localizations?.prepareTo ?? 'Prepare to';
        return '$prepareToText $lowerInstruction';
      }
    }

    // For longer distances (200m+), add "in X meters" context
    if (remainingDistance > 200) {
      final distanceText = FormattingUtils.formatDistance(remainingDistance);
      if (lowerInstruction.contains('turn')) {
        final inDistanceText = localizations?.inDistance ?? 'In';
        return '$inDistanceText $distanceText, $lowerInstruction';
      } else if (lowerInstruction.contains('merge') || lowerInstruction.contains('exit')) {
        final inDistanceText = localizations?.inDistance ?? 'In';
        return '$inDistanceText $distanceText, $lowerInstruction';
      }
    }

    // Default: return original instruction
    return instruction;
  }
}
