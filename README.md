# Mapbox Navigation Plus

A comprehensive Flutter navigation library that provides turn-by-turn navigation, route calculation, and map visualization using Mapbox services. This package offers a modular architecture with customizable components for building sophisticated navigation applications.

## Features

- **Turn-by-turn Navigation**: Real-time navigation with voice guidance and visual instructions
- **Route Calculation**: Calculate optimal routes using Mapbox Directions API with support for waypoints and routing options
- **Map Visualization**: Interactive maps with route lines, markers, and customizable styling
- **Location Tracking**: Real-time location updates with customizable location puck
- **Progress Tracking**: Detailed route progress information including distance, duration, and upcoming maneuvers
- **Voice Guidance**: Text-to-speech navigation instructions
- **Route Styling**: Customizable route appearance with multiple themes and styling options
- **Location Puck Customization**: Configurable location puck with different themes and styles
- **Destination Pin Styling**: Customizable destination markers with various design options
- **Waze-like Camera**: Immersive navigation experience with smooth camera transitions and road-based effects
- **Event-driven Architecture**: Stream-based updates for navigation state, progress, and events

## Getting Started

### Prerequisites

1. **Mapbox Access Token**: Get your access token from [Mapbox Account Dashboard](https://account.mapbox.com/access-tokens/)
2. **Flutter SDK**: Ensure you have Flutter SDK 3.9.2 or higher
3. **Platform Setup**: Follow platform-specific setup instructions for location services

### Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  mapbox_navigation_plus: ^0.0.1
  mapbox_maps_flutter: ^2.11.0
  location: ^8.0.1
  flutter_tts: ^4.2.3
  http: ^1.5.0
```

### Platform Configuration

#### Android

Add the following to your `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

#### iOS

Add the following to your `ios/Runner/Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs access to location for navigation</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>This app needs access to location for navigation</string>
```

### Mapbox Configuration

Set your Mapbox access token in your app:

```dart
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MapboxOptions.setAccessToken('YOUR_MAPBOX_ACCESS_TOKEN');
  runApp(MyApp());
}
```

## Usage

### Basic Navigation Setup

### Basic Navigation with Address Search

```dart
import 'package:flutter/material.dart';
import 'package:mapbox_navigation_plus/mapbox_navigation_plus.dart';
import 'package:geocoding/geocoding.dart';

class NavigationApp extends StatefulWidget {
  @override
  _NavigationAppState createState() => _NavigationAppState();
}

class _NavigationAppState extends State<NavigationApp> {
  NavigationController? _navigationController;
  MapboxMapController? _mapController;

  // Address search functionality
  final TextEditingController _addressController = TextEditingController();
  LocationPoint? _destination;
  String? _destinationAddress;
  bool _isSearching = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Navigation map widget
          NavigationView(
            mapboxAccessToken: 'YOUR_MAPBOX_ACCESS_TOKEN',
            initialCenter: LocationPoint.fromLatLng(37.7749, -122.4194),
            initialZoom: 16.0,
            onMapCreated: (controller) {
              _mapController = controller;
              _initializeNavigation();
            },
          ),

          // Address search and controls
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Destination:', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _addressController,
                            decoration: InputDecoration(
                              hintText: 'Enter address or place name',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.search),
                            ),
                            onSubmitted: (value) => _searchAddress(value),
                          ),
                        ),
                        SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _isSearching ? null : () => _searchAddress(_addressController.text),
                          child: _isSearching
                              ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : Text('Search'),
                        ),
                      ],
                    ),

                    if (_destinationAddress != null) ...[
                      SizedBox(height: 8),
                      Text('Selected: $_destinationAddress'),
                    ],

                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: _destination != null ? _startNavigation : null,
                          child: Text('Start Navigation'),
                        ),
                        ElevatedButton(
                          onPressed: _stopNavigation,
                          child: Text('Stop'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Address search using geocoding
  Future<void> _searchAddress(String address) async {
    if (address.trim().isEmpty) return;

    setState(() => _isSearching = true);

    try {
      List<Location> locations = await locationFromAddress(address);

      if (locations.isNotEmpty) {
        final location = locations.first;
        final destinationPoint = LocationPoint.fromLatLng(
          location.latitude,
          location.longitude,
        );

        // Get formatted address for display
        List<Placemark> placemarks = await placemarkFromCoordinates(
          location.latitude,
          location.longitude,
        );

        setState(() {
          _destination = destinationPoint;
          _destinationAddress = placemarks.isNotEmpty
              ? _formatAddress(placemarks.first)
              : address;
          _isSearching = false;
        });
      }
    } catch (e) {
      setState(() => _isSearching = false);
      // Handle error
    }
  }

  String _formatAddress(Placemark placemark) {
    final parts = <String>[];
    if (placemark.street?.isNotEmpty == true) parts.add(placemark.street!);
    if (placemark.locality?.isNotEmpty == true) parts.add(placemark.locality!);
    if (placemark.administrativeArea?.isNotEmpty == true) parts.add(placemark.administrativeArea!);
    if (placemark.country?.isNotEmpty == true) parts.add(placemark.country!);
    return parts.join(', ');
  }

  Future<void> _initializeNavigation() async {
    if (_mapController == null) return;

    // Create navigation services
    final locationProvider = DefaultLocationProvider();
    final progressTracker = DefaultRouteProgressTracker();
    final voiceGuidance = DefaultVoiceGuidance();

    // Initialize voice guidance
    await voiceGuidance.initialize();

    // Create navigation controller
    _navigationController = NavigationController(
      routingEngine: MapboxRoutingEngine(
        accessToken: 'YOUR_MAPBOX_ACCESS_TOKEN'
      ),
      locationProvider: locationProvider,
      progressTracker: progressTracker,
      voiceGuidance: voiceGuidance,
      mapController: _mapController!,
      routeStyleConfig: RouteStyleConfig.defaultConfig,
      locationPuckConfig: LocationPuckThemes.defaultTheme,
      destinationPinConfig: DestinationPinConfig.defaultConfig,
    );

    // Initialize location services
    await _navigationController!.initializeLocation();
  }

  Future<void> _startNavigation() async {
    if (_navigationController == null || _destination == null) return;

    final currentLocation = await _navigationController!.locationProvider.getCurrentLocation();
    if (currentLocation == null) return;

    final result = await _navigationController!.startNavigation(
      origin: currentLocation,
      destination: _destination!,
    );

    if (result.success) {
      print('Navigation started successfully!');
    } else {
      print('Failed to start navigation: ${result.message}');
    }
  }

  Future<void> _stopNavigation() async {
    await _navigationController?.stopNavigation();
  }

  @override
  void dispose() {
    _navigationController?.dispose();
    _addressController.dispose();
    super.dispose();
  }
}
```

### Advanced Navigation with Custom Styling

```dart
class AdvancedNavigationExample extends StatefulWidget {
  @override
  _AdvancedNavigationExampleState createState() => _AdvancedNavigationExampleState();
}

class _AdvancedNavigationExampleState extends State<AdvancedNavigationExample>
    implements NavigationEventListener {

  NavigationController? _navigationController;
  NavigationState _currentState = NavigationState.idle;
  RouteProgress? _currentProgress;

  // Custom route styling
  final RouteStyleConfig _customStyle = RouteStyleConfig(
    routeLineStyle: RouteLineStyle(
      color: Color(0xFF2196F3),
      width: 12.0,
      opacity: 0.9,
      capStyle: LineCapStyle.round,
      joinStyle: LineJoinStyle.round,
    ),
    traveledLineStyle: RouteLineStyle(
      color: Color(0xFF4CAF50),
      width: 12.0,
      opacity: 0.8,
    ),
    remainingLineStyle: RouteLineStyle(
      color: Color(0xFF2196F3),
      width: 12.0,
      opacity: 1.0,
    ),
  );

  Future<void> _initializeAdvancedNavigation() async {
    // Create navigation controller with custom styling
    _navigationController = NavigationController(
      routingEngine: MapboxRoutingEngine(
        accessToken: 'YOUR_MAPBOX_ACCESS_TOKEN'
      ),
      locationProvider: DefaultLocationProvider(),
      progressTracker: DefaultRouteProgressTracker(),
      voiceGuidance: DefaultVoiceGuidance(),
      mapController: _mapController!,
      routeStyleConfig: _customStyle,
      locationPuckConfig: LocationPuckThemes.defaultTheme,
      destinationPinConfig: DestinationPinConfig.defaultConfig,
    );

    // Add navigation event listener
    _navigationController!.addNavigationListener(this);

    // Listen to navigation state changes
    _navigationController!.stateStream.listen((state) {
      setState(() {
        _currentState = state;
      });
    });

    // Listen to progress updates
    _navigationController!.progressStream.listen((progress) {
      setState(() {
        _currentProgress = progress;
      });
    });

    await _navigationController!.initializeLocation();
  }

  // Start navigation with waypoints and custom options
  Future<void> _startAdvancedNavigation() async {
    final origin = LocationPoint.fromLatLng(37.7749, -122.4194);
    final destination = LocationPoint.fromLatLng(37.7849, -122.4094);
    final waypoints = [
      LocationPoint.fromLatLng(37.7799, -122.4144), // Waypoint
    ];

    final routingOptions = RoutingOptions(
      profile: RouteProfile.driving,
      alternatives: false,
      steps: true,
      voiceInstructions: true,
      bannerInstructions: true,
    );

    final result = await _navigationController!.startNavigation(
      origin: origin,
      destination: destination,
      waypoints: waypoints,
      options: routingOptions,
    );

    if (result.success) {
      // Navigation started with waypoints and custom options
    }
  }

  // NavigationEventListener implementation
  @override
  void onNavigationStateChanged(NavigationState state) {
    print('Navigation state changed to: ${state.description}');
  }

  @override
  void onRouteProgressChanged(RouteProgress progress) {
    print('Distance remaining: ${progress.distanceRemaining} meters');
    print('Duration remaining: ${progress.durationRemaining} seconds');
  }

  @override
  void onUpcomingManeuver(Maneuver maneuver) {
    print('Upcoming maneuver: ${maneuver.instruction}');
  }

  @override
  void onArrival() {
    print('You have arrived at your destination!');
  }

  @override
  void onError(NavigationError error) {
    print('Navigation error: ${error.message}');
  }
}
```

### Listening to Navigation Events

```dart
class EventListenerExample extends StatefulWidget {
  @override
  _EventListenerExampleState createState() => _EventListenerExampleState();
}

class _EventListenerExampleState extends State<EventListenerExample> {
  NavigationController? _navigationController;

  void _setupEventListeners() {
    if (_navigationController == null) return;

    // Listen to navigation state changes
    _navigationController!.stateStream.listen((state) {
      switch (state) {
        case NavigationState.idle:
          print('Navigation is idle');
          break;
        case NavigationState.routing:
          print('Calculating route...');
          break;
        case NavigationState.navigating:
          print('Navigation in progress');
          break;
        case NavigationState.paused:
          print('Navigation paused');
          break;
        case NavigationState.arrived:
          print('Arrived at destination');
          break;
        case NavigationState.error:
          print('Navigation error occurred');
          break;
      }
    });

    // Listen to progress updates
    _navigationController!.progressStream.listen((progress) {
      print('Progress: ${progress.distanceRemaining}m remaining, ETA: ${progress.eta}');
    });

    // Listen to upcoming maneuvers
    _navigationController!.upcomingManeuverStream.listen((maneuver) {
      print('Next turn: ${maneuver.instruction} in ${maneuver.distance}m');
    });

    // Listen to voice instructions
    _navigationController!.instructionStream.listen((instruction) {
      print('Voice instruction: $instruction');
    });

    // Listen to navigation errors
    _navigationController!.errorStream.listen((error) {
      print('Navigation error: ${error.message}');
      if (error.originalError != null) {
        print('Original error: ${error.originalError}');
      }
    });
  }
}
```

### Custom Route Themes and UI Customization

```dart
class ThemeExample extends StatefulWidget {
  @override
  _ThemeExampleState createState() => _ThemeExampleState();
}

class _ThemeExampleState extends State<ThemeExample> {
  RouteStyleConfig _currentRouteTheme = RouteStyleConfig.defaultConfig;
  LocationPuckConfig _currentLocationPuckTheme = LocationPuckThemes.defaultTheme;
  DestinationPinConfig _currentDestinationPinTheme = DestinationPinConfig.defaultConfig;

  void _applyRouteTheme(RouteStyleConfig theme) {
    setState(() {
      _currentRouteTheme = theme;
    });
    _navigationController?.updateRouteStyleConfig(theme);
  }

  void _applyLocationPuckTheme(LocationPuckConfig theme) {
    setState(() {
      _currentLocationPuckTheme = theme;
    });
    _navigationController?.updateLocationPuckConfig(theme);
  }

  void _applyDestinationPinTheme(DestinationPinConfig theme) {
    setState(() {
      _currentDestinationPinTheme = theme;
    });
    _navigationController?.updateDestinationPinConfig(theme);
  }

  // Available route themes
  final List<RouteStyleConfig> _routeThemes = [
    RouteStyleConfig.defaultConfig,
    RouteStyleThemes.darkTheme,
    RouteStyleThemes.highContrastTheme,
    RouteStyleConfig(
      routeLineStyle: RouteLineStyle(
        color: Color(0xFFFF6600),
        width: 14.0,
        opacity: 0.9,
      ),
      traveledLineStyle: RouteLineStyle(
        color: Color(0xFF888888),
        width: 14.0,
        opacity: 0.7,
      ),
    ),
  ];

  // Available location puck themes
  final List<LocationPuckConfig> _locationPuckThemes = [
    LocationPuckThemes.defaultTheme,
    LocationPuckThemes.minimalTheme,
    LocationPuckThemes.boldTheme,
    LocationPuckThemes.nightTheme,
  ];

  // Available destination pin themes
  final List<DestinationPinConfig> _destinationPinThemes = [
    DestinationPinConfig.defaultConfig,
    DestinationPinConfig.minimalConfig,
    DestinationPinConfig.boldConfig,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Theme selectors
          Container(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Route theme selector
                Text('Route Theme:', style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButton<RouteStyleConfig>(
                  value: _currentRouteTheme,
                  isExpanded: true,
                  items: _routeThemes.map((theme) {
                    return DropdownMenuItem<RouteStyleConfig>(
                      value: theme,
                      child: Text('Route Theme ${_routeThemes.indexOf(theme) + 1}'),
                    );
                  }).toList(),
                  onChanged: (theme) {
                    if (theme != null) {
                      _applyRouteTheme(theme);
                    }
                  },
                ),
                SizedBox(height: 16),

                // Location puck theme selector
                Text('Location Puck Theme:', style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButton<LocationPuckConfig>(
                  value: _currentLocationPuckTheme,
                  isExpanded: true,
                  items: _locationPuckThemes.map((theme) {
                    return DropdownMenuItem<LocationPuckConfig>(
                      value: theme,
                      child: Text('Puck Theme ${_locationPuckThemes.indexOf(theme) + 1}'),
                    );
                  }).toList(),
                  onChanged: (theme) {
                    if (theme != null) {
                      _applyLocationPuckTheme(theme);
                    }
                  },
                ),
                SizedBox(height: 16),

                // Destination pin theme selector
                Text('Destination Pin Theme:', style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButton<DestinationPinConfig>(
                  value: _currentDestinationPinTheme,
                  isExpanded: true,
                  items: _destinationPinThemes.map((theme) {
                    return DropdownMenuItem<DestinationPinConfig>(
                      value: theme,
                      child: Text('Pin Theme ${_destinationPinThemes.indexOf(theme) + 1}'),
                    );
                  }).toList(),
                  onChanged: (theme) {
                    if (theme != null) {
                      _applyDestinationPinTheme(theme);
                    }
                  },
                ),
              ],
            ),
          ),

          // Navigation map
          Expanded(
            child: NavigationView(
              mapboxAccessToken: 'YOUR_MAPBOX_ACCESS_TOKEN',
              onMapCreated: _initializeNavigation,
            ),
          ),
        ],
      ),
    );
  }
}
```

### Custom Location Puck and Destination Pin Configuration

```dart
class CustomUIExample extends StatefulWidget {
  @override
  _CustomUIExampleState createState() => _CustomUIExampleState();
}

class _CustomUIExampleState extends State<CustomUIExample> {
  // Custom location puck configuration
  final LocationPuckConfig _customLocationPuck = LocationPuckConfig(
    puckImage: 'assets/custom_location_puck.png',
    shadowImage: 'assets/custom_puck_shadow.png',
    bearingImage: 'assets/custom_puck_bearing.png',
    scale: 1.2,
    opacity: 0.9,
  );

  // Custom destination pin configuration
  final DestinationPinConfig _customDestinationPin = DestinationPinConfig(
    pinImage: 'assets/custom_destination_pin.png',
    shadowImage: 'assets/custom_pin_shadow.png',
    scale: 1.5,
    opacity: 1.0,
  );

  Future<void> _initializeWithCustomUI() async {
    _navigationController = NavigationController(
      routingEngine: MapboxRoutingEngine(
        accessToken: 'YOUR_MAPBOX_ACCESS_TOKEN'
      ),
      locationProvider: DefaultLocationProvider(),
      progressTracker: DefaultRouteProgressTracker(),
      voiceGuidance: DefaultVoiceGuidance(),
      mapController: _mapController!,
      routeStyleConfig: RouteStyleConfig.defaultConfig,
      locationPuckConfig: _customLocationPuck,
      destinationPinConfig: _customDestinationPin,
    );

    await _navigationController!.initializeLocation();
  }

  // Show/hide destination pin programmatically
  Future<void> _toggleDestinationPin() async {
    if (_navigationController?.currentRoute != null) {
      await _navigationController!.hideDestinationPin();
    } else {
      final destination = LocationPoint.fromLatLng(37.7849, -122.4094);
      await _navigationController!.showDestinationPin(destination);
    }
  }
}
```

## API Reference

### NavigationController

The main controller that orchestrates all navigation functionality.

#### Key Methods:

- `startNavigation({required origin, required destination, waypoints?, options?})`: Start navigation with route calculation
- `startNavigationWithRoute({required route})`: Start navigation with a pre-calculated route
- `stopNavigation()`: Stop current navigation session
- `pauseNavigation()`: Pause navigation
- `resumeNavigation()`: Resume paused navigation
- `reroute()`: Calculate new route from current location
- `recenterMap()`: Center map on current location
- `initializeLocation()`: Initialize location services
- `updateRouteStyleConfig(RouteStyleConfig config)`: Update route styling
- `updateLocationPuckConfig(LocationPuckConfig config)`: Update location puck appearance
- `updateDestinationPinConfig(DestinationPinConfig config)`: Update destination pin appearance
- `showDestinationPin(LocationPoint location)`: Show destination pin at specific location
- `hideDestinationPin()`: Hide the destination pin

#### Key Properties:

- `currentState`: Current navigation state
- `currentRoute`: Currently active route
- `currentProgress`: Route progress information
- `eta`: Estimated time of arrival
- `remainingDistance`: Distance remaining to destination
- `remainingDuration`: Duration remaining to destination
- `routeStyleConfig`: Current route styling configuration
- `locationPuckConfig`: Current location puck configuration
- `destinationPinConfig`: Current destination pin configuration

#### Streams:

- `stateStream`: Navigation state changes
- `progressStream`: Route progress updates
- `upcomingManeuverStream`: Upcoming navigation maneuvers
- `instructionStream`: Voice instructions
- `errorStream`: Navigation errors

### NavigationView

The Flutter widget for displaying the navigation map.

#### Parameters:

- `mapboxAccessToken`: Required Mapbox access token
- `initialCenter`: Initial map center coordinates
- `initialZoom`: Initial zoom level (default: 16.0)
- `styleUrl`: Custom Mapbox style URL
- `enableLocation`: Enable location tracking (default: true)
- `onMapCreated`: Callback when map is created

### Core Models

- `LocationPoint`: Represents a geographical location
- `RouteModel`: Represents a navigation route
- `RouteProgress`: Current progress along a route
- `Maneuver`: Navigation maneuver instruction
- `NavigationState`: Current navigation state
- `RouteStyleConfig`: Route appearance configuration
- `LocationPuckConfig`: Location puck appearance and behavior configuration
- `DestinationPinConfig`: Destination pin appearance and styling configuration
- `LocationPuckThemes`: Predefined location puck themes (default, minimal, bold, night)
- `RouteStyleThemes`: Predefined route styling themes (default, dark, high contrast)

## Additional Information

### Dependencies

This package requires the following dependencies:

- `mapbox_maps_flutter`: ^2.11.0 - Mapbox maps integration
- `location`: ^8.0.1 - Location services
- `flutter_tts`: ^4.2.3 - Text-to-speech for voice guidance
- `http`: ^1.5.0 - HTTP requests for routing API

### Contributing

We welcome contributions! Please feel free to submit issues and pull requests.

### Issues and Support

For bug reports and feature requests, please use the [GitHub issue tracker](https://github.com/your-repo/issues).

### License

This project is licensed under the MIT License - see the LICENSE file for details.

### More Information

For detailed API documentation and additional examples, visit the [example folder](example/).
