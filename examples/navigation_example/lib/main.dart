import 'package:flutter/material.dart';
import 'package:mapbox_navigation/mapbox_navigation.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;

void main() {
  runApp(const NavigationExampleApp());
}

class NavigationExampleApp extends StatelessWidget {
  const NavigationExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mapbox Navigation Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const NavigationExampleScreen(),
    );
  }
}

class NavigationExampleScreen extends StatefulWidget {
  const NavigationExampleScreen({super.key});

  @override
  State<NavigationExampleScreen> createState() => _NavigationExampleScreenState();
}

class _NavigationExampleScreenState extends State<NavigationExampleScreen> {
  // Replace with your Mapbox access token
  static const String accessToken = 'YOUR_MAPBOX_ACCESS_TOKEN_HERE';
  
  NavigationController? _navigationController;
  
  // Example coordinates (San Francisco to Los Angeles)
  final Waypoint _origin = Waypoint(
    latitude: 37.7749,
    longitude: -122.4194,
    name: 'San Francisco, CA',
  );
  
  final Waypoint _destination = Waypoint(
    latitude: 34.0522,
    longitude: -118.2437,
    name: 'Los Angeles, CA',
  );
  
  bool _isNavigating = false;
  NavigationState _navigationState = NavigationState.idle();
  NavigationStep? _currentStep;
  RouteData? _currentRoute;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapbox Navigation Example'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // Navigation Controls
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Navigation Status: ${_navigationState.status.name}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (_currentStep != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Instruction:',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(_currentStep!.instruction),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Distance: ${_currentStep!.distance.toStringAsFixed(0)}m'),
                              Text('Duration: ${_currentStep!.duration.toStringAsFixed(0)}s'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isNavigating ? null : _startNavigation,
                        child: const Text('Start Navigation'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isNavigating ? _stopNavigation : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Stop Navigation'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Mapbox Navigation View
          Expanded(
            child: MapboxNavigationView(
              accessToken: accessToken,
              initialCameraPosition: mapbox.CameraOptions(
                center: mapbox.Point(
                  coordinates: mapbox.Position(_origin.longitude, _origin.latitude),
                ),
                zoom: 12.0,
              ),
              styleUri: mapbox.MapboxStyles.MAPBOX_STREETS,
              onMapReady: _onMapReady,
              onNavigationStateChanged: _onNavigationStateChanged,
              onStepChanged: _onStepChanged,
              onError: _onError,
              voiceSettings: const VoiceSettings(
                enabled: true,
                speechRate: 0.5,
                pitch: 1.0,
                volume: 0.8,
                language: 'en-US',
                minimumInterval: 5,
                announcementDistances: [1000, 500, 100],
                announceArrival: true,
                announceRouteRecalculation: true,
              ),
              enableTrafficData: true,
              simulationSpeed: 1.0, // Normal speed for real navigation
            ),
          ),
        ],
      ),
    );
  }
  
  void _onMapReady(NavigationController navigationController) {
    setState(() {
      _navigationController = navigationController;
    });
    
    // Listen to navigation state changes
    _navigationController!.stateStream.listen((state) {
      if (mounted) {
        setState(() {
          _navigationState = state;
          _isNavigating = state.status == NavigationStatus.navigating;
        });
      }
    });
    
    // Listen to navigation step changes
    _navigationController!.stepStream.listen((step) {
      if (mounted) {
        setState(() {
          _currentStep = step;
        });
      }
    });
  }
  
  void _onNavigationStateChanged(NavigationState state) {
    debugPrint('Navigation state changed: $state');
  }
  
  void _onStepChanged(NavigationStep step) {
    debugPrint('Navigation step: ${step.instruction}');
  }
  
  void _onError(String error) {
    debugPrint('Navigation error: $error');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Navigation error: $error'),
        backgroundColor: Colors.red,
      ),
    );
  }
  
  Future<void> _startNavigation() async {
    if (_navigationController == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Navigation controller not ready'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    try {
      await _navigationController!.startNavigation(
        origin: _origin,
        destination: _destination,
        profile: 'driving-traffic', // Use traffic-aware routing
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start navigation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _stopNavigation() async {
    if (_navigationController == null) return;
    
    try {
      await _navigationController!.stopNavigation();
      setState(() {
        _currentStep = null;
        _currentRoute = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to stop navigation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}