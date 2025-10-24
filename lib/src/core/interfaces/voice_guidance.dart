import 'dart:async';
import '../models/voice_instruction.dart';

/// Abstract interface for voice guidance during navigation
abstract class VoiceGuidance {
  /// Speaks the provided instruction
  Future<void> speak(VoiceInstruction instruction);

  /// Stops current speech and clears queue
  Future<void> stop();

  /// Pauses current speech (can be resumed)
  Future<void> pause();

  /// Resumes paused speech
  Future<void> resume();

  /// Gets current speech state
  VoiceState get currentState;

  /// Stream of voice state changes
  Stream<VoiceState> get voiceStateStream;

  /// Sets voice volume (0.0 to 1.0)
  Future<void> setVolume(double volume);

  /// Sets speech rate (0.5 to 2.0, where 1.0 is normal)
  Future<void> setSpeechRate(double rate);

  /// Sets voice language/locale (e.g., 'en-US', 'es-ES')
  Future<void> setLanguage(String language);

  /// Whether voice guidance is enabled
  bool get isEnabled;

  /// Enable or disable voice guidance
  Future<void> setEnabled(bool enabled);
}

/// Voice guidance state enum
enum VoiceState {
  idle,
  speaking,
  paused,
  error,
}