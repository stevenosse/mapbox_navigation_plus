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
import '../utils/voice_utils.dart';
import '../localization/navigation_localizations.dart';
import 'navigation_instruction_widget.dart';
import 'navigation_status_widget.dart';
import 'navigation_controls_widget.dart';
import 'map_overlay_manager.dart';

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

  /// Custom overlay controller for managing map overlays
  final OverlayController? overlayController;

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

  /// Custom overlay configurations
  final List<OverlayConfig> customOverlays;

  /// Callback when an overlay is tapped
  final void Function(String overlayId)? onOverlayTap;

  /// Navigation controls style
  final NavigationControlsStyle? navigationControlsStyle;

  /// Navigation status style
  final NavigationStatusStyle? navigationStatusStyle;

  /// Navigation instruction style
  final NavigationInstructionStyle? navigationInstructionStyle;

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
    this.overlayController,
    this.customNavigationControls,
    this.customInstructionWidget,
    this.customStatusWidget,
    this.showNavigationControls = true,
    this.showStatusWidget = true,
    this.customOverlays = const [],
    this.onOverlayTap,
    this.navigationControlsStyle,
    this.navigationStatusStyle,
    this.navigationInstructionStyle,
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
  late OverlayController _overlayController;

  NavigationState _currentState = NavigationState.idle();
  NavigationStep? _currentStep;

  @override
  void initState() {
    super.initState();
    _overlayController = widget.overlayController ?? OverlayController();
    _initializeServices();
    _setupDefaultOverlays();
  }

  @override
  void dispose() {
    _navigationController?.dispose();
    _locationService?.dispose();
    _routeVisualizationService?.dispose();
    _voiceService?.dispose();
    if (widget.overlayController == null) {
      _overlayController.dispose();
    }
    super.dispose();
  }

  /// Initializes all navigation services
  void _initializeServices() {
    _locationService = LocationService();
    _directionsAPI = MapboxDirectionsAPI(
        accessToken: widget.accessToken, language: widget.language);

    // Initialize voice service if settings are provided
    if (widget.voiceSettings != null) {
      _voiceService = VoiceInstructionService()
        ..initialize(widget.voiceSettings!);
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
          _updateOverlayWidgets();
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
          _updateOverlayWidgets();
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
  RouteVisualizationService? get routeVisualizationService =>
      _routeVisualizationService;

  /// Whether traffic data is enabled for this navigator
  bool get isTrafficDataEnabled => widget.enableTrafficData;

  /// Whether voice instructions are enabled
  bool get isVoiceEnabled => _voiceService?.isEnabled ?? false;

  /// Gets the voice service for advanced voice management
  VoiceInstructionService? get voiceService => _voiceService;

  /// Gets the overlay controller for dynamic widget management
  OverlayController get overlayController => _overlayController;

  /// Add a custom overlay widget
  void addOverlay(OverlayConfig config) {
    _overlayController.addOverlay(config);
  }

  /// Remove an overlay by ID
  void removeOverlay(String id) {
    _overlayController.removeOverlay(id);
  }

  /// Update an existing overlay
  void updateOverlay(String id, OverlayConfig Function(OverlayConfig) updater) {
    _overlayController.updateOverlay(id, updater);
  }

  /// Show an overlay
  void showOverlay(String id) {
    _overlayController.showOverlay(id);
  }

  /// Hide an overlay
  void hideOverlay(String id) {
    _overlayController.hideOverlay(id);
  }

  /// Toggle overlay visibility
  void toggleOverlay(String id) {
    _overlayController.toggleOverlay(id);
  }

  /// Clear all overlays
  void clearAllOverlays() {
    _overlayController.clearOverlays();
  }

  /// Get overlay by ID
  OverlayConfig? getOverlay(String id) {
    return _overlayController.getOverlay(id);
  }

  /// Check if overlay exists
  bool hasOverlay(String id) {
    return _overlayController.hasOverlay(id);
  }

  /// Get all current overlays
  List<OverlayConfig> get allOverlays => _overlayController.overlays;

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

  /// Sets up default overlay widgets
  void _setupDefaultOverlays() {
    // Add custom overlays first
    for (final overlay in widget.customOverlays) {
      _overlayController.addOverlay(overlay);
    }

    // Add default navigation controls if enabled
    if (widget.showNavigationControls) {
      _overlayController.addOverlay(
        OverlayConfig(
          id: 'navigation_controls',
          widget: widget.customNavigationControls ??
              NavigationControlsWidget(
                navigationController: _navigationController,
                voiceService: _voiceService,
                isVoiceEnabled: _voiceService?.isEnabled ?? false,
                style: widget.navigationControlsStyle,
                onVoiceToggle: (enabled) {
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
                  _navigationController?.recalculateRoute();
                },
              ),
          position: OverlayPosition.centerRight,
          offset: const Offset(16, 0),
          zIndex: 100,
        ),
      );
    }

    // Add default status widget if enabled
    if (widget.showStatusWidget) {
      _overlayController.addOverlay(
        OverlayConfig(
          id: 'navigation_status',
          widget: widget.customStatusWidget ??
              NavigationStatusWidget(
                navigationState: _currentState,
                style: widget.navigationStatusStyle,
              ),
          position: OverlayPosition.bottomCenter,
          offset: const Offset(0, 16),
          zIndex: 50,
        ),
      );
    }
  }

  /// Updates overlay widgets when navigation state changes
  void _updateOverlayWidgets() {
    // Update navigation controls
    if (widget.showNavigationControls &&
        _overlayController.hasOverlay('navigation_controls')) {
      _overlayController.updateOverlay('navigation_controls', (config) {
        return config.copyWith(
          widget: widget.customNavigationControls ??
              NavigationControlsWidget(
                navigationController: _navigationController,
                voiceService: _voiceService,
                isVoiceEnabled: _voiceService?.isEnabled ?? false,
                style: widget.navigationControlsStyle,
                onVoiceToggle: (enabled) {
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
                  _navigationController?.recalculateRoute();
                },
              ),
        );
      });
    }

    // Update status widget
    if (widget.showStatusWidget &&
        _overlayController.hasOverlay('navigation_status')) {
      _overlayController.updateOverlay('navigation_status', (config) {
        return config.copyWith(
          widget: widget.customStatusWidget ??
              NavigationStatusWidget(
                navigationState: _currentState,
                style: widget.navigationStatusStyle,
              ),
        );
      });
    }

    // Update instruction widget based on current step
    if (_currentStep != null && widget.showInstructions) {
      final instructionWidget = widget.customInstructionWidget ??
          NavigationInstructionWidget(
            currentStep: _currentStep,
            remainingDistance: _currentState.remainingDistance,
            remainingTime: _currentState.remainingDuration,
            style: widget.navigationInstructionStyle,
          );

      _overlayController.addOverlay(
        OverlayConfig(
          id: 'navigation_instruction',
          widget: instructionWidget,
          position: OverlayPosition.topCenter,
          offset: Offset(0, MediaQuery.of(context).padding.top + 16),
          zIndex: 75,
        ),
      );
    } else {
      _overlayController.removeOverlay('navigation_instruction');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Update overlay widgets when state changes
    _updateOverlayWidgets();

    return ManagedMapOverlay(
      controller: _overlayController,
      onOverlayTap: widget.onOverlayTap,
      child: MapWidget(
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
        layerAbove: null,
      ),
    );
  }
}
