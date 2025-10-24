/// Voice instruction for navigation
class VoiceInstruction {
  /// The announcement text to be spoken
  final String announcement;

  /// Distance along the route geometry where this instruction should be spoken
  final double distanceAlongGeometry;

  /// Optional SSML markup for enhanced speech
  final String? ssml;

  /// Language code for this instruction
  final String language;

  /// Whether this is a pre-maneuver instruction
  final bool isPreManeuver;

  /// Distance to maneuver when this should be spoken (meters)
  final double triggerDistance;

  const VoiceInstruction({
    required this.announcement,
    required this.distanceAlongGeometry,
    this.ssml,
    this.language = 'en',
    this.isPreManeuver = true,
    this.triggerDistance = 200.0,
  });

  /// Creates a voice instruction from Mapbox Directions API response
  factory VoiceInstruction.fromMapbox(Map<String, dynamic> json) {
    return VoiceInstruction(
      announcement: json['announcement'] as String? ?? '',
      distanceAlongGeometry: (json['distanceAlongGeometry'] as num?)?.toDouble() ?? 0.0,
      ssml: json['ssml'] as String?,
      language: json['language'] as String? ?? 'en',
    );
  }

  /// Gets the instruction for display (non-spoken format)
  String get displayText {
    // Remove SSML tags if present
    if (ssml != null) {
      return ssml!.replaceAll(RegExp(r'<[^>]*>'), '');
    }
    return announcement;
  }

  /// Determines if this instruction should be spoken at given distance
  bool shouldSpeakAt(double distanceToManeuver) {
    return distanceToManeuver <= triggerDistance;
  }

  @override
  String toString() {
    return 'VoiceInstruction(announcement: $announcement, distanceAlongGeometry: $distanceAlongGeometry)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VoiceInstruction &&
          runtimeType == other.runtimeType &&
          announcement == other.announcement &&
          distanceAlongGeometry == other.distanceAlongGeometry;

  @override
  int get hashCode => Object.hash(announcement, distanceAlongGeometry);
}