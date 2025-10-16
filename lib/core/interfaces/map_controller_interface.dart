import 'dart:async';
import '../models/route_model.dart';
import '../models/route_result.dart';
import '../models/location_point.dart';
import '../models/route_progress.dart';
import '../models/map_marker.dart';
import '../models/route_style_config.dart';
import '../models/location_puck_config.dart';
import '../models/destination_pin_config.dart';

/// Abstract interface for map control and visualization
abstract class MapControllerInterface {
  /// Draws a route on the map
  Future<void> drawRoute({
    required RouteModel route,
    RouteStyleConfig? styleConfig,
  });

  /// Draws multiple routes on the map for route selection
  /// Each route will be styled differently to distinguish them
  /// Returns a map of route IDs to their visual representations
  Future<Map<String, String>> drawMultipleRoutes({
    required List<RouteResult> routes,
    RouteStyleConfig? baseStyleConfig,
    bool highlightFastest = true,
  });

  /// Clears multiple routes from the map
  Future<void> clearMultipleRoutes();

  /// Highlights a specific route from multiple routes
  Future<void> highlightRoute(String routeId);

  /// Updates the progress line along the route (shows traveled vs remaining)
  Future<void> updateProgressLine({
    required RouteProgress progress,
    RouteStyleConfig? styleConfig,
  });

  /// Adds markers to the map
  Future<void> addMarkers(List<MapMarker> markers);

  /// Removes all markers
  Future<void> clearMarkers();

  /// Moves camera to specific position
  Future<void> moveCamera({
    required LocationPoint center,
    double? zoom,
    double? bearing,
    double? pitch,
    double? heading,
    CameraAnimation? animation,
  });

  /// Centers map on current location
  Future<void> centerOnLocation({
    required LocationPoint location,
    double zoom = 16.0,
    bool followLocation = false,
  });

  /// Starts/stop following user location
  Future<void> setLocationFollowMode(bool follow);

  /// Clears all route lines and overlays
  Future<void> clearRoute();

  /// Clears everything from the map
  Future<void> clear();

  /// Gets current camera position
  Future<CameraPosition> getCameraPosition();

  /// Stream of camera position changes
  Stream<CameraPosition> get cameraPositionStream;

  /// Stream of map gestures (user interaction)
  Stream<MapGesture> get gestureStream;

  /// Whether the map is currently following user location
  bool get isFollowingLocation;

  /// Updates the custom location puck position and heading
  Future<void> updateLocationPuck(LocationPoint location);

  /// Sets the location puck to idle state with car marker and background
  Future<void> setIdleLocationPuck();

  /// Sets the location puck to navigation state with navigation marker (no background)
  Future<void> setNavigationLocationPuck();

  /// Removes the location puck from the map
  Future<void> hideLocationPuck();

  /// Configures the location puck appearance
  Future<void> configureLocationPuck(LocationPuckConfig config);

  /// Sets the destination pin configuration
  Future<void> configureDestinationPin(DestinationPinConfig config);

  /// Shows destination pin at specified location
  Future<void> showDestinationPin(LocationPoint location);

  /// Hides the destination pin
  Future<void> hideDestinationPin();
}

/// Camera position information
class CameraPosition {
  final LocationPoint center;
  final double zoom;
  final double bearing;
  final double pitch;

  const CameraPosition({
    required this.center,
    required this.zoom,
    this.bearing = 0.0,
    this.pitch = 0.0,
  });
}

/// Camera animation options
class CameraAnimation {
  final Duration duration;
  final AnimationType type;

  const CameraAnimation({
    this.duration = const Duration(milliseconds: 500),
    this.type = AnimationType.easeInOut,
  });
}

/// Camera animation type
enum AnimationType { linear, easeInOut, easeIn, easeOut }

/// Map gesture types
enum MapGesture { pan, zoom, rotate, pitch }

/// Legacy route styling options (deprecated - use RouteStyleConfig instead)
@Deprecated('Use RouteStyleConfig and RouteLineStyle instead')
class RouteStyle {
  final double width;
  final String color;
  final double opacity;

  const RouteStyle({
    this.width = 8.0,
    this.color = '#3366CC',
    this.opacity = 1.0,
  });
}
