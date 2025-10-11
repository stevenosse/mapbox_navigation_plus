import 'dart:async';
import 'dart:math' as math;
import '../../core/models/route_progress.dart';
import '../../core/models/location_point.dart';
import '../../core/models/maneuver.dart';

/// Service that handles smooth road transition effects for Waze-like navigation
class RoadTransitionEffects {
  // Current road state
  RoadType _currentRoadType = RoadType.unknown;
  
  // Transition state
  bool _isTransitioning = false;
  Timer? _transitionTimer;
  StreamController<RoadTransitionEvent>? _transitionController;
  
  // Configuration
  static const Duration _transitionDuration = Duration(milliseconds: 2000);
// m/s difference
  
  /// Stream of road transition events
  Stream<RoadTransitionEvent> get transitionEvents => 
      _transitionController?.stream ?? const Stream.empty();
  
  RoadTransitionEffects() {
    _transitionController = StreamController<RoadTransitionEvent>.broadcast();
  }
  
  /// Updates road type and triggers transitions if needed
  void updateRoadType({
    required LocationPoint location,
    required RouteProgress routeProgress,
  }) {
    final newRoadType = _detectRoadType(location, routeProgress);
    
    if (newRoadType != _currentRoadType && !_isTransitioning) {
      _triggerRoadTransition(
        from: _currentRoadType,
        to: newRoadType,
        location: location,
        routeProgress: routeProgress,
      );
    }
    
    _currentRoadType = newRoadType;
  }
  
  /// Detects current road type based on location and route progress
  RoadType _detectRoadType(LocationPoint location, RouteProgress routeProgress) {
    // Use speed limit and road name to determine road type
    final speedLimit = routeProgress.currentStep.speedLimit;
    final roadName = routeProgress.currentRoadName.toLowerCase();
    final currentSpeed = location.speed ?? 0.0;
    
    // Highway detection
    if (_isHighway(roadName, speedLimit, currentSpeed)) {
      return RoadType.highway;
    }
    
    // Arterial road detection
    if (_isArterialRoad(roadName, speedLimit, currentSpeed)) {
      return RoadType.arterial;
    }
    
    // Residential/city street detection
    if (_isResidentialRoad(speedLimit, currentSpeed)) {
      return RoadType.residential;
    }
    
    // Ramp detection (on/off ramps)
    if (_isRamp(routeProgress)) {
      return RoadType.ramp;
    }
    
    return RoadType.unknown;
  }
  
  bool _isHighway(String roadName, double? speedLimit, double currentSpeed) {
    // Check road name patterns
    final highwayPatterns = [
      'highway', 'freeway', 'interstate', 'motorway', 'expressway',
      'i-', 'hwy', 'route', 'sr-', 'us-'
    ];
    
    for (final pattern in highwayPatterns) {
      if (roadName.contains(pattern)) return true;
    }
    
    // Check speed limit (highways typically 55+ mph / 90+ km/h)
    if (speedLimit != null && speedLimit >= 25.0) return true; // ~90 km/h
    
    // Check current speed (sustained high speed indicates highway)
    if (currentSpeed >= 20.0) return true; // ~72 km/h
    
    return false;
  }
  
  bool _isArterialRoad(String roadName, double? speedLimit, double currentSpeed) {
    final arterialPatterns = [
      'boulevard', 'avenue', 'blvd', 'ave', 'parkway', 'pkwy'
    ];
    
    for (final pattern in arterialPatterns) {
      if (roadName.contains(pattern)) return true;
    }
    
    // Arterial roads typically have moderate speed limits
    if (speedLimit != null && speedLimit >= 15.0 && speedLimit < 25.0) {
      return true; // ~54-90 km/h
    }
    
    return false;
  }
  
  bool _isResidentialRoad(double? speedLimit, double currentSpeed) {
    // Low speed limits indicate residential areas
    if (speedLimit != null && speedLimit < 15.0) return true; // <54 km/h
    
    // Sustained low speeds
    if (currentSpeed < 10.0) return true; // <36 km/h
    
    return false;
  }
  
  bool _isRamp(RouteProgress routeProgress) {
    final maneuver = routeProgress.upcomingManeuver;
    if (maneuver == null) return false;
    
    return maneuver.type == ManeuverType.onRamp ||
           maneuver.type == ManeuverType.offRamp ||
           maneuver.type == ManeuverType.merge;
  }
  
  /// Triggers a road transition with appropriate effects
  void _triggerRoadTransition({
    required RoadType from,
    required RoadType to,
    required LocationPoint location,
    required RouteProgress routeProgress,
  }) {
    if (_isTransitioning) return;
    
    _isTransitioning = true;
    
    final transition = RoadTransition(
      from: from,
      to: to,
      location: location,
      timestamp: DateTime.now(),
    );
    
    // Determine transition effect based on road types
    final effect = _getTransitionEffect(from, to);
    
    // Emit transition event
    _transitionController?.add(RoadTransitionEvent(
      transition: transition,
      effect: effect,
      phase: TransitionPhase.start,
    ));
    
    // Start transition animation
    _startTransitionAnimation(transition, effect);
  }
  
  /// Determines the appropriate transition effect
  TransitionEffect _getTransitionEffect(RoadType from, RoadType to) {
    // Highway entrance
    if (from != RoadType.highway && to == RoadType.highway) {
      return TransitionEffect.highwayEntrance;
    }
    
    // Highway exit
    if (from == RoadType.highway && to != RoadType.highway) {
      return TransitionEffect.highwayExit;
    }
    
    // Ramp transitions
    if (to == RoadType.ramp) {
      return TransitionEffect.rampEntrance;
    }
    if (from == RoadType.ramp) {
      return TransitionEffect.rampExit;
    }
    
    // Urban to residential
    if ((from == RoadType.arterial || from == RoadType.highway) && 
        to == RoadType.residential) {
      return TransitionEffect.urbanToResidential;
    }
    
    // Residential to urban
    if (from == RoadType.residential && 
        (to == RoadType.arterial || to == RoadType.highway)) {
      return TransitionEffect.residentialToUrban;
    }
    
    return TransitionEffect.generic;
  }
  
  /// Starts the transition animation sequence
  void _startTransitionAnimation(RoadTransition transition, TransitionEffect effect) {
    final totalSteps = 10;
    var currentStep = 0;
    
    _transitionTimer = Timer.periodic(
      Duration(milliseconds: _transitionDuration.inMilliseconds ~/ totalSteps),
      (timer) {
        currentStep++;
        final progress = currentStep / totalSteps;
        
        // Emit progress event
        _transitionController?.add(RoadTransitionEvent(
          transition: transition,
          effect: effect,
          phase: TransitionPhase.progress,
          progress: progress,
        ));
        
        if (currentStep >= totalSteps) {
          // Transition complete
          _transitionController?.add(RoadTransitionEvent(
            transition: transition,
            effect: effect,
            phase: TransitionPhase.complete,
            progress: 1.0,
          ));
          
          timer.cancel();
          _isTransitioning = false;
        }
      },
    );
  }
  
  /// Gets camera adjustments for transition effects
  CameraTransitionAdjustments getCameraAdjustments(
    TransitionEffect effect,
    double progress,
  ) {
    switch (effect) {
      case TransitionEffect.highwayEntrance:
        return _getHighwayEntranceAdjustments(progress);
      case TransitionEffect.highwayExit:
        return _getHighwayExitAdjustments(progress);
      case TransitionEffect.rampEntrance:
      case TransitionEffect.rampExit:
        return _getRampAdjustments(progress);
      case TransitionEffect.urbanToResidential:
        return _getUrbanToResidentialAdjustments(progress);
      case TransitionEffect.residentialToUrban:
        return _getResidentialToUrbanAdjustments(progress);
      default:
        return const CameraTransitionAdjustments();
    }
  }
  
  CameraTransitionAdjustments _getHighwayEntranceAdjustments(double progress) {
    // Gradually zoom out and increase pitch for highway perspective
    final zoomAdjustment = -2.0 * progress; // Zoom out by 2 levels
    final pitchAdjustment = 15.0 * progress; // Increase pitch by 15 degrees
    
    return CameraTransitionAdjustments(
      zoomDelta: zoomAdjustment,
      pitchDelta: pitchAdjustment,
      animationDuration: 500,
    );
  }
  
  CameraTransitionAdjustments _getHighwayExitAdjustments(double progress) {
    // Gradually zoom in and decrease pitch for surface street perspective
    final zoomAdjustment = 2.0 * progress; // Zoom in by 2 levels
    final pitchAdjustment = -15.0 * progress; // Decrease pitch by 15 degrees
    
    return CameraTransitionAdjustments(
      zoomDelta: zoomAdjustment,
      pitchDelta: pitchAdjustment,
      animationDuration: 500,
    );
  }
  
  CameraTransitionAdjustments _getRampAdjustments(double progress) {
    // Moderate adjustments for ramp transitions
    final zoomAdjustment = 1.0 * math.sin(progress * math.pi); // Smooth zoom change
    final pitchAdjustment = 5.0 * math.sin(progress * math.pi); // Gentle pitch change
    
    return CameraTransitionAdjustments(
      zoomDelta: zoomAdjustment,
      pitchDelta: pitchAdjustment,
      animationDuration: 300,
    );
  }
  
  CameraTransitionAdjustments _getUrbanToResidentialAdjustments(double progress) {
    // Zoom in for better detail in residential areas
    final zoomAdjustment = 1.5 * progress;
    final pitchAdjustment = -10.0 * progress; // Lower pitch for better overview
    
    return CameraTransitionAdjustments(
      zoomDelta: zoomAdjustment,
      pitchDelta: pitchAdjustment,
      animationDuration: 400,
    );
  }
  
  CameraTransitionAdjustments _getResidentialToUrbanAdjustments(double progress) {
    // Zoom out and increase pitch for urban driving
    final zoomAdjustment = -1.5 * progress;
    final pitchAdjustment = 10.0 * progress;
    
    return CameraTransitionAdjustments(
      zoomDelta: zoomAdjustment,
      pitchDelta: pitchAdjustment,
      animationDuration: 400,
    );
  }
  
  /// Disposes resources
  void dispose() {
    _transitionTimer?.cancel();
    _transitionController?.close();
  }
}

/// Types of roads
enum RoadType {
  highway,
  arterial,
  residential,
  ramp,
  unknown,
}

/// Road transition information
class RoadTransition {
  final RoadType from;
  final RoadType to;
  final LocationPoint location;
  final DateTime timestamp;
  
  const RoadTransition({
    required this.from,
    required this.to,
    required this.location,
    required this.timestamp,
  });
}

/// Types of transition effects
enum TransitionEffect {
  highwayEntrance,
  highwayExit,
  rampEntrance,
  rampExit,
  urbanToResidential,
  residentialToUrban,
  generic,
}

/// Transition phases
enum TransitionPhase {
  start,
  progress,
  complete,
}

/// Road transition event
class RoadTransitionEvent {
  final RoadTransition transition;
  final TransitionEffect effect;
  final TransitionPhase phase;
  final double progress;
  
  const RoadTransitionEvent({
    required this.transition,
    required this.effect,
    required this.phase,
    this.progress = 0.0,
  });
}

/// Camera adjustments for transitions
class CameraTransitionAdjustments {
  final double zoomDelta;
  final double pitchDelta;
  final double bearingDelta;
  final int animationDuration;
  
  const CameraTransitionAdjustments({
    this.zoomDelta = 0.0,
    this.pitchDelta = 0.0,
    this.bearingDelta = 0.0,
    this.animationDuration = 300,
  });
}