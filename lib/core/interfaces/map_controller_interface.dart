import 'dart:async';
import 'dart:ui';
import '../models/route_model.dart';
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

  /// Draws multiple routes on the map with different colors
  Future<void> drawMultipleRoutes({
    required List<RouteModel> routes,
    List<Color>? colors,
    RouteStyleConfig? baseStyleConfig,
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

  /// Whether the map is currently following user location
  bool get isFollowingLocation;

  /// Sets the location following state (for gesture detection)
  void setFollowingLocation(bool follow);

  /// Updates the custom location puck position and heading
  Future<void> updateLocationPuck(LocationPoint location);

  /// Sets the location puck to idle state with car marker and background
  Future<void> setIdleLocationPuck();

  /// Sets the location puck to navigation state with navigation marker (no background)
  Future<void> setNavigationLocationPuck();

  /// Configures the location puck appearance
  Future<void> configureLocationPuck(LocationPuckConfig config);

  /// Sets the destination pin configuration
  Future<void> configureDestinationPin(DestinationPinConfig config);

  /// Shows destination pin at specified location
  Future<void> showDestinationPin(LocationPoint location);

  /// Hides the destination pin
  Future<void> hideDestinationPin();

  /// Zooms in the map by one level
  Future<double> zoomIn();

  /// Zooms out the map by one level
  Future<double> zoomOut();

  /// Gets the current zoom level
  Future<double> getCurrentZoom();
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
