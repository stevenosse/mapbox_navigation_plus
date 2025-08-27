# Mapbox Navigation Example

A comprehensive Flutter example demonstrating the core functionality of the `mapbox_navigation` package. This example showcases 3D turn-by-turn navigation with voice instructions, traffic data, and real-time location tracking.

## Features Demonstrated

- **3D Navigation View**: Interactive Mapbox map with 3D navigation capabilities
- **Turn-by-Turn Navigation**: Real-time navigation instructions and step updates
- **Voice Instructions**: Configurable voice guidance with multiple languages
- **Traffic Data**: Real-time traffic information for optimal routing
- **Location Tracking**: GPS-based location services with permission handling
- **Navigation State Management**: Complete navigation lifecycle management
- **Error Handling**: Comprehensive error handling and user feedback

## Prerequisites

### 1. Mapbox Access Token

You need a valid Mapbox access token to run this example:

1. Sign up for a free account at [mapbox.com](https://www.mapbox.com/)
2. Navigate to your [Account Dashboard](https://account.mapbox.com/)
3. Create a new access token or use your default public token
4. Copy the access token for use in the app

### 2. Development Environment

- Flutter SDK 3.0.0 or higher
- Dart SDK 3.0.0 or higher
- Android Studio / Xcode for platform-specific development
- A physical device (recommended for GPS testing)

## Setup Instructions

### 1. Clone and Navigate

```bash
# Navigate to the example directory
cd examples/navigation_example
```

### 2. Install Dependencies

```bash
# Get Flutter dependencies
flutter pub get
```

### 3. Configure Mapbox Access Token

Open `lib/main.dart` and replace the placeholder with your actual Mapbox access token:

```dart
// Replace with your Mapbox access token
const String mapboxAccessToken = 'YOUR_MAPBOX_ACCESS_TOKEN_HERE';
```

**⚠️ Security note**: For production apps, store your access token securely using environment variables or secure storage solutions. Never commit access tokens to version control.

### 4. Platform-Specific Setup

#### Android Setup

The example includes pre-configured Android permissions in `android/app/src/main/AndroidManifest.xml`:

- `ACCESS_FINE_LOCATION` - For precise GPS location
- `ACCESS_COARSE_LOCATION` - For network-based location
- `INTERNET` - For map tiles and routing API
- `FOREGROUND_SERVICE` - For background location tracking

#### iOS Setup

The example includes pre-configured iOS permissions in `ios/Runner/Info.plist`:

- `NSLocationWhenInUseUsageDescription` - Location access while using the app

### 5. Run the Example

```bash
# Run on connected device
flutter run

# Run on specific device
flutter devices
flutter run -d <device_id>
```

## Usage Guide

### Basic Navigation

1. **Launch the App**: The app opens with a map centered on San Francisco
2. **Grant Permissions**: Allow location permissions when prompted
3. **Start Navigation**: Tap the "Start Navigation" button to begin navigation from San Francisco to Los Angeles
4. **Follow Instructions**: The app will display turn-by-turn instructions and provide voice guidance
5. **Stop Navigation**: Use the "Stop Navigation" button to end the navigation session

### Understanding the Interface

- **Navigation Status**: Shows the current state (idle, calculating, navigating, etc.)
- **Current Instruction Card**: Displays the next maneuver with distance and duration
- **Map View**: Interactive 3D map with route visualization
- **Control Buttons**: Start/stop navigation controls

### Customizing the Example

#### Change Destination

Modify the waypoints in `lib/main.dart`:

```dart
final Waypoint _origin = Waypoint(
  latitude: YOUR_START_LATITUDE,
  longitude: YOUR_START_LONGITUDE,
  name: 'Your Start Location',
);

final Waypoint _destination = Waypoint(
  latitude: YOUR_END_LATITUDE,
  longitude: YOUR_END_LONGITUDE,
  name: 'Your Destination',
);
```

#### Adjust Voice Settings

Customize voice instructions in the `MapboxNavigationView`:

```dart
voiceSettings: const VoiceSettings(
  enabled: true,
  speechRate: 0.5,        // Speech speed (0.1 - 1.0)
  pitch: 1.0,             // Voice pitch (0.5 - 2.0)
  volume: 0.8,            // Volume level (0.0 - 1.0)
  language: 'en-US',      // Language code
  minimumInterval: 5,     // Minimum seconds between announcements
  announcementDistances: [1000, 500, 100], // Distances for announcements
  announceArrival: true,
  announceRouteRecalculation: true,
),
```

#### Enable/Disable Traffic Data

```dart
MapboxNavigationView(
  // ... other properties
  enableTrafficData: true, // Set to false to disable traffic
)
```

## Testing

### On Device

- **Physical Device**: Recommended for GPS testing and real navigation
- **Location Simulation**: Use device location simulation for testing different routes

### In Simulator

- **iOS Simulator**: Supports location simulation through Xcode
- **Android Emulator**: Enable location services and use mock locations

### Simulation Mode

The example includes simulation capabilities for testing:

```dart
MapboxNavigationView(
  // ... other properties
  simulationSpeed: 2.0, // 2x speed simulation for testing
)
```

## Troubleshooting

### Common Issues

1. **"Invalid Access Token" Error**
   - Verify your Mapbox access token is correct
   - Ensure the token has the necessary scopes
   - Check for any whitespace or formatting issues

2. **Location Permission Denied**
   - Grant location permissions in device settings
   - Restart the app after granting permissions
   - Check platform-specific permission configurations

3. **No Route Found**
   - Verify origin and destination coordinates are valid
   - Ensure there's a valid road network between points
   - Check internet connectivity for routing API calls

4. **Voice Instructions Not Working**
   - Check device volume settings
   - Verify text-to-speech is available on the device
   - Ensure voice settings are properly configured

### Debug Mode

Enable debug logging to troubleshoot issues:

```dart
// Add this to see detailed navigation logs
debugPrint('Navigation state: ${_navigationState.status}');
debugPrint('Current step: ${_currentStep?.instruction}');
```

## API Usage Examples

This example demonstrates key APIs from the `mapbox_navigation` package:

### Navigation Controller

```dart
// Start navigation
await _navigationController!.startNavigation(
  origin: _origin,
  destination: _destination,
  profile: 'driving-traffic',
);

// Stop navigation
await _navigationController!.stopNavigation();

// Listen to state changes
_navigationController!.stateStream.listen((state) {
  // Handle navigation state updates
});
```

### Navigation States

- `NavigationStatus.idle` - Navigation not started
- `NavigationStatus.calculating` - Route calculation in progress
- `NavigationStatus.navigating` - Active navigation
- `NavigationStatus.arrived` - Destination reached
- `NavigationStatus.error` - Navigation error occurred

## Next Steps

- Explore the main package documentation for advanced features
- Check out additional examples for specific use cases
- Integrate the package into your own Flutter applications
- Customize the UI and navigation behavior for your needs

## Support

For issues with this example:

1. Check the main package documentation
2. Review the troubleshooting section above
3. Create an issue on the project repository
4. Consult the Mapbox documentation for API-specific questions

---

**Note**: This example is designed for demonstration purposes. For production use, implement proper error handling, secure token storage, and user experience optimizations.