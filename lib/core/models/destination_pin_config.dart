import 'package:flutter/material.dart';

/// Configuration for customizing destination pin appearance
class DestinationPinConfig {
  /// Image asset path for the destination pin
  final String? imagePath;

  /// Size of the destination pin in logical pixels
  final double size;

  /// Opacity of the destination pin (0.0 to 1.0)
  final double opacity;

  /// Anchor point for the pin (0.0 to 1.0 for both x and y)
  /// (0.5, 1.0) means center-bottom, which is typical for pins
  final Offset anchor;

  /// Whether to show a shadow under the pin
  final bool showShadow;

  /// Color of the shadow
  final Color shadowColor;

  /// Blur radius of the shadow
  final double shadowBlurRadius;

  /// Offset of the shadow
  final Offset shadowOffset;

  const DestinationPinConfig({
    this.imagePath,
    this.size = 32.0,
    this.opacity = 1.0,
    this.anchor = const Offset(0.5, 1.0),
    this.showShadow = true,
    this.shadowColor = const Color(0x40000000),
    this.shadowBlurRadius = 4.0,
    this.shadowOffset = const Offset(0, 2),
  });

  /// Default destination pin configuration
  static const DestinationPinConfig defaultConfig = DestinationPinConfig();

  /// Create a copy with modified properties
  DestinationPinConfig copyWith({
    String? imagePath,
    double? size,
    double? opacity,
    Offset? anchor,
    bool? showShadow,
    Color? shadowColor,
    double? shadowBlurRadius,
    Offset? shadowOffset,
  }) {
    return DestinationPinConfig(
      imagePath: imagePath ?? this.imagePath,
      size: size ?? this.size,
      opacity: opacity ?? this.opacity,
      anchor: anchor ?? this.anchor,
      showShadow: showShadow ?? this.showShadow,
      shadowColor: shadowColor ?? this.shadowColor,
      shadowBlurRadius: shadowBlurRadius ?? this.shadowBlurRadius,
      shadowOffset: shadowOffset ?? this.shadowOffset,
    );
  }

  /// Convert to JSON for Mapbox native implementation
  Map<String, dynamic> toJson() {
    return {
      'imagePath': imagePath,
      'size': size,
      'opacity': opacity,
      'anchor': [anchor.dx, anchor.dy],
      'showShadow': showShadow,
      'shadowColor':
          '#${shadowColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
      'shadowBlurRadius': shadowBlurRadius,
      'shadowOffset': [shadowOffset.dx, shadowOffset.dy],
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DestinationPinConfig &&
        other.imagePath == imagePath &&
        other.size == size &&
        other.opacity == opacity &&
        other.anchor == anchor &&
        other.showShadow == showShadow &&
        other.shadowColor == shadowColor &&
        other.shadowBlurRadius == shadowBlurRadius &&
        other.shadowOffset == shadowOffset;
  }

  @override
  int get hashCode {
    return Object.hash(
      imagePath,
      size,
      opacity,
      anchor,
      showShadow,
      shadowColor,
      shadowBlurRadius,
      shadowOffset,
    );
  }

  @override
  String toString() {
    return 'DestinationPinConfig('
        'imagePath: $imagePath, '
        'size: $size, '
        'opacity: $opacity, '
        'anchor: $anchor, '
        'showShadow: $showShadow, '
        'shadowColor: $shadowColor, '
        'shadowBlurRadius: $shadowBlurRadius, '
        'shadowOffset: $shadowOffset)';
  }
}

/// Predefined destination pin configurations
class DestinationPinThemes {
  /// Default destination pin
  static const DestinationPinConfig defaultTheme =
      DestinationPinConfig.defaultConfig;
}
