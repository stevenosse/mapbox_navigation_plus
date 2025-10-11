Class diagram: 

```mermaid
classDiagram
    class NavigationController {
        +RoutingEngine routingEngine
        +LocationProvider locationProvider
        +RouteProgressTracker progressTracker
        +VoiceGuidance voiceGuidance
        +MapControllerInterface mapController

        +Stream~NavigationState~ state
        +Stream~RouteProgress~ progressUpdates
        +Stream~Maneuver~ upcomingManeuver
        +Stream~void~ arrived

        +startNavigation(origin, destination, waypoints)
        +stopNavigation()
        +pauseNavigation()
        +resumeNavigation()
        +recenterMap()
    }

    class RoutingEngine {
        +getRoute(origin, destination, waypoints, profile, voiceInstructions) RouteModel
        +reroute(currentLocation, previousRoute) RouteModel
    }

    class LocationProvider {
        +start()
        +stop()
        +Stream~LocationPoint~ locationStream
    }

    class VoiceGuidance {
        +speak(instruction)
        +pause()
        +resume()
        +stop()
    }

    class RouteProgressTracker {
        +start(route, locationStream)
        +stop()
        +Stream~RouteProgress~ onProgressChanged
        +Stream~Maneuver~ onUpcomingManeuver
        +Stream~RouteDeviation~ onDeviated
        +Stream~void~ onArrived
    }

    class MapControllerInterface {
        +drawRoute(geometry)
        +updateProgressLine(progressGeometry)
        +showMarkers(markers)
        +moveCamera(position, zoom, bearing)
        +clear()
    }

    class RouteModel {
        +List~Leg~ legs
        +geometry
        +duration
        +distance
    }

    class Leg {
        +List~Step~ steps
        +duration
        +distance
    }

    class Step {
        +Maneuver maneuver
        +duration
        +distance
        +List~VoiceInstruction~ voiceInstructions
    }

    class Maneuver {
        +type
        +modifier
        +instruction
    }

    class VoiceInstruction {
        +announcement
        +distanceAlongGeometry
    }

    class RouteProgress {
        +LocationPoint currentLocation
        +double distanceTraveled
        +double distanceRemaining
        +double durationRemaining
        +int currentLegIndex
        +int currentStepIndex
    }

    %% Relationships
    NavigationController --> RoutingEngine
    NavigationController --> LocationProvider
    NavigationController --> RouteProgressTracker
    NavigationController --> VoiceGuidance
    NavigationController --> MapControllerInterface

    RoutingEngine --> RouteModel
    RouteModel --> Leg
    Leg --> Step
    Step --> Maneuver
    Step --> VoiceInstruction

    RouteProgressTracker --> RouteModel
    RouteProgressTracker --> LocationProvider

    MapControllerInterface ..> RouteModel : uses
```

Here are a breakdown of **small dev steps** + a **class diagram** sketch for the full system (pure-Dart version). You can use this as roadmap + implementation guide.

---

## Small development steps (milestones)

These are ordered so you can build incrementally, test, then add complexity.

| Step       | What to build / deliverable         | Key tasks & acceptance criteria                                                                                                                                                                                                                                                                                                           |
| ---------- | ----------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Step 1** | Basic routing + map display         | - Implement `RoutingEngine` that calls Mapbox Directions API <br> - Parse route geometry + steps + maneuvers <br> - Display route polyline on the map using `mapbox_maps_flutter` <br> - Show origin & destination markers <br> - Basic map control (zoom, center)                                                                        |
| **Step 2** | Location & following user location  | - Set up `LocationProvider` using `geolocator` <br> - Show current location as marker on map <br> - Implement camera follow mode (i.e. map moves/centers on current position) <br> - Handle permissions gracefully                                                                                                                        |
| **Step 3** | Route progress tracking + UI data   | - Build `RouteProgressTracker` to track which step / leg you are in <br> - Compute distance remaining, ETA, distance until next maneuver <br> - Expose streams or callbacks for progress updates <br> - Simple instruction UI (text banner) showing next turn, etc.                                                                       |
| **Step 4** | Voice guidance                      | - Use `flutter_tts` to speak instructions <br> - Use voice instructions from Mapbox (with `distanceAlongGeometry`) to schedule announcements <br> - Allow pausing / cancelling / resuming voice <br> - Support basic localization (language) if possible                                                                                  |
| **Step 5** | Deviation detection & rerouting     | - Implement logic to detect off-route (user distance from route geometry exceeds threshold) <br> - On deviation, call `RoutingEngine.reroute(...)` <br> - Update route polyline, reset progress & voice/instruction as needed <br> - UI feedback to user (e.g. “rerouting”)                                                               |
| **Step 6** | UI customization & theming          | - Build default widgets: instruction banner, step list, summary, ETA/distance info <br> - Define style/theme classes, allow overriding colours/fonts/layout <br> - Allow custom widget injection (e.g. replace instruction banner with your own) <br> - Make map route-line styling configurable                                          |
| **Step 7** | Error handling, lifecycles & polish | - Handle errors: routing failures, GPS errors, network offline <br> - Handle app lifecycle events: background / resume <br> - Efficiency: throttle location updates, avoid unnecessary redraws <br> - Unit tests / integration tests for key logic: progress tracking, deviation detection, voice scheduling <br> - Logging / diagnostics |
| **Step 8** | Optional nice-to-haves              | - Alternative routes <br> - Traffic-aware route profiles (if Mapbox API supports) <br> - Offline caching of routes or map tiles (if feasible) <br> - Voice instruction SSML support or richer markup <br> - Animations of the route line (e.g. highlighted traveled vs remaining)                                                         |

You might want to split Steps further depending on team size. After each step, ensure API surface is stable so downstream steps (UI etc.) don’t break.

---

### Model classes

* `Maneuver`

  * type (turn, depart, arrive, etc.)
  * modifier (left, right, etc.)
  * instruction text

* `VoiceInstruction`

  * announcement (String)
  * distanceAlongGeometry (double)
  * optional SSML or markup

* `RouteProgress`

  * current location (LocationPoint)
  * distance traveled
  * distance remaining
  * time remaining / ETA
  * current leg / step indices

* `NavigationState` (enum)

  * idle, routing, navigating, paused, arrived, deviated, error