/// Voice instruction settings for navigation
class VoiceSettings {
  /// Whether voice instructions are enabled
  final bool enabled;

  /// Speech rate (0.3 to 1.0, where 0.5 is normal speed)
  final double speechRate;

  /// Voice pitch (0.5 to 2.0, where 1.0 is normal pitch)
  final double pitch;

  /// Voice volume (0.0 to 1.0)
  final double volume;

  /// Language code for voice instructions (e.g., 'en-US', 'es-ES')
  final String language;

  /// Minimum interval between voice instructions in milliseconds
  final int minimumInterval;

  /// Distance thresholds for voice announcements in meters
  final List<double> announcementDistances;

  /// Whether to announce arrival at destination
  final bool announceArrival;

  /// Whether to announce route recalculation
  final bool announceRouteRecalculation;

  const VoiceSettings({
    this.enabled = true,
    this.speechRate = 0.5,
    this.pitch = 1.0,
    this.volume = 1.0,
    this.language = 'en-US',
    this.minimumInterval = 20000, // 20 seconds
    this.announcementDistances = const [800.0, 300.0, 100.0],
    this.announceArrival = true,
    this.announceRouteRecalculation = true,
  });

  /// Creates default voice settings
  factory VoiceSettings.defaults({String? language}) {
    return VoiceSettings(language: language ?? 'en-US');
  }

  /// Creates voice settings optimized for highway driving
  factory VoiceSettings.highway({String? language}) {
    return VoiceSettings(
      language: language ?? 'en-US',
      speechRate: 0.6,
      announcementDistances: [
        1000.0,
        500.0,
        200.0
      ], // Earlier warnings for high speed
      minimumInterval: 25000, // Longer intervals for highway
    );
  }

  /// Creates voice settings optimized for city driving
  factory VoiceSettings.city() {
    return const VoiceSettings(
      speechRate: 0.5,
      announcementDistances: [400.0, 150.0], // Fewer city announcements
      minimumInterval: 15000, // Less frequent updates in city
    );
  }

  /// Creates a copy of settings with updated properties
  VoiceSettings copyWith({
    bool? enabled,
    double? speechRate,
    double? pitch,
    double? volume,
    String? language,
    int? minimumInterval,
    List<double>? announcementDistances,
    bool? announceArrival,
    bool? announceRouteRecalculation,
  }) {
    return VoiceSettings(
      enabled: enabled ?? this.enabled,
      speechRate: speechRate ?? this.speechRate,
      pitch: pitch ?? this.pitch,
      volume: volume ?? this.volume,
      language: language ?? this.language,
      minimumInterval: minimumInterval ?? this.minimumInterval,
      announcementDistances:
          announcementDistances ?? this.announcementDistances,
      announceArrival: announceArrival ?? this.announceArrival,
      announceRouteRecalculation:
          announceRouteRecalculation ?? this.announceRouteRecalculation,
    );
  }

  /// Validates that settings values are within acceptable ranges
  bool get isValid {
    return speechRate >= 0.3 &&
        speechRate <= 1.0 &&
        pitch >= 0.5 &&
        pitch <= 2.0 &&
        volume >= 0.0 &&
        volume <= 1.0 &&
        minimumInterval >= 5000 && // At least 5 seconds
        announcementDistances.isNotEmpty &&
        announcementDistances.every((distance) => distance > 0);
  }

  @override
  String toString() {
    return 'VoiceSettings(enabled: $enabled, rate: $speechRate, pitch: $pitch, volume: $volume, language: $language)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VoiceSettings &&
        other.enabled == enabled &&
        other.speechRate == speechRate &&
        other.pitch == pitch &&
        other.volume == volume &&
        other.language == language &&
        other.minimumInterval == minimumInterval &&
        _listEquals(other.announcementDistances, announcementDistances) &&
        other.announceArrival == announceArrival &&
        other.announceRouteRecalculation == announceRouteRecalculation;
  }

  @override
  int get hashCode {
    return Object.hash(
      enabled,
      speechRate,
      pitch,
      volume,
      language,
      minimumInterval,
      Object.hashAll(announcementDistances),
      announceArrival,
      announceRouteRecalculation,
    );
  }

  /// Helper method to compare lists
  bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
