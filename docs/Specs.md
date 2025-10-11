## Goals & constraints

Before architecture, restate what you want:

* Replicate / approximate Mapbox Navigation feature set: routing, turn-by-turn, re-routing, voice guidance, route line, progress tracking, UI, etc.
* Use **mapbox_maps_flutter** for map rendering
* Use **geolocator** for location, permissions, GPS updates
* Use **flutter_tts** for voice instructions
* Keep UI customizable (pluggable, themable)
* Keep internal code modular and replaceable
* Keep simple for consumers (good API surface)

You’ll need to juggle cross-platform (iOS/Android) concerns, native integration (for routing), error handling, lifecycle, etc.

One caveat: the official `mapbox_maps_flutter` is just “maps” (rendering, layers, camera, etc.) — it doesn’t itself provide full navigation (routing, instruction logic). Others have pointed out that the community “flutter_mapbox_navigation” bridges to native Mapbox Navigation, but with limited flexibility. ([Stack Overflow][1]) You’ll likely have to integrate parts of the Mapbox Navigation SDKs (or your own routing engine) at the platform level.

Also, Mapbox’s Android Navigation SDK uses a modular architecture (you can swap components) via interface contracts (Router, TripNotification, Logger, etc.) ([Mapbox][2]) You may borrow that philosophy.

---

## Modular Architecture Proposal

Here’s how I’d slice it into modules / layers. Each module has a clear responsibility and interacts via interfaces (contracts). The UI layer is decoupled, so you can replace or customize.

```
navigation_package/
  ├── core/
  │    ├── interfaces/        # contracts/interfaces
  │    │     ├── location_provider.dart
  │    │     ├── routing_engine.dart
  │    │     ├── voice_guidance.dart
  │    │     ├── route_progress_tracker.dart
  │    │     ├── map_controller_interface.dart
  │    │     └── nav_controller.dart
  │    ├── models/            # data classes: instructions, route, segment, waypoints, etc.
  │    ├── utils/             # shared utils, geometry, math, etc.
  │    └── errors/
  ├── services/               # default implementations of interfaces
  │    ├── location/          # uses geolocator
  │    ├── routing/           # default routing (Mapbox API / native SDK)
  │    ├── voice/             # uses flutter_tts
  │    └── progress/           # tracks along the route, detect deviations etc.
  ├── ui/                     # UI / widget layer
  │    ├── map_widget/        # map + route line + markers etc.
  │    ├── instruction_widget/ # shows next turn, instruction list, etc.
  │    ├── speed_widget/
  │    ├── summary_widget/
  │    └── configurable theme & styling
  └── navigation_controller.dart  # façade that ties everything together (the “entry point”)
```

### Module Responsibilities & Interfaces

Here’s a breakdown of what each interface should provide, and how you might implement it:

| Module / Interface       | Responsibility                                                           | Key Methods / Events                                                                         | Default Implementation                                                                |
| ------------------------ | ------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| `LocationProvider`       | Abstract GPS updates, permissions, heading, accuracy                     | `start()`, `stop()`, stream of location updates, heading, error events                       | Use `geolocator` in `services/location/`                                              |
| `RoutingEngine`          | Compute routes, re-routing                                               | `getRoute(start, end, via...)`, `reroute(currentLocation)`, possibly traffic updates         | Default: call Mapbox Directions API; optionally native Mapbox Navigation SDK bridging |
| `RouteProgressTracker`   | Track user progress down the route, detect deviations, upcoming maneuver | input: route + location stream → events (onManeuver, onDeviated, onArrived)                  | A pure Dart implementation in `services/progress/`                                    |
| `VoiceGuidance`          | Manage turn instruction text → audio playback                            | `speak(instruction)`, `stop()`, `pause()`, `resume()`                                        | Wrap `flutter_tts`                                                                    |
| `MapControllerInterface` | Route line drawing, camera control, marker placement                     | `drawRoute(...)`, `updateProgressLine(...)`, `moveCamera(...)`, `addMarkers(...)`, `clear()` | Implementation via `mapbox_maps_flutter` calls                                        |
| `NavController` (façade) | Tie everything: takes start/stop, handles state, coordinates modules     | `startNavigation()`, `pause()`, `stop()`, `recenter()`, state stream (nav states)            | Orchestrates the modules, manages lifecycle, error handling                           |
| UI Widgets               | Pure Flutter UI layer consuming the NavController and drawing state      | Expose configuration (styles, layout)                                                        | Provide default widgets, but allow users to inject custom ones                        |

You’ll use dependency injection (or simple constructor injection) so consumers can swap out modules (e.g. custom voice, custom routing engine).

### Data & Models

Define shared data models in `core/models` that are independent of UI or platform:

* `Route` — list of `Leg`s or `Segment`s
* `Maneuver` / `Instruction` — text, distance, time, type (turn left, etc.)
* `RouteProgress` — how far traveled, current step index, etc.
* `LocationPoint` — lat/lng + accuracy + heading/time
* `NavigationState` — enum (idle, routing, navigating, arrived, deviated, error)
* `NavError` types

These models are used across UI, control logic, and services.

### Flow / Lifecycle

Here’s how a typical navigation session flows:

1. **Setup / initialization**

   * Consumer instantiates `NavigationController`, passing in (or defaulting) the modules (location provider, routing engine, voice, progress tracker, map controller).
   * Consumer supplies the `MapWidget` from your UI package (or passes its own), binds it with the `MapControllerInterface`.

2. **Start navigation**

   * `NavController.startNavigation(start, end, waypoints)`
   * Internally calls routing: `routingEngine.getRoute(...)`
   * Receives `Route` model
   * Instruct map controller to draw route line
   * Subscribe to location updates
   * Feed location updates into progress tracker
   * Progress tracker emits maneuver events, step changes, deviation, arrival
   * On maneuver events, invoke voice guidance `speak(...)`
   * Also notify UI listeners of changing state (e.g. update widget showing next turn, remaining distance)

3. **During navigation**

   * Location updates stream in
   * Progress tracker continuously computes current progress, upcoming instruction
   * UI updates (map position, next instruction widget)
   * If deviation detected, `NavController` can trigger re-routing (using routingEngine.reroute)
   * voice speaks new instructions
   * Optionally allow user to pause, resume, recenter map

4. **End / arrival**

   * When arrival event triggers, stop location updates, stop voice, notify UI
   * Clear route, camera maybe zoom out

5. **Lifecycle / app background / resume**

   * Need to handle app going to background / pausing (especially on Android, iOS).
   * Possibly need a foreground service (Android) or background permission for location updates.
   * Manage map lifecycle, widget disposal, stopping modules.

6. **Error handling / fallback**

   * If routing fails (network error), surface error to consumer / UI
   * If GPS lost, handle gracefully
   * If voice or TTS fails, degrade gracefully

### Customizability & Simplicity

* **Facade / high-level API**: The consumer sees only `NavigationController` (or similarly named) and UI widgets. They don’t need to know internals.
* **Module injection**: Provide default modules, but allow developer to inject custom ones (e.g. custom routing, voice, progress) via constructor or builder.
* **UI theming / style**: Expose styling parameters (colors, fonts, layouts). Use patterns like builder callbacks or widget composition so users can override parts (for instance, pass in a custom widget for instruction display).
* **Plugin pattern / feature toggles**: Some features (like rerouting, voice, offline routing) may be optional. You can design your modules so some are no-op or disabled.
* **Minimal API surface**: Provide the core APIs for navigation, and keep advanced configuration as opt-in.

---

## Platform Integration Challenges & Native Bridging

Because routing, instruction generation, re-routing logic, and advanced navigation features are often rich and rely on Mapbox’s native SDKs, you may need to bridge into native code (Android / iOS) to get:

* Faster route generation, traffic awareness
* Re-routing on deviation
* Lane guidance, spoken instruction metadata
* Offline routing
* Map snapshot / route alternatives

You’ll need (in `platform/android` and `platform/ios`):

* Native modules / channels (MethodChannel / MessageChannel) to call platform SDK APIs
* Serialization between Dart and platform types
* Handle threading / background location permissions
* Lifecycle hooks (pause / resume)

If you avoid deep native integration and rely only on calling Mapbox Web APIs + client logic in Dart, you’ll have more flexibility but more work to implement robust features (re-routing logic, traffic, etc).

The Mapbox Android Navigation documentation on modularization may inform how you separate native components (Router, Notification, Logger) as swappable modules. ([Mapbox][2])

---

## Example Usage (Consumer Side)

Here’s how I’d hope consumers use your package:

```dart
final navController = NavigationController(
  locationProvider: DefaultLocationProvider(),
  routingEngine: MapboxRoutingEngine(apiKey: "..."),
  voiceGuidance: DefaultVoiceGuidance(),
);

Widget build(BuildContext ctx) {
  return Stack(
    children: [
      MapNavigationWidget(
        controller: navController,
        style: MyMapStyle(...),
      ),
      Positioned(
        bottom: 80,
        left: 16,
        right: 16,
        child: InstructionBanner(
          controller: navController,
          style: MyInstructionStyle(...),
        ),
      ),
      Positioned(
        bottom: 16,
        right: 16,
        child: FloatingActionButton(
          onPressed: () => navController.recenter(),
          child: Icon(Icons.my_location),
        ),
      ),
    ],
  );
}
```

And controlling:

```dart
navController.startNavigation(
  from: LatLng(...),
  to: LatLng(...),
);
```

You can also expose streams / change notifications:

```dart
navController.onRouteProgress.listen((progress) { ... });
navController.onManeuver.listen((m) { ... });
navController.onStateChanged.listen((state) { ... });
```

---

## Development Strategy & Phased Approach

Since building it all at once is large, break into incremental “blocks”:

1. **Block 1: basic routing + map draw**

   * Use Mapbox Directions API in Dart
   * Draw route line on map via mapbox_maps_flutter
   * Show start / end markers
   * Move camera to follow user location (geolocator)
   * Expose a minimal API to start / stop route

2. **Block 2: progress tracking & instruction list**

   * Build `RouteProgressTracker` in Dart
   * Parse instructions from the route response
   * Expose upcoming instruction data to UI

3. **Block 3: voice guidance**

   * Integrate flutter_tts to speak instructions
   * Handle timing (e.g. speak a few seconds before maneuver)

4. **Block 4: rerouting / deviation handling**

   * Detect when user leaves the route
   * Trigger re-routing, update map, reset progress

5. **Block 5: UI components, customization, styling**

   * Build default widgets (instruction banners, step list, summary, speed)
   * Introduce customizable style parameters
   * Allow replacing widgets

6. **Block 6: native integration (optional / advanced)**

   * For better performance, traffic, offline routing
   * Bridge to native Mapbox Navigation SDK, or your own routing engine

7. **Block 7: lifecycle, background, error & edge cases**

   * Handle app background / foreground transitions
   * Permission management
   * Error surfaces
   * Testing, logging

At each block, test and expose stable APIs so that users of your package can start using early versions even while advanced features aren’t complete.
