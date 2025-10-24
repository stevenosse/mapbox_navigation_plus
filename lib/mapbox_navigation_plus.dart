/// Mapbox Navigation Package
///
/// A comprehensive Flutter navigation library that provides turn-by-turn navigation,
/// route calculation, and map visualization using Mapbox services.
///
/// Features:
/// - Route calculation using Mapbox Directions API
/// - Turn-by-turn navigation with voice guidance
/// - Real-time route progress tracking
/// - Map visualization with route lines and markers
/// - Modular and customizable architecture
///
library;

// Core interfaces
export 'src/core/interfaces/location_provider.dart';
export 'src/core/interfaces/routing_engine.dart';
export 'src/core/interfaces/voice_guidance.dart';
export 'src/core/interfaces/route_progress_tracker.dart';
export 'src/core/interfaces/map_controller_interface.dart';
export 'src/core/interfaces/nav_controller.dart';

// Core models
export 'src/core/models/location_point.dart';
export 'src/core/models/navigation_state.dart';
export 'src/core/models/route_model.dart';
export 'src/core/models/route_progress.dart';
export 'src/core/models/leg.dart';
export 'src/core/models/step.dart';
export 'src/core/models/maneuver.dart';
export 'src/core/models/voice_instruction.dart';
export 'src/core/models/map_marker.dart';
export 'src/core/models/routing_options.dart';
export 'src/core/models/route_style_config.dart';
export 'src/core/models/location_puck_config.dart';

// Services
export 'src/services/routing/mapbox_routing_engine.dart';
export 'src/services/location/default_location_provider.dart';
export 'src/services/progress/default_route_progress_tracker.dart';
export 'src/services/voice/default_voice_guidance.dart';

// UI Components
export 'src/ui/navigation_view/navigation_view.dart';
export 'src/ui/navigation_view/mapbox_map_controller.dart';

// Main navigation controller
export 'src/navigation_controller.dart';

export 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart'
    show
        MapboxOptions,
        MapWidget,
        MapboxMap,
        LocationPuck,
        LocationPuck2D,
        LocationPuck3D,
        DefaultLocationPuck2D,
        LocationComponentSettings,
        CameraOptions,
        Position,
        Point;
