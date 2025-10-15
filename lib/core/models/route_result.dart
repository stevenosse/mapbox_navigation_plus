import 'route_model.dart';
import 'routing_options.dart';

/// Represents a route result with its optimization type and metadata
class RouteResult {
  /// The calculated route
  final RouteModel route;
  
  /// The type of optimization used for this route
  final RouteType routeType;
  
  /// Additional metadata about the route calculation
  final RouteMetadata metadata;
  
  const RouteResult({
    required this.route,
    required this.routeType,
    required this.metadata,
  });
  
  /// Creates a RouteResult from a RouteModel and RouteType
  factory RouteResult.fromRoute({
    required RouteModel route,
    required RouteType routeType,
    DateTime? calculatedAt,
    Map<String, dynamic>? additionalData,
  }) {
    return RouteResult(
      route: route,
      routeType: routeType,
      metadata: RouteMetadata(
        calculatedAt: calculatedAt ?? DateTime.now(),
        routeTypeName: routeType.displayName,
        additionalData: additionalData ?? {},
      ),
    );
  }
  
  @override
  String toString() {
    return 'RouteResult(type: ${routeType.displayName}, '
           'distance: ${route.distance}m, '
           'duration: ${route.duration}s)';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RouteResult &&
           other.route == route &&
           other.routeType == routeType &&
           other.metadata == metadata;
  }
  
  @override
  int get hashCode => Object.hash(route, routeType, metadata);
}

/// Metadata associated with a route calculation
class RouteMetadata {
  /// When the route was calculated
  final DateTime calculatedAt;
  
  /// Human-readable name of the route type
  final String routeTypeName;
  
  /// Additional data specific to the route calculation
  final Map<String, dynamic> additionalData;
  
  const RouteMetadata({
    required this.calculatedAt,
    required this.routeTypeName,
    this.additionalData = const {},
  });
  
  /// Creates a copy with updated values
  RouteMetadata copyWith({
    DateTime? calculatedAt,
    String? routeTypeName,
    Map<String, dynamic>? additionalData,
  }) {
    return RouteMetadata(
      calculatedAt: calculatedAt ?? this.calculatedAt,
      routeTypeName: routeTypeName ?? this.routeTypeName,
      additionalData: additionalData ?? this.additionalData,
    );
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RouteMetadata &&
           other.calculatedAt == calculatedAt &&
           other.routeTypeName == routeTypeName &&
           _mapEquals(other.additionalData, additionalData);
  }
  
  @override
  int get hashCode => Object.hash(calculatedAt, routeTypeName, additionalData);
  
  /// Helper method to compare maps
  bool _mapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }
}