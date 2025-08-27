import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../services/voice_instruction_service.dart';
import '../models/navigation_step.dart';
import '../models/voice_settings.dart';
import '../localization/navigation_localizations.dart';
import '../utils/voice_utils.dart';

/// Wrapper service that provides localized voice instructions
class LocalizedVoiceService {
  final VoiceInstructionService _voiceService;
  final BuildContext _context;

  LocalizedVoiceService(this._voiceService, this._context);

  /// Gets localized voice instructions
  NavigationLocalizations get _localizations =>
      NavigationLocalizations.of(_context);

  /// Initialize the voice service
  Future<bool> initialize([VoiceSettings? settings]) =>
      _voiceService.initialize(settings);

  /// Update voice settings
  Future<void> updateSettings(VoiceSettings newSettings) =>
      _voiceService.updateSettings(newSettings);

  /// Stream of spoken instructions
  Stream<String> get instructionStream => _voiceService.instructionStream;

  /// Stream of voice instruction errors
  Stream<VoiceInstructionError> get errorStream => _voiceService.errorStream;

  /// Current voice settings
  VoiceSettings get settings => _voiceService.settings;

  /// Whether voice instructions are currently enabled
  bool get isEnabled => _voiceService.isEnabled;

  /// Whether TTS is currently speaking
  bool get isSpeaking => _voiceService.isSpeaking;

  /// Announces a navigation step with localized instructions
  Future<void> announceStep({
    required NavigationStep step,
    required geo.Position currentPosition,
    double? remainingDistance,
  }) async {
    if (!isEnabled) return;

    final distance =
        remainingDistance ?? step.getRemainingDistance(currentPosition);

    // Create localized voice instruction
    final instruction = VoiceUtils.createVoiceInstruction(
      baseInstruction: step.instruction,
      remainingDistance: distance,
      maneuverType: step.maneuver,
      // Pass localized strings
      turnLeftNow: _localizations.turnLeftNow,
      turnRightNow: _localizations.turnRightNow,
      mergeNow: _localizations.mergeNow,
      takeTheExit: _localizations.takeTheExit,
      enterRoundabout: _localizations.enterRoundabout,
      prepareToTurnLeft: _localizations.prepareToTurnLeft,
      prepareToTurnRight: _localizations.prepareToTurnRight,
      prepareToMerge: _localizations.prepareToMerge,
      prepareToExit: _localizations.prepareToExit,
      prepareToEnterRoundabout: _localizations.prepareToEnterRoundabout,
      prepareTo: _localizations.prepareTo,
      inDistance: _localizations.inDistance,
    );

    // Queue the instruction using the base service
    await _voiceService.testAnnouncement(instruction);
  }

  /// Announces navigation start with localized text
  Future<void> announceNavigationStart({
    String? destinationName,
    double? totalDistance,
  }) async {
    if (!isEnabled) return;

    final instruction = VoiceUtils.createNavigationStartAnnouncement(
      destinationName: destinationName,
      totalDistance: totalDistance,
      navigationStarting: _localizations.navigationStarting,
      totalDistanceLabel: _localizations.totalDistanceLabel,
      yourDestination: _localizations.yourDestination,
    );

    await _voiceService.testAnnouncement(instruction);
  }

  /// Announces arrival with localized text
  Future<void> announceArrival({String? destinationName}) async {
    if (!isEnabled) return;

    final instruction = VoiceUtils.createArrivalAnnouncement(
      destinationName: destinationName,
      youHaveArrived: _localizations.youHaveArrived,
    );

    await _voiceService.testAnnouncement(instruction);
  }

  /// Announces route recalculation with localized text
  Future<void> announceRouteRecalculation() async {
    if (!isEnabled) return;

    final instruction = VoiceUtils.createRouteRecalculationAnnouncement(
      recalculatingRoute: _localizations.recalculatingRoute,
    );

    await _voiceService.testAnnouncement(instruction);
  }

  /// Test method with localized message
  Future<void> testAnnouncement([String? message]) async {
    final testMessage = message ?? _localizations.voiceTestMessage;
    await _voiceService.testAnnouncement(testMessage);
  }

  /// Check TTS availability
  Future<Map<String, dynamic>> checkTTSAvailability() =>
      _voiceService.checkTTSAvailability();

  /// Dispose the service
  Future<void> dispose() => _voiceService.dispose();
}
