import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart' as geo;

import '../models/voice_settings.dart';
import '../models/navigation_step.dart';
import '../utils/voice_utils.dart';
import '../utils/constants.dart' as nav_constants;

/// Service for managing voice instructions during navigation
class VoiceInstructionService {
  FlutterTts? _tts;
  VoiceSettings _settings = VoiceSettings.defaults();

  bool _isInitialized = false;
  bool _isSpeaking = false;
  DateTime? _lastInstructionTime;

  // Queue for managing multiple instructions
  final List<_VoiceInstruction> _instructionQueue = [];
  Timer? _queueProcessingTimer;

  // Track announced distances for each step to avoid repetition
  final Map<String, Set<double>> _announcedDistances = {};

  // Streams for voice events
  final StreamController<String> _instructionController = StreamController<String>.broadcast();
  final StreamController<VoiceInstructionError> _errorController = StreamController<VoiceInstructionError>.broadcast();

  /// Stream of spoken instructions
  Stream<String> get instructionStream => _instructionController.stream;

  /// Stream of voice instruction errors
  Stream<VoiceInstructionError> get errorStream => _errorController.stream;

  /// Current voice settings
  VoiceSettings get settings => _settings;

  /// Whether voice instructions are currently enabled
  bool get isEnabled => _settings.enabled && _isInitialized;

  /// Whether TTS is currently speaking
  bool get isSpeaking => _isSpeaking;

  /// Initializes the voice instruction service
  Future<bool> initialize([VoiceSettings? settings]) async {
    try {
      _settings = settings ?? VoiceSettings.defaults();

      if (!_settings.enabled) {
        _isInitialized = false;
        return false;
      }

      _tts = FlutterTts();

      await _configureTTS();

      _setupTTSCallbacks();

      _isInitialized = true;
      _startQueueProcessing();

      return true;
    } catch (e) {
      _errorController.add(VoiceInstructionError(
        'Failed to initialize voice service: $e',
        VoiceErrorType.initialization,
      ));
      return false;
    }
  }

  /// Configures TTS with current settings
  Future<void> _configureTTS() async {
    if (_tts == null) return;

    try {
      await _tts!.setLanguage(_settings.language);
      await _tts!.setSpeechRate(_settings.speechRate);
      await _tts!.setPitch(_settings.pitch);
      await _tts!.setVolume(_settings.volume);

      // Platform-specific configurations
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _tts!.setSharedInstance(true);
        await _tts!.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [IosTextToSpeechAudioCategoryOptions.allowBluetooth],
        );
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        await _tts!.setQueueMode(1); // QUEUE_FLUSH mode
      }
    } catch (e) {
      _errorController.add(VoiceInstructionError(
        'Failed to configure TTS: $e',
        VoiceErrorType.configuration,
      ));
    }
  }

  /// Sets up TTS event callbacks
  void _setupTTSCallbacks() {
    if (_tts == null) return;

    _tts!.setStartHandler(() {
      _isSpeaking = true;
    });

    _tts!.setCompletionHandler(() {
      _isSpeaking = false;
    });

    _tts!.setErrorHandler((message) {
      _isSpeaking = false;
      _errorController.add(VoiceInstructionError(
        'TTS error: $message',
        VoiceErrorType.playback,
      ));
    });

    _tts!.setCancelHandler(() {
      _isSpeaking = false;
    });
  }

  /// Updates voice settings and reconfigures TTS
  Future<void> updateSettings(VoiceSettings newSettings) async {
    _settings = newSettings;

    if (!_settings.enabled) {
      await _stopCurrentInstruction();
      _clearQueue();
      _isInitialized = false;
      return;
    }

    if (!_isInitialized) {
      await initialize(newSettings);
      return;
    }

    await _configureTTS();
  }

  /// Announces a navigation step based on current position and distance
  Future<void> announceStep({
    required NavigationStep step,
    required geo.Position currentPosition,
    double? remainingDistance,
  }) async {
    if (!isEnabled) {
      return;
    }

    final distance = remainingDistance ?? step.getRemainingDistance(currentPosition);
    final stepId = _getStepId(step);

    // Check if we should announce at this distance
    if (!_shouldAnnounceAtDistance(stepId, distance)) {
      return;
    }

    // Create voice instruction
    final instruction = VoiceUtils.createVoiceInstruction(
      baseInstruction: step.instruction,
      remainingDistance: distance,
      maneuverType: step.maneuver,
    );

    // Determine priority based on distance
    final priority = _getPriorityForDistance(distance);

    await _queueInstruction(_VoiceInstruction(
      text: instruction,
      priority: priority,
      instructionType: nav_constants.VoiceConstants.instructionTypeManeuver,
      stepId: stepId,
      distance: distance,
    ));
  }

  /// Announces navigation start
  Future<void> announceNavigationStart({
    String? destinationName,
    double? totalDistance,
  }) async {
    if (!isEnabled) return;

    final instruction = VoiceUtils.createNavigationStartAnnouncement(
      destinationName: destinationName,
      totalDistance: totalDistance,
    );

    await _queueInstruction(_VoiceInstruction(
      text: instruction,
      priority: nav_constants.VoiceConstants.priorityNormal,
      instructionType: nav_constants.VoiceConstants.instructionTypeStart,
    ));
  }

  /// Announces arrival at destination
  Future<void> announceArrival({String? destinationName}) async {
    if (!isEnabled || !_settings.announceArrival) return;

    final instruction = VoiceUtils.createArrivalAnnouncement(
      destinationName: destinationName,
    );

    await _queueInstruction(_VoiceInstruction(
      text: instruction,
      priority: nav_constants.VoiceConstants.priorityHigh,
      instructionType: nav_constants.VoiceConstants.instructionTypeArrival,
    ));
  }

  /// Announces route recalculation
  Future<void> announceRouteRecalculation() async {
    if (!isEnabled || !_settings.announceRouteRecalculation) return;

    final instruction = VoiceUtils.createRouteRecalculationAnnouncement();

    await _queueInstruction(_VoiceInstruction(
      text: instruction,
      priority: nav_constants.VoiceConstants.priorityNormal,
      instructionType: nav_constants.VoiceConstants.instructionTypeRecalculation,
    ));
  }

  /// Test method to manually announce a simple message (for debugging)
  Future<void> testAnnouncement([String? message]) async {
    final testMessage = message ?? 'Voice instructions are working correctly';

    await _queueInstruction(_VoiceInstruction(
      text: testMessage,
      priority: nav_constants.VoiceConstants.priorityUrgent,
      instructionType: 'test',
    ));
  }

  /// Check if TTS is available and configured properly (for debugging)
  Future<Map<String, dynamic>> checkTTSAvailability() async {
    final result = <String, dynamic>{
      'isInitialized': _isInitialized,
      'isEnabled': isEnabled,
      'ttsInstance': _tts != null,
      'settings': _settings.toString(),
    };

    if (_tts != null) {
      try {
        // Try to get available languages (if method exists)
        try {
          final languages = await _tts!.getLanguages;
          result['availableLanguages'] = languages;
        } catch (e) {
          result['languagesError'] = 'getLanguages not available: $e';
        }

        // Try to get available engines (if method exists)
        try {
          final engines = await _tts!.getEngines;
          result['availableEngines'] = engines;
        } catch (e) {
          result['enginesError'] = 'getEngines not available: $e';
        }

        // Check if current language is supported
        final isLanguageAvailable = await _tts!.isLanguageAvailable(_settings.language);
        result['isLanguageAvailable'] = isLanguageAvailable;
      } catch (e) {
        result['error'] = e.toString();
      }
    }

    return result;
  }

  /// Queues a voice instruction for playback
  Future<void> _queueInstruction(_VoiceInstruction instruction) async {
    if (!VoiceUtils.isValidForTTS(instruction.text)) {
      return;
    }

    // Check minimum interval between instructions
    if (_lastInstructionTime != null) {
      final timeSinceLastInstruction = DateTime.now().difference(_lastInstructionTime!);
      if (timeSinceLastInstruction.inMilliseconds < _settings.minimumInterval &&
          instruction.priority < nav_constants.VoiceConstants.priorityUrgent) {
        return;
      }
    }

    // Handle urgent instructions by clearing queue
    if (instruction.priority == nav_constants.VoiceConstants.priorityUrgent) {
      await _stopCurrentInstruction();
      _clearQueue();
    }

    // Add to queue and sort by priority
    _instructionQueue.add(instruction);
    _instructionQueue.sort((a, b) => b.priority.compareTo(a.priority));

    // Mark distance as announced for this step
    if (instruction.stepId != null && instruction.distance != null) {
      _announcedDistances.putIfAbsent(instruction.stepId!, () => <double>{});
      _announcedDistances[instruction.stepId!]!.add(instruction.distance!);
    }
  }

  /// Starts processing the instruction queue
  void _startQueueProcessing() {
    _queueProcessingTimer?.cancel();
    _queueProcessingTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _processQueue(),
    );
  }

  /// Processes queued instructions
  Future<void> _processQueue() async {
    if (!isEnabled || _isSpeaking || _instructionQueue.isEmpty) return;

    final instruction = _instructionQueue.removeAt(0);
    await _speakInstruction(instruction);
  }

  /// Speaks a single instruction
  Future<void> _speakInstruction(_VoiceInstruction instruction) async {
    if (_tts == null) {
      return;
    }

    if (!isEnabled) {
      return;
    }

    try {
      await _tts!.speak(instruction.text);
      _lastInstructionTime = DateTime.now();
      _instructionController.add(instruction.text);
    } catch (e) {
      _errorController.add(VoiceInstructionError(
        'Failed to speak instruction: $e',
        VoiceErrorType.playback,
      ));
    }
  }

  /// Stops current instruction playback
  Future<void> _stopCurrentInstruction() async {
    if (_tts == null) return;

    try {
      await _tts!.stop();
    } catch (e) {
      // Ignore stop errors
    }
  }

  /// Clears the instruction queue
  void _clearQueue() {
    _instructionQueue.clear();
  }

  /// Determines if instruction should be announced at given distance
  bool _shouldAnnounceAtDistance(String stepId, double distance) {
    final announcedSet = _announcedDistances[stepId] ?? <double>{};

    for (final threshold in _settings.announcementDistances) {
      if (distance <= threshold && !announcedSet.contains(threshold)) {
        return true;
      }
    }

    return false;
  }

  /// Gets priority level for given distance
  int _getPriorityForDistance(double distance) {
    if (distance <= 50) {
      return nav_constants.VoiceConstants.priorityUrgent;
    } else if (distance <= 200) {
      return nav_constants.VoiceConstants.priorityHigh;
    } else {
      return nav_constants.VoiceConstants.priorityNormal;
    }
  }

  /// Generates a unique ID for a navigation step
  String _getStepId(NavigationStep step) {
    return '${step.instruction}_${step.startLocation.latitude}_${step.startLocation.longitude}';
  }

  /// Cleans up announced distances for completed steps
  void cleanupCompletedSteps(List<NavigationStep> currentSteps) {
    final currentStepIds = currentSteps.map((step) => _getStepId(step)).toSet();
    _announcedDistances.removeWhere((stepId, _) => !currentStepIds.contains(stepId));
  }

  /// Disposes the service and cleans up resources
  Future<void> dispose() async {
    _queueProcessingTimer?.cancel();

    if (_tts != null) {
      await _stopCurrentInstruction();
      // Note: FlutterTts doesn't have a dispose method, but we clear our reference
      _tts = null;
    }

    _clearQueue();
    _announcedDistances.clear();

    await _instructionController.close();
    await _errorController.close();

    _isInitialized = false;
  }
}

/// Represents a queued voice instruction
class _VoiceInstruction {
  final String text;
  final int priority;
  final String instructionType;
  final String? stepId;
  final double? distance;
  final DateTime timestamp;

  _VoiceInstruction({
    required this.text,
    required this.priority,
    required this.instructionType,
    this.stepId,
    this.distance,
  }) : timestamp = DateTime.now();
}

/// Represents a voice instruction error
class VoiceInstructionError {
  final String message;
  final VoiceErrorType type;
  final DateTime timestamp;

  VoiceInstructionError(this.message, this.type) : timestamp = DateTime.now();

  @override
  String toString() => 'VoiceInstructionError($type): $message';
}

/// Types of voice instruction errors
enum VoiceErrorType {
  initialization,
  configuration,
  playback,
  unknown,
}
