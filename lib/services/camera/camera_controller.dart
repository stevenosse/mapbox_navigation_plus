import 'dart:async';
import 'dart:math' as math;
import '../../core/interfaces/map_controller_interface.dart';
import '../../core/models/location_point.dart';
import '../../core/models/route_progress.dart';
import '../../core/models/maneuver.dart';
import 'road_transition_effects.dart';

/// Waze-like camera controller that keeps user position fixed at screen center
/// while the environment moves dynamically around them
class CameraController {
  final MapControllerInterface _mapController;
  final RoadTransitionEffects _roadTransitionEffects;

  // Camera state
  LocationPoint? _currentLocation;
  LocationPoint? _previousLocation;
  double _currentSpeed = 0.0;
  double _currentHeading = 0.0;
  double _targetHeading = 0.0;

  // Animation state
  Timer? _smoothTurnTimer;
  Timer? _speedAdjustmentTimer;
  bool _isAnimatingTurn = false;

  // Heading smoothing
  double _headingVelocity = 0.0; // For predictive smoothing
  DateTime? _lastHeadingUpdate;

  // Turn prediction
  final List<double> _recentHeadings = [];
  static const int _headingHistorySize = 5;

  // Configuration constants
  static const double _minZoom = 16.0;
  static const double _maxZoom = 18.0;
  static const double _minPitch = 45.0;
  static const double _maxPitch = 75.0;
  static const double _lowSpeedThreshold = 5.0; // m/s (~18 km/h)
  static const double _highSpeedThreshold = 25.0; // m/s (~90 km/h)
  static const double _maxTurnRate = 180.0; // degrees per second
  static const double _headingTolerance = 2.0; // degrees

  // Standardized animation durations (milliseconds)
  static const int _quickAnimationDuration = 200; // Quick updates
  static const int _standardAnimationDuration = 400; // Standard transitions
  static const int _slowAnimationDuration = 800; // Slow transitions
  static const int _verySlowAnimationDuration = 1500; // Very slow transitions

  // Turn animation durations
  static const int _turnAnimationDuration = 500; // milliseconds
  static const int _fastTurnAnimationDuration = 300; // for quick corrections

  // Animation performance
  static const int _turnAnimationFps = 30; // Reduced from 60fps for better performance
  static const int _speedAnimationFps = 20; // 20fps for speed adjustments
  static const int _smoothUpdateDuration = 50; // Minimal animation for smooth updates

  CameraController(this._mapController)
    : _roadTransitionEffects = RoadTransitionEffects() {
    // Listen to road transition events for camera adjustments
    _roadTransitionEffects.transitionEvents.listen(_onRoadTransition);
  }

  /// Updates camera position with Waze-like behavior
  Future<void> updateCamera({
    required LocationPoint location,
    RouteProgress? routeProgress,
  }) async {
    _previousLocation = _currentLocation;
    _currentLocation = location;

    // Update road transition effects only during navigation
    if (routeProgress != null) {
      _roadTransitionEffects.updateRoadType(
        location: location,
        routeProgress: routeProgress,
      );
    }

    // Calculate current speed and heading
    _updateSpeedAndHeading(location);

    // Calculate optimal camera parameters based on speed and context
    final cameraParams = _calculateOptimalCameraParameters(
      location: location,
      routeProgress: routeProgress,
    );

    // Cancel any existing animations to prevent conflicts
    _cancelAllAnimations();

    // Apply smooth heading changes for turns
    await _applySmoothHeadingChange(cameraParams.bearing);

    // Apply speed-based zoom and pitch adjustments
    await _applySpeedBasedAdjustments(cameraParams);

    // Move camera with fixed user position (user stays at screen center)
    await _executeCameraMove(cameraParams);
  }

  /// Updates speed and heading from location data
  void _updateSpeedAndHeading(LocationPoint location) {
    // Use GPS speed if available, otherwise calculate from position changes
    if (location.speed != null && location.speed! > 0) {
      _currentSpeed = location.speed!;
    } else if (_previousLocation != null) {
      final distance = _previousLocation!.distanceTo(location);
      final timeDiff =
          location.timestamp
              .difference(_previousLocation!.timestamp)
              .inMilliseconds /
          1000.0;
      if (timeDiff > 0) {
        _currentSpeed = distance / timeDiff;
      }
    }

    // Enhanced heading calculation with prediction
    final now = DateTime.now();
    if (location.heading != null && _currentSpeed > 1.0) {
      _updateHeadingWithPrediction(location.heading!, now);
    } else if (_previousLocation != null && _currentSpeed > 1.0) {
      final calculatedHeading = _previousLocation!.bearingTo(location);
      _updateHeadingWithPrediction(calculatedHeading, now);
    }
  }

  /// Updates heading with velocity tracking and prediction for smoother turns
  void _updateHeadingWithPrediction(double newHeading, DateTime timestamp) {
    // Add to recent headings for trend analysis
    _recentHeadings.add(newHeading);
    if (_recentHeadings.length > _headingHistorySize) {
      _recentHeadings.removeAt(0);
    }

    // Calculate heading velocity for predictive smoothing
    if (_lastHeadingUpdate != null) {
      final timeDiff =
          timestamp.difference(_lastHeadingUpdate!).inMilliseconds / 1000.0;
      if (timeDiff > 0) {
        final headingDiff = _calculateHeadingDifference(
          _targetHeading,
          newHeading,
        );
        _headingVelocity = headingDiff / timeDiff;
      }
    }

    // Predict future heading based on current velocity and turn trend
    double predictedHeading = newHeading;
    if (_recentHeadings.length >= 3 && _headingVelocity.abs() > 10.0) {
      // Predict 0.5 seconds ahead for smoother anticipation
      final prediction = _headingVelocity * 0.5;
      predictedHeading = _normalizeHeading(newHeading + prediction);
    }

    _targetHeading = predictedHeading;
    _lastHeadingUpdate = timestamp;
  }

  /// Calculates optimal camera parameters based on speed and navigation context
  CameraParameters _calculateOptimalCameraParameters({
    required LocationPoint location,
    RouteProgress? routeProgress,
  }) {
    // Base parameters
    double zoom = _calculateSpeedBasedZoom();
    double pitch = _calculateSpeedBasedPitch();
    int animationDuration = _quickAnimationDuration; // Quick updates for smooth movement

    // During navigation, use navigation-specific logic
    if (routeProgress != null) {
      final maneuverAdjustments = _calculateManeuverAdjustments(routeProgress);

      // Apply maneuver-specific adjustments
      zoom = math.max(
        zoom + maneuverAdjustments.zoomAdjustment,
        maneuverAdjustments.minZoom,
      );
      pitch = math.min(
        pitch + maneuverAdjustments.pitchAdjustment,
        maneuverAdjustments.maxPitch,
      );

      // Slower animation for complex maneuvers
      if (maneuverAdjustments.isComplexManeuver) {
        animationDuration = _standardAnimationDuration;
      }
    } else {
      // Non-navigation state: use standard zoom and pitch
      zoom = 17.0;
      pitch = 45.0;
      animationDuration = _standardAnimationDuration;
    }

    return CameraParameters(
      zoom: zoom,
      pitch: pitch,
      bearing: _targetHeading,
      animationDuration: animationDuration,
    );
  }

  /// Calculates zoom level based on current speed with enhanced visibility logic
  double _calculateSpeedBasedZoom() {
    // Base zoom calculation
    double baseZoom;
    if (_currentSpeed <= _lowSpeedThreshold) {
      // High zoom for low speeds (parking, city driving)
      baseZoom = _maxZoom;
    } else if (_currentSpeed >= _highSpeedThreshold) {
      // Lower zoom for high speeds (highway driving)
      baseZoom = _minZoom;
    } else {
      // Smooth curve interpolation for more natural transitions
      final speedRatio =
          (_currentSpeed - _lowSpeedThreshold) /
          (_highSpeedThreshold - _lowSpeedThreshold);
      final easedRatio = _easeInOutCubic(speedRatio);
      baseZoom = _maxZoom - (easedRatio * (_maxZoom - _minZoom));
    }

    // Adjust zoom based on heading velocity (turning)
    if (_headingVelocity.abs() > 30.0) {
      // Zoom out slightly during turns for better context
      baseZoom = math.max(baseZoom - 1.0, _minZoom);
    }

    return baseZoom;
  }

  /// Calculates pitch (tilt) based on current speed with dynamic adjustments
  double _calculateSpeedBasedPitch() {
    // Base pitch calculation
    double basePitch;
    if (_currentSpeed <= _lowSpeedThreshold) {
      // Lower pitch for low speeds (better overview)
      basePitch = _minPitch;
    } else if (_currentSpeed >= _highSpeedThreshold) {
      // Higher pitch for high speeds (more immersive, forward-looking)
      basePitch = _maxPitch;
    } else {
      // Smooth curve interpolation for natural transitions
      final speedRatio =
          (_currentSpeed - _lowSpeedThreshold) /
          (_highSpeedThreshold - _lowSpeedThreshold);
      final easedRatio = _easeInOutCubic(speedRatio);
      basePitch = _minPitch + (easedRatio * (_maxPitch - _minPitch));
    }

    // Dynamic pitch adjustments based on movement patterns
    if (_headingVelocity.abs() > 45.0) {
      // Reduce pitch during sharp turns for better visibility
      basePitch = math.max(basePitch - 10.0, _minPitch);
    } else if (_currentSpeed > _highSpeedThreshold * 0.8 &&
        _headingVelocity.abs() < 5.0) {
      // Increase pitch for straight highway driving
      basePitch = math.min(basePitch + 5.0, _maxPitch);
    }

    return basePitch;
  }

  /// Calculates camera adjustments for upcoming maneuvers
  ManeuverAdjustments _calculateManeuverAdjustments(
    RouteProgress routeProgress,
  ) {
    final upcomingManeuver = routeProgress.upcomingManeuver;
    final distanceToManeuver = routeProgress.distanceToNextManeuver;

    if (upcomingManeuver == null) {
      return ManeuverAdjustments(
        minZoom: _minZoom,
        maxPitch: _maxPitch,
        isComplexManeuver: false,
        zoomAdjustment: 0.0,
        pitchAdjustment: 0.0,
      );
    }

    // Determine maneuver complexity
    final isComplexManeuver = _isComplexManeuver(upcomingManeuver);

    // Progressive adjustments based on distance to maneuver
    double zoomAdjustment = 0.0;
    double pitchAdjustment = 0.0;
    double minZoom = _minZoom;
    double maxPitch = _maxPitch;

    // Distance-based progressive adjustments
    if (distanceToManeuver < 500) {
      // Start adjusting 500m before maneuver
      final proximityFactor =
          1.0 - (distanceToManeuver / 500.0).clamp(0.0, 1.0);

      if (isComplexManeuver) {
        // Complex maneuvers: zoom out and reduce pitch for better overview
        zoomAdjustment = -1.5 * proximityFactor; // Gradually zoom out
        pitchAdjustment = -15.0 * proximityFactor; // Reduce pitch for overview
        minZoom = math.max(_minZoom, 16.5);
        maxPitch = math.min(_maxPitch, 55.0);

        // Extra adjustments for specific complex maneuvers
        if (upcomingManeuver.type == ManeuverType.roundabout ||
            upcomingManeuver.type == ManeuverType.roundaboutExit) {
          zoomAdjustment -= 0.5; // Extra zoom out for roundabouts
          pitchAdjustment -= 5.0; // Lower pitch for roundabout overview
        }
      } else {
        // Simple maneuvers: slight zoom in for better detail
        zoomAdjustment = 0.5 * proximityFactor;
        pitchAdjustment =
            5.0 * proximityFactor; // Slight pitch increase for focus
        minZoom = math.max(_minZoom, 17.0);
      }

      // Special handling for highway exits and merges
      if (upcomingManeuver.type == ManeuverType.offRamp ||
          upcomingManeuver.type == ManeuverType.onRamp ||
          upcomingManeuver.type == ManeuverType.merge) {
        zoomAdjustment = -1.0 * proximityFactor; // Zoom out for highway context
        pitchAdjustment =
            -10.0 * proximityFactor; // Lower pitch for lane visibility
      }
    }

    return ManeuverAdjustments(
      minZoom: minZoom,
      maxPitch: maxPitch,
      isComplexManeuver: isComplexManeuver,
      zoomAdjustment: zoomAdjustment,
      pitchAdjustment: pitchAdjustment,
    );
  }

  /// Determines if a maneuver is complex and needs special camera handling
  bool _isComplexManeuver(Maneuver maneuver) {
    switch (maneuver.type) {
      case ManeuverType.roundabout:
      case ManeuverType.roundaboutExit:
      case ManeuverType.merge:
      case ManeuverType.fork:
      case ManeuverType.onRamp:
      case ManeuverType.offRamp:
        return true;
      case ManeuverType.turn:
        // Sharp turns are complex
        return maneuver.modifier == ManeuverModifier.sharpLeft ||
            maneuver.modifier == ManeuverModifier.sharpRight ||
            maneuver.modifier == ManeuverModifier.uTurn;
      default:
        return false;
    }
  }

  /// Applies smooth heading changes for natural turn animations
  Future<void> _applySmoothHeadingChange(double targetBearing) async {
    if (_isAnimatingTurn) return;

    final headingDifference = _calculateHeadingDifference(
      _currentHeading,
      targetBearing,
    );

    // Only animate if the heading change is significant
    if (headingDifference.abs() > _headingTolerance) {
      _isAnimatingTurn = true;

      // Cancel any existing turn animation
      _smoothTurnTimer?.cancel();

      // Determine animation duration based on turn magnitude and speed
      final turnMagnitude = headingDifference.abs();
      final speedFactor = (_currentSpeed / _highSpeedThreshold).clamp(0.5, 2.0);

      int animationDuration;
      if (turnMagnitude > 90) {
        // Large turns need more time
        animationDuration = (_standardAnimationDuration / speedFactor).round();
      } else if (turnMagnitude < 15) {
        // Small corrections can be faster
        animationDuration = (_fastTurnAnimationDuration / speedFactor).round();
      } else {
        // Standard turns
        animationDuration = (_turnAnimationDuration / speedFactor).round();
      }

      // Limit turn rate for natural movement
      final maxChange = _maxTurnRate * (animationDuration / 1000.0);
      final clampedChange =
          headingDifference.sign * math.min(turnMagnitude, maxChange);
      final finalTarget = _normalizeHeading(_currentHeading + clampedChange);

      // Animate heading change over time
      final startHeading = _currentHeading;
      final totalChange = _calculateHeadingDifference(
        startHeading,
        finalTarget,
      );
      final startTime = DateTime.now();

      _smoothTurnTimer = Timer.periodic(
        Duration(milliseconds: (1000 / _turnAnimationFps).round()), // 30fps for better performance
        (timer) {
          final elapsed = DateTime.now().difference(startTime).inMilliseconds;
          final progress = (elapsed / animationDuration).clamp(0.0, 1.0);

          if (progress >= 1.0) {
            _currentHeading = finalTarget;
            timer.cancel();
            _isAnimatingTurn = false;

            // If there's still a significant difference, continue with remaining turn
            final remainingDiff = _calculateHeadingDifference(
              _currentHeading,
              targetBearing,
            );
            if (remainingDiff.abs() > _headingTolerance) {
              _applySmoothHeadingChange(targetBearing);
            }
          } else {
            // Use advanced easing for more natural movement
            final easedProgress = _easeInOutQuart(progress);
            _currentHeading = _normalizeHeading(
              startHeading + (totalChange * easedProgress),
            );
          }
        },
      );
    } else {
      _currentHeading = targetBearing;
    }
  }

  /// Applies speed-based camera adjustments with smooth transitions
  Future<void> _applySpeedBasedAdjustments(CameraParameters params) async {
    // Cancel any existing speed adjustment animation
    _speedAdjustmentTimer?.cancel();

    // Get current camera position for smooth transitions
    final currentCameraPosition = await _mapController.getCameraPosition();
    final currentZoom = currentCameraPosition.zoom;
    final currentPitch = currentCameraPosition.pitch;

    final zoomDifference = (params.zoom - currentZoom).abs();
    final pitchDifference = (params.pitch - currentPitch).abs();

    // Only animate if changes are significant
    if (zoomDifference > 0.5 || pitchDifference > 2.0) {
      final startTime = DateTime.now();
      const animationDuration = 1000; // 1 second for smooth speed adjustments

      _speedAdjustmentTimer = Timer.periodic(
        Duration(milliseconds: (1000 / _speedAnimationFps).round()), // 20fps for smooth updates
        (timer) {
          final elapsed = DateTime.now().difference(startTime).inMilliseconds;
          final progress = (elapsed / animationDuration).clamp(0.0, 1.0);

          if (progress >= 1.0) {
            timer.cancel();
          } else {
            final easedProgress = _easeInOutCubic(progress);
            final interpolatedZoom =
                currentZoom + ((params.zoom - currentZoom) * easedProgress);
            final interpolatedPitch =
                currentPitch + ((params.pitch - currentPitch) * easedProgress);

            // Apply the interpolated values with minimal animation for smoothness
            _executeSmoothCameraUpdate(
              zoom: interpolatedZoom,
              pitch: interpolatedPitch,
              bearing: params.bearing,
            );
          }
        },
      );
    }
  }

  /// Calculates the shortest angular difference between two headings
  double _calculateHeadingDifference(double from, double to) {
    double diff = to - from;

    // Normalize to [-180, 180]
    while (diff > 180) {
      diff -= 360;
    }
    while (diff < -180) {
      diff += 360;
    }

    return diff;
  }

  /// Normalizes heading to [0, 360) range
  double _normalizeHeading(double heading) {
    while (heading < 0) {
      heading += 360;
    }
    while (heading >= 360) {
      heading -= 360;
    }
    return heading;
  }

  /// Cubic easing function for smooth animations
  double _easeInOutCubic(double t) {
    return t < 0.5 ? 4 * t * t * t : 1 - math.pow(-2 * t + 2, 3) / 2;
  }

  /// Quartic easing function for more natural turn animations
  double _easeInOutQuart(double t) {
    return t < 0.5 ? 8 * t * t * t * t : 1 - math.pow(-2 * t + 2, 4) / 2;
  }

  /// Cancels all ongoing animations to prevent conflicts
  void _cancelAllAnimations() {
    _smoothTurnTimer?.cancel();
    _speedAdjustmentTimer?.cancel();
    _isAnimatingTurn = false;
  }

  /// Executes a camera move with coordinated animation
  Future<void> _executeCameraMove(CameraParameters params) async {
    if (_currentLocation == null) return;

    await _mapController.moveCamera(
      center: _currentLocation!,
      zoom: params.zoom,
      bearing: params.bearing,
      pitch: params.pitch,
      heading: params.bearing,
      animation: CameraAnimation(
        duration: Duration(milliseconds: params.animationDuration),
        type: AnimationType.linear,
      ),
    );
  }

  /// Executes smooth camera updates without conflicting with other animations
  Future<void> _executeSmoothCameraUpdate({
    required double zoom,
    required double pitch,
    required double bearing,
  }) async {
    if (_currentLocation == null) return;

    await _mapController.moveCamera(
      center: _currentLocation!,
      zoom: zoom,
      pitch: pitch,
      bearing: bearing,
      heading: bearing,
      animation: CameraAnimation(
        duration: Duration(milliseconds: _smoothUpdateDuration),
        type: AnimationType.linear,
      ),
    );
  }

  /// Disposes resources
  void dispose() {
    _cancelAllAnimations();
    _roadTransitionEffects.dispose();
  }

  /// Handles road transition events for camera adjustments
  void _onRoadTransition(RoadTransitionEvent event) {
    if (_currentLocation == null) return;

    // Calculate base camera parameters
    final baseZoom = _calculateSpeedBasedZoom();
    final basePitch = _calculateSpeedBasedPitch();

    // Apply camera adjustments based on road transition
    double zoomDelta = 0.0;
    double pitchDelta = 0.0;
    int durationMs = _standardAnimationDuration;

    switch (event.effect) {
      case TransitionEffect.highwayEntrance:
        // Zoom out and increase pitch for highway perspective
        zoomDelta = -1.0;
        pitchDelta = 5.0;
        durationMs = _verySlowAnimationDuration;
        break;
      case TransitionEffect.highwayExit:
        // Zoom in and decrease pitch for local roads
        zoomDelta = 1.0;
        pitchDelta = -5.0;
        durationMs = _verySlowAnimationDuration;
        break;
      case TransitionEffect.urbanToResidential:
        // Subtle zoom in for residential areas
        zoomDelta = 0.5;
        pitchDelta = -2.0;
        durationMs = _slowAnimationDuration;
        break;
      case TransitionEffect.residentialToUrban:
        // Zoom out for urban areas
        zoomDelta = -0.5;
        pitchDelta = 2.0;
        durationMs = _slowAnimationDuration;
        break;
      default:
        // Generic transition - minimal adjustment
        zoomDelta = 0.0;
        pitchDelta = 0.0;
        durationMs = _standardAnimationDuration;
    }

    // Calculate target camera parameters with transition adjustments
    final targetZoom = (baseZoom + zoomDelta).clamp(_minZoom, _maxZoom);
    final targetPitch = (basePitch + pitchDelta).clamp(_minPitch, _maxPitch);

    // Apply smooth transition
    _mapController.moveCamera(
      center: _currentLocation!,
      zoom: targetZoom,
      pitch: targetPitch,
      bearing: _currentHeading,
      heading: _currentHeading,
      animation: CameraAnimation(
        duration: Duration(milliseconds: durationMs),
        type: AnimationType.easeInOut,
      ),
    );
  }
}

/// Camera parameters for a specific update
class CameraParameters {
  final double zoom;
  final double pitch;
  final double bearing;
  final int animationDuration;

  const CameraParameters({
    required this.zoom,
    required this.pitch,
    required this.bearing,
    required this.animationDuration,
  });
}

/// Maneuver-specific camera adjustments
class ManeuverAdjustments {
  final double minZoom;
  final double maxPitch;
  final bool isComplexManeuver;
  final double zoomAdjustment;
  final double pitchAdjustment;

  const ManeuverAdjustments({
    required this.minZoom,
    required this.maxPitch,
    required this.isComplexManeuver,
    required this.zoomAdjustment,
    required this.pitchAdjustment,
  });
}
