import 'dart:async';
import 'package:flutter/material.dart';
import 'package:location/location.dart';
import '../../core/interfaces/location_provider.dart';
import '../../core/models/location_point.dart';

/// Real implementation of LocationProvider using location package
class DefaultLocationProvider implements LocationProvider {
  final StreamController<LocationPoint> _locationController =
      StreamController<LocationPoint>.broadcast();
  final StreamController<double> _headingController =
      StreamController<double>.broadcast();

  final Location _location = Location();
  bool _isServiceEnabled = false;
  PermissionStatus _permissionStatus = PermissionStatus.denied;
  LocationPoint? _currentLocation;
  double? _currentHeading;
  StreamSubscription<LocationData>? _locationSubscription;

  @override
  Stream<LocationPoint> get locationStream => _locationController.stream;

  @override
  Future<void> start() async {
    try {
      _isServiceEnabled = await _location.serviceEnabled();
      if (!_isServiceEnabled) {
        _isServiceEnabled = await _location.requestService();
        if (!_isServiceEnabled) {
          throw Exception('Location services are disabled');
        }
      }

      // Check permissions
      _permissionStatus = await _location.hasPermission();
      if (_permissionStatus == PermissionStatus.denied) {
        _permissionStatus = await _location.requestPermission();
        if (_permissionStatus != PermissionStatus.granted) {
          throw Exception('Location permissions are denied');
        }
      }

      // Start location updates
      _locationSubscription = _location.onLocationChanged.listen(
        _onLocationData,
        onError: (error) {
          _locationController.addError(error);
        },
      );

      // Get initial position
      try {
        final locationData = await _location.getLocation();
        _onLocationData(locationData);
      } catch (e) {
        // If we can't get initial position, that's okay - we'll wait for stream updates
      }
    } catch (e) {
      _locationController.addError(e);
      rethrow;
    }
  }

  @override
  Future<void> stop() async {
    await _locationSubscription?.cancel();
    _locationSubscription = null;
  }

  @override
  LocationPoint? get currentLocation => _currentLocation;

  @override
  Stream<double>? get headingStream => _headingController.stream;

  @override
  double? get currentHeading => _currentHeading;

  @override
  double get accuracyThreshold => 20.0;

  @override
  bool get isLocationServiceEnabled => _isServiceEnabled;

  @override
  Future<LocationPermissionStatus> getPermissionStatus() async {
    final permission = await _location.hasPermission();
    return _mapPermissionStatus(permission);
  }

  @override
  Future<LocationPermissionStatus> requestPermission() async {
    final permission = await _location.requestPermission();
    _permissionStatus = permission;
    return _mapPermissionStatus(permission);
  }

  void _onLocationData(LocationData locationData) {
    // Only process if we have valid coordinates
    if (locationData.latitude == null || locationData.longitude == null) {
      return;
    }

    _currentLocation = LocationPoint(
      latitude: locationData.latitude!,
      longitude: locationData.longitude!,
      timestamp: DateTime.now(),
      heading: locationData.heading,
      accuracy: locationData.accuracy,
      altitude: locationData.altitude,
      speed: locationData.speed,
    );

    _currentHeading = locationData.heading;

    _locationController.add(_currentLocation!);
    if (locationData.heading != null) {
      _headingController.add(locationData.heading!);
    }
  }

  LocationPermissionStatus _mapPermissionStatus(PermissionStatus permission) {
    switch (permission) {
      case PermissionStatus.granted:
        return LocationPermissionStatus.always;
      case PermissionStatus.grantedLimited:
        return LocationPermissionStatus.whileInUse;
      case PermissionStatus.denied:
        return LocationPermissionStatus.denied;
      case PermissionStatus.deniedForever:
        return LocationPermissionStatus.deniedForever;
    }
  }

  @override
  Future<LocationPoint?> getCurrentLocation() async {
    try {
      final locationData = await _location.getLocation();

      if (locationData.latitude == null || locationData.longitude == null) {
        return null;
      }

      return LocationPoint(
        latitude: locationData.latitude!,
        longitude: locationData.longitude!,
        timestamp: DateTime.now(),
        heading: locationData.heading,
        accuracy: locationData.accuracy,
        altitude: locationData.altitude,
        speed: locationData.speed,
      );
    } catch (e) {
      debugPrint('Error getting current location: $e');
      return null;
    }
  }

  void dispose() {
    stop();
    _locationController.close();
    _headingController.close();
  }
}
