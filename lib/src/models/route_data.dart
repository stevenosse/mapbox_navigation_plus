import 'package:geolocator/geolocator.dart';
import 'navigation_step.dart';
import 'waypoint.dart';

/// Traffic annotation data for route segments
class TrafficAnnotation {
  /// Congestion level (severe, heavy, moderate, low, unknown)
  final String congestion;

  /// Numeric congestion level (0-100)
  final int? congestionNumeric;

  /// Speed in km/h for this segment
  final double? speed;

  /// Distance of this segment in meters
  final double distance;

  /// Duration of this segment in seconds
  final double duration;

  const TrafficAnnotation({
    required this.congestion,
    this.congestionNumeric,
    this.speed,
    required this.distance,
    required this.duration,
  });

  /// Creates TrafficAnnotation from Mapbox API response
  factory TrafficAnnotation.fromMapboxData(Map<String, dynamic> data) {
    return TrafficAnnotation(
      congestion: data['congestion'] as String? ?? 'unknown',
      congestionNumeric: data['congestion_numeric'] as int?,
      speed: (data['speed'] as num?)?.toDouble(),
      distance: (data['distance'] as num?)?.toDouble() ?? 0.0,
      duration: (data['duration'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  String toString() {
    return 'TrafficAnnotation(congestion: $congestion, numeric: $congestionNumeric, speed: $speed)';
  }
}

/// Represents a complete navigation route with all steps and metadata
class RouteData {
  /// List of navigation steps for this route
  final List<NavigationStep> steps;

  /// Total distance of the route in meters
  final double totalDistance;

  /// Estimated total duration in seconds
  final double totalDuration;

  /// Complete route geometry as a list of coordinates
  final List<Waypoint> geometry;

  /// The origin point of the route
  final Waypoint origin;

  /// The destination point of the route
  final Waypoint destination;

  /// Optional waypoints along the route
  final List<Waypoint>? waypoints;

  /// Route profile used (driving, walking, cycling)
  final String profile;

  /// Traffic annotations for route segments (only available for driving-traffic profile)
  final List<TrafficAnnotation>? trafficAnnotations;

  // Caching for performance optimization
  Map<String, double>? _stepDistanceCache;
  Map<String, double>? _calculationCache;
  Waypoint? _lastCalculationPosition;

  RouteData({
    required this.steps,
    required this.totalDistance,
    required this.totalDuration,
    required this.geometry,
    required this.origin,
    required this.destination,
    this.waypoints,
    this.profile = 'driving',
    this.trafficAnnotations,
  });

  /// Creates a RouteData from Mapbox Directions API response
  factory RouteData.fromMapboxResponse(
    Map<String, dynamic> route,
    Waypoint origin,
    Waypoint destination, {
    List<Waypoint>? waypoints,
    String? profile,
  }) {
    final legs = route['legs'] as List<dynamic>;
    final geometry = route['geometry'] as Map<String, dynamic>;
    final coordinates = geometry['coordinates'] as List<dynamic>;

    // Convert coordinates to Waypoint objects
    final routeGeometry = coordinates.map((coord) {
      final coordList = coord as List<dynamic>;
      return Waypoint.fromCoordinates(
        coordList[1].toDouble(),
        coordList[0].toDouble(),
      );
    }).toList();

    // Extract all steps from all legs
    final allSteps = <NavigationStep>[];
    for (final leg in legs) {
      final legSteps = leg['steps'] as List<dynamic>;
      for (final step in legSteps) {
        allSteps
            .add(NavigationStep.fromMapboxStep(step as Map<String, dynamic>));
      }
    }

    // Extract traffic annotations if available (only for driving-traffic profile)
    List<TrafficAnnotation>? trafficAnnotations;
    if (profile?.contains('traffic') == true) {
      final annotations = <TrafficAnnotation>[];

      for (final leg in legs) {
        final legAnnotation = leg['annotation'] as Map<String, dynamic>?;
        if (legAnnotation != null) {
          final congestionList = legAnnotation['congestion'] as List<dynamic>?;
          final congestionNumericList =
              legAnnotation['congestion_numeric'] as List<dynamic>?;
          final speedList = legAnnotation['speed'] as List<dynamic>?;
          final distanceList = legAnnotation['distance'] as List<dynamic>?;
          final durationList = legAnnotation['duration'] as List<dynamic>?;

          if (congestionList != null) {
            for (int i = 0; i < congestionList.length; i++) {
              annotations.add(TrafficAnnotation(
                congestion: congestionList[i] as String? ?? 'unknown',
                congestionNumeric: congestionNumericList?[i] as int?,
                speed: (speedList?[i] as num?)?.toDouble(),
                distance: (distanceList?[i] as num?)?.toDouble() ?? 0.0,
                duration: (durationList?[i] as num?)?.toDouble() ?? 0.0,
              ));
            }
          }
        }
      }

      if (annotations.isNotEmpty) {
        trafficAnnotations = annotations;
      }
    }

    return RouteData(
      steps: allSteps,
      totalDistance: (route['distance'] as num?)?.toDouble() ?? 0.0,
      totalDuration: (route['duration'] as num?)?.toDouble() ?? 0.0,
      geometry: routeGeometry,
      origin: origin,
      destination: destination,
      waypoints: waypoints,
      profile: profile ?? 'driving',
      trafficAnnotations: trafficAnnotations,
    );
  }

  /// Gets the currently active step (first non-completed step)
  NavigationStep? get currentStep {
    try {
      return steps.firstWhere((step) => !step.isCompleted);
    } catch (e) {
      return null;
    }
  }

  /// Gets the next step after the current one
  NavigationStep? get nextStep {
    final current = currentStep;
    if (current == null) return null;

    final currentIndex = steps.indexOf(current);
    if (currentIndex >= 0 && currentIndex < steps.length - 1) {
      return steps[currentIndex + 1];
    }
    return null;
  }

  /// Calculates the remaining distance from current position
  double getRemainingDistance(Waypoint currentPosition) {
    final current = currentStep;
    if (current == null) return 0.0;

    // Check cache if position hasn't changed significantly (within 5 meters)
    final cacheKey = 'remaining_distance_${current.hashCode}';
    if (_lastCalculationPosition != null && 
        _calculationCache != null &&
        _lastCalculationPosition!.distanceTo(currentPosition) < 5.0) {
      final cached = _calculationCache![cacheKey];
      if (cached != null) return cached;
    }

    final currentIndex = steps.indexOf(current);
    double remaining = 0.0;

    // Add distance from current position to end of current step
    remaining += currentPosition.distanceTo(
      Waypoint.fromPosition(current.endLocation),
    );

    // Add distance of all remaining steps (cached calculation)
    for (int i = currentIndex + 1; i < steps.length; i++) {
      remaining += steps[i].distance;
    }

    // Cache the result
    _calculationCache ??= {};
    _calculationCache![cacheKey] = remaining;
    _lastCalculationPosition = currentPosition;

    return remaining;
  }

  /// Calculates the remaining duration from current position
  double getRemainingDuration(Waypoint currentPosition) {
    final current = currentStep;
    if (current == null) return 0.0;

    // Check cache if position hasn't changed significantly (within 5 meters)
    final cacheKey = 'remaining_duration_${current.hashCode}';
    if (_lastCalculationPosition != null && 
        _calculationCache != null &&
        _lastCalculationPosition!.distanceTo(currentPosition) < 5.0) {
      final cached = _calculationCache![cacheKey];
      if (cached != null) return cached;
    }

    final currentIndex = steps.indexOf(current);
    double remaining = 0.0;

    // Estimate remaining time for current step based on progress
    final stepProgress = getStepProgress(currentPosition, current);
    remaining += current.duration * (1.0 - stepProgress);

    // Add duration of all remaining steps
    for (int i = currentIndex + 1; i < steps.length; i++) {
      remaining += steps[i].duration;
    }

    // Cache the result
    _calculationCache ??= {};
    _calculationCache![cacheKey] = remaining;
    _lastCalculationPosition = currentPosition;

    return remaining;
  }

  /// Calculates progress through a specific step (0.0 to 1.0)
  double getStepProgress(Waypoint currentPosition, NavigationStep step) {
    // Cache step distance calculation
    _stepDistanceCache ??= {};
    final stepKey = '${step.startLocation.latitude}_${step.startLocation.longitude}_${step.endLocation.latitude}_${step.endLocation.longitude}';
    
    double totalStepDistance = _stepDistanceCache![stepKey] ?? 0.0;
    if (totalStepDistance == 0.0) {
      totalStepDistance = Geolocator.distanceBetween(
        step.startLocation.latitude,
        step.startLocation.longitude,
        step.endLocation.latitude,
        step.endLocation.longitude,
      );
      _stepDistanceCache![stepKey] = totalStepDistance;
    }

    if (totalStepDistance == 0) return 1.0;

    final distanceFromStart =
        Waypoint.fromPosition(step.startLocation).distanceTo(currentPosition);

    return (distanceFromStart / totalStepDistance).clamp(0.0, 1.0);
  }

  /// Clears all cached calculations - call when route changes
  void clearCache() {
    _stepDistanceCache?.clear();
    _calculationCache?.clear();
    _lastCalculationPosition = null;
  }

  /// Creates a copy of this route with updated steps
  RouteData copyWith({
    List<NavigationStep>? steps,
    double? totalDistance,
    double? totalDuration,
    List<Waypoint>? geometry,
    Waypoint? origin,
    Waypoint? destination,
    List<Waypoint>? waypoints,
    String? profile,
    List<TrafficAnnotation>? trafficAnnotations,
  }) {
    return RouteData(
      steps: steps ?? this.steps,
      totalDistance: totalDistance ?? this.totalDistance,
      totalDuration: totalDuration ?? this.totalDuration,
      geometry: geometry ?? this.geometry,
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      waypoints: waypoints ?? this.waypoints,
      profile: profile ?? this.profile,
      trafficAnnotations: trafficAnnotations ?? this.trafficAnnotations,
    );
  }

  /// Calculates the remaining distance from current position (Position compatibility)
  double getRemainingDistanceFromPosition(Position currentPosition) {
    return getRemainingDistance(Waypoint.fromPosition(currentPosition));
  }

  /// Calculates the remaining duration from current position (Position compatibility)
  double getRemainingDurationFromPosition(Position currentPosition) {
    return getRemainingDuration(Waypoint.fromPosition(currentPosition));
  }

  /// Calculates progress through a specific step (Position compatibility)
  double getStepProgressFromPosition(
      Position currentPosition, NavigationStep step) {
    return getStepProgress(Waypoint.fromPosition(currentPosition), step);
  }

  /// Converts route geometry to GeoJSON LineString format
  Map<String, dynamic> toGeoJson() {
    final coordinates = geometry
        .map((waypoint) => [
              waypoint.longitude,
              waypoint.latitude,
            ])
        .toList();

    return {
      'type': 'Feature',
      'geometry': {
        'type': 'LineString',
        'coordinates': coordinates,
      },
      'properties': {
        'route_id': hashCode.toString(),
        'distance': totalDistance,
        'duration': totalDuration,
        'profile': profile,
      },
    };
  }

  /// Converts route to GeoJSON with traffic annotations
  Map<String, dynamic> toGeoJsonWithTraffic() {
    if (trafficAnnotations == null || trafficAnnotations!.isEmpty) {
      return toGeoJson();
    }

    // Create multiple line segments for different traffic levels
    final features = <Map<String, dynamic>>[];

    // Group consecutive segments with same congestion level
    int segmentStart = 0;
    String? currentCongestion;

    for (int i = 0; i < trafficAnnotations!.length; i++) {
      final annotation = trafficAnnotations![i];

      if (currentCongestion != null &&
          annotation.congestion != currentCongestion) {
        // Create feature for previous segment
        features.add(_createTrafficSegmentFeature(
          segmentStart,
          i,
          currentCongestion,
        ));
        segmentStart = i;
      }

      currentCongestion = annotation.congestion;
    }

    // Add final segment
    if (currentCongestion != null &&
        segmentStart < trafficAnnotations!.length) {
      features.add(_createTrafficSegmentFeature(
        segmentStart,
        trafficAnnotations!.length,
        currentCongestion,
      ));
    }

    return {
      'type': 'FeatureCollection',
      'features': features,
    };
  }

  /// Creates a GeoJSON feature for a traffic segment
  Map<String, dynamic> _createTrafficSegmentFeature(
    int startIndex,
    int endIndex,
    String congestion,
  ) {
    final segmentCoordinates = geometry
        .skip(startIndex)
        .take(endIndex - startIndex)
        .map((waypoint) => [waypoint.longitude, waypoint.latitude])
        .toList();

    return {
      'type': 'Feature',
      'geometry': {
        'type': 'LineString',
        'coordinates': segmentCoordinates,
      },
      'properties': {
        'congestion': congestion,
        'route_id': hashCode.toString(),
        'segment_start': startIndex,
        'segment_end': endIndex,
      },
    };
  }

  /// Whether this route has traffic data
  bool get hasTrafficData =>
      trafficAnnotations != null && trafficAnnotations!.isNotEmpty;

  @override
  String toString() {
    return 'RouteData(steps: ${steps.length}, distance: ${totalDistance.toStringAsFixed(0)}m, duration: ${(totalDuration / 60).toStringAsFixed(1)}min, traffic: ${hasTrafficData ? 'yes' : 'no'})';
  }
}
