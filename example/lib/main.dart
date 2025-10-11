import 'package:flutter/material.dart';
import 'package:mapbox_navigation_plus/mapbox_navigation_plus.dart';
import 'config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Config.instance.loadVariables();

  if (!Config.instance.isMapboxConfigured) {
    throw Exception(
      'Mapbox access token not configured. Please edit variables.json',
    );
  }

  MapboxOptions.setAccessToken(Config.instance.mapboxAccessToken);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mapbox Navigation Demo',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const NavigationDemo(),
    );
  }
}

class NavigationDemo extends StatefulWidget {
  const NavigationDemo({super.key});

  @override
  State<NavigationDemo> createState() => _NavigationDemoState();
}

class _NavigationDemoState extends State<NavigationDemo>
    implements NavigationEventListener {
  // Mapbox access token is loaded from variables.json
  // Get your token from: https://account.mapbox.com/access-tokens/
  String get _mapboxAccessToken => Config.instance.mapboxAccessToken;

  NavigationController? _navigationController;
  MapboxMapController? _mapController;

  // Demo destination (San Francisco area)
  final LocationPoint _destination = LocationPoint.fromLatLng(
    37.7849,
    -122.4094,
  );

  // Current user location
  LocationPoint? _currentLocation;

  NavigationState _currentState = NavigationState.idle;
  RouteProgress? _currentProgress;
  String _statusMessage = 'Ready to navigate';
  bool _isLoading = false;

  // Route styling options
  RouteStyleConfig _currentRouteStyle = RouteStyleConfig.defaultConfig;
  int _selectedStyleIndex = 0;
  
  // Location puck styling options
  final LocationPuckConfig _currentLocationPuckStyle = LocationPuckThemes.defaultTheme;
  
  // Destination pin styling options
  final DestinationPinConfig _currentDestinationPinStyle = DestinationPinConfig.defaultConfig;
  
  final List<RouteStyleConfig> _routeStyles = [
    RouteStyleConfig.defaultConfig,
    RouteStyleThemes.darkTheme,
    RouteStyleThemes.highContrastTheme,
    const RouteStyleConfig(
      routeLineStyle: RouteLineStyle(
        color: Color(0xFFFF6600),
        width: 14.0,
        opacity: 0.9,
        capStyle: LineCapStyle.round,
        joinStyle: LineJoinStyle.round,
      ),
      traveledLineStyle: RouteLineStyle(
        color: Color(0xFF888888),
        width: 14.0,
        opacity: 0.7,
        capStyle: LineCapStyle.round,
        joinStyle: LineJoinStyle.round,
      ),
      remainingLineStyle: RouteLineStyle(
        color: Color(0xFFFF9900),
        width: 14.0,
        opacity: 1.0,
        capStyle: LineCapStyle.round,
        joinStyle: LineJoinStyle.round,
      ),
    ),
  ];
  
  final List<String> _styleNames = [
    'Default',
    'Dark Theme',
    'High Contrast',
    'Custom Orange',
  ];

  @override
  void initState() {
    super.initState();
    _checkConfiguration();
    _statusMessage = 'Tap "Start Navigation" to begin';
  }

  void _checkConfiguration() {
    if (!Config.instance.isMapboxConfigured) {
      setState(() {
        _statusMessage =
            '⚠️ Mapbox token not configured. Please edit variables.json';
      });
    }
  }

  Future<void> _initCurrentLocation() async {
    try {
      final location = await _navigationController?.locationProvider
          .getCurrentLocation();
      if (location != null) {
        setState(() {
          _currentLocation = location;
        });
      }
    } catch (e) {
      debugPrint('Error getting current location: $e');
    }
  }

  @override
  void dispose() {
    _navigationController?.removeNavigationListener(this);
    _navigationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapbox Navigation Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Stack(
        children: [
          // Map widget
          NavigationView(
            mapboxAccessToken: _mapboxAccessToken,
            initialCenter:
                _currentLocation ??
                _destination, // Use current location or fallback to destination
            initialZoom: 17.0,
            routeProgress: _currentProgress,
            onMapCreated: (controller) {
              _mapController = controller;
              _initializeNavigation();
            },
          ),

          // Navigation controls overlay
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Status: ${_currentState.description}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _statusMessage,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (_currentProgress != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Remaining: ${_currentProgress!.formattedDistanceRemaining}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        'ETA: ${_currentProgress!.formattedETA}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                    const SizedBox(height: 16),
                    
                    // Route Style Selection
                    Text(
                      'Route Style:',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    DropdownButton<int>(
                      value: _selectedStyleIndex,
                      isExpanded: true,
                      items: _styleNames.asMap().entries.map((entry) {
                        return DropdownMenuItem<int>(
                          value: entry.key,
                          child: Text(entry.value),
                        );
                      }).toList(),
                      onChanged: (int? newIndex) {
                        if (newIndex != null) {
                          setState(() {
                            _selectedStyleIndex = newIndex;
                            _currentRouteStyle = _routeStyles[newIndex];
                          });
                          // Update the navigation controller with new style
                          _navigationController?.updateRouteStyleConfig(_currentRouteStyle);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        if (!_isLoading && _currentState.canStart)
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _startNavigation,
                              child: const Text('Start Navigation'),
                            ),
                          ),
                        if (_currentState.canPause)
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _pauseNavigation,
                              child: const Text('Pause'),
                            ),
                          ),
                        if (_currentState.canResume)
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _resumeNavigation,
                              child: const Text('Resume'),
                            ),
                          ),
                        if (_currentState.canStop)
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _stopNavigation,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Stop'),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Loading indicator
          if (_isLoading)
            const Positioned(
              top: 16,
              right: 16,
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(),
                ),
              ),
            ),

          // Re-center button
          if (_currentState.isActive)
            Positioned(
              bottom: 100,
              right: 16,
              child: FloatingActionButton(
                onPressed: _recenterMap,
                child: const Icon(Icons.my_location),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _initializeNavigation() async {
    if (_mapController == null) return;

    // Create real implementations for actual navigation
    final locationProvider = DefaultLocationProvider();
    final progressTracker = DefaultRouteProgressTracker();
    final voiceGuidance = DefaultVoiceGuidance();

    // Initialize voice guidance
    try {
      await voiceGuidance.initialize();
    } catch (e) {
      setState(() {
        _statusMessage = 'Voice guidance init failed: $e';
      });
    }

    _navigationController = NavigationController(
      routingEngine: MapboxRoutingEngine(accessToken: _mapboxAccessToken),
      locationProvider: locationProvider,
      progressTracker: progressTracker,
      voiceGuidance: voiceGuidance,
      mapController: _mapController!,
      routeStyleConfig: _currentRouteStyle,
      locationPuckConfig: _currentLocationPuckStyle,
      destinationPinConfig: _currentDestinationPinStyle,
    );

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

    // Listen to errors
    _navigationController!.errorStream.listen((error) {
      setState(() {
        _statusMessage = 'Error: ${error.message}';
        _isLoading = false;
      });
    });

    // Get current location for navigation
    try {
      await _initCurrentLocation();

      await _navigationController!.initializeLocation();

      locationProvider.locationStream.listen((location) {
        if (_currentLocation == null) {
          setState(() {
            _currentLocation = location;
            _statusMessage = 'Current location acquired. Ready to navigate!';
          });
        }
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to get location: $e';
      });
    }
  }

  Future<void> _startNavigation() async {
    if (_navigationController == null) return;

    // Ensure we have current location
    if (_currentLocation == null) {
      setState(() {
        _statusMessage = 'Waiting for current location...';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Calculating route...';
    });

    try {
      final result = await _navigationController!.startNavigation(
        origin: _currentLocation!, // Use current location as origin
        destination: _destination,
      );

      if (result.success) {
        setState(() {
          _statusMessage = 'Navigation started! Following route...';
        });
      } else {
        setState(() {
          _statusMessage = 'Failed to start navigation: ${result.message}';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pauseNavigation() async {
    await _navigationController?.pauseNavigation();
    setState(() {
      _statusMessage = 'Navigation paused';
    });
  }

  Future<void> _resumeNavigation() async {
    await _navigationController?.resumeNavigation();
    setState(() {
      _statusMessage = 'Navigation resumed';
    });
  }

  Future<void> _stopNavigation() async {
    await _navigationController?.stopNavigation();
    setState(() {
      _statusMessage = 'Navigation stopped';
      _currentProgress = null;
    });
  }

  Future<void> _recenterMap() async {
    await _navigationController?.recenterMap();
  }

  // NavigationEventListener implementation
  @override
  void onNavigationStateChanged(NavigationState state) {
    setState(() {
      _currentState = state;
    });
  }

  @override
  void onRouteProgressChanged(RouteProgress progress) {
    // Progress updates are handled via stream listener above
  }

  @override
  void onUpcomingManeuver(Maneuver maneuver) {
    setState(() {
      _statusMessage = 'Upcoming: ${maneuver.instruction}';
    });
  }

  @override
  void onInstruction(String instruction) {
    setState(() {
      _statusMessage = instruction;
    });
  }

  @override
  void onError(NavigationError error) {
    setState(() {
      _statusMessage = 'Error: ${error.message}';
    });
  }

  @override
  void onArrival() {
    setState(() {
      _statusMessage = 'You have arrived at your destination!';
    });
  }
}
