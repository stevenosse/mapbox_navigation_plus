import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../models/route_data.dart';
import '../models/waypoint.dart';
import '../utils/constants.dart' as nav_constants;
import '../utils/error_handling.dart';
import '../utils/validation_utils.dart';
import '../utils/retry_utils.dart';

/// Service for interacting with Mapbox Directions API
class MapboxDirectionsAPI {
  // Using shared constants from NavigationConstants

  final String _accessToken;
  final http.Client _httpClient;
  final String _language;
  final bool _ownsHttpClient;

  MapboxDirectionsAPI({
    required String accessToken,
    http.Client? httpClient,
    String language = 'en',
  })  : _accessToken = accessToken,
        _httpClient = httpClient ?? http.Client(),
        _language = language,
        _ownsHttpClient = httpClient == null {
    ValidationUtils.validateMapboxToken(_accessToken);
  }

  /// Fetches a route from origin to destination using Waypoint objects
  ///
  /// [profile] can be 'driving', 'walking', 'cycling', 'driving-traffic'
  /// [waypoints] optional intermediate points along the route
  /// [alternatives] whether to return alternative routes
  /// [steps] whether to include turn-by-turn instructions
  /// [geometries] format for route geometry ('geojson' or 'polyline')
  /// [includeTrafficData] whether to include traffic annotations (only for driving-traffic)
  Future<RouteData> getRouteFromWaypoints({
    required Waypoint origin,
    required Waypoint destination,
    List<Waypoint>? waypoints,
    String profile = 'driving',
    bool alternatives = false,
    bool steps = true,
    String geometries = 'geojson',
    bool overview = true,
    String? language,
    bool includeTrafficData = false,
  }) async {
    // Validate input parameters
    ValidationUtils.validateRouteRequest(
      origin: origin,
      destination: destination,
      waypoints: waypoints,
      profile: profile,
    );
    return getRoute(
      origin: origin.toPosition(),
      destination: destination.toPosition(),
      waypoints: waypoints?.map((w) => w.toPosition()).toList(),
      profile: profile,
      alternatives: alternatives,
      steps: steps,
      geometries: geometries,
      overview: overview,
      language: language ?? _language,
      includeTrafficData: includeTrafficData,
    );
  }

  /// Fetches a route from origin to destination using Position objects (backward compatibility)
  ///
  /// [profile] can be 'driving', 'walking', 'cycling', 'driving-traffic'
  /// [waypoints] optional intermediate points along the route
  /// [alternatives] whether to return alternative routes
  /// [steps] whether to include turn-by-turn instructions
  /// [geometries] format for route geometry ('geojson' or 'polyline')
  /// [includeTrafficData] whether to include traffic annotations (only for driving-traffic)
  Future<RouteData> getRoute({
    required Position origin,
    required Position destination,
    List<Position>? waypoints,
    String profile = 'driving',
    bool alternatives = false,
    bool steps = true,
    String geometries = 'geojson',
    bool overview = true,
    String? language,
    bool includeTrafficData = false,
  }) async {
    // Validate input parameters
    ValidationUtils.validateCoordinates(origin.latitude, origin.longitude, context: 'origin');
    ValidationUtils.validateCoordinates(destination.latitude, destination.longitude, context: 'destination');
    
    if (!ValidationUtils.areCoordinatesDifferent(
      origin.latitude, origin.longitude,
      destination.latitude, destination.longitude,
    )) {
      throw ArgumentError('Origin and destination must be different locations');
    }

    if (waypoints != null) {
      for (int i = 0; i < waypoints.length; i++) {
        ValidationUtils.validateCoordinates(
          waypoints[i].latitude, waypoints[i].longitude, 
          context: 'waypoint[$i]'
        );
      }
    }

    if (!ValidationUtils.isValidRouteProfile(profile)) {
      throw ArgumentError('Invalid route profile: $profile');
    }

    try {
      // Build coordinates string
      final coordinates = <String>[];

      // Add origin
      coordinates.add('${origin.longitude},${origin.latitude}');

      // Add waypoints if provided
      if (waypoints != null) {
        for (final waypoint in waypoints) {
          coordinates.add('${waypoint.longitude},${waypoint.latitude}');
        }
      }

      // Add destination
      coordinates.add('${destination.longitude},${destination.latitude}');

      final coordinatesString = coordinates.join(';');

      // Automatically use driving-traffic profile if traffic data is requested
      if (includeTrafficData && profile == 'driving') {
        profile = 'driving-traffic';
      }

      // Build query parameters
      final queryParams = {
        'access_token': _accessToken,
        'alternatives': alternatives.toString(),
        'steps': steps.toString(),
        'geometries': geometries,
        'overview': overview ? 'full' : 'simplified',
        'language': language ?? _language,
      };

      // Add traffic annotations if requested and profile supports it
      if (includeTrafficData && profile.contains('traffic')) {
        queryParams['annotations'] =
            'congestion,congestion_numeric,speed,distance,duration';
      }

      // Build URL
      final uri = Uri.parse(
              '${nav_constants.NavigationConstants.mapboxDirectionsBaseUrl}/$profile/$coordinatesString')
          .replace(queryParameters: queryParams);

      // Make HTTP request with retry logic
      final response = await RetryUtils.executeWithRetry(
        () => _httpClient.get(uri),
        maxRetries: 3,
        retryWhen: (error) {
          // Retry on network errors and 5xx server errors
          final errorString = error.toString().toLowerCase();
          return errorString.contains('timeout') ||
              errorString.contains('connection') ||
              errorString.contains('500') ||
              errorString.contains('502') ||
              errorString.contains('503') ||
              errorString.contains('504');
        },
      );

      if (response.statusCode != 200) {
        throw RouteException.apiError(response.statusCode, response.body);
      }

      final data = json.decode(response.body) as Map<String, dynamic>;

      // Check for API errors
      if (data['code'] != 'Ok') {
        throw RouteException.apiError(
          response.statusCode,
          data['message'] as String? ?? 'Unknown API error',
        );
      }

      final routes = data['routes'] as List<dynamic>;
      if (routes.isEmpty) {
        throw const MapboxDirectionsException(
          'No routes found between the specified points',
          404,
        );
      }

      // Use the first (best) route
      final route = routes.first as Map<String, dynamic>;

      return RouteData.fromMapboxResponseWithPositions(
        route,
        origin,
        destination,
        waypoints: waypoints,
        profile: profile,
      );
    } catch (e) {
      if (e is RouteException) {
        rethrow;
      }
      throw ErrorHandler.handleHttpException(e as Exception);
    }
  }

  /// Fetches multiple alternative routes using Waypoint objects
  Future<List<RouteData>> getAlternativeRoutesFromWaypoints({
    required Waypoint origin,
    required Waypoint destination,
    List<Waypoint>? waypoints,
    String profile = 'driving',
    int maxAlternatives = 3,
    String? language,
    bool includeTrafficData = false,
  }) async {
    return getAlternativeRoutes(
      origin: origin.toPosition(),
      destination: destination.toPosition(),
      waypoints: waypoints?.map((w) => w.toPosition()).toList(),
      profile: profile,
      maxAlternatives: maxAlternatives,
      language: language ?? _language,
      includeTrafficData: includeTrafficData,
    );
  }

  /// Fetches multiple alternative routes using Position objects (backward compatibility)
  Future<List<RouteData>> getAlternativeRoutes({
    required Position origin,
    required Position destination,
    List<Position>? waypoints,
    String profile = 'driving',
    int maxAlternatives = 3,
    String? language,
    bool includeTrafficData = false,
  }) async {
    try {
      // Build coordinates string
      final coordinates = <String>[];

      coordinates.add('${origin.longitude},${origin.latitude}');

      if (waypoints != null) {
        for (final waypoint in waypoints) {
          coordinates.add('${waypoint.longitude},${waypoint.latitude}');
        }
      }

      coordinates.add('${destination.longitude},${destination.latitude}');

      final coordinatesString = coordinates.join(';');

      // Automatically use driving-traffic profile if traffic data is requested
      if (includeTrafficData && profile == 'driving') {
        profile = 'driving-traffic';
      }

      // Build query parameters
      final queryParams = {
        'access_token': _accessToken,
        'alternatives': 'true',
        'steps': 'true',
        'geometries': 'geojson',
        'overview': 'full',
        'language': language ?? _language,
        'alternative_count': maxAlternatives.toString(),
      };

      // Add traffic annotations if requested and profile supports it
      if (includeTrafficData && profile.contains('traffic')) {
        queryParams['annotations'] =
            'congestion,congestion_numeric,speed,distance,duration';
      }

      final uri = Uri.parse(
              '${nav_constants.NavigationConstants.mapboxDirectionsBaseUrl}/$profile/$coordinatesString')
          .replace(queryParameters: queryParams);

      final response = await RetryUtils.executeWithRetry(
        () => _httpClient.get(uri),
        maxRetries: 3,
        retryWhen: (error) {
          final errorString = error.toString().toLowerCase();
          return errorString.contains('timeout') ||
              errorString.contains('connection') ||
              errorString.contains('500') ||
              errorString.contains('502') ||
              errorString.contains('503') ||
              errorString.contains('504');
        },
      );

      if (response.statusCode != 200) {
        throw RouteException.apiError(response.statusCode, response.body);
      }

      final data = json.decode(response.body) as Map<String, dynamic>;

      if (data['code'] != 'Ok') {
        throw RouteException.apiError(
          response.statusCode,
          data['message'] as String? ?? 'Unknown API error',
        );
      }

      final routes = data['routes'] as List<dynamic>;

      return routes
          .map((route) => RouteData.fromMapboxResponseWithPositions(
                route as Map<String, dynamic>,
                origin,
                destination,
                waypoints: waypoints,
                profile: profile,
              ))
          .toList();
    } catch (e) {
      if (e is RouteException) {
        rethrow;
      }
      throw ErrorHandler.handleHttpException(e as Exception);
    }
  }

  /// Calculates estimated travel time between two points
  Future<double> getEstimatedDuration({
    required Position origin,
    required Position destination,
    String profile = 'driving',
    bool includeTrafficData = false,
  }) async {
    try {
      final route = await getRoute(
        origin: origin,
        destination: destination,
        profile: profile,
        steps: false, // Don't need detailed steps for duration only
        overview: false,
        includeTrafficData: includeTrafficData,
      );

      return route.totalDuration;
    } catch (e) {
      if (e is RouteException) rethrow;
      throw ErrorHandler.handleHttpException(e as Exception);
    }
  }

  /// Fetches a route optimized for traffic conditions
  Future<RouteData> getTrafficOptimizedRoute({
    required Waypoint origin,
    required Waypoint destination,
    List<Waypoint>? waypoints,
    String? language,
  }) async {
    return getRouteFromWaypoints(
      origin: origin,
      destination: destination,
      waypoints: waypoints,
      profile: 'driving-traffic',
      includeTrafficData: true,
      language: language ?? _language,
    );
  }

  /// Fetches multiple traffic-optimized alternative routes
  Future<List<RouteData>> getTrafficOptimizedAlternatives({
    required Waypoint origin,
    required Waypoint destination,
    List<Waypoint>? waypoints,
    int maxAlternatives = 3,
    String? language,
  }) async {
    return getAlternativeRoutesFromWaypoints(
      origin: origin,
      destination: destination,
      waypoints: waypoints,
      profile: 'driving-traffic',
      maxAlternatives: maxAlternatives,
      language: language ?? _language,
      includeTrafficData: true,
    );
  }

  /// Disposes of the HTTP client (only if we own it)
  void dispose() {
    if (_ownsHttpClient) {
      _httpClient.close();
    }
  }
}

/// Exception thrown by Mapbox Directions API operations
class MapboxDirectionsException implements Exception {
  final String message;
  final int statusCode;

  const MapboxDirectionsException(this.message, this.statusCode);

  @override
  String toString() => 'MapboxDirectionsException: $message (HTTP $statusCode)';
}
