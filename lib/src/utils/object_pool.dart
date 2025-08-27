import 'package:geolocator/geolocator.dart';
import '../models/waypoint.dart';

/// A simple object pool for frequently created objects
abstract class ObjectPool<T> {
  final List<T> _pool = [];
  final int maxPoolSize;

  ObjectPool({this.maxPoolSize = 50});

  /// Gets an object from the pool or creates a new one
  T acquire();

  /// Returns an object to the pool
  void release(T object);

  /// Clears the pool
  void clear() {
    _pool.clear();
  }

  /// Current pool size
  int get poolSize => _pool.length;

  /// Checks if pool is empty
  bool get isEmpty => _pool.isEmpty;
}

/// Object pool for Position objects used in location simulation
class PositionPool extends ObjectPool<Position> {
  PositionPool({super.maxPoolSize = 100});

  @override
  Position acquire() {
    if (_pool.isNotEmpty) {
      return _pool.removeLast();
    }

    // Create new position with default values
    // These will be overwritten when the position is used
    return Position(
      latitude: 0.0,
      longitude: 0.0,
      timestamp: DateTime.now(),
      accuracy: 0.0,
      altitude: 0.0,
      altitudeAccuracy: 0.0,
      heading: 0.0,
      headingAccuracy: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
    );
  }

  @override
  void release(Position position) {
    if (_pool.length < maxPoolSize) {
      _pool.add(position);
    }
  }

  /// Creates a new Position with specific values using pooled object
  Position createPosition({
    required double latitude,
    required double longitude,
    DateTime? timestamp,
    double accuracy = 0.0,
    double altitude = 0.0,
    double altitudeAccuracy = 0.0,
    double heading = 0.0,
    double headingAccuracy = 0.0,
    double speed = 0.0,
    double speedAccuracy = 0.0,
  }) {
    // For now, we can't efficiently reuse Position objects because they're immutable
    // This method serves as a future-proofing placeholder
    return Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: timestamp ?? DateTime.now(),
      accuracy: accuracy,
      altitude: altitude,
      altitudeAccuracy: altitudeAccuracy,
      heading: heading,
      headingAccuracy: headingAccuracy,
      speed: speed,
      speedAccuracy: speedAccuracy,
    );
  }
}

/// Object pool for Waypoint objects
class WaypointPool extends ObjectPool<Waypoint> {
  WaypointPool({super.maxPoolSize = 200});

  @override
  Waypoint acquire() {
    if (_pool.isNotEmpty) {
      return _pool.removeLast();
    }

    // Create new waypoint with default values
    return Waypoint(latitude: 0.0, longitude: 0.0);
  }

  @override
  void release(Waypoint waypoint) {
    if (_pool.length < maxPoolSize) {
      _pool.add(waypoint);
    }
  }

  /// Creates a new Waypoint with specific values
  Waypoint createWaypoint({
    required double latitude,
    required double longitude,
    String? name,
    double? altitude,
  }) {
    acquire();
    
    // Since Waypoint might be mutable, we can reuse it
    // If not, this will create a new one (check Waypoint implementation)
    return Waypoint(
      latitude: latitude,
      longitude: longitude,
      name: name,
      altitude: altitude,
    );
  }
}

/// Global object pools for common types
class ObjectPools {
  static final PositionPool positions = PositionPool();
  static final WaypointPool waypoints = WaypointPool();

  /// Clears all pools (useful for testing or memory cleanup)
  static void clearAll() {
    positions.clear();
    waypoints.clear();
  }

  /// Gets pool statistics for debugging
  static Map<String, int> getStatistics() {
    return {
      'positions_pool_size': positions.poolSize,
      'waypoints_pool_size': waypoints.poolSize,
    };
  }
}