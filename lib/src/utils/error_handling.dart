import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'constants.dart';
import 'logger.dart';

/// Custom exceptions for the navigation package
class NavigationException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;
  final StackTrace? stackTrace;

  const NavigationException(
    this.message, {
    this.code,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() {
    if (code != null) {
      return 'NavigationException [$code]: $message';
    }
    return 'NavigationException: $message';
  }
}

/// Location-related exceptions
class LocationException extends NavigationException {
  const LocationException(
    super.message, {
    super.code,
    super.originalError,
    super.stackTrace,
  });

  factory LocationException.permissionDenied() {
    return const LocationException(
      NavigationConstants.locationPermissionDenied,
      code: 'PERMISSION_DENIED',
    );
  }

  factory LocationException.serviceDisabled() {
    return const LocationException(
      NavigationConstants.locationServiceDisabled,
      code: 'SERVICE_DISABLED',
    );
  }

  factory LocationException.timeout() {
    return const LocationException(
      'Location request timed out',
      code: 'TIMEOUT',
    );
  }

  factory LocationException.accuracyTooLow(double accuracy) {
    return LocationException(
      'Location accuracy too low: ${accuracy}m',
      code: 'ACCURACY_TOO_LOW',
    );
  }
}

/// Route calculation exceptions
class RouteException extends NavigationException {
  const RouteException(
    super.message, {
    super.code,
    super.originalError,
    super.stackTrace,
  });

  factory RouteException.calculationFailed([String? details]) {
    return RouteException(
      details != null
          ? '${NavigationConstants.routeCalculationFailed}: $details'
          : NavigationConstants.routeCalculationFailed,
      code: 'CALCULATION_FAILED',
    );
  }

  factory RouteException.invalidDestination() {
    return const RouteException(
      NavigationConstants.invalidDestination,
      code: 'INVALID_DESTINATION',
    );
  }

  factory RouteException.noRouteFound() {
    return const RouteException(
      'No route found between the specified points',
      code: 'NO_ROUTE_FOUND',
    );
  }

  factory RouteException.apiError(int statusCode, String? message) {
    return RouteException(
      'API error ($statusCode): ${message ?? "Unknown error"}',
      code: 'API_ERROR',
    );
  }
}

/// Navigation state exceptions
class NavigationStateException extends NavigationException {
  const NavigationStateException(
    super.message, {
    super.code,
    super.originalError,
    super.stackTrace,
  });

  factory NavigationStateException.notStarted() {
    return const NavigationStateException(
      NavigationConstants.navigationNotStarted,
      code: 'NOT_STARTED',
    );
  }

  factory NavigationStateException.alreadyStarted() {
    return const NavigationStateException(
      'Navigation already started',
      code: 'ALREADY_STARTED',
    );
  }

  factory NavigationStateException.invalidState(String currentState) {
    return NavigationStateException(
      'Invalid navigation state: $currentState',
      code: 'INVALID_STATE',
    );
  }
}

/// Voice instruction exceptions
class VoiceException extends NavigationException {
  const VoiceException(
    super.message, {
    super.code,
    super.originalError,
    super.stackTrace,
  });

  factory VoiceException.initializationFailed([String? details]) {
    return VoiceException(
      details != null
          ? 'Voice service initialization failed: $details'
          : 'Voice service initialization failed',
      code: 'VOICE_INIT_FAILED',
    );
  }

  factory VoiceException.ttsNotAvailable() {
    return const VoiceException(
      'Text-to-speech service is not available',
      code: 'TTS_UNAVAILABLE',
    );
  }

  factory VoiceException.speakingFailed(String text) {
    return VoiceException(
      'Failed to speak instruction: $text',
      code: 'SPEAKING_FAILED',
    );
  }
}

/// Camera control exceptions
class CameraException extends NavigationException {
  const CameraException(
    super.message, {
    super.code,
    super.originalError,
    super.stackTrace,
  });

  factory CameraException.notInitialized() {
    return const CameraException(
      'Camera controller not initialized',
      code: 'NOT_INITIALIZED',
    );
  }

  factory CameraException.animationFailed() {
    return const CameraException(
      'Camera animation failed',
      code: 'ANIMATION_FAILED',
    );
  }
}

/// Validation exceptions
class ValidationException extends NavigationException {
  const ValidationException(
    super.message, {
    super.code,
    super.originalError,
    super.stackTrace,
  });

  factory ValidationException.invalidInput(String field, String value) {
    return ValidationException(
      'Invalid $field: $value',
      code: 'INVALID_INPUT',
    );
  }

  factory ValidationException.required(String field) {
    return ValidationException(
      'Required field missing: $field',
      code: 'REQUIRED_FIELD',
    );
  }
}

/// Utility class for error handling
class ErrorHandler {
  /// Handles location permission errors
  static LocationException handleLocationPermission(
      LocationPermission permission) {
    switch (permission) {
      case LocationPermission.denied:
      case LocationPermission.deniedForever:
        return LocationException.permissionDenied();
      case LocationPermission.unableToDetermine:
        return const LocationException(
          'Unable to determine location permission',
          code: 'PERMISSION_UNDETERMINED',
        );
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        throw ArgumentError(
            'Permission is granted, should not handle as error');
    }
  }

  /// Handles Geolocator exceptions
  static LocationException handleGeolocatorException(Exception error) {
    if (error is LocationServiceDisabledException) {
      return LocationException.serviceDisabled();
    }
    if (error is PermissionDeniedException) {
      return LocationException.permissionDenied();
    }

    return LocationException(
      'Location error: ${error.toString()}',
      code: 'UNKNOWN_LOCATION_ERROR',
      originalError: error,
    );
  }

  /// Handles HTTP exceptions
  static RouteException handleHttpException(Exception error) {
    if (error is SocketException) {
      return const RouteException(
        'Network connection failed',
        code: 'NETWORK_ERROR',
      );
    }
    if (error is HttpException) {
      return RouteException(
        'HTTP error: ${error.message}',
        code: 'HTTP_ERROR',
        originalError: error,
      );
    }

    return RouteException(
      'Network error: ${error.toString()}',
      code: 'UNKNOWN_NETWORK_ERROR',
      originalError: error,
    );
  }

  /// Validates and throws appropriate exceptions for invalid coordinates
  static void validateCoordinates(double latitude, double longitude) {
    if (latitude < -90 || latitude > 90) {
      throw const NavigationException(
        'Invalid latitude: must be between -90 and 90',
        code: 'INVALID_LATITUDE',
      );
    }
    if (longitude < -180 || longitude > 180) {
      throw const NavigationException(
        'Invalid longitude: must be between -180 and 180',
        code: 'INVALID_LONGITUDE',
      );
    }
  }

  /// Validates Mapbox access token
  static void validateMapboxToken(String? token) {
    if (token == null || token.isEmpty) {
      throw const NavigationException(
        'Mapbox access token is required',
        code: 'MISSING_TOKEN',
      );
    }
    if (!token.startsWith('pk.') && !token.startsWith('sk.')) {
      throw const NavigationException(
        'Invalid Mapbox access token format',
        code: 'INVALID_TOKEN_FORMAT',
      );
    }
  }

  /// Safely executes an async operation with error handling
  static Future<T> safeExecute<T>(
    Future<T> Function() operation, {
    String? context,
    T Function(Exception error)? fallback,
  }) async {
    try {
      return await operation();
    } on NavigationException {
      rethrow; // Re-throw our custom exceptions
    } catch (error, stackTrace) {
      final contextMessage = context != null ? '$context: ' : '';

      if (fallback != null && error is Exception) {
        return fallback(error);
      }

      throw NavigationException(
        '$contextMessage${error.toString()}',
        code: 'EXECUTION_ERROR',
        originalError: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Logs errors in a consistent format using the logging framework
  static void logError(
    NavigationException error, {
    String? context,
    Logger? logger,
  }) {
    final effectiveLogger = logger ?? NavigationLoggers.general;
    final contextPrefix = context != null ? '[$context] ' : '';
    final message = '$contextPrefix${error.message}';

    effectiveLogger.error(message, error.originalError, error.stackTrace);
  }

  /// Logs warnings using the logging framework
  static void logWarning(
    String message, {
    String? context,
    Logger? logger,
    Object? error,
  }) {
    final effectiveLogger = logger ?? NavigationLoggers.general;
    final contextPrefix = context != null ? '[$context] ' : '';
    final fullMessage = '$contextPrefix$message';

    effectiveLogger.warning(fullMessage, error);
  }
}

class MapboxDirectionsException implements Exception {
  final String message;
  final int statusCode;

  const MapboxDirectionsException(this.message, this.statusCode);

  @override
  String toString() => 'MapboxDirectionsException: $message (HTTP $statusCode)';
}
