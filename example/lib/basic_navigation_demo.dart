import 'package:example/config.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:mapbox_navigation_plus/mapbox_navigation_plus.dart';

class BasicNavigationDemo extends StatefulWidget {
  const BasicNavigationDemo({super.key});

  @override
  State<BasicNavigationDemo> createState() => _BasicNavigationDemoState();
}

class _BasicNavigationDemoState extends State<BasicNavigationDemo>
    implements NavigationEventListener {
  final locationProvider = DefaultLocationProvider();
  final progressTracker = DefaultRouteProgressTracker();
  final voiceGuidance = DefaultVoiceGuidance();
  // Mapbox access token is loaded from variables.json
  // Get your token from: https://account.mapbox.com/access-tokens/
  String get _mapboxAccessToken => Config.instance.mapboxAccessToken;

  NavigationController? _navigationController;
  MapboxMapController? _mapController;

  // Address input controllers
  final TextEditingController _addressController = TextEditingController();
  final FocusNode _addressFocusNode = FocusNode();

  LocationPoint? _destination;
  String? _destinationAddress;

  // Current user location
  LocationPoint? _currentLocation;

  double _defaultZoom = 18.5;
  double _navigationZoom = 20.0;

  NavigationState _currentState = NavigationState.idle;
  RouteProgress? _currentProgress;
  String _statusMessage = 'Ready to navigate';
  bool _isLoading = false;
  bool _isSearching = false;
  bool _showControls = false;

  // Route styling options
  RouteStyleConfig _currentRouteStyle = RouteStyleConfig.defaultConfig;
  int _selectedStyleIndex = 0;

  // Location puck styling options
  final LocationPuckConfig _currentLocationPuckStyle =
      LocationPuckThemes.defaultTheme;

  // Destination pin styling options
  final DestinationPinConfig _currentDestinationPinStyle =
      DestinationPinConfig.defaultConfig;

  final List<RouteStyleConfig> _routeStyles = [
    RouteStyleConfig.defaultConfig,
    RouteStyleThemes.darkTheme,
    RouteStyleThemes.highContrastTheme,
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
    _statusMessage = 'Enter a destination address to begin';

    // Set a default destination for demo purposes
    _destination = LocationPoint.fromLatLng(37.784947, -122.409444);
    _destinationAddress = '142 Mason St, San Francisco, CA 94102, USA';
  }

  void _checkConfiguration() {
    if (!Config.instance.isMapboxConfigured) {
      setState(() {
        _statusMessage =
            '⚠️ Mapbox token not configured. Please edit variables.json';
      });
    }
  }

  @override
  void dispose() {
    _navigationController?.removeNavigationListener(this);
    _navigationController?.dispose();
    _addressController.dispose();
    _addressFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapbox Navigation Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: Icon(_showControls ? Icons.visibility_off : Icons.visibility),
            onPressed: () {
              setState(() {
                _showControls = !_showControls;
              });
            },
            tooltip: _showControls ? 'Hide Controls' : 'Show Controls',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Map widget
          NavigationView(
            mapboxAccessToken: _mapboxAccessToken,
            initialCenter:
                _currentLocation ??
                _destination, // Use current location or fallback to destination
            initialZoom: _defaultZoom,
            navigationController: _navigationController,
            pitch: 75,
            navigationModeZoom: _navigationZoom,
            onMapCreated: (controller) async {
              _mapController = controller;
              await _initializeNavigation();
            },
            onFollowingLocationStopped: () {
              setState(() {});
            },
          ),

          // Navigation controls overlay - only show when enabled
          if (_showControls) ...[
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

                      // Address search section
                      const SizedBox(height: 16),
                      Text(
                        'Destination:',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _addressController,
                              focusNode: _addressFocusNode,
                              decoration: InputDecoration(
                                hintText: 'Enter address or place name',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.search),
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_addressController.text.isNotEmpty)
                                      IconButton(
                                        icon: Icon(Icons.clear),
                                        onPressed: () {
                                          _addressController.clear();
                                          setState(() {
                                            _destination = null;
                                            _destinationAddress = null;
                                          });
                                        },
                                      ),
                                    PopupMenuButton<String>(
                                      icon: Icon(Icons.more_vert),
                                      onSelected: (value) {
                                        if (value == 'san_francisco') {
                                          _addressController.text =
                                              'San Francisco, CA';
                                          _searchAddress('San Francisco, CA');
                                        } else if (value == 'new_york') {
                                          _addressController.text =
                                              'New York, NY';
                                          _searchAddress('New York, NY');
                                        } else if (value == 'los_angeles') {
                                          _addressController.text =
                                              'Los Angeles, CA';
                                          _searchAddress('Los Angeles, CA');
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        PopupMenuItem(
                                          value: 'san_francisco',
                                          child: Text('San Francisco, CA'),
                                        ),
                                        PopupMenuItem(
                                          value: 'new_york',
                                          child: Text('New York, NY'),
                                        ),
                                        PopupMenuItem(
                                          value: 'los_angeles',
                                          child: Text('Los Angeles, CA'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              onSubmitted: (value) => _searchAddress(value),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _isSearching
                                ? null
                                : () => _searchAddress(_addressController.text),
                            child: _isSearching
                                ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text('Search'),
                          ),
                        ],
                      ),

                      if (_destinationAddress != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _destinationAddress!,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
                            _navigationController?.updateRouteStyleConfig(
                              _currentRouteStyle,
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          if (!_isLoading && _currentState.canStart)
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _destination != null
                                    ? _startNavigation
                                    : null,
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
          ],

          // Loading indicator - show regardless of controls visibility
          if (_isLoading)
            Positioned(
              top: 16,
              right: 16,
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(),
                ),
              ),
            ),

          // Floating action buttons - always accessible
          if (!_showControls && _currentState.canStart && _destination != null)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton.icon(
                    onPressed: _startNavigation,
                    icon: const Icon(Icons.navigation),
                    label: const Text('Start Navigation'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 48),
                    ),
                  ),
                ),
              ),
            ),

          // Re-center button
          Positioned(
            top: MediaQuery.of(context).size.height * 0.1,
            right: 16,
            child: Column(
              children: [
                if (_navigationController?.mapController.isFollowingLocation !=
                    true)
                  FloatingActionButton(
                    onPressed: _recenterMap,
                    child: const Icon(Icons.my_location),
                  ),
                // zoom in control
                FloatingActionButton(
                  heroTag: 'zoomIn',
                  onPressed: _zoomIn,
                  child: const Icon(Icons.add),
                ),
                // zoom out control
                FloatingActionButton(
                  heroTag: 'zoomOut',
                  onPressed: _zoomOut,
                  child: const Icon(Icons.remove),
                ),
              ],
            ),
          ),

          if (!_showControls)
            Positioned(
              top: 16,
              left: 16,
              child: FloatingActionButton(
                mini: true,
                onPressed: _showQuickSearchDialog,
                tooltip: 'Search Destination',
                child: const Icon(Icons.search),
              ),
            ),
        ],
      ),
    );
  }

  void _zoomIn() async {
    if (_mapController == null) return;
    final zoom = await _mapController!.zoomIn();
    _setZoom(zoom);
  }

  void _zoomOut() async {
    if (_mapController == null) return;
    final zoom = await _mapController!.zoomOut();
    _setZoom(zoom);
  }

  void _setZoom(double zoom) {
    if (_navigationController?.isNavigationActive == true) {
      _navigationZoom = zoom;
    } else {
      _defaultZoom = zoom;
    }

    setState(() {});
  }

  Future<void> _initializeNavigation() async {
    if (_mapController == null) return;

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

    // Validate destination
    if (_destination == null) {
      setState(() {
        _statusMessage = 'Please search for and select a destination first';
      });
      return;
    }

    // Ensure we have current location
    if (_currentLocation == null) {
      setState(() {
        _statusMessage = 'Waiting for current location...';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage =
          'Calculating route to ${_destinationAddress ?? 'destination'}...';
    });

    try {
      final result = await _navigationController!.startNavigation(
        origin: _currentLocation!, // Use current location as origin
        destination: _destination!,
      );

      if (result.success) {
        setState(() {
          _statusMessage =
              'Navigation started! Following route to ${_destinationAddress ?? 'destination'}...';
        });
      } else {
        setState(() {
          _statusMessage = 'Failed to start navigation: ${result.message}';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error starting navigation: $e';
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

  // Quick search dialog for when controls are hidden
  Future<void> _showQuickSearchDialog() async {
    final TextEditingController dialogController = TextEditingController(
      text: _destinationAddress ?? '',
    );

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Search Destination'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: dialogController,
                decoration: const InputDecoration(
                  hintText: 'Enter address or place name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.search),
                ),
                autofocus: true,
                onSubmitted: (value) {
                  Navigator.of(context).pop();
                  _addressController.text = value;
                  _searchAddress(value);
                },
              ),
              const SizedBox(height: 16),
              if (_destinationAddress != null) ...[
                Text('Current destination:'),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _destinationAddress!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            if (_destination != null)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _startNavigation();
                },
                child: const Text('Navigate'),
              ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _addressController.text = dialogController.text;
                _searchAddress(dialogController.text);
              },
              child: const Text('Search'),
            ),
          ],
        );
      },
    );
  }

  // Address search functionality
  Future<void> _searchAddress(String address) async {
    if (address.trim().isEmpty) {
      setState(() {
        _statusMessage = 'Please enter an address';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _statusMessage = 'Searching for address...';
    });

    try {
      // Use geocoding to convert address to coordinates
      List<Location> locations = await locationFromAddress(address);

      if (locations.isNotEmpty) {
        final location = locations.first;
        final destinationPoint = LocationPoint.fromLatLng(
          location.latitude,
          location.longitude,
        );

        // Get the formatted address for display
        List<Placemark> placemarks = await placemarkFromCoordinates(
          location.latitude,
          location.longitude,
        );

        String formattedAddress = address; // fallback to input
        if (placemarks.isNotEmpty) {
          final placemark = placemarks.first;
          formattedAddress = _formatAddress(placemark);
        }

        setState(() {
          _destination = destinationPoint;
          _destinationAddress = formattedAddress;
          _statusMessage = 'Destination found! Ready to navigate.';
          _isSearching = false;
        });

        // Optionally center map on the destination
        if (_mapController != null) {
          await _mapController!.moveCamera(
            center: destinationPoint,
            zoom: 15.0,
            animation: const CameraAnimation(
              duration: Duration(milliseconds: 800),
              type: AnimationType.easeInOut,
            ),
          );
        }
      } else {
        setState(() {
          _statusMessage = 'No results found for "$address"';
          _destination = null;
          _destinationAddress = null;
          _isSearching = false;
        });
      }
    } catch (e) {
      String errorMessage = 'Error searching for address';

      // Provide more specific error messages
      if (e.toString().contains('network')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else if (e.toString().contains('timeout')) {
        errorMessage = 'Request timed out. Please try again.';
      } else if (e.toString().contains('not found')) {
        errorMessage = 'Address not found. Please try a different search.';
      } else {
        errorMessage = 'Error searching for address: ${e.toString()}';
      }

      setState(() {
        _statusMessage = errorMessage;
        _destination = null;
        _destinationAddress = null;
        _isSearching = false;
      });
    }
  }

  // Helper method to format address from placemark
  String _formatAddress(Placemark placemark) {
    final parts = <String>[];

    if (placemark.street?.isNotEmpty == true) {
      parts.add(placemark.street!);
    }

    if (placemark.subLocality?.isNotEmpty == true) {
      parts.add(placemark.subLocality!);
    } else if (placemark.locality?.isNotEmpty == true) {
      parts.add(placemark.locality!);
    }

    if (placemark.administrativeArea?.isNotEmpty == true) {
      parts.add(placemark.administrativeArea!);
    }

    if (placemark.postalCode?.isNotEmpty == true) {
      parts.add(placemark.postalCode!);
    }

    if (placemark.country?.isNotEmpty == true) {
      parts.add(placemark.country!);
    }

    return parts.join(', ');
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
