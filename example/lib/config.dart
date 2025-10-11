import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Configuration manager for sensitive data like API keys
class Config {
  static Config? _instance;
  static Config get instance => _instance ??= Config._();

  Config._();

  Map<String, dynamic>? _variables;

  /// Load variables from the variables.json file
  Future<void> loadVariables() async {
    try {
      final content = await rootBundle.loadString('variables.json');
      _variables = jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      if (kDebugMode) {
        print('Error loading variables.json: $e');
      }
      _variables = {};
    }
  }

  /// Get Mapbox access token
  String get mapboxAccessToken {
    final token = _variables?['mapbox_access_token'] as String?;

    if (token == null ||
        token.isEmpty ||
        token == 'YOUR_MAPBOX_ACCESS_TOKEN_HERE') {
      if (kDebugMode) {
        print(
          'Warning: Mapbox access token not configured. Please set it in variables.json',
        );
      }
      return '';
    }

    return token;
  }

  /// Check if Mapbox token is properly configured
  bool get isMapboxConfigured {
    final token = mapboxAccessToken;
    return token.isNotEmpty && token != 'YOUR_MAPBOX_ACCESS_TOKEN_HERE';
  }
}
