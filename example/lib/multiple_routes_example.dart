import 'package:flutter/material.dart';
import 'package:mapbox_navigation_plus/mapbox_navigation_plus.dart';

/// Example demonstrating multiple route selection functionality
class MultipleRoutesExample extends StatefulWidget {
  final String mapboxAccessToken;

  const MultipleRoutesExample({super.key, required this.mapboxAccessToken});

  @override
  State<MultipleRoutesExample> createState() => _MultipleRoutesExampleState();
}

class _MultipleRoutesExampleState extends State<MultipleRoutesExample> {
  NavigationController? _navigationController;
  MapboxMapController? _mapController;
  late final RoutingEngine _routingEngine = MapboxRoutingEngine(
    accessToken: widget.mapboxAccessToken,
  );

  // Route selection state

  // Example locations (San Francisco to Oakland)
  final LocationPoint _origin = LocationPoint.fromLatLng(37.7749, -122.4194);
  final LocationPoint _destination = LocationPoint.fromLatLng(
    37.8044,
    -122.2712,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Multiple Routes Example'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Stack(
        children: [
          // Navigation map
          NavigationView(
            mapboxAccessToken: widget.mapboxAccessToken,
            initialCenter: _origin,
            initialZoom: 12.0,
            onMapCreated: _initializeNavigation,
          ),

          // Control panel
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Multiple Routes Demo',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'From: San Francisco\nTo: Oakland',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _requestMultipleRoutes,
                      child: const Text('Get Route Options'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: () => _navigationController?.resumeFollowing(),
              child: Icon(Icons.gps_fixed),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _initializeNavigation(MapboxMapController controller) async {
    _mapController = controller;

    // Initialize navigation controller
    _navigationController = NavigationController(
      routingEngine: _routingEngine,
      locationProvider: DefaultLocationProvider(),
      progressTracker: DefaultRouteProgressTracker(),
      voiceGuidance: DefaultVoiceGuidance(),
      mapController: controller,
    );

    await _navigationController!.initializeLocation();
  }

  Future<void> _requestMultipleRoutes() async {
    if (_navigationController == null) return;

    // TODO: load multiple routes
  }

  @override
  void dispose() {
    _navigationController?.dispose();
    super.dispose();
  }
}
