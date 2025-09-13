import 'dart:async';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../models/route_data.dart';
import '../models/navigation_step.dart';
import '../utils/constants.dart' as nav_constants;

/// Controller for managing camera behavior during navigation
class CameraController {
  MapboxMap? _mapboxMap;

  // Current camera state
  double _currentZoom = nav_constants.NavigationConstants.defaultZoom;
  double _currentPitch = nav_constants.NavigationConstants.navigationPitch;
  double _currentBearing = nav_constants.NavigationConstants.defaultBearing;
  bool _isFollowingUser = true;
  bool _isNavigationMode = false;

  // Smooth camera tracking
  geo.Position? _lastCameraPosition;
  DateTime? _lastCameraUpdate;
  Timer? _smoothUpdateTimer;

  static const double _smoothingFactor =
      0.3; // Interpolation factor for smoother movement

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

    // For smooth real-time updates, use direct camera setting without animation
    // This prevents the jarring effect of multiple overlapping animations
    final shouldAnimateSmooth = _shouldUseSmoothAnimation(userPosition);

    if (_isNavigationMode && route != null) {
      await _updateNavigationCamera(
        userPosition: userPosition,
        userBearing: userBearing,
        route: route,
        animate: shouldAnimateSmooth,
      );
    } else {
      await _updateFollowCamera(
        userPosition: userPosition,
        userBearing: userBearing,
        animate: shouldAnimateSmooth,
      );
    }

    _lastCameraPosition = userPosition;
    _lastCameraUpdate = DateTime.now();
  }

  /// Updates camera to follow a specific navigation step
  Future<void> followStep(NavigationStep step) async {
    if (_mapboxMap == null) return;

    // Calculate bearing for the step
    final stepBearing = step.getBearing();

    // Update camera to look ahead in the direction of the step
    final cameraOptions = CameraOptions(
      center: Point(
          coordinates: Position(
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
      center: Point(
          coordinates: Position(
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
    // Validate position before using
    if (!_isValidPosition(userPosition)) {
      return; // Skip invalid positions
    }

    // Calculate bearing from route if available, otherwise use user bearing
    double targetBearing = userBearing ?? 0.0;

    if (route != null) {
      final routeBearing = _calculateRouteBearing(userPosition, route);
      if (routeBearing != null) {
        // Smooth bearing transitions to prevent sudden rotations
        targetBearing = _smoothBearing(_currentBearing, routeBearing);
      }
    }

    // Use actual user position for camera - no smoothing that could cause invalid positions
    // Only smooth if we're very close to the last position (within 20 meters)
    final useSmoothing = _lastCameraPosition != null &&
        geo.Geolocator.distanceBetween(
              _lastCameraPosition!.latitude,
              _lastCameraPosition!.longitude,
              userPosition.latitude,
              userPosition.longitude,
            ) <
            20.0;

    final cameraPosition =
        useSmoothing ? _smoothPosition(userPosition) : userPosition;

    _currentBearing = targetBearing;
    _currentPitch = nav_constants.NavigationConstants.navigationPitch;

    // Create camera options with validated position
    final cameraOptions = CameraOptions(
      center: Point(
          coordinates:
              Position(cameraPosition.longitude, cameraPosition.latitude)),
      zoom: _currentZoom,
      bearing: targetBearing,
      pitch: _currentPitch,
    );

    try {
      if (animate && useSmoothing) {
        // Only animate for small smooth movements
        await _mapboxMap!.flyTo(
            cameraOptions,
            MapAnimationOptions(
              duration: 100,
              startDelay: 0,
            ));
      } else {
        // Direct camera update for instant response or large movements
        await _mapboxMap!.setCamera(cameraOptions);
      }
    } catch (e) {
      // Fallback to basic camera update if flyTo fails
      try {
        // Use original position if smoothed position causes issues
        final fallbackOptions = CameraOptions(
          center: Point(
              coordinates:
                  Position(userPosition.longitude, userPosition.latitude)),
          zoom: _currentZoom,
          bearing: targetBearing,
          pitch: _currentPitch,
        );
        await _mapboxMap!.setCamera(fallbackOptions);
      } catch (fallbackError) {
        // Silently ignore camera update errors to prevent disruption
      }
    }
  }

  /// Updates camera for simple follow mode (top-down)
  Future<void> _updateFollowCamera({
    required geo.Position userPosition,
    double? userBearing,
    bool animate = true,
  }) async {
    // Validate position before using
    if (!_isValidPosition(userPosition)) {
      return; // Skip invalid positions
    }

    final targetBearing = userBearing != null
        ? _smoothBearing(_currentBearing, userBearing)
        : _currentBearing;

    // Use actual position for camera, only smooth for small movements
    final useSmoothing = _lastCameraPosition != null &&
        geo.Geolocator.distanceBetween(
              _lastCameraPosition!.latitude,
              _lastCameraPosition!.longitude,
              userPosition.latitude,
              userPosition.longitude,
            ) <
            20.0;

    final cameraPosition =
        useSmoothing ? _smoothPosition(userPosition) : userPosition;

    _currentBearing = targetBearing;
    _currentPitch = nav_constants.NavigationConstants.overviewPitch;

    final cameraOptions = CameraOptions(
      center: Point(
          coordinates:
              Position(cameraPosition.longitude, cameraPosition.latitude)),
      zoom: _currentZoom,
      bearing: targetBearing,
      pitch: _currentPitch,
    );

    try {
      if (animate && useSmoothing) {
        await _mapboxMap!.flyTo(
            cameraOptions,
            MapAnimationOptions(
              duration: 100,
              startDelay: 0,
            ));
      } else {
        await _mapboxMap!.setCamera(cameraOptions);
      }
    } catch (e) {
      // Fallback with original position
      try {
        final fallbackOptions = CameraOptions(
          center: Point(
              coordinates:
                  Position(userPosition.longitude, userPosition.latitude)),
          zoom: _currentZoom,
          bearing: targetBearing,
          pitch: _currentPitch,
        );
        await _mapboxMap!.setCamera(fallbackOptions);
      } catch (fallbackError) {
        // Silently ignore camera update errors
      }
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
              duration:
                  nav_constants.NavigationConstants.quickAnimationDuration,
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
              duration:
                  nav_constants.NavigationConstants.quickAnimationDuration,
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
        center: Point(
            coordinates: Position(
          userPosition.longitude,
          userPosition.latitude,
        )),
        anchor: ScreenCoordinate(x: 0, y: 0),
        zoom: 17,
        bearing: userBearing, // Use actual user bearing for rotation
        pitch: 60, // 3D tilt (0 is flat, 60 is looking ahead)
      ),
      MapAnimationOptions(duration: 2000, startDelay: 0),
    );

    // Update internal state
    _currentZoom = 17;
    _currentPitch = 60;
    _currentBearing = userBearing;
  }

  /// Determines if smooth animation should be used based on update frequency
  bool _shouldUseSmoothAnimation(geo.Position currentPosition) {
    if (_lastCameraUpdate == null || _lastCameraPosition == null) {
      return false; // First update, no animation
    }

    final timeSinceLastUpdate = DateTime.now().difference(_lastCameraUpdate!);
    final distance = geo.Geolocator.distanceBetween(
      _lastCameraPosition!.latitude,
      _lastCameraPosition!.longitude,
      currentPosition.latitude,
      currentPosition.longitude,
    );

    // Use animation only for small, frequent updates
    // This creates smooth movement without jarring jumps
    return timeSinceLastUpdate.inMilliseconds < 200 && distance < 50;
  }

  /// Smooths position updates for fluid camera movement
  geo.Position _smoothPosition(geo.Position targetPosition) {
    if (_lastCameraPosition == null) {
      return targetPosition;
    }

    // Validate that smoothing won't create invalid coordinates
    final distance = geo.Geolocator.distanceBetween(
      _lastCameraPosition!.latitude,
      _lastCameraPosition!.longitude,
      targetPosition.latitude,
      targetPosition.longitude,
    );

    // Don't smooth if distance is too large (likely a jump/teleport)
    if (distance > 50.0) {
      return targetPosition;
    }

    // Apply exponential smoothing for ultra-smooth movement
    final smoothedLat = _lastCameraPosition!.latitude +
        (targetPosition.latitude - _lastCameraPosition!.latitude) *
            _smoothingFactor;
    final smoothedLng = _lastCameraPosition!.longitude +
        (targetPosition.longitude - _lastCameraPosition!.longitude) *
            _smoothingFactor;

    // Validate smoothed coordinates
    if (smoothedLat.abs() > 90 || smoothedLng.abs() > 180) {
      return targetPosition; // Return original if smoothed is invalid
    }

    return geo.Position(
      latitude: smoothedLat,
      longitude: smoothedLng,
      timestamp: targetPosition.timestamp,
      accuracy: targetPosition.accuracy,
      altitude: targetPosition.altitude,
      altitudeAccuracy: targetPosition.altitudeAccuracy,
      heading: targetPosition.heading,
      headingAccuracy: targetPosition.headingAccuracy,
      speed: targetPosition.speed,
      speedAccuracy: targetPosition.speedAccuracy,
    );
  }

  /// Smooths bearing transitions to prevent sudden rotations
  double _smoothBearing(double currentBearing, double targetBearing) {
    // Handle bearing wrap-around (0-360 degrees)
    double diff = targetBearing - currentBearing;

    // Normalize difference to [-180, 180]
    if (diff > 180) {
      diff -= 360;
    } else if (diff < -180) {
      diff += 360;
    }

    // Apply smoothing with larger factor for smaller changes
    final smoothingFactor = diff.abs() < 30 ? 0.3 : 0.5;
    return currentBearing + diff * smoothingFactor;
  }

  /// Validates if a position is valid for camera use
  bool _isValidPosition(geo.Position position) {
    // Check latitude bounds (-90 to 90)
    if (position.latitude.abs() > 90) {
      return false;
    }

    // Check longitude bounds (-180 to 180)
    if (position.longitude.abs() > 180) {
      return false;
    }

    // Check for NaN or infinite values
    if (position.latitude.isNaN ||
        position.latitude.isInfinite ||
        position.longitude.isNaN ||
        position.longitude.isInfinite) {
      return false;
    }

    // Check if position is (0, 0) which is often a default/error value
    if (position.latitude == 0 && position.longitude == 0) {
      // Unless we're actually near the equator/prime meridian
      if (_lastCameraPosition != null) {
        final distance = geo.Geolocator.distanceBetween(
          _lastCameraPosition!.latitude,
          _lastCameraPosition!.longitude,
          0,
          0,
        );
        // If we're more than 1000km from (0,0) and suddenly at (0,0), it's likely an error
        if (distance > 1000000) {
          return false;
        }
      }
    }

    return true;
  }

  /// Reset camera to default state
  void reset() {
    _smoothUpdateTimer?.cancel();
    _smoothUpdateTimer = null;
    _lastCameraPosition = null;
    _lastCameraUpdate = null;
    _currentZoom = nav_constants.NavigationConstants.defaultZoom;
    _currentPitch = nav_constants.NavigationConstants.defaultPitch;
    _currentBearing = nav_constants.NavigationConstants.defaultBearing;
    _isFollowingUser = true;
    _isNavigationMode = false;
  }

  /// Dispose resources
  void dispose() {
    _smoothUpdateTimer?.cancel();
    _smoothUpdateTimer = null;
    _mapboxMap = null;
  }
}
