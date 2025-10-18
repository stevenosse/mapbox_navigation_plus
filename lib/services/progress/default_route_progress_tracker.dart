import 'dart:async';

import '../../core/interfaces/route_progress_tracker.dart';
import '../../core/models/route_model.dart';
import '../../core/models/route_progress.dart';
import '../../core/models/location_point.dart';
import '../../core/models/maneuver.dart';

/// Road type classification for adaptive timing
enum NavigationRoadType {
  highway,
  suburban,
  urban,
}

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
  Maneuver? _lastAnnouncedManeuver;

  double _deviationThreshold = 30.0;
  double _maneuverNotificationThreshold = 250.0;

  // Speed-based timing configuration
  double _currentSpeed = 0.0; // m/s
  DateTime? _lastSpeedCalculationTime;
  static const double _citySpeedThreshold = 15.6; // ~35 mph in m/s
  static const double _highwaySpeedThreshold = 24.6; // ~55 mph in m/s

  // Adaptive timing buffers (in seconds)
  static const double _cityWarningTime = 10.0; // 10 seconds for city driving
  static const double _highwayWarningTime = 25.0; // 25 seconds for highway driving
  static const double _minAnnouncementDistance = 30.0; // Minimum 30m
  static const double _maxAnnouncementDistance = 600.0; // Maximum 600m

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
    _lastAnnouncedManeuver = null;

    _locationSubscription = locationStream.listen(
      _onLocationUpdate,
      onError: (error) {
        _progressController.addError(error);
      },
    );

    _progressTimer = Timer.periodic(const Duration(seconds: 5), (_) {
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
    _lastAnnouncedManeuver = null;
    _currentSpeed = 0.0;
    _lastSpeedCalculationTime = null;
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

    // Update speed calculation first
    _updateCurrentSpeed(location);

    _currentProgress = RouteProgress.fromLocationAndRoute(
      currentLocation: location,
      route: _currentRoute!,
      startTime: _startTime!,
    );

    _checkRouteDeviation(location);

    _checkUpcomingManeuvers();

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

    // Check if this is the same maneuver as the last announced one
    bool isSameManeuver = _lastAnnouncedManeuver != null &&
        _lastAnnouncedManeuver!.stepIndex == upcomingManeuver.stepIndex &&
        _lastAnnouncedManeuver!.legIndex == upcomingManeuver.legIndex &&
        _lastAnnouncedManeuver!.type == upcomingManeuver.type &&
        _lastAnnouncedManeuver!.modifier == upcomingManeuver.modifier;

    // Calculate adaptive announcement distance based on current conditions
    final adaptiveDistance = _calculateAdaptiveAnnouncementDistance(upcomingManeuver);

    // Check if we should notify about upcoming maneuver
    bool shouldNotify = false;

    if (_lastManeuverNotificationTime == null) {
      // First notification - announce when within adaptive distance
      shouldNotify = distanceToManeuver <= adaptiveDistance;
    } else {
      final timeSinceLastNotification = now.difference(
        _lastManeuverNotificationTime!,
      );

      // Don't notify if it's the same maneuver and we've already announced it recently
      if (isSameManeuver && timeSinceLastNotification.inSeconds < 30) {
        return;
      }

      // Use different thresholds based on road type and speed
      final roadType = _getRoadType();
      double reminderDistance;
      double urgentDistance;
      double cooldownPeriod;

      switch (roadType) {
        case NavigationRoadType.highway:
          reminderDistance = 100.0; // Highway reminder distance
          urgentDistance = 50.0;   // Highway urgent distance
          cooldownPeriod = 20.0;   // Longer cooldown for highway
          break;
        case NavigationRoadType.urban:
          reminderDistance = 30.0;  // Urban reminder distance
          urgentDistance = 15.0;    // Urban urgent distance
          cooldownPeriod = 10.0;    // Shorter cooldown for city
          break;
        case NavigationRoadType.suburban:
          reminderDistance = 60.0;  // Suburban reminder distance
          urgentDistance = 30.0;    // Suburban urgent distance
          cooldownPeriod = 15.0;    // Medium cooldown for suburban
          break;
      }

      // Main announcement when within adaptive distance and past cooldown
      if (distanceToManeuver <= adaptiveDistance &&
          timeSinceLastNotification.inSeconds > cooldownPeriod) {
        shouldNotify = true;
      }
      // Reminder announcement when getting closer (but not for same maneuver recently)
      else if (distanceToManeuver <= reminderDistance &&
          timeSinceLastNotification.inSeconds > cooldownPeriod / 2 &&
          !isSameManeuver) {
        shouldNotify = true;
      }
      // Urgent announcement when very close to maneuver point
      else if (distanceToManeuver <= urgentDistance &&
          timeSinceLastNotification.inSeconds > 5.0 &&
          !isSameManeuver) {
        shouldNotify = true;
      }
      // Final reminder for same maneuver if significant time has passed
      else if (distanceToManeuver <= urgentDistance && isSameManeuver &&
          timeSinceLastNotification.inSeconds > 25.0) {
        shouldNotify = true;
      }
    }

    if (shouldNotify) {
      _maneuverController.add(upcomingManeuver);
      _lastManeuverNotificationTime = now;
      _lastAnnouncedManeuver = upcomingManeuver;
    }
  }

  /// Determines if a maneuver is complex and needs earlier announcement
  bool _isComplexManeuver(Maneuver maneuver) {
    final roadType = _getRoadType();

    // All highway maneuvers are inherently more complex due to high speeds
    if (roadType == NavigationRoadType.highway) {
      switch (maneuver.type) {
        case ManeuverType.offRamp:
        case ManeuverType.fork:
        case ManeuverType.roundabout:
        case ManeuverType.exitRotary:
        case ManeuverType.exitRoundabout:
        case ManeuverType.merge:
          return true;
        case ManeuverType.turn:
          return maneuver.modifier == ManeuverModifier.uTurn ||
                 maneuver.modifier == ManeuverModifier.sharpLeft ||
                 maneuver.modifier == ManeuverModifier.sharpRight;
        default:
          return false;
      }
    }

    // Urban maneuvers - different complexity criteria
    switch (maneuver.type) {
      case ManeuverType.roundabout:
      case ManeuverType.exitRotary:
      case ManeuverType.exitRoundabout:
        return true; // Roundabouts are complex in any environment
      case ManeuverType.offRamp:
      case ManeuverType.fork:
        return roadType == NavigationRoadType.suburban; // Only complex in suburban areas
      case ManeuverType.turn:
      case ManeuverType.merge:
        return maneuver.modifier == ManeuverModifier.uTurn ||
               maneuver.modifier == ManeuverModifier.sharpLeft ||
               maneuver.modifier == ManeuverModifier.sharpRight;
      default:
        return false;
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

  /// Updates current speed calculation based on location updates
  void _updateCurrentSpeed(LocationPoint currentLocation) {
    if (_lastLocation == null || _lastSpeedCalculationTime == null) {
      _currentSpeed = 0.0;
      _lastSpeedCalculationTime = currentLocation.timestamp;
      return;
    }

    final timeDiff = currentLocation.timestamp
        .difference(_lastSpeedCalculationTime!)
        .inSeconds;

    if (timeDiff <= 0) {
      // Avoid division by zero or negative time
      return;
    }

    // Calculate speed over a longer window for stability
    final distance = currentLocation.distanceTo(_lastLocation!);
    final instantSpeed = distance / timeDiff;

    // Apply smoothing to prevent rapid speed fluctuations
    if (_currentSpeed == 0.0) {
      _currentSpeed = instantSpeed;
    } else {
      // Weighted average (70% previous, 30% new)
      _currentSpeed = (_currentSpeed * 0.7) + (instantSpeed * 0.3);
    }

    // Reset calculation window every 5 seconds for fresh readings
    if (timeDiff > 5) {
      _lastSpeedCalculationTime = currentLocation.timestamp;
    }
  }

  /// Determines road type based on current speed and route characteristics
  NavigationRoadType _getRoadType() {
    // Primary classification by speed
    if (_currentSpeed >= _highwaySpeedThreshold) {
      return NavigationRoadType.highway;
    } else if (_currentSpeed <= _citySpeedThreshold) {
      return NavigationRoadType.urban;
    }

    // For intermediate speeds, check current road characteristics
    if (_currentProgress != null && _currentProgress!.currentRoadName.isNotEmpty) {
      final roadName = _currentProgress!.currentRoadName.toLowerCase();

      // Highway indicators
      if (roadName.contains('highway') ||
          roadName.contains('freeway') ||
          roadName.contains('interstate') ||
          roadName.contains('i-') ||
          roadName.contains('us ') ||
          roadName.contains('route ') ||
          roadName.contains('exit')) {
        return NavigationRoadType.highway;
      }

      // Urban indicators
      if (roadName.contains('street') ||
          roadName.contains('st ') ||
          roadName.contains('avenue') ||
          roadName.contains('rd ') ||
          roadName.contains('boulevard') ||
          roadName.contains('dr ')) {
        return NavigationRoadType.urban;
      }
    }

    // Default to suburban for intermediate speeds without clear indicators
    return NavigationRoadType.suburban;
  }

  /// Calculates adaptive announcement distance based on speed and road type
  double _calculateAdaptiveAnnouncementDistance(Maneuver maneuver) {
    final roadType = _getRoadType();
    double baseTime;

    // Select appropriate warning time based on road type
    switch (roadType) {
      case NavigationRoadType.highway:
        baseTime = _highwayWarningTime;
        break;
      case NavigationRoadType.urban:
        baseTime = _cityWarningTime;
        break;
      case NavigationRoadType.suburban:
        baseTime = (_cityWarningTime + _highwayWarningTime) / 2; // Average
        break;
    }

    // Add extra time for complex maneuvers
    if (_isComplexManeuver(maneuver)) {
      baseTime += 5.0; // Extra 5 seconds for complex maneuvers
    }

    // Calculate distance = speed × time
    double calculatedDistance = _currentSpeed * baseTime;

    // Add complexity buffer based on maneuver type
    calculatedDistance += _getComplexityBuffer(maneuver, roadType);

    // Apply bounds
    calculatedDistance = calculatedDistance.clamp(
      _minAnnouncementDistance,
      _maxAnnouncementDistance
    );

    return calculatedDistance;
  }

  /// Gets additional distance buffer for complex maneuvers
  double _getComplexityBuffer(Maneuver maneuver, NavigationRoadType roadType) {
    switch (maneuver.type) {
      case ManeuverType.offRamp:
      case ManeuverType.fork:
        return roadType == NavigationRoadType.highway ? 100.0 : 50.0;
      case ManeuverType.roundabout:
      case ManeuverType.exitRotary:
      case ManeuverType.exitRoundabout:
        return roadType == NavigationRoadType.highway ? 75.0 : 25.0;
      case ManeuverType.turn:
      case ManeuverType.merge:
        if (maneuver.modifier == ManeuverModifier.uTurn ||
            maneuver.modifier == ManeuverModifier.sharpLeft ||
            maneuver.modifier == ManeuverModifier.sharpRight) {
          return roadType == NavigationRoadType.highway ? 50.0 : 20.0;
        }
        return 0.0;
      default:
        return 0.0;
    }
  }

  void dispose() {
    stopTracking();
    _progressController.close();
    _maneuverController.close();
    _deviationController.close();
    _arrivalController.close();
  }
}
