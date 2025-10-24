import 'dart:async';
import '../models/location_point.dart';

/// Abstract interface for providing location updates and managing GPS services
abstract class LocationProvider {
  /// Starts location updates and returns a stream of location points
  Future<void> start();

  /// Stops location updates
  Future<void> stop();

  /// Stream of location updates
  Stream<LocationPoint> get locationStream;

  /// Current location (null if not available)
  LocationPoint? get currentLocation;

  /// Stream of heading updates (optional)
  Stream<double>? get headingStream;

  /// Current heading in degrees (0-360, null if not available)
  double? get currentHeading;

  /// Location accuracy threshold for navigation in meters
  double get accuracyThreshold;

  /// Whether location services are enabled
  bool get isLocationServiceEnabled;

  /// Location permission status
  Future<LocationPermissionStatus> getPermissionStatus();

  /// Request location permission
  Future<LocationPermissionStatus> requestPermission();

  /// Get current location once
  Future<LocationPoint?> getCurrentLocation();
}

/// Location permission status enum
enum LocationPermissionStatus {
  denied,
  deniedForever,
  whileInUse,
  always,
  unableToDetermine,
}
