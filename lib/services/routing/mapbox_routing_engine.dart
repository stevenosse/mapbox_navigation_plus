import 'dart:async' as http;
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/interfaces/routing_engine.dart';
import '../../core/models/route_model.dart';
import '../../core/models/location_point.dart';
import '../../core/models/routing_options.dart';

/// Mapbox Directions API implementation of RoutingEngine
class MapboxRoutingEngine implements RoutingEngine {
  final String _accessToken;
  final String _baseUrl = 'https://api.mapbox.com/directions/v5';

  MapboxRoutingEngine({required String accessToken})
    : _accessToken = accessToken {
    if (_accessToken.isEmpty) {
      throw ArgumentError('Mapbox access token cannot be empty');
    }
  }

  @override
  Future<RouteModel> getRoute({
    required LocationPoint origin,
    required LocationPoint destination,
    List<LocationPoint>? waypoints,
    RoutingOptions? options,
  }) async {
    try {
      final requestOptions = options ?? const RoutingOptions();
      final url = _buildDirectionsUrl(
        origin: origin,
        destination: destination,
        waypoints: waypoints,
        options: requestOptions,
      );

      final response = await http
          .get(Uri.parse(url), headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return RouteModel.fromMapbox(data);
      } else {
        throw RoutingError._fromResponse(response.statusCode, response.body);
      }
    } catch (e) {
      if (e is RoutingError) rethrow;
      throw RoutingError._fromException(e);
    }
  }

  @override
  Future<RouteModel> reroute({
    required LocationPoint currentLocation,
    required RouteModel originalRoute,
    LocationPoint? destination,
    List<LocationPoint>? waypoints,
    RoutingOptions? options,
  }) async {
    // For rerouting, we use the current location as origin and the original destination
    final rerouteDestination = destination ?? originalRoute.destination;
    final rerouteWaypoints = waypoints ?? originalRoute.waypoints;

    return getRoute(
      origin: currentLocation,
      destination: rerouteDestination,
      waypoints: rerouteWaypoints,
      options: options,
    );
  }

  @override
  Future<List<RouteModel>> getAlternativeRoutes({
    required LocationPoint origin,
    required LocationPoint destination,
    List<LocationPoint>? waypoints,
    RoutingOptions? options,
    int maxAlternatives = 3,
  }) async {
    try {
      final requestOptions = (options ?? const RoutingOptions()).copyWith(
        alternatives: true, // Enable alternatives to get multiple routes
      );

      final url = _buildDirectionsUrl(
        origin: origin,
        destination: destination,
        waypoints: waypoints,
        options: requestOptions,
      );

      final response = await http
          .get(Uri.parse(url), headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final routes = <RouteModel>[];

        if (data['routes'] != null) {
          for (final routeData in data['routes'] as List) {
            routes.add(
              RouteModel.fromMapbox(routeData as Map<String, dynamic>),
            );
          }
        }

        return routes;
      } else {
        throw RoutingError._fromResponse(response.statusCode, response.body);
      }
    } catch (e) {
      if (e is RoutingError) rethrow;
      throw RoutingError._fromException(e);
    }
  }

  @override
  Future<bool> validateRoute(RouteModel route) async {
    try {
      // Basic validation - check if route geometry is still valid
      // For a more thorough validation, we could check road closures, traffic, etc.
      if (route.legs.isEmpty) return false;
      if (route.distance <= 0) return false;
      if (route.duration <= 0) return false;

      // Validate that origin and destination are valid coordinates
      if (!_isValidCoordinate(route.origin.latitude, route.origin.longitude)) {
        return false;
      }
      if (!_isValidCoordinate(
        route.destination.latitude,
        route.destination.longitude,
      )) {
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  void cancelRouteCalculation() {
    // Note: HTTP requests in Dart don't have built-in cancellation support
    // In a real implementation, you might want to use a more advanced HTTP client
    // or manage request tokens for cancellation
  }

  /// Builds the Mapbox Directions API URL
  String _buildDirectionsUrl({
    required LocationPoint origin,
    required LocationPoint destination,
    List<LocationPoint>? waypoints,
    required RoutingOptions options,
  }) {
    // Build coordinates string
    final coordinates = <String>[];
    coordinates.add('${origin.longitude},${origin.latitude}');

    if (waypoints != null && waypoints.isNotEmpty) {
      for (final waypoint in waypoints) {
        coordinates.add('${waypoint.longitude},${waypoint.latitude}');
      }
    }

    coordinates.add('${destination.longitude},${destination.latitude}');

    final coordinatesStr = coordinates.join(';');
    final baseUrl = '$_baseUrl/${options.profile.value}/$coordinatesStr';

    // Build query parameters - start with essential ones
    final params = <String, String>{
      'access_token': _accessToken,
      'alternatives': options.alternatives.toString(),
      'geometries': 'geojson',
      'overview': 'full',
      'steps': 'true',
      'language': options.language,
    };

    // Add optional parameters
    if (options.avoid.isNotEmpty) {
      params['avoid'] = options.avoid.map((type) => type.value).join(',');
    }

    if (options.maxWalkingDistance != 1000.0) {
      params['max_walking_distance'] = options.maxWalkingDistance.toString();
    }

    // Add any additional parameters
    params.addAll(options.additionalParams);

    // Build query string
    final queryString = params.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');

    return '$baseUrl?$queryString';
  }

  /// Validates latitude and longitude coordinates
  bool _isValidCoordinate(double latitude, double longitude) {
    return latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }
}

/// Custom routing error types
class RoutingError implements Exception {
  final RoutingErrorType type;
  final String message;
  final int? statusCode;
  final dynamic originalError;

  const RoutingError._({
    required this.type,
    required this.message,
    this.statusCode,
    this.originalError,
  });

  factory RoutingError._fromResponse(int statusCode, String responseBody) {
    final type = _mapStatusCodeToErrorType(statusCode);
    String message = 'HTTP $statusCode';

    try {
      final data = jsonDecode(responseBody) as Map<String, dynamic>?;
      if (data != null) {
        message = data['message'] as String? ?? message;
      }
    } catch (e) {
      // Use default message if JSON parsing fails
    }

    return RoutingError._(type: type, message: message, statusCode: statusCode);
  }

  factory RoutingError._fromException(dynamic exception) {
    RoutingErrorType type;
    String message;

    if (exception is http.TimeoutException) {
      type = RoutingErrorType.timeout;
      message = 'Request timed out';
    } else if (exception is http.ClientException) {
      type = RoutingErrorType.networkError;
      message = 'Network error: ${exception.message}';
    } else if (exception is ArgumentError) {
      type = RoutingErrorType.invalidParameters;
      message = exception.message;
    } else {
      type = RoutingErrorType.unknown;
      message = exception.toString();
    }

    return RoutingError._(
      type: type,
      message: message,
      originalError: exception,
    );
  }

  static RoutingErrorType _mapStatusCodeToErrorType(int statusCode) {
    switch (statusCode) {
      case 400:
        return RoutingErrorType.invalidParameters;
      case 401:
        return RoutingErrorType.unauthorized;
      case 403:
        return RoutingErrorType.forbidden;
      case 404:
        return RoutingErrorType.notFound;
      case 429:
        return RoutingErrorType.rateLimited;
      case 500:
      case 502:
      case 503:
        return RoutingErrorType.serverError;
      default:
        return RoutingErrorType.unknown;
    }
  }

  @override
  String toString() {
    return 'RoutingError(type: $type, message: $message, statusCode: $statusCode)';
  }
}

/// Routing error type enumeration
enum RoutingErrorType {
  invalidParameters,
  unauthorized,
  forbidden,
  notFound,
  rateLimited,
  serverError,
  timeout,
  networkError,
  unknown,
}
