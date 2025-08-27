import 'package:flutter/material.dart';
import '../models/navigation_step.dart';
import '../models/route_data.dart';
import '../utils/maneuver_utils.dart';
import '../utils/formatting_utils.dart';
import '../utils/constants.dart' as nav_constants;

/// A customizable widget that displays turn-by-turn navigation instructions
class NavigationInstructionWidget extends StatelessWidget {
  /// The current navigation step to display
  final NavigationStep? currentStep;

  /// The next navigation step (optional)
  final NavigationStep? nextStep;

  /// The complete route data for additional context
  final RouteData? route;

  /// Remaining distance to destination
  final double? remainingDistance;

  /// Remaining time to destination
  final double? remainingTime;

  /// Custom styling for the instruction widget
  final NavigationInstructionStyle? style;

  /// Whether to show the next step preview
  final bool showNextStep;

  /// Whether to show remaining distance and time
  final bool showProgress;

  const NavigationInstructionWidget({
    super.key,
    this.currentStep,
    this.nextStep,
    this.route,
    this.remainingDistance,
    this.remainingTime,
    this.style,
    this.showNextStep = true,
    this.showProgress = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = style ?? NavigationInstructionStyle.defaultStyle();

    return Container(
      margin: effectiveStyle.margin,
      padding: effectiveStyle.padding,
      decoration: effectiveStyle.decoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current instruction
          _buildCurrentInstruction(effectiveStyle),

          // Progress information
          if (showProgress &&
              (remainingDistance != null || remainingTime != null))
            _buildProgressInfo(effectiveStyle),

          // Next step preview
          if (showNextStep && nextStep != null)
            _buildNextStepPreview(effectiveStyle),
        ],
      ),
    );
  }

  Widget _buildCurrentInstruction(NavigationInstructionStyle style) {
    if (currentStep == null) {
      return Text(
        'No navigation active',
        style: style.instructionTextStyle,
      );
    }

    return Row(
      children: [
        // Maneuver icon
        Container(
          width: 48,
          height: 48,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: style.iconBackgroundColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            ManeuverUtils.getManeuverIcon(currentStep!.maneuver),
            color: style.iconColor,
            size: nav_constants.NavigationConstants.iconSize,
          ),
        ),

        // Instruction text
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                currentStep!.instruction,
                style: style.instructionTextStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (currentStep!.distance > 0)
                Text(
                  FormattingUtils.formatDistance(currentStep!.distance),
                  style: style.distanceTextStyle,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressInfo(NavigationInstructionStyle style) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: style.progressBackgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          if (remainingDistance != null)
            Column(
              children: [
                Text(
                  'Distance',
                  style: style.progressLabelStyle,
                ),
                Text(
                  FormattingUtils.formatDistance(remainingDistance!),
                  style: style.progressValueStyle,
                ),
              ],
            ),
          if (remainingTime != null)
            Column(
              children: [
                Text(
                  'Time',
                  style: style.progressLabelStyle,
                ),
                Text(
                  FormattingUtils.formatDuration(remainingTime!),
                  style: style.progressValueStyle,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildNextStepPreview(NavigationInstructionStyle style) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: style.nextStepBackgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(
            ManeuverUtils.getManeuverIcon(nextStep!.maneuver),
            color: style.nextStepIconColor,
            size: nav_constants.NavigationConstants.smallIconSize,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Then ${nextStep!.instruction}',
              style: style.nextStepTextStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Styling configuration for the navigation instruction widget
class NavigationInstructionStyle {
  final EdgeInsets margin;
  final EdgeInsets padding;
  final Decoration decoration;
  final TextStyle instructionTextStyle;
  final TextStyle distanceTextStyle;
  final TextStyle nextStepTextStyle;
  final TextStyle progressLabelStyle;
  final TextStyle progressValueStyle;
  final Color iconColor;
  final Color iconBackgroundColor;
  final Color nextStepIconColor;
  final Color progressBackgroundColor;
  final Color nextStepBackgroundColor;

  const NavigationInstructionStyle({
    required this.margin,
    required this.padding,
    required this.decoration,
    required this.instructionTextStyle,
    required this.distanceTextStyle,
    required this.nextStepTextStyle,
    required this.progressLabelStyle,
    required this.progressValueStyle,
    required this.iconColor,
    required this.iconBackgroundColor,
    required this.nextStepIconColor,
    required this.progressBackgroundColor,
    required this.nextStepBackgroundColor,
  });

  factory NavigationInstructionStyle.defaultStyle() {
    return NavigationInstructionStyle(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      instructionTextStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
      distanceTextStyle: const TextStyle(
        fontSize: 14,
        color: Colors.blue,
        fontWeight: FontWeight.w500,
      ),
      nextStepTextStyle: const TextStyle(
        fontSize: 12,
        color: Colors.grey,
      ),
      progressLabelStyle: const TextStyle(
        fontSize: 10,
        color: Colors.grey,
        fontWeight: FontWeight.w500,
      ),
      progressValueStyle: const TextStyle(
        fontSize: 14,
        color: Colors.black87,
        fontWeight: FontWeight.w600,
      ),
      iconColor: Colors.white,
      iconBackgroundColor: Colors.blue,
      nextStepIconColor: Colors.grey,
      progressBackgroundColor: Colors.grey.withValues(alpha: 0.1),
      nextStepBackgroundColor: Colors.grey.withValues(alpha: 0.05),
    );
  }

  NavigationInstructionStyle copyWith({
    EdgeInsets? margin,
    EdgeInsets? padding,
    Decoration? decoration,
    TextStyle? instructionTextStyle,
    TextStyle? distanceTextStyle,
    TextStyle? nextStepTextStyle,
    TextStyle? progressLabelStyle,
    TextStyle? progressValueStyle,
    Color? iconColor,
    Color? iconBackgroundColor,
    Color? nextStepIconColor,
    Color? progressBackgroundColor,
    Color? nextStepBackgroundColor,
  }) {
    return NavigationInstructionStyle(
      margin: margin ?? this.margin,
      padding: padding ?? this.padding,
      decoration: decoration ?? this.decoration,
      instructionTextStyle: instructionTextStyle ?? this.instructionTextStyle,
      distanceTextStyle: distanceTextStyle ?? this.distanceTextStyle,
      nextStepTextStyle: nextStepTextStyle ?? this.nextStepTextStyle,
      progressLabelStyle: progressLabelStyle ?? this.progressLabelStyle,
      progressValueStyle: progressValueStyle ?? this.progressValueStyle,
      iconColor: iconColor ?? this.iconColor,
      iconBackgroundColor: iconBackgroundColor ?? this.iconBackgroundColor,
      nextStepIconColor: nextStepIconColor ?? this.nextStepIconColor,
      progressBackgroundColor:
          progressBackgroundColor ?? this.progressBackgroundColor,
      nextStepBackgroundColor:
          nextStepBackgroundColor ?? this.nextStepBackgroundColor,
    );
  }
}
