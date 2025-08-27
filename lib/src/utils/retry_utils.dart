import 'dart:async';
import 'dart:math';

/// Utility for handling retries with exponential backoff
class RetryUtils {
  /// Executes a function with retry logic and exponential backoff
  static Future<T> executeWithRetry<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    Duration initialDelay = const Duration(milliseconds: 500),
    double backoffMultiplier = 2.0,
    Duration maxDelay = const Duration(seconds: 10),
    bool Function(dynamic error)? retryWhen,
  }) async {
    int attempts = 0;
    Duration currentDelay = initialDelay;

    while (attempts <= maxRetries) {
      try {
        return await operation();
      } catch (error) {
        attempts++;
        
        // Don't retry if we've exceeded max attempts
        if (attempts > maxRetries) {
          rethrow;
        }

        // Don't retry if retryWhen condition fails
        if (retryWhen != null && !retryWhen(error)) {
          rethrow;
        }

        // Default retry conditions for network errors
        if (!_shouldRetryByDefault(error)) {
          rethrow;
        }

        // Wait before retrying with exponential backoff
        await Future.delayed(currentDelay);
        
        // Calculate next delay with jitter to avoid thundering herd
        final jitter = Random().nextDouble() * 0.1; // 10% jitter
        currentDelay = Duration(
          milliseconds: min(
            (currentDelay.inMilliseconds * backoffMultiplier * (1 + jitter)).round(),
            maxDelay.inMilliseconds,
          ),
        );
      }
    }

    // This should never be reached due to rethrow above
    throw StateError('Retry loop completed unexpectedly');
  }

  /// Default retry condition for common network and server errors
  static bool _shouldRetryByDefault(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    // Retry on common network errors
    if (errorString.contains('timeout') ||
        errorString.contains('connection') ||
        errorString.contains('network') ||
        errorString.contains('socket')) {
      return true;
    }

    // Retry on HTTP server errors (5xx)
    if (errorString.contains('500') ||
        errorString.contains('502') ||
        errorString.contains('503') ||
        errorString.contains('504')) {
      return true;
    }

    // Don't retry on client errors (4xx) by default
    return false;
  }

  /// Creates a retry condition for HTTP status codes
  static bool Function(dynamic) retryOnHttpErrors(List<int> retryStatusCodes) {
    return (error) {
      final errorString = error.toString();
      return retryStatusCodes.any((code) => errorString.contains(code.toString()));
    };
  }

  /// Creates a retry condition for specific error types
  static bool Function(dynamic) retryOnErrorTypes(List<Type> errorTypes) {
    return (error) {
      return errorTypes.any((type) => error.runtimeType == type);
    };
  }
}