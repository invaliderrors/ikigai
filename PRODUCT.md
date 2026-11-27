# Product

<!-- impeccable:product-schema 1 -->

## Platform

macos

Native macOS app (SwiftUI, macOS 15+). Impeccable's schema has no macOS value. Apple's macOS Human Interface Guidelines govern structure and controls.

## Users

Two groups, served with equal weight, each in its own mode:

- **Players** want a beautiful moving desktop without technical work. They browse, preview, apply and switch wallpapers, often from the menu bar while doing something else.
- **Creators** turn art (anime, games, landscapes, their own work) into wallpapers. They range from someone with one picture and a minute to spare, to power users who want layers, masks and shaders.

## Product Purpose

Ikigai is a live wallpaper engine for macOS: play, create and share animated wallpapers. Success means a player has a moving desktop within a minute of first launch, and a creator turns one picture into a living wallpaper in about a minute.

## Positioning

The only Mac wallpaper app where creation is a first-class mode beside playing. A native studio, starting from a single image (automatic depth and subject cut-out, paint-to-animate, effect presets), produces portable `.ikigai` files. It runs at near-zero cost because it pauses whenever the wallpaper can't be seen.

## Operating Context

- Lives in the menu bar. The desktop behind the user's windows is the real output surface.
- Multiple displays, Spaces, Stage Manager and fullscreen apps are normal conditions, not edge cases.
- Laptops on battery are common: cost and pausing are product behavior, not tuning.
- Wallpapers come from a bundled starter pack and user imports (video files, web folders, `.ikigai` files). A community gallery comes later (roadmap Phase 6).

## Capabilities and Constraints

- Wallpaper types: Scene (layered 2D rendered with Metal), Video, Web.
- `.ikigai` package format: a manifest plus assets, versioned. Packages are untrusted input.
- macOS does not allow third-party animated lock screens; Ikigai's surface is the desktop only.
- Roadmap order: player → scene engine → studio → reactive → personalization → sharing → advanced (`docs/ROADMAP.md`).
- Open: whether the gallery has accounts and monetization; distribution channel (Developer ID vs Mac App Store); behavior when system Reduce Motion is on.

## Brand Commitments

- Name: **Ikigai**.
- No logo, palette or visual identity has been decided yet.

## Evidence on Hand

- None yet: no starter-pack wallpapers, users, testimonials or gallery content exist. Future work must not invent them; mock content must be labeled as placeholder.

## Product Principles

1. **Two modes, one home.** Playing and creating are equal and clearly separated. Neither is buried inside the other.
2. **The desktop is the canvas.** Previews and edits show on the real desktop whenever possible.
3. **Invisible when unseen.** If the wallpaper can't be seen, it costs nothing.
4. **Simple on top, deep underneath.** Every creation tool works by default and reveals depth on demand.
5. **Portable by default.** Everything a creator makes is a single file they own.
