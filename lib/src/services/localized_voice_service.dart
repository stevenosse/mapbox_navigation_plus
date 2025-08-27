import 'package:geolocator/geolocator.dart' as geo;
import '../services/voice_instruction_service.dart';
import '../models/navigation_step.dart';
import '../models/voice_settings.dart';

/// Wrapper service that provides localized voice instructions
class LocalizedVoiceService {
  final VoiceInstructionService _voiceService;

  LocalizedVoiceService(this._voiceService);

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

    // Queue the instruction using the base service
    await _voiceService.announceStep(
      currentPosition: currentPosition,
      step: step,
      remainingDistance: remainingDistance,
    );
  }

  /// Announces navigation start with localized text
  Future<void> announceNavigationStart({
    String? destinationName,
    double? totalDistance,
  }) async {
    if (!isEnabled) return;

    await _voiceService.announceNavigationStart(
      destinationName: destinationName,
      totalDistance: totalDistance,
    );
  }

  /// Announces arrival with localized text
  Future<void> announceArrival({String? destinationName}) async {
    if (!isEnabled) return;

    await _voiceService.announceArrival(destinationName: destinationName);
  }

  /// Announces route recalculation with localized text
  Future<void> announceRouteRecalculation() async {
    // Delegate to the underlying voice service which handles the announceRouteRecalculation setting
    await _voiceService.announceRouteRecalculation();
  }

  /// Check TTS availability
  Future<Map<String, dynamic>> checkTTSAvailability() =>
      _voiceService.checkTTSAvailability();

  /// Dispose the service
  Future<void> dispose() => _voiceService.dispose();
}
