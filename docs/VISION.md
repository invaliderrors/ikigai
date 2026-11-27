# Ikigai — Vision

**Ikigai is a live wallpaper engine for macOS.** Play, create and share animated wallpapers: anime, games, landscapes, abstract art, anything. Its creator studio is simple enough that one picture becomes a living wallpaper in about a minute.

Ikigai should feel as if Apple had made a Mac version of Wallpaper Engine: native, light on battery, and fun to create with.

## Who it's for

| Person | Wants | Ikigai gives them |
|---|---|---|
| **Player** | A beautiful desktop that moves, with no technical work | A library, one-click apply, per-display wallpapers, playlists |
| **Creator** | To turn their art or favorite scenes into wallpapers | A studio that starts from one image: automatic depth, subject cut-out, paint-to-animate, effect presets |
| **Power creator** | Full control | Layers, masks, Metal shader effects, keyframes and, later, scripting |

## Pillars

1. **Native first.** SwiftUI, the macOS 26 design language, menu bar control, multiple displays, Spaces and Stage Manager all work as a Mac user expects.
2. **Costs almost nothing.** Wallpapers pause when covered, in fullscreen, on battery or in Low Power Mode. They never keep the Mac awake. A typical scene should be unnoticeable in Activity Monitor.
3. **Creation is the product.** Every effect has a sensible default, works by dragging or painting, and shows a live preview on the real desktop.
4. **Room to grow.** Simple tools sit on top of a real engine (a layer stack, masks and shader passes), so experts are never limited.
5. **Made to share.** A wallpaper is one portable `.ikigai` file. A community gallery comes later.

## Wallpaper types

- **Scene**: layered 2D artwork rendered with Metal. Parallax, particles, shader effects (wave, sway, shake, water ripple, scroll, glow, color grading), masks, and reactions to audio, time and the cursor.
- **Video**: a looping movie with aspect-fill and per-display cropping.
- **Web**: HTML/CSS/JS for generative and interactive pieces, running in a locked-down web view.
- **3D model layers** (later): an animated 3D model placed inside a scene, with camera and lighting presets, rendered by RealityKit.

## What makes it easy (the signature features)

- **One-image wizard.** Drop in a picture. Ikigai estimates depth (Core ML), lifts the subject from the background (Vision) and builds a parallax scene with suggested effects.
- **Paint to animate.** Brush over hair, water, clouds or grass and pick "sway", "ripple" or "scroll".
- **Effect presets.** Rain on glass, snow, fireflies, petals, embers, light leaks and audio visualizers, each one click away.
- **Preview on your desktop.** The studio's canvas is the real desktop while you edit.

## Not doing (for now)

- **Animated lock screen.** macOS doesn't allow third-party lock-screen wallpapers.
- **Windows or Linux.**
- **Importing Wallpaper Engine Workshop items.** Their licensing and format are not ours to use.
- **Full 3D worlds or a 3D editor.** 3D arrives later as model layers inside 2D scenes, with camera and lighting presets (roadmap Phase 8), not as a separate 3D tool.

## Content and responsibility

People will make wallpapers from anime, games and other copyrighted art. Players use local files freely. The public gallery will need takedown (DMCA) handling, content ratings with a mature-content filter, and moderation before it launches.
