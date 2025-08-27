import 'package:http/http.dart' as http;
import 'location_service.dart';
import 'mapbox_directions_api.dart';
import 'voice_instruction_service.dart';
import 'route_visualization_service.dart';
import '../controllers/navigation_controller.dart';
import '../controllers/camera_controller.dart';

/// Factory for creating navigation services with proper configuration
class NavigationServiceFactory {
  /// Creates a configured location service
  static LocationService createLocationService() {
    return LocationService();
  }

  /// Creates a configured Mapbox Directions API service
  static MapboxDirectionsAPI createDirectionsAPI({
    required String accessToken,
    String language = 'en',
    http.Client? httpClient,
  }) {
    return MapboxDirectionsAPI(
      accessToken: accessToken,
      httpClient: httpClient,
      language: language,
    );
  }

  /// Creates a configured voice instruction service
  static VoiceInstructionService createVoiceService() {
    return VoiceInstructionService();
  }

  /// Creates a configured camera controller
  static CameraController createCameraController() {
    return CameraController();
  }

  /// Creates a configured route visualization service
  static RouteVisualizationService createRouteVisualizationService() {
    return RouteVisualizationService();
  }

  /// Creates a fully configured navigation controller with dependencies
  static NavigationController createNavigationController({
    required LocationService locationService,
    required MapboxDirectionsAPI directionsAPI,
    required CameraController cameraController,
    VoiceInstructionService? voiceService,
    NavigationStartBuilder? navigationStartBuilder,
    ArrivalAnnouncementBuilder? arrivalAnnouncementBuilder,
  }) {
    return NavigationController(
      locationService: locationService,
      directionsAPI: directionsAPI,
      cameraController: cameraController,
      voiceService: voiceService,
      navigationStartBuilder: navigationStartBuilder,
      arrivalAnnouncementBuilder: arrivalAnnouncementBuilder,
    );
  }
}
