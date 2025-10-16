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
export 'core/interfaces/location_provider.dart';
export 'core/interfaces/routing_engine.dart';
export 'core/interfaces/voice_guidance.dart';
export 'core/interfaces/route_progress_tracker.dart';
export 'core/interfaces/map_controller_interface.dart';
export 'core/interfaces/nav_controller.dart';

// Core models
export 'core/models/location_point.dart';
export 'core/models/navigation_state.dart';
export 'core/models/route_model.dart';
export 'core/models/route_progress.dart';
export 'core/models/leg.dart';
export 'core/models/step.dart';
export 'core/models/maneuver.dart';
export 'core/models/voice_instruction.dart';
export 'core/models/map_marker.dart';
export 'core/models/routing_options.dart';
export 'core/models/route_style_config.dart';
export 'core/models/location_puck_config.dart';
export 'core/models/destination_pin_config.dart';
export 'core/models/route_result.dart';

// Services
export 'services/routing/mapbox_routing_engine.dart';
export 'services/location/default_location_provider.dart';
export 'services/progress/default_route_progress_tracker.dart';
export 'services/voice/default_voice_guidance.dart';

// UI Components
export 'ui/navigation_view/navigation_view.dart';
export 'ui/navigation_view/mapbox_map_controller.dart';

// Main navigation controller
export 'navigation_controller.dart';

export 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart'
    show MapboxOptions;
