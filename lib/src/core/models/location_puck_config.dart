import 'package:flutter/material.dart';

/// Configuration for customizing location puck appearance
class LocationPuckConfig {
  /// Image asset path for the location puck when idle (not navigating)
  final String? idleImagePath;

  /// Image asset path for the location puck during navigation
  final String? navigationImagePath;

  /// Size of the location puck in logical pixels
  final double size;

  /// Opacity of the location puck (0.0 to 1.0)
  final double opacity;

  /// Whether to show accuracy circle around the location puck
  final bool showAccuracyCircle;

  /// Color of the accuracy circle
  final Color accuracyCircleColor;

  /// Opacity of the accuracy circle (0.0 to 1.0)
  final double accuracyCircleOpacity;

  const LocationPuckConfig({
    this.idleImagePath,
    this.navigationImagePath,
    this.size = 24.0,
    this.opacity = 1.0,
    this.showAccuracyCircle = true,
    this.accuracyCircleColor = const Color(0x4D3366CC),
    this.accuracyCircleOpacity = 0.3,
  });

  /// Default location puck configuration
  static const LocationPuckConfig defaultConfig = LocationPuckConfig();

  /// Create a copy with modified properties
  LocationPuckConfig copyWith({
    String? idleImagePath,
    String? navigationImagePath,
    double? size,
    double? opacity,
    bool? showAccuracyCircle,
    Color? accuracyCircleColor,
    double? accuracyCircleOpacity,
  }) {
    return LocationPuckConfig(
      idleImagePath: idleImagePath ?? this.idleImagePath,
      navigationImagePath: navigationImagePath ?? this.navigationImagePath,
      size: size ?? this.size,
      opacity: opacity ?? this.opacity,
      showAccuracyCircle: showAccuracyCircle ?? this.showAccuracyCircle,
      accuracyCircleColor: accuracyCircleColor ?? this.accuracyCircleColor,
      accuracyCircleOpacity:
          accuracyCircleOpacity ?? this.accuracyCircleOpacity,
    );
  }

  /// Convert to JSON for Mapbox native implementation
  Map<String, dynamic> toJson() {
    return {
      'idleImagePath': idleImagePath,
      'navigationImagePath': navigationImagePath,
      'size': size,
      'opacity': opacity,
      'showAccuracyCircle': showAccuracyCircle,
      'accuracyCircleColor':
          '#${accuracyCircleColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
      'accuracyCircleOpacity': accuracyCircleOpacity,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocationPuckConfig &&
        other.idleImagePath == idleImagePath &&
        other.navigationImagePath == navigationImagePath &&
        other.size == size &&
        other.opacity == opacity &&
        other.showAccuracyCircle == showAccuracyCircle &&
        other.accuracyCircleColor == accuracyCircleColor &&
        other.accuracyCircleOpacity == accuracyCircleOpacity;
  }

  @override
  int get hashCode {
    return Object.hash(
      idleImagePath,
      navigationImagePath,
      size,
      opacity,
      showAccuracyCircle,
      accuracyCircleColor,
      accuracyCircleOpacity,
    );
  }

  @override
  String toString() {
    return 'LocationPuckConfig('
        'idleImagePath: $idleImagePath, '
        'navigationImagePath: $navigationImagePath, '
        'size: $size, '
        'opacity: $opacity, '
        'showAccuracyCircle: $showAccuracyCircle, '
        'accuracyCircleColor: $accuracyCircleColor, '
        'accuracyCircleOpacity: $accuracyCircleOpacity)';
  }
}

/// Predefined location puck configurations
class LocationPuckThemes {
  /// Default blue location puck
  static const LocationPuckConfig defaultTheme =
      LocationPuckConfig.defaultConfig;
}
