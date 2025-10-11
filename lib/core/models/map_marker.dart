import 'location_point.dart';

/// Map marker for navigation visualization
class MapMarker {
  /// Unique identifier for this marker
  final String id;

  /// Marker position
  final LocationPoint position;

  /// Marker type
  final MarkerType type;

  /// Marker title
  final String? title;

  /// Marker subtitle/description
  final String? subtitle;

  /// Icon to display
  final String? iconImage;

  /// Marker size
  final MarkerSize size;

  /// Marker color (as hex string)
  final String color;

  /// Whether marker is draggable
  final bool isDraggable;

  /// Anchor point (0.0-1.0, where 0.5,0.5 is center)
  final double anchorX;
  final double anchorY;

  /// Z-index for drawing order
  final int zIndex;

  /// Whether marker is visible
  final bool isVisible;

  /// Additional data payload
  final Map<String, dynamic> data;

  const MapMarker({
    required this.id,
    required this.position,
    required this.type,
    this.title,
    this.subtitle,
    this.iconImage,
    this.size = MarkerSize.medium,
    this.color = '#3366CC',
    this.isDraggable = false,
    this.anchorX = 0.5,
    this.anchorY = 1.0,
    this.zIndex = 0,
    this.isVisible = true,
    this.data = const {},
  });

  /// Creates an origin marker
  factory MapMarker.origin({
    required LocationPoint position,
    String? title,
    String id = 'origin_marker',
  }) {
    return MapMarker(
      id: id,
      position: position,
      type: MarkerType.origin,
      title: title ?? 'Start',
      iconImage: 'origin-marker',
      color: '#00AA00',
      size: MarkerSize.large,
    );
  }

  /// Creates a destination marker
  factory MapMarker.destination({
    required LocationPoint position,
    String? title,
    String id = 'destination_marker',
  }) {
    return MapMarker(
      id: id,
      position: position,
      type: MarkerType.destination,
      title: title ?? 'Destination',
      iconImage: 'destination-marker',
      color: '#CC0000',
      size: MarkerSize.large,
    );
  }

  /// Creates a waypoint marker
  factory MapMarker.waypoint({
    required LocationPoint position,
    required int index,
    String? title,
    String id = 'waypoint_marker',
  }) {
    return MapMarker(
      id: '${id}_$index',
      position: position,
      type: MarkerType.waypoint,
      title: title ?? 'Waypoint $index',
      iconImage: 'waypoint-marker',
      color: '#FF9900',
      size: MarkerSize.medium,
    );
  }

  /// Creates a current location marker
  factory MapMarker.currentLocation({
    required LocationPoint position,
    double? heading,
    String id = 'current_location_marker',
  }) {
    return MapMarker(
      id: id,
      position: position,
      type: MarkerType.currentLocation,
      title: 'Your Location',
      iconImage: heading != null ? 'location-bearing-icon' : 'location-icon',
      color: '#3366CC',
      size: MarkerSize.medium,
      data: {'heading': heading},
    );
  }

  /// Creates a maneuver marker
  factory MapMarker.maneuver({
    required LocationPoint position,
    required String instruction,
    String id = 'maneuver_marker',
  }) {
    return MapMarker(
      id: id,
      position: position,
      type: MarkerType.maneuver,
      title: instruction,
      iconImage: 'maneuver-marker',
      color: '#666666',
      size: MarkerSize.small,
    );
  }

  /// Gets marker icon name based on type
  String get defaultIconImage {
    switch (type) {
      case MarkerType.origin:
        return 'origin-marker';
      case MarkerType.destination:
        return 'destination-marker';
      case MarkerType.waypoint:
        return 'waypoint-marker';
      case MarkerType.currentLocation:
        return 'location-icon';
      case MarkerType.maneuver:
        return 'maneuver-marker';
      case MarkerType.custom:
        return iconImage ?? 'default-marker';
    }
  }

  /// Gets marker size in pixels
  double get sizeInPixels {
    switch (size) {
      case MarkerSize.small:
        return 24.0;
      case MarkerSize.medium:
        return 32.0;
      case MarkerSize.large:
        return 48.0;
    }
  }

  /// Creates a copy with updated values
  MapMarker copyWith({
    String? id,
    LocationPoint? position,
    MarkerType? type,
    String? title,
    String? subtitle,
    String? iconImage,
    MarkerSize? size,
    String? color,
    bool? isDraggable,
    double? anchorX,
    double? anchorY,
    int? zIndex,
    bool? isVisible,
    Map<String, dynamic>? data,
  }) {
    return MapMarker(
      id: id ?? this.id,
      position: position ?? this.position,
      type: type ?? this.type,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      iconImage: iconImage ?? this.iconImage,
      size: size ?? this.size,
      color: color ?? this.color,
      isDraggable: isDraggable ?? this.isDraggable,
      anchorX: anchorX ?? this.anchorX,
      anchorY: anchorY ?? this.anchorY,
      zIndex: zIndex ?? this.zIndex,
      isVisible: isVisible ?? this.isVisible,
      data: data ?? this.data,
    );
  }

  @override
  String toString() {
    return 'MapMarker(id: $id, type: $type, position: $position, title: $title)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapMarker && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Marker type enumeration
enum MarkerType {
  origin,
  destination,
  waypoint,
  currentLocation,
  maneuver,
  custom,
}

/// Marker size enumeration
enum MarkerSize { small, medium, large }
