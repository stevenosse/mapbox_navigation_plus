import 'package:example/basic_navigation_demo.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_navigation_plus/mapbox_navigation_plus.dart';
import 'config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Config.instance.loadVariables();

  if (!Config.instance.isMapboxConfigured) {
    throw Exception(
      'Mapbox access token not configured. Please edit variables.json',
    );
  }

  MapboxOptions.setAccessToken(Config.instance.mapboxAccessToken);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mapbox Navigation Demo',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: BasicNavigationDemo(),
    );
  }
}
