import 'package:flutter/material.dart';

/// A widget that displays the current speed limit in a circular road sign style
class SpeedLimitWidget extends StatelessWidget {
  /// The speed limit value to display
  final int? speedLimit;

  /// The unit of speed measurement (mph or km/h)
  final SpeedUnit unit;

  /// Custom styling for the speed limit widget
  final SpeedLimitStyle? style;

  /// Whether the widget is visible
  final bool isVisible;

  /// Callback when the widget is tapped
  final VoidCallback? onTap;

  const SpeedLimitWidget({
    super.key,
    this.speedLimit,
    this.unit = SpeedUnit.mph,
    this.style,
    this.isVisible = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible || speedLimit == null) {
      return const SizedBox.shrink();
    }

    final effectiveStyle = style ?? SpeedLimitStyle.defaultStyle();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: effectiveStyle.size,
        height: effectiveStyle.size,
        decoration: BoxDecoration(
          color: effectiveStyle.backgroundColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: effectiveStyle.borderColor,
            width: effectiveStyle.borderWidth,
          ),
          boxShadow: effectiveStyle.shadows,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              speedLimit.toString(),
              style: effectiveStyle.speedTextStyle,
            ),
            Text(
              unit == SpeedUnit.mph ? 'mph' : 'km/h',
              style: effectiveStyle.unitTextStyle,
            ),
          ],
        ),
      ),
    );
  }
}

/// Speed measurement units
enum SpeedUnit {
  mph,
  kmh,
}

/// Styling configuration for the speed limit widget
class SpeedLimitStyle {
  final double size;
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;
  final TextStyle speedTextStyle;
  final TextStyle unitTextStyle;
  final List<BoxShadow> shadows;

  const SpeedLimitStyle({
    required this.size,
    required this.backgroundColor,
    required this.borderColor,
    required this.borderWidth,
    required this.speedTextStyle,
    required this.unitTextStyle,
    required this.shadows,
  });

  factory SpeedLimitStyle.defaultStyle() {
    return SpeedLimitStyle(
      size: 60,
      backgroundColor: Colors.white,
      borderColor: Colors.black,
      borderWidth: 3,
      speedTextStyle: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.black,
        height: 1.0,
      ),
      unitTextStyle: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: Colors.black,
        height: 1.0,
      ),
      shadows: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.2),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  SpeedLimitStyle copyWith({
    double? size,
    Color? backgroundColor,
    Color? borderColor,
    double? borderWidth,
    TextStyle? speedTextStyle,
    TextStyle? unitTextStyle,
    List<BoxShadow>? shadows,
  }) {
    return SpeedLimitStyle(
      size: size ?? this.size,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      borderColor: borderColor ?? this.borderColor,
      borderWidth: borderWidth ?? this.borderWidth,
      speedTextStyle: speedTextStyle ?? this.speedTextStyle,
      unitTextStyle: unitTextStyle ?? this.unitTextStyle,
      shadows: shadows ?? this.shadows,
    );
  }
}
