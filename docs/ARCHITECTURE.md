# Ikigai — Architecture

## Layout

```
App/                      SwiftUI app: menu bar, library, studio (MainActor by default)
Packages/IkigaiKit/       Engine, as a local Swift package
  IkigaiCore              Manifest, package format, library storage. No AppKit; fully tested.
  IkigaiDesktop  (Ph. 1)  Desktop windows, displays/Spaces/power monitoring, pause policy
  IkigaiRender   (Ph. 2)  Metal scene renderer, video and web hosts
project.yml               XcodeGen spec; the .xcodeproj is generated and not committed
```

A module is added when its phase starts, not before.

## Wallpaper package (`.ikigai`)

A folder (a macOS document package) zipped for sharing:

```
Sunset.ikigai/
  manifest.json     WallpaperManifest: formatVersion, id, title, kind, entry, tags
  preview.jpg       library thumbnail
  assets/…          images, video, html, masks
```

Rules:
- `formatVersion` is an integer. Ikigai refuses to open versions newer than it understands and migrates older ones.
- Every path in a manifest is relative and must resolve inside the package (`PackagePath.resolve`). Packages come from strangers.
- The library lives in `~/Library/Application Support/Ikigai/Library/`. Settings live in `UserDefaults`.

## Desktop host

- One borderless window per display at `kCGDesktopWindowLevel`: below the desktop icons and above the system wallpaper. It joins all Spaces, stays put in Mission Control and ignores mouse events.
- The pause policy combines window occlusion, fullscreen, power source, Low Power Mode, screen lock and sleep. The wallpaper renders only when someone can see it.
- Video players never prevent display sleep.

## Scene engine (Phase 2)

Ikigai renders scenes with its own small engine: a 2D layer compositor with effects, built on Metal. It is deliberately not a game engine.

### What it is

| Part | Responsibility |
|---|---|
| **Scene document** | `Codable` value types in `IkigaiCore`: layers, transforms, effects, masks, parameters. Stored in the `.ikigai` package. |
| **Compiler** | Turns a document into a render plan: for each layer, its effect passes in order, then the composite. Validates against the package (paths, sizes, known effects). |
| **Renderer** | Executes the plan each frame. One shared `MTLDevice`, command queue and texture cache; one `MTKView` per display. |
| **Effects** | Each effect is one fragment function, a parameter struct and an optional mask texture. Blur, bloom and color grading use Core Image on the same Metal device. |
| **Particles** | GPU particles (compute or instanced draw) with presets: snow, rain, dust, petals, embers. |
| **Inputs** | Time, a smoothed mouse position (parallax), and later audio levels (Phase 4). |
| **Frame loop** | Driven by the display link at the FPS cap. When paused it encodes no work at all. |

Effects are a closed list per roadmap phase. Phase 2: wave, sway, shake, scroll, water ripple, glow/bloom, color grade, blur, particles, parallax.

### What it is not

No physics, 3D, scene-graph editor framework, scripting runtime or general asset pipeline. Video stays on AVFoundation, web on WebKit, depth and subject cut-out on Core ML and Vision. A 3D renderer (likely RealityKit) is out of scope until after Phase 7.

### Why our own

- Third-party engines (Unity, Godot) add 50–100+ MB of runtime and a frame loop that is hard to make truly idle, and the app would feel non-native.
- One design for the format, the Studio and the renderer: every effect the Studio offers is one the engine renders cheaply.
- Wallpaper Engine takes the same approach: its scenes run on its own lightweight renderer.

### The renderer spike (first week of Phase 2)

Build the smallest renderer that can draw one real scene, measure it, and build the full effect set only if it meets these budgets. The numbers are starting targets; revise them with evidence, never silently.

**Test scene:** 6 image layers, 2 masked effects (sway and water ripple), 1 particle layer (about 2,000 particles), mouse parallax, at 30 fps.

| Check | Target |
|---|---|
| Baseline machine | Lowest supported Apple Silicon (M1, 8 GB), built-in display plus one 4K external |
| Stretch machine | An M-series Pro or Max driving three displays, two of them 4K |
| CPU while playing | Under 3% of one core on average (Activity Monitor) |
| GPU time per frame | Under 4 ms per 4K display |
| Memory | Under 300 MB for the test scene |
| Paused | 0% CPU and no GPU work, confirmed in Instruments |
| Resume | First frame within 100 ms |
| Stability | No hitch longer than 2 frames over a 10-minute run |

Report the results in the Phase 2 PR, with Instruments traces attached.

Open decision: support Intel Macs or not. Apple Silicon is first either way.

## Security

- Imported packages are untrusted. Paths are confined to the package, and sizes and counts are limited on import.
- Web wallpapers run in a `WKWebView` that can read only their own package. Network access is off by default.
- Future scripts run in a `JSContext` with no access to the host.

## Conventions

- Swift 6 language mode with strict concurrency. App code is MainActor by default; `IkigaiCore` is nonisolated and `Sendable`.
- Tests use Swift Testing in the package. Every phase adds tests for its core logic.
- Minimum macOS 15.
