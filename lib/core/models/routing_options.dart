/// Routing configuration options
class RoutingOptions {
  /// Route profile (driving, walking, cycling)
  final RouteProfile profile;

  /// Whether to generate alternative routes
  final bool alternatives;

  /// Include voice instructions
  final bool voiceInstructions;

  /// Include geometry for route visualization
  final bool includeGeometry;

  /// Language for instructions
  final String language;

  /// Units for distance (metric or imperial)
  final DistanceUnits units;

  /// Avoid certain road types
  final Set<RoadType> avoid;

  /// Maximum walking distance for multi-modal routes (meters)
  final double maxWalkingDistance;

  /// Ferry crossing tolerance
  final FerryTolerance ferryTolerance;

  /// Whether to consider real-time traffic data
  final bool useTrafficData;

  /// Preferred route type for optimization (used as default when not specified)
  final RouteType? preferredRouteType;

  /// Additional mapbox API parameters
  final Map<String, String> additionalParams;

  const RoutingOptions({
    this.profile = RouteProfile.driving,
    this.alternatives = false,
    this.voiceInstructions = true,
    this.includeGeometry = true,
    this.language = 'en',
    this.units = DistanceUnits.metric,
    this.avoid = const {},
    this.maxWalkingDistance = 1000.0,
    this.ferryTolerance = FerryTolerance.normal,
    this.useTrafficData = true,
    this.preferredRouteType,
    this.additionalParams = const {},
  });

  /// Creates a copy with updated values
  RoutingOptions copyWith({
    RouteProfile? profile,
    bool? alternatives,
    bool? voiceInstructions,
    bool? includeGeometry,
    String? language,
    DistanceUnits? units,
    Set<RoadType>? avoid,
    double? maxWalkingDistance,
    FerryTolerance? ferryTolerance,
    bool? useTrafficData,
    RouteType? preferredRouteType,
    Map<String, String>? additionalParams,
  }) {
    return RoutingOptions(
      profile: profile ?? this.profile,
      alternatives: alternatives ?? this.alternatives,
      voiceInstructions: voiceInstructions ?? this.voiceInstructions,
      includeGeometry: includeGeometry ?? this.includeGeometry,
      language: language ?? this.language,
      units: units ?? this.units,
      avoid: avoid ?? this.avoid,
      maxWalkingDistance: maxWalkingDistance ?? this.maxWalkingDistance,
      ferryTolerance: ferryTolerance ?? this.ferryTolerance,
      useTrafficData: useTrafficData ?? this.useTrafficData,
      preferredRouteType: preferredRouteType ?? this.preferredRouteType,
      additionalParams: additionalParams ?? this.additionalParams,
    );
  }

  /// Creates routing options optimized for a specific route type
  factory RoutingOptions.forRouteType(RouteType routeType, {
    RoutingOptions? baseOptions,
  }) {
    final base = baseOptions ?? const RoutingOptions();
    
    return base.copyWith(
      profile: routeType.mapboxProfile,
      avoid: routeType.avoidTypes,
      preferredRouteType: routeType,
      useTrafficData: routeType == RouteType.timeOptimized || 
                      routeType == RouteType.balanced,
    );
  }

  /// Converts to query parameters for API calls
  Map<String, String> toQueryParameters() {
    final params = <String, String>{
      'profile': profile.value,
      'alternatives': alternatives.toString(),
      'language': language,
      'units': units.value,
      if (voiceInstructions) 'voice_instructions': 'true',
      if (includeGeometry) 'geometries': 'geojson',
      if (maxWalkingDistance != 1000.0) 'max_walking_distance': maxWalkingDistance.toString(),
      ...additionalParams,
    };

    // Add avoid parameters
    if (avoid.isNotEmpty) {
      params['avoid'] = avoid.map((type) => type.value).join(',');
    }

    // Add traffic-related parameters
    if (!useTrafficData && profile == RouteProfile.drivingTraffic) {
      // Override to use non-traffic profile if traffic data is disabled
      params['profile'] = RouteProfile.driving.value;
    }

    return params;
  }
}

/// Route profile enumeration
enum RouteProfile {
  driving('mapbox/driving'),
  drivingTraffic('mapbox/driving-traffic'),
  walking('mapbox/walking'),
  cycling('mapbox/cycling');

  const RouteProfile(this.value);
  final String value;
}

/// Distance units enumeration
enum DistanceUnits {
  metric('metric'),
  imperial('imperial');

  const DistanceUnits(this.value);
  final String value;
}

/// Road types to avoid
enum RoadType {
  motorway('motorway'),
  toll('toll'),
  ferry('ferry'),
  unpaved('unpaved');

  const RoadType(this.value);
  final String value;
}

/// Ferry crossing tolerance
enum FerryTolerance {
  low('low'),
  normal('normal'),
  high('high');

  const FerryTolerance(this.value);
  final String value;
}

/// Route optimization types for multiple route requests
enum RouteType {
  /// Fastest route considering current traffic
  timeOptimized('time_optimized', 'Fastest route'),
  
  /// Shortest distance route
  distanceOptimized('distance_optimized', 'Shortest route'),
  
  /// Route without considering traffic data
  noTraffic('no_traffic', 'Route without traffic'),
  
  /// Most fuel-efficient route
  ecoFriendly('eco_friendly', 'Eco-friendly route'),
  
  /// Route avoiding tolls
  tollFree('toll_free', 'Toll-free route'),
  
  /// Route avoiding highways/motorways
  scenicRoute('scenic_route', 'Scenic route'),
  
  /// Balanced route considering time, distance, and traffic
  balanced('balanced', 'Balanced route');

  const RouteType(this.value, this.displayName);
  final String value;
  final String displayName;
  
  /// Gets the appropriate Mapbox profile for this route type
  RouteProfile get mapboxProfile {
    switch (this) {
      case RouteType.timeOptimized:
      case RouteType.balanced:
        return RouteProfile.drivingTraffic;
      case RouteType.noTraffic:
      case RouteType.distanceOptimized:
      case RouteType.tollFree:
      case RouteType.scenicRoute:
      case RouteType.ecoFriendly:
        return RouteProfile.driving;
    }
  }
  
  /// Gets the avoid parameters for this route type
  Set<RoadType> get avoidTypes {
    switch (this) {
      case RouteType.tollFree:
        return {RoadType.toll};
      case RouteType.scenicRoute:
        return {RoadType.motorway};
      case RouteType.timeOptimized:
      case RouteType.distanceOptimized:
      case RouteType.noTraffic:
      case RouteType.ecoFriendly:
      case RouteType.balanced:
        return {};
    }
  }
}