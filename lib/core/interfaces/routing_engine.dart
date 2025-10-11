import 'dart:async';
import '../models/route_model.dart';
import '../models/location_point.dart';
import '../models/routing_options.dart';

/// Abstract interface for route calculation and re-routing
abstract class RoutingEngine {
  /// Calculates a route from origin to destination with optional waypoints
  Future<RouteModel> getRoute({
    required LocationPoint origin,
    required LocationPoint destination,
    List<LocationPoint>? waypoints,
    RoutingOptions? options,
  });

  /// Re-routes from current location when deviation is detected
  Future<RouteModel> reroute({
    required LocationPoint currentLocation,
    required RouteModel originalRoute,
    LocationPoint? destination,
    List<LocationPoint>? waypoints,
    RoutingOptions? options,
  });

  /// Gets multiple alternative routes for comparison
  Future<List<RouteModel>> getAlternativeRoutes({
    required LocationPoint origin,
    required LocationPoint destination,
    List<LocationPoint>? waypoints,
    RoutingOptions? options,
    int maxAlternatives = 3,
  });

  /// Validates if a route is still valid (e.g., no road closures)
  Future<bool> validateRoute(RouteModel route);

  /// Cancel ongoing route calculation
  void cancelRouteCalculation();
}