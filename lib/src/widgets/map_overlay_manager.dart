import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// Positioning options for overlay widgets
enum OverlayPosition {
  topLeft,
  topCenter,
  topRight,
  centerLeft,
  center,
  centerRight,
  bottomLeft,
  bottomCenter,
  bottomRight,
  custom, // For custom positioning with specific coordinates
}

/// Configuration for an overlay widget
class OverlayConfig {
  /// Unique identifier for the overlay
  final String id;

  /// The widget to display
  final Widget widget;

  /// Position of the overlay
  final OverlayPosition position;

  /// Custom offset for fine-tuning position
  final Offset offset;

  /// Custom alignment for custom positioning
  final Alignment? customAlignment;

  /// Z-index for layering (higher values appear on top)
  final int zIndex;

  /// Whether the overlay is visible
  final bool visible;

  /// Animation duration for show/hide transitions
  final Duration animationDuration;

  /// Custom animation curve
  final Curve animationCurve;

  const OverlayConfig({
    required this.id,
    required this.widget,
    this.position = OverlayPosition.center,
    this.offset = Offset.zero,
    this.customAlignment,
    this.zIndex = 0,
    this.visible = true,
    this.animationDuration = const Duration(milliseconds: 300),
    this.animationCurve = Curves.easeInOut,
  });

  OverlayConfig copyWith({
    String? id,
    Widget? widget,
    OverlayPosition? position,
    Offset? offset,
    Alignment? customAlignment,
    int? zIndex,
    bool? visible,
    Duration? animationDuration,
    Curve? animationCurve,
  }) {
    return OverlayConfig(
      id: id ?? this.id,
      widget: widget ?? this.widget,
      position: position ?? this.position,
      offset: offset ?? this.offset,
      customAlignment: customAlignment ?? this.customAlignment,
      zIndex: zIndex ?? this.zIndex,
      visible: visible ?? this.visible,
      animationDuration: animationDuration ?? this.animationDuration,
      animationCurve: animationCurve ?? this.animationCurve,
    );
  }
}

/// A flexible overlay manager for positioning widgets over a map
class MapOverlayManager extends StatefulWidget {
  /// List of overlay configurations
  final List<OverlayConfig> overlays;

  /// The child widget (typically the map)
  final Widget child;

  /// Default animation duration for overlay changes
  final Duration defaultAnimationDuration;

  /// Callback when an overlay is tapped
  final void Function(String overlayId)? onOverlayTap;

  const MapOverlayManager({
    super.key,
    required this.overlays,
    required this.child,
    this.defaultAnimationDuration = const Duration(milliseconds: 300),
    this.onOverlayTap,
  });

  @override
  State<MapOverlayManager> createState() => _MapOverlayManagerState();
}

class _MapOverlayManagerState extends State<MapOverlayManager> {
  @override
  Widget build(BuildContext context) {
    // Sort overlays by z-index to ensure proper layering
    final sortedOverlays = List<OverlayConfig>.from(widget.overlays)
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    return Stack(
      children: [
        // Base child (map)
        widget.child,

        // Overlay widgets
        ...sortedOverlays.map((overlay) => _buildOverlayWidget(overlay)),
      ],
    );
  }

  Widget _buildOverlayWidget(OverlayConfig config) {
    Widget overlayWidget = GestureDetector(
      onTap: () => widget.onOverlayTap?.call(config.id),
      child: config.widget,
    );

    // Wrap with animation if needed
    overlayWidget = AnimatedOpacity(
      opacity: config.visible ? 1.0 : 0.0,
      duration: config.animationDuration,
      curve: config.animationCurve,
      child: overlayWidget,
    );

    // Position the widget based on configuration
    return _positionWidget(overlayWidget, config);
  }

  Widget _positionWidget(Widget widget, OverlayConfig config) {
    switch (config.position) {
      case OverlayPosition.topLeft:
        return Positioned(
          top: config.offset.dy,
          left: config.offset.dx,
          child: widget,
        );
      case OverlayPosition.topCenter:
        return Positioned(
          top: config.offset.dy,
          left: 0,
          right: 0,
          child: Align(
            alignment: Alignment.topCenter,
            child: Transform.translate(
              offset: Offset(config.offset.dx, 0),
              child: widget,
            ),
          ),
        );
      case OverlayPosition.topRight:
        return Positioned(
          top: config.offset.dy,
          right: config.offset.dx,
          child: widget,
        );
      case OverlayPosition.centerLeft:
        return Positioned(
          top: 0,
          bottom: 0,
          left: config.offset.dx,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Transform.translate(
              offset: Offset(0, config.offset.dy),
              child: widget,
            ),
          ),
        );
      case OverlayPosition.center:
        return Positioned(
          top: 0,
          bottom: 0,
          left: 0,
          right: 0,
          child: Align(
            alignment: Alignment.center,
            child: Transform.translate(
              offset: config.offset,
              child: widget,
            ),
          ),
        );
      case OverlayPosition.centerRight:
        return Positioned(
          top: 0,
          bottom: 0,
          right: config.offset.dx,
          child: Align(
            alignment: Alignment.centerRight,
            child: Transform.translate(
              offset: Offset(0, config.offset.dy),
              child: widget,
            ),
          ),
        );
      case OverlayPosition.bottomLeft:
        return Positioned(
          bottom: config.offset.dy,
          left: config.offset.dx,
          child: widget,
        );
      case OverlayPosition.bottomCenter:
        return Positioned(
          bottom: config.offset.dy,
          left: 0,
          right: 0,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Transform.translate(
              offset: Offset(config.offset.dx, 0),
              child: widget,
            ),
          ),
        );
      case OverlayPosition.bottomRight:
        return Positioned(
          bottom: config.offset.dy,
          right: config.offset.dx,
          child: widget,
        );
      case OverlayPosition.custom:
        return Positioned(
          top: 0,
          bottom: 0,
          left: 0,
          right: 0,
          child: Align(
            alignment: config.customAlignment ?? Alignment.center,
            child: Transform.translate(
              offset: config.offset,
              child: widget,
            ),
          ),
        );
    }
  }
}

/// Helper class for managing overlay configurations
class OverlayController {
  final List<OverlayConfig> _overlays = [];
  final ValueNotifier<List<OverlayConfig>> _overlaysNotifier =
      ValueNotifier([]);

  /// Stream of overlay changes
  ValueListenable<List<OverlayConfig>> get overlaysStream => _overlaysNotifier;

  /// Current list of overlays
  List<OverlayConfig> get overlays => List.unmodifiable(_overlays);

  /// Add a new overlay
  void addOverlay(OverlayConfig config) {
    // Remove existing overlay with same ID if it exists
    _overlays.removeWhere((overlay) => overlay.id == config.id);
    _overlays.add(config);
    _notifyListeners();
  }

  /// Remove an overlay by ID
  void removeOverlay(String id) {
    _overlays.removeWhere((overlay) => overlay.id == id);
    _notifyListeners();
  }

  /// Update an existing overlay
  void updateOverlay(String id, OverlayConfig Function(OverlayConfig) updater) {
    final index = _overlays.indexWhere((overlay) => overlay.id == id);
    if (index != -1) {
      _overlays[index] = updater(_overlays[index]);
      _notifyListeners();
    }
  }

  /// Show an overlay
  void showOverlay(String id) {
    updateOverlay(id, (config) => config.copyWith(visible: true));
  }

  /// Hide an overlay
  void hideOverlay(String id) {
    updateOverlay(id, (config) => config.copyWith(visible: false));
  }

  /// Toggle overlay visibility
  void toggleOverlay(String id) {
    updateOverlay(id, (config) => config.copyWith(visible: !config.visible));
  }

  /// Clear all overlays
  void clearOverlays() {
    _overlays.clear();
    _notifyListeners();
  }

  /// Get overlay by ID
  OverlayConfig? getOverlay(String id) {
    try {
      return _overlays.firstWhere((overlay) => overlay.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Check if overlay exists
  bool hasOverlay(String id) {
    return _overlays.any((overlay) => overlay.id == id);
  }

  void _notifyListeners() {
    _overlaysNotifier.value = List.unmodifiable(_overlays);
  }

  void dispose() {
    _overlaysNotifier.dispose();
  }
}

/// Widget that automatically rebuilds when overlays change
class ManagedMapOverlay extends StatelessWidget {
  /// The overlay controller
  final OverlayController controller;

  /// The child widget (typically the map)
  final Widget child;

  /// Callback when an overlay is tapped
  final void Function(String overlayId)? onOverlayTap;

  const ManagedMapOverlay({
    super.key,
    required this.controller,
    required this.child,
    this.onOverlayTap,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<OverlayConfig>>(
      valueListenable: controller.overlaysStream,
      builder: (context, overlays, _) {
        return MapOverlayManager(
          overlays: overlays,
          onOverlayTap: onOverlayTap,
          child: child,
        );
      },
    );
  }
}
