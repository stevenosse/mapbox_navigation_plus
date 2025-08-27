import 'package:flutter/material.dart';
import 'package:mapbox_navigation/mapbox_navigation.dart';

class AdvancedFeaturesScreen extends StatefulWidget {
  final String accessToken;

  const AdvancedFeaturesScreen({super.key, required this.accessToken});

  @override
  State<AdvancedFeaturesScreen> createState() => _AdvancedFeaturesScreenState();
}

class _AdvancedFeaturesScreenState extends State<AdvancedFeaturesScreen> {
  NavigationController? _navigationController;
  NavigationState _navigationState = NavigationState.idle();
  NavigationStep? _currentStep;
  RouteData? _currentRoute;
  bool _isNavigating = false;
  bool _showCustomInstructions = true;
  bool _useSimulation = true;
  double _simulationSpeed = 2.0;

  // Multiple waypoints example (San Francisco -> Oakland -> San Jose)
  final List<Waypoint> _waypoints = [
    Waypoint(
      latitude: 37.7749,
      longitude: -122.4194,
      name: 'San Francisco, CA',
    ),
    Waypoint(
      latitude: 37.8044,
      longitude: -122.2712,
      name: 'Oakland, CA',
    ),
    Waypoint(
      latitude: 37.3382,
      longitude: -121.8863,
      name: 'San Jose, CA',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Features'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Advanced Controls Panel
          _buildAdvancedControlsPanel(),

          // Navigation View
          Expanded(
            child: MapboxNavigationView(
              accessToken: widget.accessToken,
              initialCameraPosition: CameraOptions(
                center: Point(
                  coordinates:
                      Position(_waypoints[0].longitude, _waypoints[0].latitude),
                ),
                zoom: 10.0,
              ),
              styleUri: MapboxStyles.MAPBOX_STREETS,
              onMapReady: _onMapReady,
              onNavigationStateChanged: _onNavigationStateChanged,
              onStepChanged: _onStepChanged,
              onError: _onError,
              instructionBuilder: _showCustomInstructions
                  ? (NavigationStep step) => _buildCustomInstruction(step)!
                  : null,
              showInstructions: !_showCustomInstructions,
              voiceSettings: const VoiceSettings(
                enabled: true,
                speechRate: 0.6,
                pitch: 1.1,
                volume: 0.9,
                language: 'en-US',
                minimumInterval: 3,
                announcementDistances: [800, 400, 100],
                announceArrival: true,
                announceRouteRecalculation: true,
              ),
              enableTrafficData: true,
              simulationSpeed: _useSimulation ? _simulationSpeed : 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedControlsPanel() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status and Route Info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Status: ${_navigationState.status.name}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (_currentRoute != null)
                        Text(
                          '${(_currentRoute!.totalDistance / 1000).toStringAsFixed(1)} km',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                    ],
                  ),
                  if (_currentStep != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Next: ${_currentStep!.instruction}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: _navigationState.routeProgress,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).primaryColor,
                      ),
                    ),
                  ]
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Navigation Controls
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed:
                      _isNavigating ? null : _startMultiWaypointNavigation,
                  icon: const Icon(Icons.route),
                  label: const Text('Multi-Stop Route'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isNavigating ? _stopNavigation : null,
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget? _buildCustomInstruction(NavigationStep step) {
    return Positioned(
      top: 60,
      left: 16,
      right: 16,
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                Theme.of(context).primaryColor,
                Theme.of(context).primaryColor.withValues(alpha: 0.8),
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getManeuverIcon(step.maneuver),
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.instruction,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'In ${step.distance.toInt()}m',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Progress bar
              const SizedBox(height: 16),
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _navigationState.stepProgress,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getManeuverIcon(String maneuver) {
    switch (maneuver.toLowerCase()) {
      case 'turn-left':
      case 'turn-slight-left':
      case 'turn-sharp-left':
        return Icons.turn_left;
      case 'turn-right':
      case 'turn-slight-right':
      case 'turn-sharp-right':
        return Icons.turn_right;
      case 'straight':
      case 'continue':
        return Icons.straight;
      case 'uturn':
        return Icons.u_turn_left;
      case 'merge':
        return Icons.merge;
      case 'on-ramp':
      case 'off-ramp':
        return Icons.ramp_left;
      case 'fork':
        return Icons.call_split;
      case 'roundabout':
        return Icons.roundabout_left;
      case 'arrive':
        return Icons.flag;
      default:
        return Icons.navigation;
    }
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
          _currentRoute = state.route;
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
    debugPrint('Advanced Navigation state changed: ${state.status}');

    // Show arrival notification
    if (state.status == NavigationStatus.arrived) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Arrived at waypoint!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _onStepChanged(NavigationStep step) {
    debugPrint('Advanced Navigation step: ${step.instruction}');
  }

  void _onError(String error) {
    debugPrint('Advanced Navigation error: $error');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Navigation error: $error'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> _startMultiWaypointNavigation() async {
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
      // Start navigation with multiple waypoints
      await _navigationController!.startNavigation(
        origin: _waypoints.first,
        destination: _waypoints.last,
        stops: _waypoints.length > 2
            ? _waypoints.sublist(1, _waypoints.length - 1)
            : null,
        profile: 'driving-traffic',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🚗 Multi-waypoint navigation started!'),
          backgroundColor: Colors.blue,
        ),
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

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Navigation stopped'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to stop navigation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Advanced Settings'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: const Text('Custom Instructions'),
                    subtitle: const Text('Use custom instruction widget'),
                    value: _showCustomInstructions,
                    onChanged: (value) {
                      setDialogState(() {
                        _showCustomInstructions = value;
                      });
                      setState(() {
                        _showCustomInstructions = value;
                      });
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Simulation Mode'),
                    subtitle: const Text('Enable route simulation'),
                    value: _useSimulation,
                    onChanged: (value) {
                      setDialogState(() {
                        _useSimulation = value;
                      });
                      setState(() {
                        _useSimulation = value;
                      });
                    },
                  ),
                  if (_useSimulation) ...[
                    const SizedBox(height: 16),
                    Text(
                        'Simulation Speed: ${_simulationSpeed.toStringAsFixed(1)}x'),
                    Slider(
                      value: _simulationSpeed,
                      min: 0.5,
                      max: 5.0,
                      divisions: 9,
                      onChanged: (value) {
                        setDialogState(() {
                          _simulationSpeed = value;
                        });
                        setState(() {
                          _simulationSpeed = value;
                        });
                      },
                    ),
                  ]
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
