import 'dart:async';

import '../../core/interfaces/route_progress_tracker.dart';
import '../../core/models/route_model.dart';
import '../../core/models/route_progress.dart';
import '../../core/models/location_point.dart';
import '../../core/models/maneuver.dart';

/// Real implementation of RouteProgressTracker
class DefaultRouteProgressTracker implements RouteProgressTracker {
  final StreamController<RouteProgress> _progressController =
      StreamController<RouteProgress>.broadcast();
  final StreamController<Maneuver> _maneuverController =
      StreamController<Maneuver>.broadcast();
  final StreamController<RouteDeviation> _deviationController =
      StreamController<RouteDeviation>.broadcast();
  final StreamController<void> _arrivalController =
      StreamController<void>.broadcast();

  RouteModel? _currentRoute;
  StreamSubscription<LocationPoint>? _locationSubscription;
  Timer? _progressTimer;

  RouteProgress? _currentProgress;
  RouteProgress? _lastEmittedProgress;
  bool _isTracking = false;
  DateTime? _startTime;
  DateTime? _lastManeuverNotificationTime;
  LocationPoint? _lastLocation;
  bool _hasArrived = false;

  double _deviationThreshold = 30.0;
  double _maneuverNotificationThreshold = 200.0;

  @override
  Future<void> startTracking({
    required RouteModel route,
    required Stream<LocationPoint> locationStream,
  }) async {
    if (_isTracking) {
      await stopTracking();
    }

    _currentRoute = route;
    _startTime = DateTime.now();
    _isTracking = true;
    _hasArrived = false;
    _lastManeuverNotificationTime = null;

    // Start listening to location updates
    _locationSubscription = locationStream.listen(
      _onLocationUpdate,
      onError: (error) {
        _progressController.addError(error);
      },
    );

    // Start periodic progress updates (every 2 seconds, only if significant changes)
    _progressTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_currentProgress != null && _shouldEmitProgress()) {
        _lastEmittedProgress = _currentProgress;
        _progressController.add(_currentProgress!);
      }
    });
  }

  @override
  Future<void> stopTracking() async {
    _isTracking = false;

    await _locationSubscription?.cancel();
    _locationSubscription = null;

    _progressTimer?.cancel();
    _progressTimer = null;

    _currentRoute = null;
    _currentProgress = null;
    _lastEmittedProgress = null;
    _startTime = null;
    _lastManeuverNotificationTime = null;
    _lastLocation = null;
    _hasArrived = false;
  }

  @override
  Stream<RouteProgress> get progressStream => _progressController.stream;

  @override
  Stream<Maneuver> get upcomingManeuverStream => _maneuverController.stream;

  @override
  Stream<RouteDeviation> get deviationStream => _deviationController.stream;

  @override
  Stream<void> get arrivalStream => _arrivalController.stream;

  @override
  RouteProgress? get currentProgress => _currentProgress;

  @override
  bool get isTracking => _isTracking;

  @override
  double get deviationThreshold => _deviationThreshold;

  @override
  set deviationThreshold(double threshold) {
    _deviationThreshold = threshold;
  }

  @override
  double get maneuverNotificationThreshold => _maneuverNotificationThreshold;

  @override
  set maneuverNotificationThreshold(double threshold) {
    _maneuverNotificationThreshold = threshold;
  }

  void _onLocationUpdate(LocationPoint location) {
    if (!_isTracking || _currentRoute == null || _startTime == null) return;

    // Calculate route progress
    _currentProgress = RouteProgress.fromLocationAndRoute(
      currentLocation: location,
      route: _currentRoute!,
      startTime: _startTime!,
    );

    // Check for route deviation
    _checkRouteDeviation(location);

    // Check for upcoming maneuvers
    _checkUpcomingManeuvers();

    // Check for arrival
    _checkArrival();

    if (_lastLocation == null ||
        _hasSignificantLocationChange(location) ||
        _lastEmittedProgress == null) {
      _lastEmittedProgress = _currentProgress;
      _progressController.add(_currentProgress!);
    }

    _lastLocation = location;
  }

  void _checkRouteDeviation(LocationPoint location) {
    if (_currentProgress == null) return;

    final isOnRoute = _currentProgress!.isOnRoute;
    final distanceFromRoute = _currentProgress!.distanceFromRoute;

    if (!isOnRoute && distanceFromRoute > _deviationThreshold) {
      final deviation = RouteDeviation(
        currentLocation: location,
        distanceFromRoute: distanceFromRoute,
        timestamp: DateTime.now(),
      );
      _deviationController.add(deviation);
    }
  }

  void _checkUpcomingManeuvers() {
    if (_currentProgress == null || _currentRoute == null) return;

    final upcomingManeuver = _currentProgress!.upcomingManeuver;
    if (upcomingManeuver == null) return;

    final distanceToManeuver = _currentProgress!.distanceToNextManeuver;
    final now = DateTime.now();

    // Check if we should notify about upcoming maneuver
    bool shouldNotify = false;

    if (_lastManeuverNotificationTime == null) {
      // First notification
      shouldNotify = distanceToManeuver <= _maneuverNotificationThreshold;
    } else {
      final timeSinceLastNotification = now.difference(
        _lastManeuverNotificationTime!,
      );

      // Notify if we're getting close to maneuver or if enough time has passed
      if (distanceToManeuver <= _maneuverNotificationThreshold &&
          timeSinceLastNotification.inSeconds > 30) {
        shouldNotify = true;
      }
      // Urgent notification when very close
      else if (distanceToManeuver <= 50.0 &&
          timeSinceLastNotification.inSeconds > 10) {
        shouldNotify = true;
      }
    }

    if (shouldNotify) {
      _maneuverController.add(upcomingManeuver);
      _lastManeuverNotificationTime = now;
    }
  }

  void _checkArrival() {
    if (_currentProgress == null || _hasArrived) return;

    final distanceRemaining = _currentProgress!.distanceRemaining;
    final currentLocation = _currentProgress!.currentLocation;
    final isOnRoute = _currentProgress!.isOnRoute;
    final distanceFromRoute = _currentProgress!.distanceFromRoute;

    // CRITICAL: Only check for arrival if user is on route or very close to route
    // This prevents false arrivals when off-route but near destination
    if (!isOnRoute && distanceFromRoute > 25.0) {
      return;
    }

    // Primary arrival condition: within 15 meters of destination
    if (distanceRemaining <= 15.0) {
      bool shouldTriggerArrival = false;

      // Additional validation: check direct distance to destination
      final directDistanceToDestination = currentLocation.distanceTo(
        _currentRoute!.destination,
      );

      // Only proceed if we're actually close to the destination point
      if (directDistanceToDestination > 30.0) {
        return;
      }

      // Check if user is moving slowly (less than 2 m/s) to confirm arrival
      if (_lastLocation != null) {
        final timeDiff = currentLocation.timestamp
            .difference(_lastLocation!.timestamp)
            .inSeconds;

        if (timeDiff > 0) {
          final distance = currentLocation.distanceTo(_lastLocation!);
          final speed = distance / timeDiff;

          // Trigger arrival if:
          // 1. Very close to destination (≤ 8 meters) regardless of speed
          // 2. Within 15 meters AND moving slowly (< 2 m/s)
          // 3. Within 15 meters AND stationary for multiple readings
          if (distanceRemaining <= 8.0 && directDistanceToDestination <= 15.0) {
            shouldTriggerArrival = true;
          } else if (speed < 2.0 && directDistanceToDestination <= 20.0) {
            shouldTriggerArrival = true;
          }
        } else {
          // No time difference means stationary - trigger if close enough
          shouldTriggerArrival =
              distanceRemaining <= 12.0 && directDistanceToDestination <= 18.0;
        }
      } else {
        // First location reading - trigger if very close
        shouldTriggerArrival =
            distanceRemaining <= 10.0 && directDistanceToDestination <= 15.0;
      }

      if (shouldTriggerArrival) {
        _hasArrived = true;
        _arrivalController.add(null);
      }
    }
  }

  /// Checks if there's significant location change to emit progress
  bool _hasSignificantLocationChange(LocationPoint currentLocation) {
    if (_lastLocation == null) return true;

    // Check if location changed significantly (more than 10 meters)
    final distance = currentLocation.distanceTo(_lastLocation!);
    if (distance > 10.0) return true;

    // Check if progress ratio changed significantly (more than 1%)
    if (_currentProgress != null && _lastEmittedProgress != null) {
      final progressDiff =
          (_currentProgress!.routeProgress -
                  _lastEmittedProgress!.routeProgress)
              .abs();
      if (progressDiff > 0.01) return true;
    }

    return false;
  }

  /// Checks if progress should be emitted during periodic timer
  bool _shouldEmitProgress() {
    if (_currentProgress == null || _lastEmittedProgress == null) return true;

    // Only emit if progress ratio changed significantly
    final progressDiff =
        (_currentProgress!.routeProgress - _lastEmittedProgress!.routeProgress)
            .abs();
    return progressDiff > 0.005; // 0.5% change threshold
  }

  void dispose() {
    stopTracking();
    _progressController.close();
    _maneuverController.close();
    _deviationController.close();
    _arrivalController.close();
  }
}
