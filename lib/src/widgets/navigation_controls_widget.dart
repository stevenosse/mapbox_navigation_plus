import 'package:flutter/material.dart';
import '../controllers/navigation_controller.dart';
import '../services/voice_instruction_service.dart';
import '../utils/constants.dart' as nav_constants;

/// Callback types for navigation control actions
typedef VoidCallback = void Function();
typedef BoolCallback = void Function(bool value);

/// A customizable widget that provides navigation control buttons
class NavigationControlsWidget extends StatelessWidget {
  /// The navigation controller for accessing navigation functions
  final NavigationController? navigationController;

  /// The voice instruction service for voice toggle functionality
  final VoiceInstructionService? voiceService;

  /// Whether voice guidance is currently enabled
  final bool isVoiceEnabled;

  /// Callback for voice toggle button
  final BoolCallback? onVoiceToggle;

  /// Callback for zoom in button
  final VoidCallback? onZoomIn;

  /// Callback for zoom out button
  final VoidCallback? onZoomOut;

  /// Callback for route recalculation button
  final VoidCallback? onRecalculateRoute;

  /// Custom styling for the controls widget
  final NavigationControlsStyle? style;

  /// Whether to show the voice toggle button
  final bool showVoiceToggle;

  /// Whether to show the zoom controls
  final bool showZoomControls;

  /// Whether to show the recalculate route button
  final bool showRecalculateButton;

  /// Custom positioning for the controls
  final NavigationControlsPosition position;

  const NavigationControlsWidget({
    super.key,
    this.navigationController,
    this.voiceService,
    this.isVoiceEnabled = false,
    this.onVoiceToggle,
    this.onZoomIn,
    this.onZoomOut,
    this.onRecalculateRoute,
    this.style,
    this.showVoiceToggle = true,
    this.showZoomControls = true,
    this.showRecalculateButton = true,
    this.position = NavigationControlsPosition.rightCenter,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = style ?? NavigationControlsStyle.defaultStyle();

    return Container(
      margin: effectiveStyle.margin,
      padding: effectiveStyle.padding,
      decoration: effectiveStyle.decoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Voice toggle button
          if (showVoiceToggle) _buildVoiceToggleButton(effectiveStyle),

          // Spacing between buttons
          if (showVoiceToggle && (showZoomControls || showRecalculateButton))
            SizedBox(height: effectiveStyle.buttonSpacing),

          // Zoom controls
          if (showZoomControls) ..._buildZoomControls(effectiveStyle),

          // Spacing between zoom and recalculate
          if (showZoomControls && showRecalculateButton)
            SizedBox(height: effectiveStyle.buttonSpacing),

          // Recalculate route button
          if (showRecalculateButton) _buildRecalculateButton(effectiveStyle),
        ],
      ),
    );
  }

  Widget _buildVoiceToggleButton(NavigationControlsStyle style) {
    return _buildControlButton(
      icon: isVoiceEnabled ? Icons.volume_up : Icons.volume_off,
      onPressed: () => onVoiceToggle?.call(!isVoiceEnabled),
      style: style,
      isActive: isVoiceEnabled,
      tooltip:
          isVoiceEnabled ? 'Turn off voice guidance' : 'Turn on voice guidance',
    );
  }

  List<Widget> _buildZoomControls(NavigationControlsStyle style) {
    return [
      _buildControlButton(
        icon: Icons.add,
        onPressed: onZoomIn,
        style: style,
        tooltip: 'Zoom in',
      ),
      SizedBox(height: style.buttonSpacing),
      _buildControlButton(
        icon: Icons.remove,
        onPressed: onZoomOut,
        style: style,
        tooltip: 'Zoom out',
      ),
    ];
  }

  Widget _buildRecalculateButton(NavigationControlsStyle style) {
    return _buildControlButton(
      icon: Icons.refresh,
      onPressed: onRecalculateRoute,
      style: style,
      tooltip: 'Recalculate route',
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required NavigationControlsStyle style,
    bool isActive = false,
    String? tooltip,
  }) {
    final button = Material(
      color: isActive ? style.activeButtonColor : style.buttonColor,
      borderRadius: BorderRadius.circular(style.buttonRadius),
      elevation: style.buttonElevation,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(style.buttonRadius),
        child: Container(
          width: style.buttonSize,
          height: style.buttonSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(style.buttonRadius),
            border: isActive
                ? Border.all(
                    color: style.activeBorderColor,
                    width: style.activeBorderWidth,
                  )
                : null,
          ),
          child: Icon(
            icon,
            color: isActive ? style.activeIconColor : style.iconColor,
            size: style.iconSize,
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip,
        child: button,
      );
    }

    return button;
  }
}

/// Positioning options for navigation controls
enum NavigationControlsPosition {
  topLeft,
  topRight,
  centerLeft,
  centerRight,
  bottomLeft,
  bottomRight,
  rightCenter, // Default - right side, vertically centered
}

/// Styling configuration for the navigation controls widget
class NavigationControlsStyle {
  final EdgeInsets margin;
  final EdgeInsets padding;
  final Decoration decoration;
  final double buttonSize;
  final double buttonRadius;
  final double buttonElevation;
  final double buttonSpacing;
  final double iconSize;
  final Color buttonColor;
  final Color activeButtonColor;
  final Color iconColor;
  final Color activeIconColor;
  final Color activeBorderColor;
  final double activeBorderWidth;

  const NavigationControlsStyle({
    required this.margin,
    required this.padding,
    required this.decoration,
    required this.buttonSize,
    required this.buttonRadius,
    required this.buttonElevation,
    required this.buttonSpacing,
    required this.iconSize,
    required this.buttonColor,
    required this.activeButtonColor,
    required this.iconColor,
    required this.activeIconColor,
    required this.activeBorderColor,
    required this.activeBorderWidth,
  });

  factory NavigationControlsStyle.defaultStyle() {
    return NavigationControlsStyle(
      margin: const EdgeInsets.only(right: 16, top: 100),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      buttonSize: 48,
      buttonRadius: 8,
      buttonElevation: 2,
      buttonSpacing: 8,
      iconSize: nav_constants.NavigationConstants.iconSize,
      buttonColor: Colors.white,
      activeButtonColor: Colors.blue,
      iconColor: Colors.black87,
      activeIconColor: Colors.white,
      activeBorderColor: Colors.blue,
      activeBorderWidth: 2,
    );
  }

  NavigationControlsStyle copyWith({
    EdgeInsets? margin,
    EdgeInsets? padding,
    Decoration? decoration,
    double? buttonSize,
    double? buttonRadius,
    double? buttonElevation,
    double? buttonSpacing,
    double? iconSize,
    Color? buttonColor,
    Color? activeButtonColor,
    Color? iconColor,
    Color? activeIconColor,
    Color? activeBorderColor,
    double? activeBorderWidth,
  }) {
    return NavigationControlsStyle(
      margin: margin ?? this.margin,
      padding: padding ?? this.padding,
      decoration: decoration ?? this.decoration,
      buttonSize: buttonSize ?? this.buttonSize,
      buttonRadius: buttonRadius ?? this.buttonRadius,
      buttonElevation: buttonElevation ?? this.buttonElevation,
      buttonSpacing: buttonSpacing ?? this.buttonSpacing,
      iconSize: iconSize ?? this.iconSize,
      buttonColor: buttonColor ?? this.buttonColor,
      activeButtonColor: activeButtonColor ?? this.activeButtonColor,
      iconColor: iconColor ?? this.iconColor,
      activeIconColor: activeIconColor ?? this.activeIconColor,
      activeBorderColor: activeBorderColor ?? this.activeBorderColor,
      activeBorderWidth: activeBorderWidth ?? this.activeBorderWidth,
    );
  }
}
