import 'dart:developer' as developer;

/// Log levels in order of severity
enum LogLevel {
  debug,
  info,
  warning,
  error,
}

/// A simple logging utility that replaces debug prints with structured logging
class Logger {
  final String _name;
  static LogLevel _globalLogLevel = LogLevel.info;
  static bool _enableLogging = true;

  const Logger(this._name);

  /// Sets the global log level - only logs at this level or higher will be output
  static void setLogLevel(LogLevel level) {
    _globalLogLevel = level;
  }

  /// Enables or disables all logging
  static void setLoggingEnabled(bool enabled) {
    _enableLogging = enabled;
  }

  /// Gets the current global log level
  static LogLevel get globalLogLevel => _globalLogLevel;

  /// Whether logging is enabled
  static bool get isLoggingEnabled => _enableLogging;

  /// Log a debug message
  void debug(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.debug, message, error, stackTrace);
  }

  /// Log an info message
  void info(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.info, message, error, stackTrace);
  }

  /// Log a warning message
  void warning(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.warning, message, error, stackTrace);
  }

  /// Log an error message
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.error, message, error, stackTrace);
  }

  /// Internal logging method
  void _log(LogLevel level, String message, Object? error, StackTrace? stackTrace) {
    if (!_enableLogging || level.index < _globalLogLevel.index) {
      return;
    }

    final timestamp = DateTime.now().toIso8601String();
    final levelName = level.name.toUpperCase();
    final logMessage = '[$timestamp] [$levelName] [$_name] $message';

    // Use developer.log for better integration with debugging tools
    developer.log(
      logMessage,
      time: DateTime.now(),
      level: _getLevelValue(level),
      name: _name,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Converts LogLevel to developer.log level value
  int _getLevelValue(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 500;
      case LogLevel.info:
        return 800;
      case LogLevel.warning:
        return 900;
      case LogLevel.error:
        return 1000;
    }
  }
}

/// Pre-configured loggers for different parts of the system
class NavigationLoggers {
  static const Logger location = Logger('Location');
  static const Logger navigation = Logger('Navigation');
  static const Logger voice = Logger('Voice');
  static const Logger routes = Logger('Routes');
  static const Logger camera = Logger('Camera');
  static const Logger visualization = Logger('Visualization');
  static const Logger api = Logger('API');
  static const Logger validation = Logger('Validation');
  static const Logger general = Logger('Navigation');

  /// Initialize logging configuration
  static void initialize({
    LogLevel logLevel = LogLevel.info,
    bool enabled = true,
  }) {
    Logger.setLogLevel(logLevel);
    Logger.setLoggingEnabled(enabled);
    
    general.info('Navigation logging initialized - Level: ${logLevel.name}, Enabled: $enabled');
  }

  /// Disable logging for production builds
  static void disableForProduction() {
    Logger.setLoggingEnabled(false);
  }

  /// Enable debug logging for development
  static void enableDebugLogging() {
    Logger.setLogLevel(LogLevel.debug);
    Logger.setLoggingEnabled(true);
  }
}