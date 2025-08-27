import 'package:flutter/material.dart';

/// Constants used throughout the navigation package
class NavigationConstants {
  // Camera configuration
  static const double defaultZoom = 17.0;
  static const double defaultPitch = 60.0;
  static const double defaultBearing = 180;
  static const double minZoom = 8.0;
  static const double maxZoom = 20.0;
  static const double minPitch = 0.0;
  static const double maxPitch = 85.0;

  // Animation durations (in milliseconds)
  static const int cameraAnimationDuration = 1000;
  static const int animationDuration = 800;
  static const int quickAnimationDuration = 300;
  static const int fastAnimationDuration = 500;
  static const int slowAnimationDuration = 2000;

  // Camera pitch settings
  static const double overviewPitch = 0.0;
  static const double navigationPitch = 60.0;

  // Distance thresholds (in meters)
  static const double stepAdvanceThreshold = 30.0;
  static const double offRouteThreshold = 50.0;
  static const double recalculationThreshold = 100.0;
  static const double arrivalThreshold = 20.0;

  static const double locationAccuracyThreshold = 10.0;
  static const int locationUpdateInterval = 100;
  static const double simulationSpeed = 10.0;

  // UI dimensions
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double cardElevation = 8.0;
  static const double smallCardElevation = 4.0;
  static const double iconSize = 24.0;
  static const double largeIconSize = 32.0;
  static const double smallIconSize = 16.0;

  // Map configuration
  static const String defaultStyleUri = 'mapbox://styles/mapbox/streets-v12';
  static const double defaultLatitude = 37.7749;
  static const double defaultLongitude = -122.4194;

  // API configuration
  static const String mapboxDirectionsBaseUrl =
      'https://api.mapbox.com/directions/v5/mapbox';
  static const String drivingProfile = 'driving';
  static const String walkingProfile = 'walking';
  static const String cyclingProfile = 'cycling';
  static const String drivingTrafficProfile = 'driving-traffic';

  // Error messages
  static const String locationPermissionDenied = 'Location permission denied';
  static const String locationServiceDisabled = 'Location service disabled';
  static const String routeCalculationFailed = 'Failed to calculate route';
  static const String navigationNotStarted = 'Navigation not started';
  static const String invalidDestination = 'Invalid destination';

  // Formatting
  static const int distanceDecimalPlaces = 1;
  static const int coordinateDecimalPlaces = 6;
  static const double metersToKilometers = 1000.0;
  static const double secondsToMinutes = 60.0;
  static const double minutesToHours = 60.0;
  static const double mpsToKmh = 3.6;
}

/// Navigation status colors
class NavigationColors {
  static const idleColor = 0xFF9E9E9E;
  static const calculatingColor = 0xFFFF9800;
  static const navigatingColor = 0xFF4CAF50;
  static const pausedColor = 0xFFFFEB3B;
  static const arrivedColor = 0xFF2196F3;
  static const errorColor = 0xFFF44336;
}

class NavigationTypography {
  // Instruction banner text
  static const double instructionTitleSize = 24.0;
  static const double instructionSubtitleSize = 20.0;
  static const FontWeight instructionTitleWeight = FontWeight.bold;
  static const FontWeight instructionSubtitleWeight = FontWeight.w600;

  // Control and status text
  static const double statusTextSize = 14.0;
  static const double progressTextSize = 16.0;
  static const double hintTextSize = 12.0;
  static const FontWeight statusTextWeight = FontWeight.w500;
  static const FontWeight progressTextWeight = FontWeight.bold;

  // Bottom bar text
  static const double timeTextSize = 18.0;
  static const double bottomProgressTextSize = 12.0;
  static const FontWeight timeTextWeight = FontWeight.bold;
  static const FontWeight bottomProgressTextWeight = FontWeight.w500;

  // Speed limit text
  static const double speedLimitNumberSize = 20.0;
  static const double speedLimitUnitSize = 10.0;
  static const FontWeight speedLimitNumberWeight = FontWeight.bold;
  static const FontWeight speedLimitUnitWeight = FontWeight.w600;
}

class NavigationUIColors {
  // Primary navigation blue gradient
  static const navigationBlueStart = 0xFF4A90E2;
  static const navigationBlueEnd = 0xFF357ABD;

  // Dark overlays for controls
  static const darkOverlay = 0xB3000000;
  static const darkOverlayLight = 0x80000000;

  // Button backgrounds
  static const buttonOverlay = 0x33FFFFFF;
  static const activeButtonOverlay = 0x4D2196F3;

  // Text colors on dark backgrounds
  static const primaryTextOnDark = 0xFFFFFFFF;
  static const secondaryTextOnDark = 0xB3FFFFFF;
  static const hintTextOnDark = 0x80FFFFFF;

  // Speed limit widget colors
  static const speedLimitBackground = 0xFFFFFFFF;
  static const speedLimitBorder = 0xFF000000;
  static const speedLimitText = 0xFF000000;
}

/// Route visualization constants
class RouteVisualizationConstants {
  static const double routeBorderWidth = 16.0;
  static const double routeTraveledWidth = 15.0;
  static const double routeRemainingWidth = 15.0;
  static const int routeBorderColor = 0xFF1976D2;
  static const int routeDefaultColor = 0xFF2196F3;
  static const int routeTraveledColor = 0xFF9E9E9E;

  // Traffic congestion colors
  static const int trafficSevereColor = 0xFFDC143C;
  static const int trafficHeavyColor = 0xFFFF6347;
  static const int trafficModerateColor = 0xFFFFD700;
  static const int trafficLightColor = 0xFF32CD32;

  // Route visualization settings
  static const double maxRouteLineWidth = 24.0;
  static const double minRouteLineWidth = 8.0;
  static const double routeOpacity = 0.95;

  // GeoJSON properties
  static const String routeSourcePrefix = 'route-source-';
  static const String routeLayerPrefix = 'route-layer-';
  static const String routeBorderLayerPrefix = 'route-border-layer-';

  // Enhanced update intervals for ultra-smooth tracing
  static const int routeUpdateIntervalMs = 50;
  static const int trafficUpdateIntervalMs = 15000;
  static const int routeRecalculationIntervalMs = 300000;
  static const int locationTrackingIntervalMs = 100;
}

/// Voice instruction constants
class VoiceConstants {
  // Default voice settings
  static const double defaultSpeechRate = 0.5;
  static const double defaultPitch = 1.0;
  static const double defaultVolume = 1.0;
  static const String defaultLanguage = 'en-US';

  // Speech rate limits
  static const double minSpeechRate = 0.3;
  static const double maxSpeechRate = 1.0;

  // Pitch limits
  static const double minPitch = 0.5;
  static const double maxPitch = 2.0;

  // Volume limits
  static const double minVolume = 0.0;
  static const double maxVolume = 1.0;

  // Timing constants
  static const int defaultMinimumInterval = 10000;
  static const int urgentInstructionTimeout = 5000;
  static const int ttsInitializationTimeout = 3000;

  // Distance thresholds for voice announcements (meters)
  static const List<double> defaultAnnouncementDistances = [500.0, 200.0, 50.0];
  static const List<double> highwayAnnouncementDistances = [
    1000.0,
    500.0,
    200.0
  ];
  static const List<double> cityAnnouncementDistances = [300.0, 100.0, 30.0];

  // Voice instruction priorities
  static const int priorityLow = 1;
  static const int priorityNormal = 2;
  static const int priorityHigh = 3;
  static const int priorityUrgent = 4;

  // TTS engine preferences (in order of preference)
  static const List<String> preferredTTSEngines = [
    'com.google.android.tts',
    'com.apple.speech.synthesis',
    'com.samsung.android.bixby.voicewakeup',
    'system_default',
  ];

  // Supported languages with their display names
  static const Map<String, String> supportedLanguages = {
    'en-US': 'English (US)',
    'en-GB': 'English (UK)',
    'es-ES': 'Spanish (Spain)',
    'es-MX': 'Spanish (Mexico)',
    'fr-FR': 'French (France)',
    'de-DE': 'German (Germany)',
    'it-IT': 'Italian (Italy)',
    'pt-BR': 'Portuguese (Brazil)',
    'ja-JP': 'Japanese (Japan)',
    'ko-KR': 'Korean (South Korea)',
    'zh-CN': 'Chinese (Simplified)',
    'ru-RU': 'Russian (Russia)',
  };

  // Audio session categories for different platforms
  static const String iosAudioCategory = 'AVAudioSessionCategoryPlayback';
  static const String androidAudioUsage =
      'USAGE_ASSISTANCE_NAVIGATION_GUIDANCE';

  // Voice instruction types
  static const String instructionTypeStart = 'navigation_start';
  static const String instructionTypeManeuver = 'maneuver';
  static const String instructionTypeArrival = 'arrival';
  static const String instructionTypeRecalculation = 'recalculation';
  static const String instructionTypeOffRoute = 'off_route';
}
