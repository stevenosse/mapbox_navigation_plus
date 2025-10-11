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
      additionalParams: additionalParams ?? this.additionalParams,
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