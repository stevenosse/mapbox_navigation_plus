import 'dart:ui';

/// Comprehensive route styling configuration
class RouteStyleConfig {
  /// Style for the main route line
  final RouteLineStyle routeLineStyle;
  
  /// Style for the traveled portion of the route
  final RouteLineStyle traveledLineStyle;
  
  /// Style for the remaining portion of the route
  final RouteLineStyle remainingLineStyle;
  
  /// Style for alternative routes (if any)
  final RouteLineStyle? alternativeLineStyle;

  const RouteStyleConfig({
    required this.routeLineStyle,
    required this.traveledLineStyle,
    required this.remainingLineStyle,
    this.alternativeLineStyle,
  });

  /// Default route styling configuration
  static const RouteStyleConfig defaultConfig = RouteStyleConfig(
    routeLineStyle: RouteLineStyle(
      color: Color(0xFF3366CC),
      width: 24.0,
      opacity: 0.8,
    ),
    traveledLineStyle: RouteLineStyle(
      color: Color(0xFF999999),
      width: 24.0,
      opacity: 0.7,
    ),
    remainingLineStyle: RouteLineStyle(
      color: Color(0xFF00AA00),
      width: 24.0,
      opacity: 1.0,
    ),
    alternativeLineStyle: RouteLineStyle(
      color: Color(0xFFCCCCCC),
      width: 15.0,
      opacity: 0.6,
    ),
  );

  /// Create a copy with modified properties
  RouteStyleConfig copyWith({
    RouteLineStyle? routeLineStyle,
    RouteLineStyle? traveledLineStyle,
    RouteLineStyle? remainingLineStyle,
    RouteLineStyle? alternativeLineStyle,
  }) {
    return RouteStyleConfig(
      routeLineStyle: routeLineStyle ?? this.routeLineStyle,
      traveledLineStyle: traveledLineStyle ?? this.traveledLineStyle,
      remainingLineStyle: remainingLineStyle ?? this.remainingLineStyle,
      alternativeLineStyle: alternativeLineStyle ?? this.alternativeLineStyle,
    );
  }
}

/// Individual route line styling options
class RouteLineStyle {
  /// Line color
  final Color color;
  
  /// Line width in pixels
  final double width;
  
  /// Line opacity (0.0 to 1.0)
  final double opacity;
  
  /// Line cap style
  final LineCapStyle capStyle;
  
  /// Line join style
  final LineJoinStyle joinStyle;

  const RouteLineStyle({
    required this.color,
    required this.width,
    this.opacity = 1.0,
    this.capStyle = LineCapStyle.round,
    this.joinStyle = LineJoinStyle.round,
  });

  /// Convert color to hex string for Mapbox
  String get colorHex {
    final int argb = (color.a * 255).round() << 24 |
                     (color.r * 255).round() << 16 |
                     (color.g * 255).round() << 8 |
                     (color.b * 255).round();
    return '#${argb.toRadixString(16).padLeft(8, '0').substring(2)}';
  }

  /// Creates a copy with modified values
  RouteLineStyle copyWith({
    Color? color,
    double? width,
    double? opacity,
    LineCapStyle? capStyle,
    LineJoinStyle? joinStyle,
  }) {
    return RouteLineStyle(
      color: color ?? this.color,
      width: width ?? this.width,
      opacity: opacity ?? this.opacity,
      capStyle: capStyle ?? this.capStyle,
      joinStyle: joinStyle ?? this.joinStyle,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RouteLineStyle &&
        other.color == color &&
        other.width == width &&
        other.opacity == opacity &&
        other.capStyle == capStyle &&
        other.joinStyle == joinStyle;
  }

  @override
  int get hashCode {
    return Object.hash(color, width, opacity, capStyle, joinStyle);
  }
}

/// Line cap style options
enum LineCapStyle {
  butt('butt'),
  round('round'),
  square('square');

  const LineCapStyle(this.value);
  final String value;
}

/// Line join style options
enum LineJoinStyle {
  bevel('bevel'),
  round('round'),
  miter('miter');

  const LineJoinStyle(this.value);
  final String value;
}

/// Predefined route style themes
class RouteStyleThemes {
  /// Default blue theme
  static const RouteStyleConfig defaultTheme = RouteStyleConfig.defaultConfig;

  /// Dark theme with bright colors
  static const RouteStyleConfig darkTheme = RouteStyleConfig(
    routeLineStyle: RouteLineStyle(
      color: Color(0xFF00D4FF),
      width: 12.0,
      opacity: 0.9,
    ),
    traveledLineStyle: RouteLineStyle(
      color: Color(0xFF666666),
      width: 12.0,
      opacity: 0.8,
    ),
    remainingLineStyle: RouteLineStyle(
      color: Color(0xFF00FF88),
      width: 12.0,
      opacity: 1.0,
    ),
    alternativeLineStyle: RouteLineStyle(
      color: Color(0xFF888888),
      width: 10.0,
      opacity: 0.6,
    ),
  );

  /// High contrast theme for accessibility
  static const RouteStyleConfig highContrastTheme = RouteStyleConfig(
    routeLineStyle: RouteLineStyle(
      color: Color(0xFF000000),
      width: 14.0,
      opacity: 1.0,
    ),
    traveledLineStyle: RouteLineStyle(
      color: Color(0xFF444444),
      width: 14.0,
      opacity: 1.0,
    ),
    remainingLineStyle: RouteLineStyle(
      color: Color(0xFF000000),
      width: 14.0,
      opacity: 1.0,
    ),
    alternativeLineStyle: RouteLineStyle(
      color: Color(0xFF888888),
      width: 12.0,
      opacity: 0.8,
    ),
  );

  /// Colorful theme
  static const RouteStyleConfig colorfulTheme = RouteStyleConfig(
    routeLineStyle: RouteLineStyle(
      color: Color(0xFFFF6B35),
      width: 12.0,
      opacity: 0.9,
    ),
    traveledLineStyle: RouteLineStyle(
      color: Color(0xFFB19CD9),
      width: 12.0,
      opacity: 0.8,
    ),
    remainingLineStyle: RouteLineStyle(
      color: Color(0xFF4ECDC4),
      width: 12.0,
      opacity: 1.0,
    ),
    alternativeLineStyle: RouteLineStyle(
      color: Color(0xFFFFC75F),
      width: 10.0,
      opacity: 0.7,
    ),
  );
}