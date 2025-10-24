import 'location_point.dart';

/// Navigation maneuver information
class Maneuver {
  /// Type of maneuver (turn, exit, merge, etc.)
  final ManeuverType type;

  /// Modifier (left, right, straight, etc.)
  final ManeuverModifier? modifier;

  /// Human-readable instruction text
  final String instruction;

  /// Distance from start of step to maneuver point (meters)
  final double distanceToManeuver;

  /// Bearing before maneuver (degrees)
  final double? bearingBefore;

  /// Bearing after maneuver (degrees)
  final double? bearingAfter;

  /// Location of maneuver point
  final LocationPoint location;

  /// Step number in the route
  final int stepIndex;

  /// Leg number in the route
  final int legIndex;

  const Maneuver({
    required this.type,
    this.modifier,
    required this.instruction,
    required this.distanceToManeuver,
    this.bearingBefore,
    this.bearingAfter,
    required this.location,
    required this.stepIndex,
    required this.legIndex,
  });

  /// Creates a maneuver from Mapbox Directions API response
  factory Maneuver.fromMapbox(
    Map<String, dynamic> json,
    int stepIndex,
    int legIndex,
  ) {
    final maneuver = json['maneuver'] as Map<String, dynamic>;
    final location = maneuver['location'] as List;

    return Maneuver(
      type: _parseManeuverType(maneuver['type'] as String),
      modifier: maneuver['modifier'] != null
          ? _parseManeuverModifier(maneuver['modifier'] as String)
          : null,
      instruction: json['maneuver']['instruction'] as String? ?? '',
      distanceToManeuver:
          (maneuver['bearing_before'] as num?)?.toDouble() ?? 0.0,
      bearingBefore: (maneuver['bearing_before'] as num?)?.toDouble(),
      bearingAfter: (maneuver['bearing_after'] as num?)?.toDouble(),
      location: LocationPoint(
        latitude: location[1] as double,
        longitude: location[0] as double,
        timestamp: DateTime.now(),
      ),
      stepIndex: stepIndex,
      legIndex: legIndex,
    );
  }

  /// Gets a short instruction for display (e.g., "Turn right")
  String get shortInstruction {
    if (modifier != null) {
      return '${modifier?.name} ${type.name}';
    }
    return type.name;
  }

  /// Gets icon name for UI representation
  String get iconName {
    if (modifier != null) {
      return '${modifier?.value}_${type.value}';
    }
    return type.value;
  }

  @override
  String toString() {
    return 'Maneuver(type: $type, modifier: $modifier, instruction: $instruction)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Maneuver &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          modifier == other.modifier &&
          instruction == other.instruction &&
          stepIndex == other.stepIndex &&
          legIndex == other.legIndex;

  @override
  int get hashCode =>
      Object.hash(type, modifier, instruction, stepIndex, legIndex);

  static ManeuverType _parseManeuverType(String type) {
    switch (type.toLowerCase()) {
      case 'turn':
        return ManeuverType.turn;
      case 'new name':
        return ManeuverType.newName;
      case 'depart':
        return ManeuverType.depart;
      case 'arrive':
        return ManeuverType.arrive;
      case 'merge':
        return ManeuverType.merge;
      case 'on ramp':
        return ManeuverType.onRamp;
      case 'off ramp':
        return ManeuverType.offRamp;
      case 'fork':
        return ManeuverType.fork;
      case 'roundabout':
        return ManeuverType.roundabout;
      case 'roundabout turn':
        return ManeuverType.roundaboutTurn;
      case 'roundabout exit':
        return ManeuverType.roundaboutExit;
      case 'notification':
        return ManeuverType.notification;
      case 'exit roundabout':
        return ManeuverType.exitRoundabout;
      case 'exit rotary':
        return ManeuverType.exitRotary;
      default:
        return ManeuverType.turn;
    }
  }

  static ManeuverModifier? _parseManeuverModifier(String? modifier) {
    if (modifier == null) return null;

    switch (modifier.toLowerCase()) {
      case 'uturn':
        return ManeuverModifier.uTurn;
      case 'sharp right':
        return ManeuverModifier.sharpRight;
      case 'right':
        return ManeuverModifier.right;
      case 'slight right':
        return ManeuverModifier.slightRight;
      case 'straight':
        return ManeuverModifier.straight;
      case 'slight left':
        return ManeuverModifier.slightLeft;
      case 'left':
        return ManeuverModifier.left;
      case 'sharp left':
        return ManeuverModifier.sharpLeft;
      default:
        return null;
    }
  }
}

/// Maneuver type enumeration
enum ManeuverType {
  turn,
  newName,
  depart,
  arrive,
  merge,
  onRamp,
  offRamp,
  fork,
  roundabout,
  roundaboutTurn,
  roundaboutExit,
  notification,
  exitRoundabout,
  exitRotary;

  String get value {
    switch (this) {
      case ManeuverType.turn:
        return 'turn';
      case ManeuverType.newName:
        return 'new_name';
      case ManeuverType.depart:
        return 'depart';
      case ManeuverType.arrive:
        return 'arrive';
      case ManeuverType.merge:
        return 'merge';
      case ManeuverType.onRamp:
        return 'on_ramp';
      case ManeuverType.offRamp:
        return 'off_ramp';
      case ManeuverType.fork:
        return 'fork';
      case ManeuverType.roundabout:
        return 'roundabout';
      case ManeuverType.roundaboutTurn:
        return 'roundabout_turn';
      case ManeuverType.roundaboutExit:
        return 'roundabout_exit';
      case ManeuverType.notification:
        return 'notification';
      case ManeuverType.exitRoundabout:
        return 'exit_roundabout';
      case ManeuverType.exitRotary:
        return 'exit_rotary';
    }
  }

  String get name {
    switch (this) {
      case ManeuverType.turn:
        return 'Turn';
      case ManeuverType.newName:
        return 'Continue';
      case ManeuverType.depart:
        return 'Depart';
      case ManeuverType.arrive:
        return 'Arrive';
      case ManeuverType.merge:
        return 'Merge';
      case ManeuverType.onRamp:
        return 'On ramp';
      case ManeuverType.offRamp:
        return 'Off ramp';
      case ManeuverType.fork:
        return 'Fork';
      case ManeuverType.roundabout:
        return 'Roundabout';
      case ManeuverType.roundaboutTurn:
        return 'Roundabout turn';
      case ManeuverType.roundaboutExit:
        return 'Roundabout exit';
      case ManeuverType.notification:
        return 'Notification';
      case ManeuverType.exitRoundabout:
        return 'Exit roundabout';
      case ManeuverType.exitRotary:
        return 'Exit rotary';
    }
  }
}

/// Maneuver modifier enumeration
enum ManeuverModifier {
  uTurn,
  sharpRight,
  right,
  slightRight,
  straight,
  slightLeft,
  left,
  sharpLeft;

  String get value {
    switch (this) {
      case ManeuverModifier.uTurn:
        return 'uturn';
      case ManeuverModifier.sharpRight:
        return 'sharp_right';
      case ManeuverModifier.right:
        return 'right';
      case ManeuverModifier.slightRight:
        return 'slight_right';
      case ManeuverModifier.straight:
        return 'straight';
      case ManeuverModifier.slightLeft:
        return 'slight_left';
      case ManeuverModifier.left:
        return 'left';
      case ManeuverModifier.sharpLeft:
        return 'sharp_left';
    }
  }

  String get name {
    switch (this) {
      case ManeuverModifier.uTurn:
        return 'U-turn';
      case ManeuverModifier.sharpRight:
        return 'Sharp right';
      case ManeuverModifier.right:
        return 'Right';
      case ManeuverModifier.slightRight:
        return 'Slight right';
      case ManeuverModifier.straight:
        return 'Straight';
      case ManeuverModifier.slightLeft:
        return 'Slight left';
      case ManeuverModifier.left:
        return 'Left';
      case ManeuverModifier.sharpLeft:
        return 'Sharp left';
    }
  }
}
