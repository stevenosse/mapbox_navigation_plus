// ignore_for_file: unused_field

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;
import 'package:mapbox_navigation_plus/core/constants.dart';
import '../../core/interfaces/map_controller_interface.dart';
import '../../core/models/route_model.dart';
import '../../core/models/location_point.dart';
import '../../core/models/route_progress.dart';
import '../../core/models/map_marker.dart';
import '../../core/models/route_style_config.dart';
import '../../core/models/location_puck_config.dart';
import '../../core/models/destination_pin_config.dart';

/// Mapbox Maps implementation of MapControllerInterface
class MapboxMapController implements MapControllerInterface {
  final mb.MapboxMap _mapboxMap;

  /// Get access to the underlying MapboxMap for advanced usage
  mb.MapboxMap get mapboxMap => _mapboxMap;

  /// Point annotation manager for custom markers
  mb.PointAnnotationManager? pointAnnotationManager;

  // Layer and source IDs for route visualization
  static const String _routeSourceId = 'route_source';
  static const String _routeLayerId = 'route_layer';
  static const String _progressSourceId = 'progress_source';
  static const String _progressLayerId = 'progress_layer';
  static const String _traveledSourceId = 'traveled_source';
  static const String _traveledLayerId = 'traveled_layer';
  static const String _markerSourceId = 'marker_source';

  // Custom location puck layer and source IDs
  static const String _locationPuckSourceId = 'location_puck_source';

  // Destination pin layer and source IDs
  static const String _destinationPinSourceId = 'destination_pin_source';
  static const String _destinationPinLayerId = 'destination_pin_layer';

  bool _isFollowingLocation = true;
  LocationPoint? _currentLocation;
  LocationPoint? _lastLocation;

  // Configuration instances
  LocationPuckConfig? _locationPuckConfig;
  DestinationPinConfig? _destinationPinConfig;

  final StreamController<CameraPosition> _cameraPositionController =
      StreamController<CameraPosition>.broadcast();
  final StreamController<MapGesture> _gestureController =
      StreamController<MapGesture>.broadcast();

  MapboxMapController(this._mapboxMap) {
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    await _createDataSources();
    await _createLayers();
  }

  Future<void> _createDataSources() async {
    // Create route line source
    await _mapboxMap.style.addSource(
      mb.GeoJsonSource(
        id: _routeSourceId,
        data: '{"type":"FeatureCollection","features":[]}',
      ),
    );

    // Create progress line source
    await _mapboxMap.style.addSource(
      mb.GeoJsonSource(
        id: _progressSourceId,
        data: '{"type":"FeatureCollection","features":[]}',
      ),
    );

    // Create traveled line source
    await _mapboxMap.style.addSource(
      mb.GeoJsonSource(
        id: _traveledSourceId,
        data: '{"type":"FeatureCollection","features":[]}',
      ),
    );

    // Create marker source
    await _mapboxMap.style.addSource(
      mb.GeoJsonSource(
        id: _markerSourceId,
        data: '{"type":"FeatureCollection","features":[]}',
      ),
    );

    // Create marker layer
    final markerLayer = mb.SymbolLayer(
      id: 'marker_layer',
      sourceId: _markerSourceId,
    );
    await _mapboxMap.style.addLayer(markerLayer);

    // Set marker layer properties
    await _mapboxMap.style.setStyleLayerProperty('marker_layer', 'icon-image', [
      'get',
      'icon',
    ]);
    await _mapboxMap.style.setStyleLayerProperty(
      'marker_layer',
      'icon-size',
      1.0,
    );
    await _mapboxMap.style.setStyleLayerProperty(
      'marker_layer',
      'icon-allow-overlap',
      true,
    );
    await _mapboxMap.style.setStyleLayerProperty(
      'marker_layer',
      'icon-ignore-placement',
      true,
    );

    // Create location puck source
    await _mapboxMap.style.addSource(
      mb.GeoJsonSource(
        id: _locationPuckSourceId,
        data: '{"type":"FeatureCollection","features":[]}',
      ),
    );
  }

  Future<void> _createLayers() async {
    // Create route layer
    final routeLayer = mb.LineLayer(
      id: _routeLayerId,
      sourceId: _routeSourceId,
    );
    try {
      await _mapboxMap.style.addLayerAt(
        routeLayer,
        mb.LayerPosition(below: 'mapbox-location-indicator-layer'),
      );
    } catch (e) {
      // Fallback: if location layer doesn't exist yet, add normally and it will be below when location is enabled
      await _mapboxMap.style.addLayer(routeLayer);
    }

    // Set route layer properties
    await _mapboxMap.style.setStyleLayerProperty(
      _routeLayerId,
      'line-color',
      '#3366CC',
    );
    await _mapboxMap.style.setStyleLayerProperty(
      _routeLayerId,
      'line-width',
      14.0,
    );
    await _mapboxMap.style.setStyleLayerProperty(
      _routeLayerId,
      'line-opacity',
      0.8,
    );

    // Create progress layer (remaining route)
    final progressLayer = mb.LineLayer(
      id: _progressLayerId,
      sourceId: _progressSourceId,
    );

    try {
      await _mapboxMap.style.addLayerAt(
        progressLayer,
        mb.LayerPosition(below: 'mapbox-location-indicator-layer'),
      );
    } catch (e) {
      await _mapboxMap.style.addLayer(progressLayer);
    }

    // Set progress layer properties
    await _mapboxMap.style.setStyleLayerProperty(
      _progressLayerId,
      'line-color',
      '#00AA00',
    );
    await _mapboxMap.style.setStyleLayerProperty(
      _progressLayerId,
      'line-width',
      14.0,
    );
    await _mapboxMap.style.setStyleLayerProperty(
      _progressLayerId,
      'line-opacity',
      1.0,
    );

    // Create traveled route layer
    final traveledLayer = mb.LineLayer(
      id: _traveledLayerId,
      sourceId: _traveledSourceId,
    );

    try {
      await _mapboxMap.style.addLayerAt(
        traveledLayer,
        mb.LayerPosition(below: 'mapbox-location-indicator-layer'),
      );
    } catch (e) {
      await _mapboxMap.style.addLayer(traveledLayer);
    }

    // Set traveled layer properties
    await _mapboxMap.style.setStyleLayerProperty(
      _traveledLayerId,
      'line-color',
      '#999999',
    );
    await _mapboxMap.style.setStyleLayerProperty(
      _traveledLayerId,
      'line-width',
      8.0,
    );
    await _mapboxMap.style.setStyleLayerProperty(
      _traveledLayerId,
      'line-opacity',
      0.7,
    );
  }

  @override
  Future<void> drawRoute({
    required RouteModel route,
    RouteStyleConfig? styleConfig,
  }) async {
    try {
      // Use provided style config or default
      final config = styleConfig ?? RouteStyleConfig.defaultConfig;
      final routeStyle = config.routeLineStyle;

      // Convert route geometry to coordinates
      final coordinates = route.geometry
          .map((point) => '[${point.longitude},${point.latitude}]')
          .join(',');

      // Create GeoJSON string for the route
      final routeGeoJson =
          '{"type":"Feature","geometry":{"type":"LineString","coordinates":[$coordinates]},"properties":{}}';

      // Update route source
      await _mapboxMap.style.getSource(_routeSourceId).then((source) async {
        if (source is mb.GeoJsonSource) {
          await source.updateGeoJSON(routeGeoJson);
        }
      });

      // Update route layer styling using the new configuration
      await _mapboxMap.style.setStyleLayerProperty(
        _routeLayerId,
        'line-color',
        routeStyle.colorHex,
      );
      await _mapboxMap.style.setStyleLayerProperty(
        _routeLayerId,
        'line-width',
        routeStyle.width,
      );
      await _mapboxMap.style.setStyleLayerProperty(
        _routeLayerId,
        'line-opacity',
        routeStyle.opacity,
      );
      await _mapboxMap.style.setStyleLayerProperty(
        _routeLayerId,
        'line-cap',
        routeStyle.capStyle.value,
      );
      await _mapboxMap.style.setStyleLayerProperty(
        _routeLayerId,
        'line-join',
        routeStyle.joinStyle.value,
      );

      // Add markers for origin and destination
      final markers = <MapMarker>[
        MapMarker.origin(position: route.origin),
        MapMarker.destination(position: route.destination),
      ];

      // Add waypoint markers if any
      for (int i = 0; i < route.waypoints.length; i++) {
        markers.add(
          MapMarker.waypoint(position: route.waypoints[i], index: i + 1),
        );
      }

      await addMarkers(markers);
    } catch (e) {
      throw Exception('Failed to draw route: $e');
    }
  }

  @override
  Future<void> updateProgressLine({
    required RouteProgress progress,
    RouteStyleConfig? styleConfig,
  }) async {
    try {
      // Use provided style config or default
      final config = styleConfig ?? RouteStyleConfig.defaultConfig;
      final traveledStyle = config.traveledLineStyle;
      final remainingStyle = config.remainingLineStyle;

      final route = progress.route;
      final geometry = route.geometry;

      if (geometry.isEmpty) return;

      // Calculate how much of the route has been traveled
      final traveledIndices = _getTraveledGeometryIndices(
        geometry,
        progress.distanceTraveled,
        route.distance,
      );

      // Create traveled route geometry
      final traveledGeometry = traveledIndices.isEmpty
          ? <LocationPoint>[]
          : geometry.sublist(0, traveledIndices.last + 1);

      // Create remaining route geometry
      final remainingGeometry = traveledIndices.isEmpty
          ? geometry
          : geometry.sublist(traveledIndices.last);

      // Update traveled route
      if (traveledGeometry.isNotEmpty) {
        final traveledLineString = mb.LineString(
          coordinates: traveledGeometry
              .map((point) => mb.Position(point.longitude, point.latitude))
              .toList(),
        );
        final traveledFeature = mb.Feature(
          id: 'traveled',
          geometry: traveledLineString,
          properties: {
            'color': traveledStyle.colorHex,
            'width': traveledStyle.width,
            'opacity': traveledStyle.opacity,
          },
        );

        await _mapboxMap.style.getSource(_traveledSourceId).then((
          source,
        ) async {
          if (source is mb.GeoJsonSource) {
            await source.updateGeoJSON(
              jsonEncode(
                mb.FeatureCollection(features: [traveledFeature]).toJson(),
              ),
            );
          }
        });

        // Update traveled layer styling
        await _mapboxMap.style.setStyleLayerProperty(
          _traveledLayerId,
          'line-color',
          traveledStyle.colorHex,
        );
        await _mapboxMap.style.setStyleLayerProperty(
          _traveledLayerId,
          'line-width',
          traveledStyle.width,
        );
        await _mapboxMap.style.setStyleLayerProperty(
          _traveledLayerId,
          'line-opacity',
          traveledStyle.opacity,
        );
        await _mapboxMap.style.setStyleLayerProperty(
          _traveledLayerId,
          'line-cap',
          traveledStyle.capStyle.value,
        );
        await _mapboxMap.style.setStyleLayerProperty(
          _traveledLayerId,
          'line-join',
          traveledStyle.joinStyle.value,
        );
      }

      // Update remaining route
      if (remainingGeometry.isNotEmpty) {
        final remainingLineString = mb.LineString(
          coordinates: remainingGeometry
              .map((point) => mb.Position(point.longitude, point.latitude))
              .toList(),
        );
        final remainingFeature = mb.Feature(
          id: 'remaining',
          geometry: remainingLineString,
          properties: {
            'color': remainingStyle.colorHex,
            'width': remainingStyle.width,
            'opacity': remainingStyle.opacity,
          },
        );

        await _mapboxMap.style.getSource(_progressSourceId).then((
          source,
        ) async {
          if (source is mb.GeoJsonSource) {
            await source.updateGeoJSON(
              jsonEncode(
                mb.FeatureCollection(features: [remainingFeature]).toJson(),
              ),
            );
          }
        });

        // Update remaining layer styling
        await _mapboxMap.style.setStyleLayerProperty(
          _progressLayerId,
          'line-color',
          remainingStyle.colorHex,
        );
        await _mapboxMap.style.setStyleLayerProperty(
          _progressLayerId,
          'line-width',
          remainingStyle.width,
        );
        await _mapboxMap.style.setStyleLayerProperty(
          _progressLayerId,
          'line-opacity',
          remainingStyle.opacity,
        );
        await _mapboxMap.style.setStyleLayerProperty(
          _progressLayerId,
          'line-cap',
          remainingStyle.capStyle.value,
        );
        await _mapboxMap.style.setStyleLayerProperty(
          _progressLayerId,
          'line-join',
          remainingStyle.joinStyle.value,
        );
      }
    } catch (e) {
      throw Exception('Failed to update progress line: $e');
    }
  }

  @override
  Future<void> addMarkers(List<MapMarker> markers) async {
    try {
      // Use AnnotationManager for destination markers with custom icons
      if (pointAnnotationManager != null) {
        final pointAnnotations = <mb.PointAnnotationOptions>[];

        for (final marker in markers) {
          if (marker.type == MarkerType.destination) {
            // Load custom image for this marker
            final flagBytes = await rootBundle.load(kDefaultArrivalMarker);

            pointAnnotations.add(
              mb.PointAnnotationOptions(
                geometry: mb.Point(
                  coordinates: mb.Position(
                    marker.position.longitude,
                    marker.position.latitude,
                  ),
                ),
                image: flagBytes.buffer.asUint8List(),
              ),
            );
          }
        }

        if (pointAnnotations.isNotEmpty) {
          await pointAnnotationManager!.createMulti(pointAnnotations);
        }
      }

      // Use symbol layer for other markers
      final features = markers
          .map((marker) {
            String iconImage = marker.iconImage ?? marker.defaultIconImage;

            // Skip destination markers as they're handled by AnnotationManager
            if (marker.type == MarkerType.destination) {
              return null;
            }

            return mb.Feature(
              id: marker.id,
              geometry: mb.Point(
                coordinates: mb.Position(
                  marker.position.longitude,
                  marker.position.latitude,
                ),
              ),
              properties: {
                'id': marker.id,
                'title': marker.title ?? '',
                'subtitle': marker.subtitle ?? '',
                'type': marker.type.name,
                'color': marker.color,
                'size': marker.sizeInPixels,
                'icon': iconImage,
                ...marker.data,
              },
            );
          })
          .where((feature) => feature != null)
          .cast<mb.Feature>()
          .toList();

      await _mapboxMap.style.getSource(_markerSourceId).then((source) async {
        if (source is mb.GeoJsonSource) {
          await source.updateGeoJSON(
            jsonEncode(mb.FeatureCollection(features: features).toJson()),
          );
        }
      });
    } catch (e) {
      throw Exception('Failed to add markers: $e');
    }
  }

  @override
  Future<void> clearMarkers() async {
    try {
      await _mapboxMap.style.getSource(_markerSourceId).then((source) async {
        if (source is mb.GeoJsonSource) {
          await source.updateGeoJSON(
            '{"type":"FeatureCollection","features":[]}',
          );
        }
      });
    } catch (e) {
      throw Exception('Failed to clear markers: $e');
    }
  }

  @override
  Future<void> moveCamera({
    required LocationPoint center,
    double? zoom,
    double? bearing,
    double? pitch,
    double? heading,
    CameraAnimation? animation,
  }) async {
    try {
      final cameraOptions = mb.CameraOptions(
        center: mb.Point(
          coordinates: mb.Position(center.longitude, center.latitude),
        ),
        zoom: zoom?.toDouble(),
        bearing: bearing?.toDouble(),
        pitch: pitch?.toDouble(),
      );

      if (animation != null) {
        await _mapboxMap.flyTo(
          cameraOptions,
          mb.MapAnimationOptions(duration: animation.duration.inMilliseconds),
        );
      } else {
        await _mapboxMap.setCamera(cameraOptions);
      }
    } catch (e) {
      throw Exception('Failed to move camera: $e');
    }
  }

  @override
  Future<void> centerOnLocation({
    required LocationPoint location,
    double zoom = 16.0,
    bool followLocation = false,
  }) async {
    _currentLocation = location;
    _isFollowingLocation = followLocation;

    await moveCamera(
      center: location,
      zoom: zoom,
      bearing: location.heading,
      animation: const CameraAnimation(
        duration: Duration(milliseconds: 800),
        type: AnimationType.easeInOut,
      ),
    );
  }

  @override
  Future<void> setLocationFollowMode(bool follow) async {
    _isFollowingLocation = follow;

    if (follow && _currentLocation != null) {
      await centerOnLocation(location: _currentLocation!, followLocation: true);
    }
  }

  @override
  Future<void> clearRoute() async {
    try {
      // Clear route sources
      await _mapboxMap.style.getSource(_routeSourceId).then((source) async {
        if (source is mb.GeoJsonSource) {
          await source.updateGeoJSON(
            '{"type":"FeatureCollection","features":[]}',
          );
        }
      });

      await _mapboxMap.style.getSource(_progressSourceId).then((source) async {
        if (source is mb.GeoJsonSource) {
          await source.updateGeoJSON(
            '{"type":"FeatureCollection","features":[]}',
          );
        }
      });

      await _mapboxMap.style.getSource(_traveledSourceId).then((source) async {
        if (source is mb.GeoJsonSource) {
          await source.updateGeoJSON(
            '{"type":"FeatureCollection","features":[]}',
          );
        }
      });
    } catch (e) {
      throw Exception('Failed to clear route: $e');
    }
  }

  @override
  Future<void> clear() async {
    await clearRoute();
    await clearMarkers();
  }

  @override
  Future<CameraPosition> getCameraPosition() async {
    try {
      final camera = await _mapboxMap.getCameraState();
      return CameraPosition(
        center: LocationPoint(
          latitude: camera.center.coordinates.lat.toDouble(),
          longitude: camera.center.coordinates.lng.toDouble(),
          timestamp: DateTime.now(),
        ),
        zoom: camera.zoom,
        bearing: camera.bearing,
        pitch: camera.pitch,
      );
    } catch (e) {
      throw Exception('Failed to get camera position: $e');
    }
  }

  @override
  Stream<CameraPosition> get cameraPositionStream =>
      _cameraPositionController.stream;

  @override
  Stream<MapGesture> get gestureStream => _gestureController.stream;

  @override
  bool get isFollowingLocation => _isFollowingLocation;

  List<int> _getTraveledGeometryIndices(
    List<LocationPoint> geometry,
    double distanceTraveled,
    double totalDistance,
  ) {
    if (geometry.isEmpty || totalDistance <= 0) return [];

    final progressRatio = (distanceTraveled / totalDistance).clamp(0.0, 1.0);
    final targetIndex = (geometry.length * progressRatio).round();

    return List.generate(targetIndex.clamp(0, geometry.length), (i) => i);
  }

  /// Updates the custom location puck position and heading
  @override
  Future<void> updateLocationPuck(LocationPoint location) async {
    try {
      _currentLocation = location;
      _lastLocation = _lastLocation ?? location;

      // Calculate smooth heading if not provided
      double heading = location.heading ?? 0.0;
      if (heading == 0.0 && _lastLocation != null) {
        heading = _calculateHeading(_lastLocation!, location);
      }

      _lastLocation = location;
    } catch (e) {
      throw Exception('Failed to update location puck: $e');
    }
  }

  /// Sets the location puck to idle state with car marker and background
  @override
  Future<void> setIdleLocationPuck() async {
    try {
      final mapboxMap = _mapboxMap;
      final config = _locationPuckConfig ?? LocationPuckThemes.defaultTheme;

      Uint8List? customLocationPuckBytes;
      Uint8List? customLocationPuckBackgroundBytes;

      // Load idle image
      try {
        final imageData = await rootBundle.load(
          config.idleImagePath ?? kDefaultLocationPuck,
        );
        customLocationPuckBytes = imageData.buffer.asUint8List();
      } catch (e) {
        debugPrint('Failed to load idle location puck image: $e');
        return;
      }

      // Load background image for idle state if accuracy circle is enabled
      if (config.showAccuracyCircle) {
        try {
          final shadowData = await rootBundle.load(
            kDefaultLocationPuckBackground,
          );
          customLocationPuckBackgroundBytes = shadowData.buffer.asUint8List();
        } catch (e) {
          debugPrint('Failed to load idle location puck background: $e');
        }
      }

      // Create idle location puck with configuration
      final locationPuck = mb.LocationPuck(
        locationPuck2D: mb.LocationPuck2D(
          topImage: customLocationPuckBytes,
          bearingImage: customLocationPuckBytes,
          shadowImage: customLocationPuckBackgroundBytes,
          opacity: config.opacity,
        ),
      );

      // Update location puck settings
      final locationSettings = mb.LocationComponentSettings(
        enabled: true,
        locationPuck: locationPuck,
        pulsingEnabled: false,
        puckBearing: mb.PuckBearing.HEADING,
        puckBearingEnabled: true,
      );

      // Apply the new settings
      await mapboxMap.location.updateSettings(locationSettings);
    } catch (e) {
      throw Exception('Failed to set idle location puck: $e');
    }
  }

  /// Sets the location puck to navigation state with navigation marker (no background)
  @override
  Future<void> setNavigationLocationPuck() async {
    try {
      final mapboxMap = _mapboxMap;
      final config = _locationPuckConfig ?? LocationPuckThemes.defaultTheme;

      Uint8List? customLocationPuckBytes;

      try {
        final imageData = await rootBundle.load(
          config.navigationImagePath ?? kDefaultNavigationLocationPuck,
        );
        customLocationPuckBytes = imageData.buffer.asUint8List();
      } catch (e) {
        debugPrint('Failed to load navigation location puck image: $e');
        return;
      }

      final locationPuck = mb.LocationPuck(
        locationPuck2D: mb.LocationPuck2D(
          bearingImage: customLocationPuckBytes,
          opacity: config.opacity,
        ),
      );

      // Update location puck settings
      final locationSettings = mb.LocationComponentSettings(
        enabled: true,
        locationPuck: locationPuck,
        pulsingEnabled: false,
        puckBearing: mb.PuckBearing.COURSE,
        puckBearingEnabled: true,
      );

      // Apply the new settings
      await mapboxMap.location.updateSettings(locationSettings);
    } catch (e) {
      throw Exception('Failed to set navigation location puck: $e');
    }
  }

  /// Removes the location puck from the map
  @override
  Future<void> hideLocationPuck() async {
    try {
      await _mapboxMap.style.getSource(_locationPuckSourceId).then((
        source,
      ) async {
        if (source is mb.GeoJsonSource) {
          await source.updateGeoJSON(
            '{"type":"FeatureCollection","features":[]}',
          );
        }
      });
    } catch (e) {
      throw Exception('Failed to hide location puck: $e');
    }
  }

  /// Calculates heading between two points
  double _calculateHeading(LocationPoint from, LocationPoint to) {
    final double deltaLon = to.longitude - from.longitude;
    final double y =
        math.sin(deltaLon * math.pi / 180) *
        math.cos(to.latitude * math.pi / 180);
    final double x =
        math.cos(from.latitude * math.pi / 180) *
            math.sin(to.latitude * math.pi / 180) -
        math.sin(from.latitude * math.pi / 180) *
            math.cos(to.latitude * math.pi / 180) *
            math.cos(deltaLon * math.pi / 180);

    double bearing = math.atan2(y, x) * 180 / math.pi;
    return (bearing + 360) % 360;
  }

  /// Dispose resources
  void dispose() {
    _cameraPositionController.close();
    _gestureController.close();
  }

  /// Configures the location puck appearance
  @override
  Future<void> configureLocationPuck(LocationPuckConfig config) async {
    _locationPuckConfig = config;
    // Apply the configuration to the current location puck if it exists
    if (_currentLocation != null) {
      await updateLocationPuck(_currentLocation!);
    }
  }

  /// Sets the destination pin configuration
  @override
  Future<void> configureDestinationPin(DestinationPinConfig config) async {
    _destinationPinConfig = config;
  }

  /// Shows destination pin at specified location
  @override
  Future<void> showDestinationPin(LocationPoint location) async {
    try {
      final config =
          _destinationPinConfig ?? DestinationPinConfig.defaultConfig;

      // Create destination pin annotation
      pointAnnotationManager ??= await _mapboxMap.annotations
          .createPointAnnotationManager();

      // Create the point annotation
      mb.PointAnnotationOptions annotation;

      if (config.imagePath != null) {
        // Load custom image
        final imageData = await rootBundle.load(config.imagePath!);
        final imageBytes = imageData.buffer.asUint8List();

        annotation = mb.PointAnnotationOptions(
          geometry: mb.Point(
            coordinates: mb.Position(location.longitude, location.latitude),
          ),
          image: imageBytes,
        );
      } else {
        // Use default pin without custom image
        annotation = mb.PointAnnotationOptions(
          geometry: mb.Point(
            coordinates: mb.Position(location.longitude, location.latitude),
          ),
        );
      }

      await pointAnnotationManager!.create(annotation);
    } catch (e) {
      throw Exception('Failed to show destination pin: $e');
    }
  }

  /// Hides the destination pin
  @override
  Future<void> hideDestinationPin() async {
    try {
      if (pointAnnotationManager != null) {
        await pointAnnotationManager!.deleteAll();
      }
    } catch (e) {
      throw Exception('Failed to hide destination pin: $e');
    }
  }

  // Multiple routes management
  final Map<String, String> _multipleRouteIds = {};
  String? _highlightedRouteId;

  /// Clears all multiple routes from the map
  @override
  Future<void> clearMultipleRoutes() async {
    try {
      // Remove all multiple route layers and sources
      for (final entry in _multipleRouteIds.entries) {
        final routeId = entry.key;
        final layerId = entry.value;
        final sourceId = '${_routeSourceId}_multiple_$routeId';

        try {
          // Remove layer
          await _mapboxMap.style.removeStyleLayer(layerId);
        } catch (e) {
          // Layer might not exist, continue
        }

        try {
          // Remove source
          await _mapboxMap.style.removeStyleSource(sourceId);
        } catch (e) {
          // Source might not exist, continue
        }
      }

      // Clear the tracking maps
      _multipleRouteIds.clear();
      _highlightedRouteId = null;
    } catch (e) {
      throw Exception('Failed to clear multiple routes: $e');
    }
  }

  /// Draws multiple routes on the map with different colors
  @override
  Future<void> drawMultipleRoutes({
    required List<RouteModel> routes,
    List<Color>? colors,
    RouteStyleConfig? baseStyleConfig,
  }) async {
    try {
      if (routes.isEmpty) return;

      // Clear existing multiple routes first
      await clearMultipleRoutes();

      // Use provided colors or generate default ones
      final routeColors =
          colors ??
          [
            const Color(0xFF3366CC), // Blue
            const Color(0xFF00AA00), // Green
            const Color(0xFFFF6600), // Orange
            const Color(0xFFCC00CC), // Purple
            const Color(0xFF00CCCC), // Cyan
          ];

      final baseConfig = baseStyleConfig ?? RouteStyleConfig.defaultConfig;

      // Create each route with its own layer and source
      for (int i = 0; i < routes.length; i++) {
        final route = routes[i];
        final routeId = route.id;
        final color = routeColors[i % routeColors.length];

        // Create unique source and layer IDs for this route
        final sourceId = '${_routeSourceId}_multiple_$routeId';
        final layerId = '${_routeLayerId}_multiple_$routeId';

        // Convert route geometry to coordinates
        final coordinates = route.geometry
            .map((point) => '[${point.longitude},${point.latitude}]')
            .join(',');

        // Create GeoJSON string for the route
        final routeGeoJson =
            '{"type":"Feature","geometry":{"type":"LineString","coordinates":[$coordinates]},"properties":{"routeId":"$routeId"}}';

        // Add source for this route
        await _mapboxMap.style.addSource(
          mb.GeoJsonSource(id: sourceId, data: routeGeoJson),
        );

        // Create and add layer for this route
        final routeLayer = mb.LineLayer(id: layerId, sourceId: sourceId);

        try {
          await _mapboxMap.style.addLayerAt(
            routeLayer,
            mb.LayerPosition(below: 'mapbox-location-indicator-layer'),
          );
        } catch (e) {
          // Fallback: add layer normally
          await _mapboxMap.style.addLayer(routeLayer);
        }

        // Set route layer properties with custom color
        await _mapboxMap.style.setStyleLayerProperty(
          layerId,
          'line-color',
          '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
        );
        await _mapboxMap.style.setStyleLayerProperty(
          layerId,
          'line-width',
          baseConfig.routeLineStyle.width,
        );
        await _mapboxMap.style.setStyleLayerProperty(
          layerId,
          'line-opacity',
          i == 0 ? 1.0 : 0.8, // First route (usually fastest) is more prominent
        );
        await _mapboxMap.style.setStyleLayerProperty(
          layerId,
          'line-cap',
          baseConfig.routeLineStyle.capStyle.value,
        );
        await _mapboxMap.style.setStyleLayerProperty(
          layerId,
          'line-join',
          baseConfig.routeLineStyle.joinStyle.value,
        );

        // Track this route for highlighting
        _multipleRouteIds[routeId] = layerId;
      }

      // Add markers for origin and destination (only once)
      if (routes.isNotEmpty) {
        final firstRoute = routes.first;
        final markers = <MapMarker>[
          MapMarker.origin(position: firstRoute.origin),
          MapMarker.destination(position: firstRoute.destination),
        ];

        // Add waypoint markers if any
        for (int i = 0; i < firstRoute.waypoints.length; i++) {
          markers.add(
            MapMarker.waypoint(position: firstRoute.waypoints[i], index: i + 1),
          );
        }

        await addMarkers(markers);
      }
    } catch (e) {
      throw Exception('Failed to draw multiple routes: $e');
    }
  }

  /// Highlights a specific route from multiple routes
  @override
  Future<void> highlightRoute(String routeId) async {
    try {
      if (!_multipleRouteIds.containsKey(routeId)) {
        throw Exception('Route ID $routeId not found in multiple routes');
      }

      final config = RouteStyleConfig.defaultConfig;

      // Reset all routes to non-highlighted state
      for (final entry in _multipleRouteIds.entries) {
        final currentRouteId = entry.key;
        final layerId = entry.value;

        try {
          if (currentRouteId == routeId) {
            // Highlight this route
            await _mapboxMap.style.setStyleLayerProperty(
              layerId,
              'line-color',
              config.routeLineStyle.colorHex,
            );
            await _mapboxMap.style.setStyleLayerProperty(
              layerId,
              'line-width',
              config.routeLineStyle.width + 2.0,
            );
            await _mapboxMap.style.setStyleLayerProperty(
              layerId,
              'line-opacity',
              1.0,
            );
          } else {
            // Make other routes subdued
            await _mapboxMap.style.setStyleLayerProperty(
              layerId,
              'line-color',
              '#888888',
            );
            await _mapboxMap.style.setStyleLayerProperty(
              layerId,
              'line-width',
              config.routeLineStyle.width,
            );
            await _mapboxMap.style.setStyleLayerProperty(
              layerId,
              'line-opacity',
              0.7,
            );
          }
        } catch (e) {
          // Layer might not exist, continue
        }
      }

      _highlightedRouteId = routeId;
    } catch (e) {
      throw Exception('Failed to highlight route: $e');
    }
  }

  @override
  void setFollowingLocation(bool follow) {
    _isFollowingLocation = follow;
  }
}
