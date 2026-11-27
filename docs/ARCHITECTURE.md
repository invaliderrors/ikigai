# Ikigai — Architecture

## Layout

```
App/                      SwiftUI app: menu bar, library, studio (MainActor by default)
Packages/IkigaiKit/       Engine, as a local Swift package
  IkigaiCore              Manifest, package format, library storage. No AppKit; fully tested.
  IkigaiRender   (Ph. 1)  Video and web players, previews; the Metal scene renderer joins in Phase 2
  IkigaiDesktop  (Ph. 1)  Desktop windows, displays/Spaces/power monitoring (decisions via IkigaiCore's PausePolicy)
project.yml               XcodeGen spec; the .xcodeproj is generated and not committed
```

A module is added when its phase starts, not before.

## Wallpaper package (`.ikigai`)

A folder in the library; shared as one `.ikigai` file, the folder as an LZFSE-compressed Apple Archive:

```
Sunset.ikigai/
  manifest.json     WallpaperManifest: formatVersion, id, title, kind, entry, tags
  preview.jpg       library thumbnail
  assets/…          images, video, html, masks
```

Rules:
- Importing a `.ikigai` file checks every entry before it's written (no absolute or `..` paths, plain files and folders only, a running size cap) and gives the wallpaper a fresh id.
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

No physics, scene-graph editor framework, scripting runtime, general asset pipeline or 3D renderer of our own. Video stays on AVFoundation, web on WebKit, depth and subject cut-out on Core ML and Vision, and 3D on RealityKit (see 3D layers below).

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

## 3D layers (Phase 8)

3D arrives as a new layer type inside 2D scenes, not as a separate kind of wallpaper. RealityKit renders the model; the scene engine composites it like any other layer.

### How it works

```
Scene document
 ├─ image layer   → Metal effect passes ──────────────────────────┐
 ├─ model layer   → RealityRenderer → texture → effect passes ────├→ composite → screen
 └─ particle layer → GPU particles ───────────────────────────────┘
```

- `RealityRenderer` (macOS 15+) renders the model into an `MTLTexture` through `CameraOutput.singleProjection(colorTexture:)`, with a transparent background.
- Our frame loop calls `updateAndRender(deltaTime:…)`, so the FPS cap and the pause policy apply to 3D unchanged. Paused means the call is not made.
- Our effects (glow, color grade, ripple…) can run on top of the model layer.
- Verified in the macOS 15 SDK: `RealityRenderer`, `ParticleEmitterComponent`, `ImageBasedLightComponent`, `ShaderGraphMaterial` and `CustomMaterial` are all available. SceneKit is deprecated and not used.

### The model layer

- **File:** `.usdz` inside the package. Creators export USD from Blender, or convert `.fbx`, `.obj` or `.gltf` with Apple's Reality Converter.
- **Animation:** one of the animations the file contains, looped.
- **Camera presets:** Still, Slow orbit, Follows the mouse, Gentle drift. Advanced settings: path, field of view.
- **Lighting presets:** environment lighting (Studio, Sunset, Night city, Overcast). Advanced settings: shadows, light direction.
- **Import limits** (untrusted input; numbers set by the spike): a triangle cap (starting at 300k), a maximum texture size (starting at 4K), and a file size cap.
- **Defaults:** 30 fps, soft shadows off, one environment light.
- Adding the layer type bumps the `.ikigai` `formatVersion`, with a migration and tests.

### The 3D spike (first one to two weeks of Phase 8)

**Test scene:** one animated `.usdz` model with environment lighting, composited between two image layers, plus mouse parallax, at 30 fps on the baseline and stretch machines from the renderer spike.

| Check | Target |
|---|---|
| Paused | 0% CPU and no GPU work when `updateAndRender` is not called |
| CPU while playing | Under 5% of one core on average |
| GPU time per frame | Under 8 ms per 4K display |
| Memory | Under 500 MB for the test scene |
| Compositing | Clean alpha edges over 2D layers, with no halos |

Fallback if RealityKit fails the spike: render the model layer with our own Metal pipeline (static meshes first, skinning later). That is months of work, not weeks, so it needs a decision before starting.

Content risk: people will import models ripped from games. The gallery's takedown and moderation process (Phase 6) covers 3D files too.

## Security

- Imported packages are untrusted. Paths are confined to the package, and sizes and counts are limited on import.
- Web wallpapers run in a `WKWebView` that can read only their own package. Network access is off by default.
- Future scripts run in a `JSContext` with no access to the host.

## Conventions

- Swift 6 language mode with strict concurrency. App code is MainActor by default; `IkigaiCore` is nonisolated and `Sendable`.
- Tests use Swift Testing in the package. Every phase adds tests for its core logic.
- Minimum macOS 15.
