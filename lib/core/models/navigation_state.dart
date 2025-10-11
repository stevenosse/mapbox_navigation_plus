/// Navigation state enumeration
enum NavigationState {
  /// Navigation is idle, no route active
  idle,

  /// Route is being calculated
  routing,

  /// Active navigation in progress
  navigating,

  /// Navigation is paused
  paused,

  /// User has arrived at destination
  arrived,

  /// User has deviated from route, re-routing in progress
  deviated,

  /// An error occurred
  error,
}

/// Extension methods for NavigationState
extension NavigationStateExtension on NavigationState {
  /// Returns true if navigation is active
  bool get isActive => this == NavigationState.navigating || this == NavigationState.paused;

  /// Returns true if navigation can be started
  bool get canStart => this == NavigationState.idle || this == NavigationState.arrived || this == NavigationState.error;

  /// Returns true if navigation can be paused
  bool get canPause => this == NavigationState.navigating;

  /// Returns true if navigation can be resumed
  bool get canResume => this == NavigationState.paused;

  /// Returns true if navigation can be stopped
  bool get canStop => this == NavigationState.navigating || this == NavigationState.paused;

  /// Returns true if re-routing is possible
  bool get canReroute => this == NavigationState.navigating || this == NavigationState.deviated;

  /// Human-readable description
  String get description {
    switch (this) {
      case NavigationState.idle:
        return 'Idle';
      case NavigationState.routing:
        return 'Calculating route';
      case NavigationState.navigating:
        return 'Navigating';
      case NavigationState.paused:
        return 'Paused';
      case NavigationState.arrived:
        return 'Arrived';
      case NavigationState.deviated:
        return 'Off route';
      case NavigationState.error:
        return 'Error';
    }
  }
}