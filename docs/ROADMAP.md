# Ikigai — Roadmap

Each phase ends with something usable. Later phases may be reordered; earlier ones may not be skipped.

## Phase 0 — Foundation ✅ (current)

- Xcode project (XcodeGen), SwiftUI app shell, `IkigaiKit` package
- Wallpaper manifest v1 + safe package paths, with tests
- CI: package tests + app build on every push
- Vision, roadmap and architecture docs

## Phase 1 — Player MVP: *"I use it every day"*

- Desktop host: one window per display, joins all Spaces, handles displays being plugged in or removed
- Pause policy: covered/fullscreen, battery, Low Power Mode, screen locked or asleep, an FPS cap
- Video and web wallpapers
- Library window: thumbnail grid, search, tags, import by drag and drop, `.ikigai` import/export
- Menu bar: switch wallpaper, pause, open library
- Different wallpaper per display, launch at login
- Decide on distribution: Developer ID + notarization + Sparkle updates (likely), or the Mac App Store

## Phase 2 — Scene engine

- First week: the renderer spike against the budgets in `docs/ARCHITECTURE.md`; build the rest only once it passes
- Metal renderer: layer stack, transforms, blend modes, opacity
- Mouse parallax, GPU particles with presets
- Effect passes: wave, sway, shake, scroll, water ripple, glow/bloom, color grading, blur
- Effect masks (painted greyscale images)
- Performance budget and an on-screen stats overlay

## Phase 3 — Studio: *"a minute from picture to wallpaper"*

- Canvas with direct manipulation, layer list, inspector, undo/redo
- Mask brush, effect browser with live thumbnails
- One-image wizard: depth estimation (Core ML), subject lifting (Vision), automatic parallax layers
- Templates and starter scenes
- Live preview on the desktop while editing

## Phase 4 — Reactive wallpapers

- Audio-reactive effects: system audio tap (Core Audio) → FFT (Accelerate) → shader inputs
- Time of day and day/night variants
- Cursor effects: hover glow, click ripples

## Phase 5 — Personalization

- Creator-exposed properties (colors, toggles, sliders) that players can change
- Playlists, shuffle, schedules

## Phase 6 — Sharing

- Public `.ikigai` format documentation
- Community gallery: accounts, uploads, tags, ratings, mature-content filter, moderation, DMCA flow
- Creator profiles

## Phase 7 — Advanced creation

- Keyframe timeline
- Scripting (JavaScriptCore, sandboxed)
- 2D mesh / puppet warp for characters (breathing, blinking, hair)
- Custom shader editor

## Phase 8 — 3D layers

- First one to two weeks: the 3D spike against the budgets in `docs/ARCHITECTURE.md`
- Model layer: import `.usdz`, loop a built-in animation, composite between 2D layers through RealityKit's off-screen renderer
- Camera presets (Still, Slow orbit, Follows the mouse, Gentle drift) and lighting presets (Studio, Sunset, Night city, Overcast)
- Import limits and validation for untrusted models
- Studio: drop in a model, pick presets, with advanced camera and lighting settings tucked away
- `.ikigai` format version bump with a migration
