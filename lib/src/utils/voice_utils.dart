/// Utilities for processing text for voice instructions
class VoiceUtils {
  /// Cleans and optimizes text for text-to-speech
  static String cleanTextForTTS(String text) {
    if (text.isEmpty) return text;

    String cleanedText = text;

    // Remove special characters and clean up
    cleanedText = cleanedText.replaceAll(RegExp(r'[^\w\s\.,!?-]'), ' ');

    // Expand common abbreviations for better pronunciation
    cleanedText = _expandAbbreviations(cleanedText);

    // Clean up multiple spaces
    cleanedText = cleanedText.replaceAll(RegExp(r'\s+'), ' ');

    // Trim whitespace
    cleanedText = cleanedText.trim();

    return cleanedText;
  }

  /// Expands common abbreviations used in navigation instructions
  static String _expandAbbreviations(String text) {
    final expansions = {
      // Directions
      r'\bN\b': 'North',
      r'\bS\b': 'South',
      r'\bE\b': 'East',
      r'\bW\b': 'West',
      r'\bNE\b': 'Northeast',
      r'\bNW\b': 'Northwest',
      r'\bSE\b': 'Southeast',
      r'\bSW\b': 'Southwest',

      // Road types
      r'\bSt\.?\b': 'Street',
      r'\bAve\.?\b': 'Avenue',
      r'\bBlvd\.?\b': 'Boulevard',
      r'\bRd\.?\b': 'Road',
      r'\bDr\.?\b': 'Drive',
      r'\bLn\.?\b': 'Lane',
      r'\bCt\.?\b': 'Court',
      r'\bPl\.?\b': 'Place',
      r'\bPkwy\.?\b': 'Parkway',
      r'\bHwy\.?\b': 'Highway',
      r'\bFwy\.?\b': 'Freeway',

      // Common terms
      r'\bft\.?\b': 'feet',
      r'\bmi\.?\b': 'miles',
      r'\bkm\.?\b': 'kilometers',
      r'\bm\.?\b': 'meters',
      r'\bmph\.?\b': 'miles per hour',
      r'\bkph\.?\b': 'kilometers per hour',

      // Numbers with ordinals for exits
      r'\b1st\b': 'first',
      r'\b2nd\b': 'second',
      r'\b3rd\b': 'third',
      r'\b(\d+)th\b': r'\1th',
    };

    String result = text;
    expansions.forEach((pattern, replacement) {
      result =
          result.replaceAll(RegExp(pattern, caseSensitive: false), replacement);
    });

    return result;
  }

  /// Creates voice-optimized instruction based on distance and maneuver type
  static String createVoiceInstruction({
    required String baseInstruction,
    required double remainingDistance,
    String? roadName,
    String? maneuverType,
    // Localization parameters
    String turnLeftNow = 'Turn left now',
    String turnRightNow = 'Turn right now',
    String mergeNow = 'Merge now',
    String takeTheExit = 'Take the exit now',
    String enterRoundabout = 'Enter the roundabout',
    String prepareToTurnLeft = 'Prepare to turn left',
    String prepareToTurnRight = 'Prepare to turn right',
    String prepareToMerge = 'Prepare to merge',
    String prepareToExit = 'Prepare to exit',
    String prepareToEnterRoundabout = 'Prepare to enter the roundabout',
    String prepareTo = 'Prepare to',
    String inDistance = 'In',
  }) {
    final cleanInstruction = cleanTextForTTS(baseInstruction);

    // For very close distances (under 50m), make it urgent and simple
    if (remainingDistance <= 50) {
      return _createUrgentInstruction(
        cleanInstruction,
        maneuverType,
        turnLeftNow: turnLeftNow,
        turnRightNow: turnRightNow,
        mergeNow: mergeNow,
        takeTheExit: takeTheExit,
        enterRoundabout: enterRoundabout,
      );
    }

    // For medium distances (50m-200m), add preparation context
    if (remainingDistance <= 200) {
      return _createPreparationInstruction(
        cleanInstruction,
        maneuverType,
        prepareToTurnLeft: prepareToTurnLeft,
        prepareToTurnRight: prepareToTurnRight,
        prepareToMerge: prepareToMerge,
        prepareToExit: prepareToExit,
        prepareToEnterRoundabout: prepareToEnterRoundabout,
        prepareTo: prepareTo,
      );
    }

    // For longer distances, provide advance notice with distance
    return _createAdvanceInstruction(
      cleanInstruction,
      remainingDistance,
      maneuverType,
      inDistance: inDistance,
    );
  }

  /// Creates urgent instruction for immediate actions
  static String _createUrgentInstruction(
    String instruction,
    String? maneuverType, {
    String turnLeftNow = 'Turn left now',
    String turnRightNow = 'Turn right now',
    String mergeNow = 'Merge now',
    String takeTheExit = 'Take the exit now',
    String enterRoundabout = 'Enter the roundabout',
  }) {
    final lowerInstruction = instruction.toLowerCase();

    if (maneuverType != null) {
      switch (maneuverType.toLowerCase()) {
        case 'turn':
          if (lowerInstruction.contains('left')) {
            return turnLeftNow;
          } else if (lowerInstruction.contains('right')) {
            return turnRightNow;
          }
          break;
        case 'merge':
          return mergeNow;
        case 'exit':
        case 'off ramp':
          return takeTheExit;
        case 'roundabout':
          return enterRoundabout;
      }
    }

    // Fallback to processed instruction with urgency
    if (lowerInstruction.contains('turn')) {
      return '${instruction.replaceAll(RegExp(r'^turn', caseSensitive: false), 'Turn')} now';
    }

    return instruction;
  }

  /// Creates preparation instruction for upcoming maneuvers
  static String _createPreparationInstruction(
    String instruction,
    String? maneuverType, {
    String prepareToTurnLeft = 'Prepare to turn left',
    String prepareToTurnRight = 'Prepare to turn right',
    String prepareToMerge = 'Prepare to merge',
    String prepareToExit = 'Prepare to exit',
    String prepareToEnterRoundabout = 'Prepare to enter the roundabout',
    String prepareTo = 'Prepare to',
  }) {
    final lowerInstruction = instruction.toLowerCase();

    if (maneuverType != null) {
      switch (maneuverType.toLowerCase()) {
        case 'turn':
          if (lowerInstruction.contains('left')) {
            return prepareToTurnLeft;
          } else if (lowerInstruction.contains('right')) {
            return prepareToTurnRight;
          }
          break;
        case 'merge':
          return prepareToMerge;
        case 'exit':
        case 'off ramp':
          return prepareToExit;
        case 'roundabout':
          return prepareToEnterRoundabout;
      }
    }

    // Add "prepare to" prefix if not already present
    if (!lowerInstruction.contains('prepare')) {
      return '$prepareTo $instruction';
    }

    return instruction;
  }

  /// Creates advance instruction with distance context
  static String _createAdvanceInstruction(
    String instruction,
    double remainingDistance,
    String? maneuverType, {
    String inDistance = 'In',
  }) {
    final distanceText = _formatDistanceForVoice(remainingDistance);

    // Create natural sounding advance instruction
    return '$inDistance $distanceText, $instruction';
  }

  /// Formats distance for natural voice pronunciation
  static String _formatDistanceForVoice(double distanceInMeters) {
    if (distanceInMeters >= 1000) {
      final kilometers = distanceInMeters / 1000;
      if (kilometers == 1.0) {
        return '1 kilometer';
      } else if (kilometers < 10) {
        return '${kilometers.toStringAsFixed(1)} kilometers';
      } else {
        return '${kilometers.round()} kilometers';
      }
    } else if (distanceInMeters >= 100) {
      final roundedDistance = (distanceInMeters / 50).round() * 50;
      return '$roundedDistance meters';
    } else {
      final roundedDistance = (distanceInMeters / 10).round() * 10;
      return '$roundedDistance meters';
    }
  }

  /// Creates arrival announcement
  static String createArrivalAnnouncement({
    String? destinationName,
    String youHaveArrived = 'You have arrived at your destination',
  }) {
    if (destinationName != null && destinationName.isNotEmpty) {
      return 'You have arrived at $destinationName';
    }
    return youHaveArrived;
  }

  /// Creates route recalculation announcement
  static String createRouteRecalculationAnnouncement({
    String recalculatingRoute = 'Route recalculated',
  }) {
    return recalculatingRoute;
  }

  /// Creates navigation start announcement
  static String createNavigationStartAnnouncement({
    String? destinationName,
    double? totalDistance,
    String navigationStarting = 'Starting navigation',
    String totalDistanceLabel = 'Total distance',
    String yourDestination = 'your destination',
  }) {
    final destination =
        destinationName?.isNotEmpty == true ? destinationName : yourDestination;

    if (totalDistance != null) {
      final distanceText = _formatDistanceForVoice(totalDistance);
      return '$navigationStarting to $destination. $totalDistanceLabel: $distanceText';
    }

    return '$navigationStarting to $destination';
  }

  /// Validates if text is suitable for TTS
  static bool isValidForTTS(String text) {
    if (text.isEmpty || text.trim().isEmpty) return false;

    // Check for excessively long text (TTS systems have limits)
    if (text.length > 200) return false;

    // Check for mostly non-alphabetic content
    final alphaCount = RegExp(r'[a-zA-Z]').allMatches(text).length;
    if (alphaCount < text.length * 0.3) return false;

    return true;
  }

  /// Estimates speech duration in milliseconds
  static int estimateSpeechDuration(String text, double speechRate) {
    if (text.isEmpty) return 0;

    // Average words per minute for TTS: ~150-200 WPM
    // Adjust based on speech rate
    final baseWPM = 175.0;
    final adjustedWPM = baseWPM * speechRate;

    final wordCount = text.split(RegExp(r'\s+')).length;
    final durationMinutes = wordCount / adjustedWPM;

    return (durationMinutes * 60 * 1000).round(); // Convert to milliseconds
  }
}
