import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../utils/constants.dart' as nav_constants;
import '../utils/error_handling.dart';
import '../utils/object_pool.dart';
import '../utils/math_utils.dart';

/// Service for handling location tracking and simulation
class LocationService {
  StreamController<Position>? _positionController;
  StreamSubscription<Position>? _locationSubscription;
  Timer? _simulationTimer;

  bool _isSimulating = false;
  Position? _currentSimulatedPosition;
  List<Position>? _simulationRoute;
  int _simulationIndex = 0;
  double _simulationSpeed = nav_constants
      .NavigationConstants.simulationSpeed; // Using shared constants

  /// Stream of position updates
  Stream<Position> get positionStream {
    _positionController ??= StreamController<Position>.broadcast();
    return _positionController!.stream;
  }

  /// Current position (real or simulated)
  Position? get currentPosition => _currentSimulatedPosition;

  /// Whether location simulation is active
  bool get isSimulating => _isSimulating;

  /// Starts real GPS location tracking
  Future<void> startLocationTracking({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 5, // meters
    Duration interval = const Duration(seconds: 1),
  }) async {
    try {
      // Stop any existing simulation
      stopSimulation();

      // Check and request permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw ErrorHandler.handleLocationPermission(permission);
        }
      }

      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.unableToDetermine) {
        throw ErrorHandler.handleLocationPermission(permission);
      }

      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw LocationException.serviceDisabled();
      }

      // Configure location settings
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      );

      // Start listening to position updates
      await ErrorHandler.safeExecute(
        () async {
          _locationSubscription = Geolocator.getPositionStream(
            locationSettings: locationSettings,
          ).listen(
            (position) {
              // Check accuracy threshold
              if (position.accuracy >
                  nav_constants.NavigationConstants.locationAccuracyThreshold) {
                ErrorHandler.logError(
                  LocationException.accuracyTooLow(position.accuracy),
                  context: 'Location tracking',
                );
                return; // Skip this position update
              }
              _currentSimulatedPosition = position;
              _positionController?.add(position);
            },
            onError: (error) {
              final locationError = error is Exception
                  ? ErrorHandler.handleGeolocatorException(error)
                  : LocationException('Location stream error: $error');
              _positionController?.addError(locationError);
            },
          );
        },
        context: 'Starting location tracking',
      );
    } catch (e) {
      throw LocationServiceException('Failed to start location tracking: $e');
    }
  }

  /// Starts location simulation along a route
  void startSimulation({
    required List<Position> route,
    double speedMps = 10.0, // meters per second
    Duration updateInterval = const Duration(milliseconds: 1000),
  }) {
    if (route.isEmpty) {
      throw const LocationServiceException('Cannot simulate empty route');
    }

    // Stop real location tracking
    stopLocationTracking();

    _isSimulating = true;
    _simulationRoute = List.from(route);
    _simulationIndex = 0;
    _simulationSpeed = speedMps;
    _currentSimulatedPosition = route.first;

    // Emit initial position
    _positionController?.add(_currentSimulatedPosition!);

    // Start simulation timer
    _simulationTimer = Timer.periodic(updateInterval, (timer) {
      _updateSimulatedPosition();
    });
  }

  /// Starts simulation from a specific position
  void startSimulationFromPosition({
    required Position startPosition,
    double speedMps = 10.0,
    Duration updateInterval = const Duration(milliseconds: 1000),
  }) {
    stopLocationTracking();

    _isSimulating = true;
    _simulationSpeed = speedMps;
    _currentSimulatedPosition = startPosition;

    // Emit initial position
    _positionController?.add(_currentSimulatedPosition!);

    // For free simulation (not following a route), just emit the same position
    _simulationTimer = Timer.periodic(updateInterval, (timer) {
      _positionController?.add(_currentSimulatedPosition!);
    });
  }

  /// Updates the simulated position along the route
  void _updateSimulatedPosition() {
    if (_simulationRoute == null ||
        _simulationIndex >= _simulationRoute!.length - 1) {
      // Reached end of route
      stopSimulation();
      return;
    }

    final currentPos = _simulationRoute![_simulationIndex];
    final nextPos = _simulationRoute![_simulationIndex + 1];

    // Calculate distance to next point
    final distance = MathUtils.calculateDistanceBetweenPositions(currentPos, nextPos);

    // Calculate how far we should move in this update
    final moveDistance = _simulationSpeed *
        (nav_constants.NavigationConstants.locationUpdateInterval / 1000);

    if (moveDistance >= distance) {
      // Move to next waypoint
      _simulationIndex++;
      _currentSimulatedPosition = _simulationRoute![_simulationIndex];
    } else {
      // Interpolate position between current and next waypoint
      final ratio = moveDistance / distance;
      final newLat = currentPos.latitude +
          (nextPos.latitude - currentPos.latitude) * ratio;
      final newLng = currentPos.longitude +
          (nextPos.longitude - currentPos.longitude) * ratio;

      // Calculate bearing for heading
      final bearing = MathUtils.calculateBearingBetweenPositions(currentPos, nextPos);

      _currentSimulatedPosition = ObjectPools.positions.createPosition(
        latitude: newLat,
        longitude: newLng,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: currentPos.altitude,
        altitudeAccuracy: 5.0,
        heading: bearing,
        headingAccuracy: 5.0,
        speed: _simulationSpeed,
        speedAccuracy: 1.0,
      );

      // Update the route with new interpolated position
      _simulationRoute![_simulationIndex] = _currentSimulatedPosition!;
    }

    // Emit updated position
    _positionController?.add(_currentSimulatedPosition!);
  }

  /// Manually sets the simulated position (for testing)
  void setSimulatedPosition(Position position) {
    if (!_isSimulating) {
      startSimulationFromPosition(startPosition: position);
    } else {
      _currentSimulatedPosition = position;
      _positionController?.add(position);
    }
  }

  /// Gets the current position (real or simulated)
  Future<Position> getCurrentPosition() async {
    if (_isSimulating && _currentSimulatedPosition != null) {
      return _currentSimulatedPosition!;
    }

    try {
      final permission = await _checkLocationPermission();
      if (!permission) {
        throw const LocationServiceException('Location permission denied');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(
              milliseconds:
                  nav_constants.NavigationConstants.locationUpdateInterval),
        ),
      );

      _currentSimulatedPosition = position;
      return position;
    } catch (e) {
      throw LocationServiceException('Failed to get current position: $e');
    }
  }

  /// Stops location simulation
  void stopSimulation() {
    _isSimulating = false;
    _simulationTimer?.cancel();
    _simulationTimer = null;
    _simulationRoute = null;
    _simulationIndex = 0;
  }

  /// Stops real location tracking
  void stopLocationTracking() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
  }

  /// Stops all location services
  void stopAll() {
    stopSimulation();
    stopLocationTracking();
  }

  /// Checks and requests location permissions
  Future<bool> _checkLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Calculates distance between two positions
  static double calculateDistance(Position pos1, Position pos2) {
    return MathUtils.calculateDistanceBetweenPositions(pos1, pos2);
  }

  /// Calculates bearing between two positions
  static double calculateBearing(Position from, Position to) {
    return MathUtils.calculateBearingBetweenPositions(from, to);
  }

  /// Disposes of the service and cleans up resources
  Future<void> dispose() async {
    stopAll();
    
    // Close position controller if not already closed
    if (_positionController != null && !_positionController!.isClosed) {
      await _positionController!.close();
    }
    _positionController = null;
  }
}

/// Exception thrown by location service operations
class LocationServiceException implements Exception {
  final String message;

  const LocationServiceException(this.message);

  @override
  String toString() => 'LocationServiceException: $message';
}
