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

  // Route selection state
  List<RouteResult>? _availableRoutes;
  bool _showRouteSelection = false;
  bool _isLoadingRoutes = false;

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
            // Route selection parameters
            availableRoutes: _availableRoutes,
            showRouteSelection: _showRouteSelection,
            onRouteSelected: _onRouteSelected,
            onRouteSelectionCancelled: _onRouteSelectionCancelled,
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
                      onPressed: _isLoadingRoutes
                          ? null
                          : _requestMultipleRoutes,
                      child: _isLoadingRoutes
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Get Route Options'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Loading overlay
          if (_isLoadingRoutes)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Calculating routes...'),
                      ],
                    ),
                  ),
                ),
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
      routingEngine: MapboxRoutingEngine(accessToken: widget.mapboxAccessToken),
      locationProvider: DefaultLocationProvider(),
      progressTracker: DefaultRouteProgressTracker(),
      voiceGuidance: DefaultVoiceGuidance(),
      mapController: controller,
    );

    // Initialize location services
    await _navigationController!.initializeLocation();
  }

  Future<void> _requestMultipleRoutes() async {
    if (_navigationController == null) return;

    setState(() {
      _isLoadingRoutes = true;
    });

    try {
      // Request multiple routes with different optimization criteria
      final routes = await _navigationController!.requestMultipleRoutes(
        origin: _origin,
        destination: _destination,
        routeTypes: [
          RouteType.timeOptimized,
          RouteType.distanceOptimized,
          RouteType.ecoFriendly,
          RouteType.scenicRoute,
        ],
        baseOptions: RoutingOptions(
          profile: RouteProfile.drivingTraffic,
          useTrafficData: true,
          voiceInstructions: true,
        ),
      );

      if (routes.isNotEmpty) {
        // Draw all routes on the map
        await _mapController?.drawMultipleRoutes(routes: routes);

        setState(() {
          _availableRoutes = routes;
          _showRouteSelection = true;
        });
      } else {
        _showErrorSnackBar('No routes found');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to calculate routes: $e');
    } finally {
      setState(() {
        _isLoadingRoutes = false;
      });
    }
  }

  void _onRouteSelected(RouteResult selectedRoute) async {
    // Hide route selection UI
    setState(() {
      _showRouteSelection = false;
    });

    // Clear multiple routes from map
    await _mapController?.clearMultipleRoutes();

    // Start navigation with the selected route
    final result = await _navigationController!.startNavigationWithRoute(
      route: selectedRoute.route,
    );

    if (result.success) {
      _showSuccessSnackBar(
        'Navigation started with ${selectedRoute.routeType.name} route',
      );
    } else {
      _showErrorSnackBar('Failed to start navigation: ${result.message}');
    }
  }

  void _onRouteSelectionCancelled() {
    setState(() {
      _showRouteSelection = false;
      _availableRoutes = null;
    });

    // Clear routes from map
    _mapController?.clearMultipleRoutes();
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  void dispose() {
    _navigationController?.dispose();
    super.dispose();
  }
}
