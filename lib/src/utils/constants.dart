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
  static const double overviewPitch = 0.0; // Top-down view
  static const double navigationPitch = 60.0; // 3D navigation view
  
  // Distance thresholds (in meters)
  static const double stepAdvanceThreshold = 30.0;
  static const double offRouteThreshold = 50.0;
  static const double recalculationThreshold = 100.0;
  static const double arrivalThreshold = 20.0;
  
  // Location tracking
  static const double locationAccuracyThreshold = 10.0;
  static const int locationUpdateInterval = 1000; // milliseconds
  static const double simulationSpeed = 10.0; // m/s
  
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
  static const double defaultLatitude = 37.7749; // San Francisco
  static const double defaultLongitude = -122.4194;
  
  // API configuration
  static const String mapboxDirectionsBaseUrl = 'https://api.mapbox.com/directions/v5/mapbox';
  static const String drivingProfile = 'driving';
  static const String walkingProfile = 'walking';
  static const String cyclingProfile = 'cycling';
  
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
  static const idleColor = 0xFF9E9E9E; // Grey
  static const calculatingColor = 0xFFFF9800; // Orange
  static const navigatingColor = 0xFF4CAF50; // Green
  static const pausedColor = 0xFFFFEB3B; // Yellow
  static const arrivedColor = 0xFF2196F3; // Blue
  static const errorColor = 0xFFF44336; // Red
}

/// Map style URIs
class MapboxStyles {
  static const String streets = 'mapbox://styles/mapbox/streets-v12';
  static const String outdoors = 'mapbox://styles/mapbox/outdoors-v12';
  static const String light = 'mapbox://styles/mapbox/light-v11';
  static const String dark = 'mapbox://styles/mapbox/dark-v11';
  static const String satellite = 'mapbox://styles/mapbox/satellite-v9';
  static const String satelliteStreets = 'mapbox://styles/mapbox/satellite-streets-v12';
  static const String navigation = 'mapbox://styles/mapbox/navigation-day-v1';
  static const String navigationNight = 'mapbox://styles/mapbox/navigation-night-v1';
}

/// Route visualization constants
class RouteVisualizationConstants {
  // Route line styling
  static const double routeBorderWidth = 12.0;
  static const double routeTraveledWidth = 12.0;
  static const int routeBorderColor = 0xFF1A1A1A; // Dark gray border
  static const int routeDefaultColor = 0xFF007AFF; // Blue remaining route
  static const int routeTraveledColor = 0xFF9E9E9E; // Gray traveled route
  
  // Traffic congestion colors
  static const int trafficSevereColor = 0xFFDC143C; // Dark red for severe traffic
  static const int trafficHeavyColor = 0xFFFF6347; // Red-orange for heavy traffic
  static const int trafficModerateColor = 0xFFFFD700; // Yellow for moderate traffic
  static const int trafficLightColor = 0xFF32CD32; // Green for light traffic
  
  // Route visualization settings
  static const double maxRouteLineWidth = 24.0;
  static const double minRouteLineWidth = 4.0;
  static const double routeOpacity = 0.8;
  
  // GeoJSON properties
  static const String routeSourcePrefix = 'route-source-';
  static const String routeLayerPrefix = 'route-layer-';
  static const String routeBorderLayerPrefix = 'route-border-layer-';
  
  // Traffic update intervals
  static const int trafficUpdateIntervalMs = 30000; // 30 seconds
  static const int routeRecalculationIntervalMs = 300000; // 5 minutes
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
  static const int defaultMinimumInterval = 10000; // 10 seconds between instructions
  static const int urgentInstructionTimeout = 5000; // 5 seconds for urgent instructions
  static const int ttsInitializationTimeout = 3000; // 3 seconds to initialize TTS
  
  // Distance thresholds for voice announcements (meters)
  static const List<double> defaultAnnouncementDistances = [500.0, 200.0, 50.0];
  static const List<double> highwayAnnouncementDistances = [1000.0, 500.0, 200.0];
  static const List<double> cityAnnouncementDistances = [300.0, 100.0, 30.0];
  
  // Voice instruction priorities
  static const int priorityLow = 1;
  static const int priorityNormal = 2;
  static const int priorityHigh = 3;
  static const int priorityUrgent = 4;
  
  // TTS engine preferences (in order of preference)
  static const List<String> preferredTTSEngines = [
    'com.google.android.tts',     // Google TTS (Android)
    'com.apple.speech.synthesis', // Apple TTS (iOS)
    'com.samsung.android.bixby.voicewakeup', // Samsung TTS
    'system_default',             // System default
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
  static const String androidAudioUsage = 'USAGE_ASSISTANCE_NAVIGATION_GUIDANCE';
  
  // Voice instruction types
  static const String instructionTypeStart = 'navigation_start';
  static const String instructionTypeManeuver = 'maneuver';
  static const String instructionTypeArrival = 'arrival';
  static const String instructionTypeRecalculation = 'recalculation';
  static const String instructionTypeOffRoute = 'off_route';
}