import 'dart:async';
import 'package:mapbox_navigation_plus/core/models/maneuver.dart';

import '../models/route_model.dart';
import '../models/route_progress.dart';
import '../models/location_point.dart';

/// Abstract interface for tracking progress along a navigation route
abstract class RouteProgressTracker {
  /// Starts tracking progress for the given route
  Future<void> startTracking({
    required RouteModel route,
    required Stream<LocationPoint> locationStream,
  });

  /// Stops tracking progress
  Future<void> stopTracking();

  /// Stream of route progress updates
  Stream<RouteProgress> get progressStream;

  /// Stream of upcoming maneuver notifications
  Stream<Maneuver> get upcomingManeuverStream;

  /// Stream of route deviation events
  Stream<RouteDeviation> get deviationStream;

  /// Stream of arrival notifications
  Stream<void> get arrivalStream;

  /// Current route progress
  RouteProgress? get currentProgress;

  /// Whether tracking is active
  bool get isTracking;

  /// Distance threshold for detecting route deviation in meters
  double get deviationThreshold;

  /// Set deviation threshold (default: 50 meters)
  set deviationThreshold(double threshold);

  /// Distance threshold for maneuver notifications in meters
  double get maneuverNotificationThreshold;

  /// Set maneuver notification threshold (default: 200 meters)
  set maneuverNotificationThreshold(double threshold);
}

/// Route deviation information
class RouteDeviation {
  final LocationPoint currentLocation;
  final double distanceFromRoute;
  final DateTime timestamp;

  const RouteDeviation({
    required this.currentLocation,
    required this.distanceFromRoute,
    required this.timestamp,
  });
}
