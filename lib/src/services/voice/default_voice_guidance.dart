import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import '../../core/interfaces/voice_guidance.dart';
import '../../core/models/voice_instruction.dart';

/// Default implementation of VoiceGuidance using Flutter TTS
class DefaultVoiceGuidance implements VoiceGuidance {
  final FlutterTts _flutterTts = FlutterTts();
  final StreamController<VoiceState> _stateController =
      StreamController<VoiceState>.broadcast();

  VoiceState _currentState = VoiceState.idle;
  bool _isEnabled = true;
  double _volume = 1.0;
  double _speechRate = 0.5;
  String _language = 'en-US';
  VoiceInstruction? _lastInstruction;

  @override
  Future<void> speak(VoiceInstruction instruction) async {
    if (!_isEnabled) return;

    _lastInstruction = instruction;

    try {
      _setState(VoiceState.speaking);

      await _flutterTts.setVolume(_volume);
      await _flutterTts.setSpeechRate(_speechRate);
      await _flutterTts.setLanguage(_language);

      await _flutterTts.speak(instruction.announcement);

      // Listen for completion
      _flutterTts.setCompletionHandler(() {
        _setState(VoiceState.idle);
      });

      _flutterTts.setErrorHandler((msg) {
        _setState(VoiceState.idle);
      });
    } catch (e) {
      _setState(VoiceState.idle);
      rethrow;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _flutterTts.stop();
      _setState(VoiceState.idle);
    } catch (e) {
      // Ignore stop errors
    }
  }

  @override
  Future<void> pause() async {
    try {
      await _flutterTts.pause();
      _setState(VoiceState.paused);
    } catch (e) {
      // Ignore pause errors
    }
  }

  @override
  Future<void> resume() async {
    // Flutter TTS doesn't have resume, so we replay the last instruction
    if (_lastInstruction != null) {
      await speak(_lastInstruction!);
    }
  }

  @override
  VoiceState get currentState => _currentState;

  @override
  Stream<VoiceState> get voiceStateStream => _stateController.stream;

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _flutterTts.setVolume(_volume);
  }

  @override
  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate.clamp(0.1, 2.0);
    await _flutterTts.setSpeechRate(_speechRate);
  }

  @override
  Future<void> setLanguage(String language) async {
    _language = language;
    await _flutterTts.setLanguage(_language);
  }

  @override
  bool get isEnabled => _isEnabled;

  @override
  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    if (!enabled && _currentState == VoiceState.speaking) {
      await stop();
    }
  }

  void _setState(VoiceState newState) {
    _currentState = newState;
    _stateController.add(_currentState);
  }

  /// Initialize the TTS engine
  Future<void> initialize() async {
    try {
      await _flutterTts.setVolume(_volume);
      await _flutterTts.setSpeechRate(_speechRate);
      await _flutterTts.setLanguage(_language);

      // Set default await options
      await _flutterTts.awaitSpeakCompletion(true);

      // Check if TTS is available
      final languages = await _flutterTts.getLanguages;
      if (languages.isEmpty) {
        throw Exception('No TTS languages available');
      }
    } catch (e) {
      throw Exception('Failed to initialize voice guidance: $e');
    }
  }

  /// Get available languages
  Future<List<String>> getAvailableLanguages() async {
    try {
      final languages = await _flutterTts.getLanguages;
      return List<String>.from(languages);
    } catch (e) {
      return [];
    }
  }

  void dispose() {
    _stateController.close();
  }
}