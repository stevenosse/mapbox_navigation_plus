import 'dart:math' as math;
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../models/route_data.dart';
import '../models/navigation_step.dart';
import '../utils/constants.dart' as nav_constants;

/// Controller for managing camera behavior during navigation
class CameraController {
  MapboxMap? _mapboxMap;

  // Using shared constants from NavigationConstants

  // Current camera state
  double _currentZoom = nav_constants.NavigationConstants.defaultZoom;
  double _currentPitch = nav_constants.NavigationConstants.navigationPitch;
  double _currentBearing = nav_constants.NavigationConstants.defaultBearing;
  bool _isFollowingUser = true;
  bool _isNavigationMode = false;

  /// Initialize the controller with a MapboxMap instance
  void initialize(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
  }

  /// Current zoom level
  double get currentZoom => _currentZoom;

  /// Current pitch angle
  double get currentPitch => _currentPitch;

  /// Current bearing
  double get currentBearing => _currentBearing;

  /// Whether camera is following user
  bool get isFollowingUser => _isFollowingUser;

  /// Whether in navigation mode (3D view)
  bool get isNavigationMode => _isNavigationMode;

  /// Updates camera position based on user location and navigation state
  Future<void> updateCamera({
    required geo.Position userPosition,
    double? userBearing,
    RouteData? route,
    bool animate = true,
  }) async {
    if (_mapboxMap == null || !_isFollowingUser) return;


    if (_isNavigationMode && route != null) {
      await _updateNavigationCamera(
        userPosition: userPosition,
        userBearing: userBearing,
        route: route,
        animate: animate,
      );
    } else {
      await _updateFollowCamera(
        userPosition: userPosition,
        userBearing: userBearing,
        animate: animate,
      );
    }
  }

  /// Updates camera to follow a specific navigation step
  Future<void> followStep(NavigationStep step) async {
    if (_mapboxMap == null) return;
    
    // Calculate bearing for the step
    final stepBearing = step.getBearing();
    
    // Update camera to look ahead in the direction of the step
    final cameraOptions = CameraOptions(
      center: Point(coordinates: Position(
        step.startLocation.longitude,
        step.startLocation.latitude,
      )),
      zoom: _currentZoom,
      bearing: stepBearing,
      pitch: _currentPitch,
    );
    
    await _mapboxMap!.flyTo(cameraOptions, MapAnimationOptions(duration: 1500));
  }
  
  /// Updates camera position smoothly for navigation
  Future<void> updatePosition(geo.Position position) async {
    if (_mapboxMap == null) return;
    
    final cameraOptions = CameraOptions(
      center: Point(coordinates: Position(
        position.longitude,
        position.latitude,
      )),
      zoom: _currentZoom,
      bearing: position.heading >= 0 ? position.heading : _currentBearing,
      pitch: _currentPitch,
    );
    
    await _mapboxMap!.setCamera(cameraOptions);
  }

  /// Updates camera for navigation mode (FPS-style behind the user)
  Future<void> _updateNavigationCamera({
    required geo.Position userPosition,
    double? userBearing,
    RouteData? route,
    bool animate = true,
  }) async {
    // Calculate bearing from route if available, otherwise use user bearing
    double targetBearing = userBearing ?? 0.0;

    if (route != null) {
      final routeBearing = _calculateRouteBearing(userPosition, route);
      if (routeBearing != null) {
        targetBearing = routeBearing;
      }
    }

    _currentBearing = targetBearing;
    _currentPitch = nav_constants.NavigationConstants.navigationPitch;

    // Create camera options
    final cameraOptions = CameraOptions(
      center: Point(coordinates: Position(userPosition.longitude, userPosition.latitude)),
      zoom: _currentZoom,
      bearing: targetBearing,
      pitch: _currentPitch,
    );

    try {
      if (animate) {
        await _mapboxMap!.flyTo(
            cameraOptions,
            MapAnimationOptions(
              duration: nav_constants.NavigationConstants.animationDuration,
            ));
      } else {
        await _mapboxMap!.setCamera(cameraOptions);
      }
    } catch (e) {
      // Fallback to basic camera update if flyTo fails
      await _mapboxMap!.setCamera(cameraOptions);
    }
  }

  /// Updates camera for simple follow mode (top-down)
  Future<void> _updateFollowCamera({
    required geo.Position userPosition,
    double? userBearing,
    bool animate = true,
  }) async {
    final targetBearing = userBearing ?? 0.0;

    _currentBearing = targetBearing;
    _currentPitch = nav_constants.NavigationConstants.overviewPitch;

    final cameraOptions = CameraOptions(
      center: Point(coordinates: Position(userPosition.longitude, userPosition.latitude)),
      zoom: _currentZoom,
      bearing: targetBearing,
      pitch: _currentPitch,
    );

    try {
      if (animate) {
        await _mapboxMap!.flyTo(
            cameraOptions,
            MapAnimationOptions(
              duration: nav_constants.NavigationConstants.quickAnimationDuration,
            ));
      } else {
        await _mapboxMap!.setCamera(cameraOptions);
      }
    } catch (e) {
      // Fallback to basic camera update if flyTo fails
      await _mapboxMap!.setCamera(cameraOptions);
    }
  }

  /// Calculate bearing from route geometry
  double? _calculateRouteBearing(geo.Position userPosition, RouteData route) {
    final currentStep = route.currentStep;
    if (currentStep == null || currentStep.geometry.isEmpty) return null;

    // Find closest point on route
    int closestIndex = 0;
    double minDistance = double.infinity;

    for (int i = 0; i < currentStep.geometry.length; i++) {
      final distance = geo.Geolocator.distanceBetween(
        userPosition.latitude,
        userPosition.longitude,
        currentStep.geometry[i].latitude,
        currentStep.geometry[i].longitude,
      );

      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
      }
    }

    // Look ahead for bearing calculation
    final lookAheadIndex = math.min(
      closestIndex + 3,
      currentStep.geometry.length - 1,
    );

    if (lookAheadIndex > closestIndex) {
      return geo.Geolocator.bearingBetween(
        currentStep.geometry[closestIndex].latitude,
        currentStep.geometry[closestIndex].longitude,
        currentStep.geometry[lookAheadIndex].latitude,
        currentStep.geometry[lookAheadIndex].longitude,
      );
    }

    // Fallback to step end bearing
    return geo.Geolocator.bearingBetween(
      userPosition.latitude,
      userPosition.longitude,
      currentStep.geometry.last.latitude,
      currentStep.geometry.last.longitude,
    );
  }

  /// Enable navigation mode (3D camera)
  void enableNavigationMode() {
    _isNavigationMode = true;
    _isFollowingUser = true;
  }

  /// Disable navigation mode (return to follow mode)
  void disableNavigationMode() {
    _isNavigationMode = false;
  }

  /// Enable user following
  void enableFollowUser() {
    _isFollowingUser = true;
  }

  /// Disable user following
  void disableFollowUser() {
    _isFollowingUser = false;
  }

  /// Sets zoom level
  Future<void> setZoom(double zoom, {bool animate = true}) async {
    if (_mapboxMap == null) return;

    _currentZoom = zoom.clamp(1.0, 22.0);

    final cameraOptions = CameraOptions(zoom: _currentZoom);

    try {
      if (animate) {
        await _mapboxMap!.flyTo(
            cameraOptions,
            MapAnimationOptions(
              duration: nav_constants.NavigationConstants.quickAnimationDuration,
            ));
      } else {
        await _mapboxMap!.setCamera(cameraOptions);
      }
    } catch (e) {
      // Ignore camera update errors
    }
  }

  /// Sets pitch angle
  Future<void> setPitch(double pitch, {bool animate = true}) async {
    if (_mapboxMap == null) return;

    _currentPitch = pitch.clamp(0.0, 60.0);

    final cameraOptions = CameraOptions(pitch: _currentPitch);

    try {
      if (animate) {
        await _mapboxMap!.flyTo(
            cameraOptions,
            MapAnimationOptions(
              duration: nav_constants.NavigationConstants.quickAnimationDuration,
            ));
      } else {
        await _mapboxMap!.setCamera(cameraOptions);
      }
    } catch (e) {
      // Ignore camera update errors
    }
  }

  /// Fit camera to show entire route
  Future<void> fitToRoute(RouteData route, {bool animate = true}) async {
    if (_mapboxMap == null || route.geometry.isEmpty) return;

    // Calculate center point and appropriate zoom level
    double centerLat = 0;
    double centerLng = 0;

    for (final point in route.geometry) {
      centerLat += point.latitude;
      centerLng += point.longitude;
    }

    centerLat /= route.geometry.length;
    centerLng /= route.geometry.length;

    // Calculate rough zoom level based on route bounds
    double minLat = route.geometry.first.latitude;
    double maxLat = route.geometry.first.latitude;
    double minLng = route.geometry.first.longitude;
    double maxLng = route.geometry.first.longitude;

    for (final point in route.geometry) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    // Simple zoom calculation based on coordinate span
    final latSpan = maxLat - minLat;
    final lngSpan = maxLng - minLng;
    final maxSpan = math.max(latSpan, lngSpan);

    double zoom = 10.0;
    if (maxSpan < 0.01) {
      zoom = 15.0;
    } else if (maxSpan < 0.05) {
      zoom = 13.0;
    } else if (maxSpan < 0.1) {
      zoom = 11.0;
    } else if (maxSpan < 0.5) {
      zoom = 9.0;
    }

    // Disable follow mode temporarily
    _isFollowingUser = false;
    _isNavigationMode = false;

    final cameraOptions = CameraOptions(
      center: Point(coordinates: Position(centerLng, centerLat)),
      zoom: zoom,
      bearing: 0.0,
      pitch: 0.0,
    );

    try {
      if (animate) {
        await _mapboxMap!.flyTo(
            cameraOptions,
            MapAnimationOptions(
              duration: nav_constants.NavigationConstants.animationDuration,
            ));
      } else {
        await _mapboxMap!.setCamera(cameraOptions);
      }
    } catch (e) {
      // Ignore camera update errors
    }
  }

  /// Updates camera with 3D viewing settings for enhanced navigation visibility
  Future<void> updateCameraWith3D({
    required geo.Position userPosition,
    required double userBearing,
    RouteData? route,
  }) async {
    if (_mapboxMap == null) return;

    // Enable navigation mode for 3D viewing
    _isNavigationMode = true;
    _isFollowingUser = true;
    
    // Apply 3D camera settings as specified
    await _mapboxMap!.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(
          userPosition.longitude,
          userPosition.latitude,
        )),
        anchor: ScreenCoordinate(x: 0, y: 0),
        zoom: 17,
        bearing: userBearing, // Use actual user bearing for rotation
        pitch: 60,    // 3D tilt (0 is flat, 60 is looking ahead)
      ),
      MapAnimationOptions(duration: 2000, startDelay: 0),
    );
    
    // Update internal state
    _currentZoom = 17;
    _currentPitch = 60;
    _currentBearing = userBearing;
  }

  /// Reset camera to default state
  void reset() {
    _currentZoom = nav_constants.NavigationConstants.defaultZoom;
    _currentPitch = nav_constants.NavigationConstants.defaultPitch;
    _currentBearing = nav_constants.NavigationConstants.defaultBearing;
    _isFollowingUser = true;
    _isNavigationMode = false;
  }

  /// Dispose resources
  void dispose() {
    _mapboxMap = null;
  }
}