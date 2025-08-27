import 'package:flutter/material.dart';
import '../models/navigation_state.dart';
import '../utils/formatting_utils.dart';
import '../localization/navigation_localizations.dart';

/// A customizable widget that displays navigation status and progress information
class NavigationStatusWidget extends StatelessWidget {
  /// The current navigation state
  final NavigationState navigationState;

  /// Custom styling for the status widget
  final NavigationStatusStyle? style;

  /// Whether to show progress information (distance and time)
  final bool showProgress;

  /// Whether to show the status indicator dot
  final bool showStatusIndicator;

  /// Custom status text override
  final String? customStatusText;

  /// Callback for when the status widget is tapped
  final VoidCallback? onTap;

  const NavigationStatusWidget({
    super.key,
    required this.navigationState,
    this.style,
    this.showProgress = true,
    this.showStatusIndicator = true,
    this.customStatusText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = style ?? NavigationStatusStyle.defaultStyle();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: effectiveStyle.margin,
        padding: effectiveStyle.padding,
        decoration: effectiveStyle.decoration,
        child: Row(
          children: [
            // Status indicator and text
            Expanded(
              child: Row(
                children: [
                  if (showStatusIndicator)
                    _buildStatusIndicator(effectiveStyle),
                  if (showStatusIndicator) const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      customStatusText ?? _getStatusText(context),
                      style: effectiveStyle.statusTextStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Progress information
            if (showProgress &&
                navigationState.status == NavigationStatus.navigating)
              _buildProgressInfo(effectiveStyle),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(NavigationStatusStyle style) {
    Color indicatorColor;
    bool isAnimated = false;

    switch (navigationState.status) {
      case NavigationStatus.idle:
        indicatorColor = style.idleIndicatorColor;
        break;
      case NavigationStatus.calculating:
        indicatorColor = style.calculatingIndicatorColor;
        isAnimated = true;
        break;
      case NavigationStatus.navigating:
        indicatorColor = style.navigatingIndicatorColor;
        break;
      case NavigationStatus.paused:
        indicatorColor = style.pausedIndicatorColor;
        break;
      case NavigationStatus.arrived:
        indicatorColor = style.arrivedIndicatorColor;
        break;
      case NavigationStatus.error:
        indicatorColor = style.errorIndicatorColor;
        break;
    }

    Widget indicator = Container(
      width: style.indicatorSize,
      height: style.indicatorSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: indicatorColor,
      ),
    );

    if (isAnimated) {
      return _AnimatedStatusIndicator(
        color: indicatorColor,
        size: style.indicatorSize,
      );
    }

    return indicator;
  }

  Widget _buildProgressInfo(NavigationStatusStyle style) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (navigationState.remainingDistance > 0) ...[
          Text(
            FormattingUtils.formatDistance(navigationState.remainingDistance),
            style: style.progressTextStyle,
          ),
          const SizedBox(width: 8),
        ],
        if (navigationState.remainingDuration > 0)
          Text(
            FormattingUtils.formatDuration(navigationState.remainingDuration),
            style: style.progressTextStyle,
          ),
      ],
    );
  }

  String _getStatusText(BuildContext context) {
    final localizations = Localizations.of(context, NavigationLocalizations);

    // Fallback to English if localization is not available
    if (localizations == null) {
      switch (navigationState.status) {
        case NavigationStatus.idle:
          return 'Ready to navigate';
        case NavigationStatus.calculating:
          return 'Calculating route...';
        case NavigationStatus.navigating:
          return 'Navigating';
        case NavigationStatus.paused:
          return 'Navigation paused';
        case NavigationStatus.arrived:
          return 'Arrived at destination';
        case NavigationStatus.error:
          return 'Navigation error';
      }
    }

    switch (navigationState.status) {
      case NavigationStatus.idle:
        return localizations.readyToNavigate;
      case NavigationStatus.calculating:
        return localizations.calculatingRoute;
      case NavigationStatus.navigating:
        return localizations.navigating;
      case NavigationStatus.paused:
        return localizations.navigationPaused;
      case NavigationStatus.arrived:
        return localizations.arrivedAtDestination;
      case NavigationStatus.error:
        return localizations.navigationError;
    }
  }
}

/// Animated status indicator for calculating state
class _AnimatedStatusIndicator extends StatefulWidget {
  final Color color;
  final double size;

  const _AnimatedStatusIndicator({
    required this.color,
    required this.size,
  });

  @override
  State<_AnimatedStatusIndicator> createState() =>
      _AnimatedStatusIndicatorState();
}

class _AnimatedStatusIndicatorState extends State<_AnimatedStatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: _animation.value),
          ),
        );
      },
    );
  }
}

/// Styling configuration for the navigation status widget
class NavigationStatusStyle {
  final EdgeInsets margin;
  final EdgeInsets padding;
  final Decoration decoration;
  final TextStyle statusTextStyle;
  final TextStyle progressTextStyle;
  final double indicatorSize;
  final Color idleIndicatorColor;
  final Color calculatingIndicatorColor;
  final Color navigatingIndicatorColor;
  final Color pausedIndicatorColor;
  final Color arrivedIndicatorColor;
  final Color errorIndicatorColor;

  const NavigationStatusStyle({
    required this.margin,
    required this.padding,
    required this.decoration,
    required this.statusTextStyle,
    required this.progressTextStyle,
    required this.indicatorSize,
    required this.idleIndicatorColor,
    required this.calculatingIndicatorColor,
    required this.navigatingIndicatorColor,
    required this.pausedIndicatorColor,
    required this.arrivedIndicatorColor,
    required this.errorIndicatorColor,
  });

  factory NavigationStatusStyle.defaultStyle() {
    return NavigationStatusStyle(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      statusTextStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.black87,
      ),
      progressTextStyle: const TextStyle(
        fontSize: 12,
        color: Colors.black54,
        fontWeight: FontWeight.w400,
      ),
      indicatorSize: 8,
      idleIndicatorColor: Colors.grey,
      calculatingIndicatorColor: Colors.orange,
      navigatingIndicatorColor: Colors.green,
      pausedIndicatorColor: Colors.yellow,
      arrivedIndicatorColor: Colors.blue,
      errorIndicatorColor: Colors.red,
    );
  }

  NavigationStatusStyle copyWith({
    EdgeInsets? margin,
    EdgeInsets? padding,
    Decoration? decoration,
    TextStyle? statusTextStyle,
    TextStyle? progressTextStyle,
    double? indicatorSize,
    Color? idleIndicatorColor,
    Color? calculatingIndicatorColor,
    Color? navigatingIndicatorColor,
    Color? pausedIndicatorColor,
    Color? arrivedIndicatorColor,
    Color? errorIndicatorColor,
  }) {
    return NavigationStatusStyle(
      margin: margin ?? this.margin,
      padding: padding ?? this.padding,
      decoration: decoration ?? this.decoration,
      statusTextStyle: statusTextStyle ?? this.statusTextStyle,
      progressTextStyle: progressTextStyle ?? this.progressTextStyle,
      indicatorSize: indicatorSize ?? this.indicatorSize,
      idleIndicatorColor: idleIndicatorColor ?? this.idleIndicatorColor,
      calculatingIndicatorColor:
          calculatingIndicatorColor ?? this.calculatingIndicatorColor,
      navigatingIndicatorColor:
          navigatingIndicatorColor ?? this.navigatingIndicatorColor,
      pausedIndicatorColor: pausedIndicatorColor ?? this.pausedIndicatorColor,
      arrivedIndicatorColor:
          arrivedIndicatorColor ?? this.arrivedIndicatorColor,
      errorIndicatorColor: errorIndicatorColor ?? this.errorIndicatorColor,
    );
  }
}
