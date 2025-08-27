/// Utility functions for formatting distances, durations, and other navigation data
class FormattingUtils {
  /// Formats distance in meters to a human-readable string
  /// 
  /// Returns meters for distances < 1000m, kilometers for larger distances
  static String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }

  /// Formats duration in seconds to a human-readable string
  /// 
  /// Returns minutes for durations < 60 minutes, hours and minutes for longer durations
  static String formatDuration(double seconds) {
    final minutes = (seconds / 60).round();
    if (minutes < 60) {
      return '$minutes min';
    } else {
      final hours = (minutes / 60).floor();
      final remainingMinutes = minutes % 60;
      return '${hours}h ${remainingMinutes}m';
    }
  }

  /// Formats speed in m/s to km/h
  static String formatSpeed(double metersPerSecond) {
    final kmh = (metersPerSecond * 3.6).round();
    return '$kmh km/h';
  }

  /// Formats bearing in degrees to cardinal direction
  static String formatBearing(double degrees) {
    const directions = [
      'N', 'NNE', 'NE', 'ENE',
      'E', 'ESE', 'SE', 'SSE',
      'S', 'SSW', 'SW', 'WSW',
      'W', 'WNW', 'NW', 'NNW'
    ];
    
    final index = ((degrees + 11.25) / 22.5).floor() % 16;
    return directions[index];
  }

  /// Formats progress as a percentage
  static String formatProgress(double progress) {
    final percentage = (progress * 100).round();
    return '$percentage%';
  }

  /// Formats coordinates to a readable string
  static String formatCoordinates(double latitude, double longitude) {
    return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
  }
}