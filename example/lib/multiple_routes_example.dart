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
  List<RouteModel> _routes = [];
  RouteModel? _selectedRoute;
  bool _isLoadingRoutes = false;
  String? _errorMessage;

  // Example locations (San Francisco to San Jose - multiple route options)
  final LocationPoint _origin = LocationPoint.fromLatLng(37.7749, -122.4194);
  final LocationPoint _destination = LocationPoint.fromLatLng(
    37.3382,
    -121.8863,
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
                      'From: San Francisco\nTo: San Jose',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoadingRoutes
                            ? null
                            : _requestMultipleRoutes,
                        icon: _isLoadingRoutes
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.alt_route),
                        label: Text(
                          _isLoadingRoutes
                              ? 'Getting Routes...'
                              : 'Get Route Options',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Error message display
          if (_errorMessage != null)
            Positioned(
              top: 200,
              left: 16,
              right: 16,
              child: Card(
                color: Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red[700]),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setState(() {
                            _errorMessage = null;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Route count indicator
          if (_routes.isNotEmpty)
            Positioned(
              top: 200,
              left: 16,
              right: 16,
              child: Card(
                color: Colors.green[50],
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Found ${_routes.length} route${_routes.length == 1 ? '' : 's'}. Select a route to display.',
                          style: TextStyle(color: Colors.green[700]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Route selection bottom sheet
          if (_routes.isNotEmpty) _buildRouteSelectionSheet(),
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
    if (_navigationController == null || _mapController == null) return;

    setState(() {
      _isLoadingRoutes = true;
      _errorMessage = null;
      _routes.clear();
      _selectedRoute = null;
    });

    try {
      // Clear any existing routes from the map
      await _mapController!.clearRoute();

      // Request multiple alternative routes
      final routes = await _routingEngine.getAlternativeRoutes(
        origin: _origin,
        destination: _destination,
        maxAlternatives: 3, // Request up to 3 alternative routes
      );

      if (routes.isNotEmpty) {
        setState(() {
          _routes = routes;
          _selectedRoute = routes.first; // Select first route by default
        });

        // Display all routes on the map with different styles
        await _displayRoutesOnMap();
      } else {
        setState(() {
          _errorMessage = 'No routes found. Please try different locations.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to get routes: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoadingRoutes = false;
      });
    }
  }

  /// Displays all routes on the map with different colors
  Future<void> _displayRoutesOnMap() async {
    if (_mapController == null || _routes.isEmpty) return;

    // Clear existing routes first
    await _mapController!.clearRoute();

    // Define different colors for each route
    final routeColors = [
      const Color(0xFF3366CC), // Blue
      const Color(0xFF00AA00), // Green
      const Color(0xFFFF6600), // Orange
      const Color(0xFFCC00CC), // Purple
      const Color(0xFF00CCCC), // Cyan
    ];

    try {
      // Use the new drawMultipleRoutes method
      await _mapController!.drawMultipleRoutes(
        routes: _routes,
        colors: routeColors,
      );

      // Highlight the selected route if any, otherwise highlight the first one
      final routeToHighlight = _selectedRoute ?? _routes.first;
      await _mapController!.highlightRoute(routeToHighlight.id);
    } catch (e) {
      print('Error displaying multiple routes: $e');
      // Fallback: draw just the selected route
      final routeToDraw = _selectedRoute ?? _routes.first;
      await _mapController!.drawRoute(route: routeToDraw);
    }
  }

  /// Handles route selection from UI
  Future<void> _selectRoute(RouteModel route) async {
    if (_mapController == null) return;

    setState(() {
      _selectedRoute = route;
    });

    // Highlight the selected route using the highlightRoute method
    try {
      await _mapController!.highlightRoute(route.id);
    } catch (e) {
      print('Error highlighting route: $e');
      // Fallback: redisplay all routes
      await _displayRoutesOnMap();
    }

    // Optionally center the map on the selected route
    if (route.geometry.isNotEmpty) {
      await _mapController!.moveCamera(
        center: route.geometry[route.geometry.length ~/ 2],
        zoom: 8.0,
        animation: const CameraAnimation(
          duration: Duration(seconds: 1),
          type: AnimationType.easeInOut,
        ),
      );
    }
  }

  /// Starts navigation with the selected route
  Future<void> _startNavigation() async {
    if (_selectedRoute == null || _navigationController == null) return;

    try {
      // Start navigation with the selected route
      await _navigationController!.startNavigationWithRoute(
        route: _selectedRoute!,
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to start navigation: ${e.toString()}';
      });
    }
  }

  /// Builds the route selection bottom sheet
  Widget _buildRouteSelectionSheet() {
    if (_routes.isEmpty) return const SizedBox.shrink();

    return DraggableScrollableSheet(
      initialChildSize: 0.35,
      minChildSize: 0.25,
      maxChildSize: 0.7,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [
              BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 1),
            ],
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.route, color: Colors.blue),
                    const SizedBox(width: 8),
                    const Text(
                      'Route Options',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_routes.length} routes',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              ),

              // Route list
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _routes.length,
                  itemBuilder: (context, index) {
                    final route = _routes[index];
                    final isSelected = route.id == _selectedRoute?.id;

                    return _buildRouteCard(route, isSelected);
                  },
                ),
              ),

              // Start navigation button
              if (_selectedRoute != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _startNavigation,
                      icon: const Icon(Icons.navigation),
                      label: const Text('Start Navigation'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Builds a single route card
  Widget _buildRouteCard(RouteModel route, bool isSelected) {
    final distance = route.distance / 1000; // Convert to km
    final duration = Duration(seconds: route.duration.round());
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    String durationText;
    if (hours > 0) {
      durationText = '${hours}h ${minutes}min';
    } else {
      durationText = '${minutes}min';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: isSelected ? 4 : 1,
      color: isSelected ? Colors.blue[50] : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? Colors.blue : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => _selectRoute(route),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Route number indicator
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue : Colors.grey[200],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    '${_routes.indexOf(route) + 1}',
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Route information
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      route.summary.isNotEmpty
                          ? route.summary
                          : 'Route ${_routes.indexOf(route) + 1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.directions_car,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${distance.toStringAsFixed(1)} km',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.access_time,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          durationText,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Selection indicator
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: isSelected ? Colors.blue : Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _navigationController?.dispose();
    super.dispose();
  }
}
