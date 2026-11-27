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

## Scene rendering (Phase 2)

- A scene document (value types, `Codable`) is compiled into a render graph: layer → effect passes → composite.
- One `MTLDevice` and texture cache are shared across displays, with one `MTKView` per display.
- The frame loop runs on the view's display link with an FPS cap. Rendering stops entirely while paused.

## Security

- Imported packages are untrusted. Paths are confined to the package, and sizes and counts are limited on import.
- Web wallpapers run in a `WKWebView` that can read only their own package. Network access is off by default.
- Future scripts run in a `JSContext` with no access to the host.

## Conventions

- Swift 6 language mode with strict concurrency. App code is MainActor by default; `IkigaiCore` is nonisolated and `Sendable`.
- Tests use Swift Testing in the package. Every phase adds tests for its core logic.
- Minimum macOS 15.
