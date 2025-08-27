import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Localization delegate for navigation strings
class NavigationLocalizations {
  NavigationLocalizations(this.locale);

  final Locale locale;

  static NavigationLocalizations of(BuildContext context) {
    return Localizations.of<NavigationLocalizations>(context, NavigationLocalizations)!;
  }

  static const LocalizationsDelegate<NavigationLocalizations> delegate = _NavigationLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('fr'),
  ];

  // Navigation status strings
  String get readyToNavigate => _localizedValues[locale.languageCode]!['readyToNavigate']!;
  String get calculatingRoute => _localizedValues[locale.languageCode]!['calculatingRoute']!;
  String get navigating => _localizedValues[locale.languageCode]!['navigating']!;
  String get navigationPaused => _localizedValues[locale.languageCode]!['navigationPaused']!;
  String get arrivedAtDestination => _localizedValues[locale.languageCode]!['arrivedAtDestination']!;
  String get navigationError => _localizedValues[locale.languageCode]!['navigationError']!;

  // Instruction enhancement strings
  String get turnLeftNow => _localizedValues[locale.languageCode]!['turnLeftNow']!;
  String get turnRightNow => _localizedValues[locale.languageCode]!['turnRightNow']!;
  String get mergeNow => _localizedValues[locale.languageCode]!['mergeNow']!;
  String get takeTheExit => _localizedValues[locale.languageCode]!['takeTheExit']!;
  String get getReady => _localizedValues[locale.languageCode]!['getReady']!;
  String get prepareToTurnLeft => _localizedValues[locale.languageCode]!['prepareToTurnLeft']!;
  String get prepareToTurnRight => _localizedValues[locale.languageCode]!['prepareToTurnRight']!;
  String get prepareToMerge => _localizedValues[locale.languageCode]!['prepareToMerge']!;
  String get prepareToExit => _localizedValues[locale.languageCode]!['prepareToExit']!;
  String get prepareTo => _localizedValues[locale.languageCode]!['prepareTo']!;
  String get inDistance => _localizedValues[locale.languageCode]!['inDistance']!;

  // Voice instruction strings
  String get voiceTestMessage => _localizedValues[locale.languageCode]!['voiceTestMessage']!;
  String get navigationStarting => _localizedValues[locale.languageCode]!['navigationStarting']!;
  String get youHaveArrived => _localizedValues[locale.languageCode]!['youHaveArrived']!;
  String get recalculatingRoute => _localizedValues[locale.languageCode]!['recalculatingRoute']!;
  String get enterRoundabout => _localizedValues[locale.languageCode]!['enterRoundabout']!;
  String get prepareToEnterRoundabout => _localizedValues[locale.languageCode]!['prepareToEnterRoundabout']!;
  String get totalDistanceLabel => _localizedValues[locale.languageCode]!['totalDistanceLabel']!;
  String get yourDestination => _localizedValues[locale.languageCode]!['yourDestination']!;

  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'readyToNavigate': 'Ready to navigate',
      'calculatingRoute': 'Calculating route...',
      'navigating': 'Navigating',
      'navigationPaused': 'Navigation paused',
      'arrivedAtDestination': 'Arrived at destination',
      'navigationError': 'Navigation error',
      'turnLeftNow': 'Turn left now',
      'turnRightNow': 'Turn right now',
      'mergeNow': 'Merge now',
      'takeTheExit': 'Take the exit',
      'getReady': 'Get ready',
      'prepareToTurnLeft': 'Prepare to turn left',
      'prepareToTurnRight': 'Prepare to turn right',
      'prepareToMerge': 'Prepare to merge',
      'prepareToExit': 'Prepare to exit',
      'prepareTo': 'Prepare to',
      'inDistance': 'In',
      'voiceTestMessage': 'Voice instructions are working correctly',
      'navigationStarting': 'Starting navigation',
      'youHaveArrived': 'You have arrived at your destination',
      'recalculatingRoute': 'Recalculating route',
      'enterRoundabout': 'Enter the roundabout',
      'prepareToEnterRoundabout': 'Prepare to enter the roundabout',
      'totalDistanceLabel': 'Total distance',
      'yourDestination': 'your destination',
    },
    'fr': {
      'readyToNavigate': 'Prêt à naviguer',
      'calculatingRoute': 'Calcul de l\'itinéraire...',
      'navigating': 'Navigation en cours',
      'navigationPaused': 'Navigation en pause',
      'arrivedAtDestination': 'Arrivé à destination',
      'navigationError': 'Erreur de navigation',
      'turnLeftNow': 'Tournez à gauche maintenant',
      'turnRightNow': 'Tournez à droite maintenant',
      'mergeNow': 'Insérez-vous maintenant',
      'takeTheExit': 'Prenez la sortie',
      'getReady': 'Préparez-vous',
      'prepareToTurnLeft': 'Préparez-vous à tourner à gauche',
      'prepareToTurnRight': 'Préparez-vous à tourner à droite',
      'prepareToMerge': 'Préparez-vous à vous insérer',
      'prepareToExit': 'Préparez-vous à sortir',
      'prepareTo': 'Préparez-vous à',
      'inDistance': 'Dans',
      'voiceTestMessage': 'Les instructions vocales fonctionnent correctement',
      'navigationStarting': 'Démarrage de la navigation',
      'youHaveArrived': 'Vous êtes arrivé à destination',
      'recalculatingRoute': 'Recalcul de l\'itinéraire',
      'enterRoundabout': 'Entrez dans le rond-point',
      'prepareToEnterRoundabout': 'Préparez-vous à entrer dans le rond-point',
      'totalDistanceLabel': 'Distance totale',
      'yourDestination': 'votre destination',
    },
  };
}

class _NavigationLocalizationsDelegate extends LocalizationsDelegate<NavigationLocalizations> {
  const _NavigationLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => NavigationLocalizations.supportedLocales.contains(Locale(locale.languageCode));

  @override
  Future<NavigationLocalizations> load(Locale locale) {
    return SynchronousFuture<NavigationLocalizations>(NavigationLocalizations(locale));
  }

  @override
  bool shouldReload(_NavigationLocalizationsDelegate old) => false;
}
