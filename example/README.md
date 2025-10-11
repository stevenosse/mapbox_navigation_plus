# Mapbox Navigation Example

This example demonstrates how to use the Mapbox Navigation package for turn-by-turn navigation.

## Setup

### 1. Configure your Mapbox Access Token

The example uses a secure configuration system that loads your Mapbox access token from a non-tracked file.

1. **Get your Mapbox access token** from [Mapbox Account Dashboard](https://account.mapbox.com/access-tokens/)

2. **Create/edit `variables.json`** in the example directory:
   ```json
   {
     "mapbox_access_token": "YOUR_MAPBOX_ACCESS_TOKEN_HERE"
   }
   ```

3. **Replace** `YOUR_MAPBOX_ACCESS_TOKEN_HERE` with your actual token

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Run the app

```bash
flutter run
```

## Features Demonstrated

- **Real GPS Location Tracking**: Uses device GPS for actual location updates
- **Route Calculation**: Calculates routes using Mapbox Directions API
- **Turn-by-Turn Navigation**: Real-time navigation with voice guidance
- **Map Visualization**: Interactive map with route lines and markers
- **Route Progress Tracking**: Monitors progress along the calculated route
- **Voice Guidance**: Text-to-speech navigation instructions

## Permissions

The app requires the following permissions:

- **Location Services**: For GPS tracking and navigation
- **Internet**: For Mapbox API calls

## Configuration Security

The `variables.json` file is included in `.gitignore` to ensure your access token is never accidentally committed to version control. This approach:

- ✅ Keeps sensitive data secure
- ✅ Allows different configurations per developer
- ✅ Prevents accidental token exposure
- ✅ Supports environment-specific configurations

## Testing

To test the navigation:

1. Ensure your device/emulator has location services enabled
2. Grant location permissions when prompted
3. Set emulator location (if using emulator)
4. Tap "Start Navigation" to begin route calculation
5. The app will show your route and provide turn-by-turn directions

## Demo Locations

The app uses predefined locations in San Francisco:
- **Origin**: Downtown San Francisco (37.7749, -122.4194)
- **Destination**: nearby location (37.7849, -122.4094)

You can modify these in `main.dart` to test with different locations.

## Troubleshooting

### "Mapbox token not configured" Error
- Ensure `variables.json` exists in the example directory
- Verify your token is correctly set in the JSON file
- Make sure the token is valid and active

### Location Issues
- Check that location services are enabled
- Verify app has location permissions
- For emulators, ensure GPS is simulated

### Voice Guidance Issues
- Ensure device volume is up
- Check that TTS is enabled in device settings
- Some emulator configurations may not support TTS