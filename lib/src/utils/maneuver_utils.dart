import 'package:flutter/material.dart';

/// Utility class for handling navigation maneuver types and their visual representations
class ManeuverUtils {
  /// Maps maneuver types to appropriate Material Design icons
  ///
  /// Handles various maneuver types including turns, merges, roundabouts, etc.
  static IconData getManeuverIcon(String maneuver) {
    switch (maneuver.toLowerCase()) {
      // Left turns
      case 'turn-left':
      case 'slight-left':
      case 'sharp-left':
      case 'slight left':
      case 'sharp left':
        return Icons.turn_left;

      // Right turns
      case 'turn':
      case 'turn-right':
      case 'slight-right':
      case 'sharp-right':
      case 'slight right':
      case 'sharp right':
        return Icons.turn_right;

      // Specific turn directions
      case 'turn_sharp_right':
        return Icons.turn_sharp_right;
      case 'turn_slight_right':
        return Icons.turn_slight_right;
      case 'turn_sharp_left':
        return Icons.turn_sharp_left;
      case 'turn_slight_left':
        return Icons.turn_slight_left;

      // Straight movements
      case 'straight':
      case 'continue':
        return Icons.straight;

      // U-turns
      case 'uturn':
      case 'u-turn':
        return Icons.u_turn_left;
      case 'u_turn_right':
        return Icons.u_turn_right;

      // Highway maneuvers
      case 'merge':
        return Icons.merge;
      case 'on ramp':
      case 'off ramp':
      case 'on_ramp':
      case 'off_ramp':
        return Icons.ramp_right;

      // Intersections
      case 'fork':
        return Icons.call_split;
      case 'roundabout':
      case 'roundabout_right':
        return Icons.roundabout_right;
      case 'roundabout_left':
        return Icons.roundabout_left;

      // Destination
      case 'arrive':
      case 'destination':
        return Icons.flag;

      // Default
      default:
        return Icons.navigation;
    }
  }

  /// Gets a color associated with the maneuver type
  static Color getManeuverColor(String maneuver) {
    switch (maneuver.toLowerCase()) {
      case 'arrive':
      case 'destination':
        return Colors.green;
      case 'uturn':
      case 'u-turn':
        return Colors.orange;
      case 'roundabout':
      case 'roundabout_right':
      case 'roundabout_left':
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }

  /// Gets a human-readable description of the maneuver
  static String getManeuverDescription(String maneuver) {
    switch (maneuver.toLowerCase()) {
      case 'turn-left':
      case 'turn_left':
        return 'Turn left';
      case 'turn-right':
      case 'turn_right':
      case 'turn':
        return 'Turn right';
      case 'slight-left':
      case 'slight_left':
        return 'Slight left';
      case 'slight-right':
      case 'slight_right':
        return 'Slight right';
      case 'sharp-left':
      case 'sharp_left':
        return 'Sharp left';
      case 'sharp-right':
      case 'sharp_right':
        return 'Sharp right';
      case 'straight':
      case 'continue':
        return 'Continue straight';
      case 'uturn':
      case 'u-turn':
        return 'Make a U-turn';
      case 'merge':
        return 'Merge';
      case 'on ramp':
      case 'on_ramp':
        return 'Take the ramp';
      case 'off ramp':
      case 'off_ramp':
        return 'Exit the highway';
      case 'fork':
        return 'Keep to the fork';
      case 'roundabout':
      case 'roundabout_right':
        return 'Enter the roundabout';
      case 'arrive':
      case 'destination':
        return 'Arrive at destination';
      default:
        return 'Continue';
    }
  }

  /// Normalizes maneuver type strings to a consistent format
  static String normalizeManeuverType(String maneuver) {
    return maneuver.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_');
  }
}
