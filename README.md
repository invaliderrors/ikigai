# Ikigai

**A live wallpaper engine for macOS.** Play, create and share animated wallpapers: anime, games, landscapes, abstract art, anything. The creator studio turns a single picture into a living wallpaper in about a minute.

> Status: **Phase 0 — Foundation.** The app shell builds; wallpapers don't play yet. See the [roadmap](docs/ROADMAP.md).

## Docs

- [Vision](docs/VISION.md): what Ikigai is, who it's for, what it won't do
- [Roadmap](docs/ROADMAP.md): phases from player MVP to community gallery
- [Architecture](docs/ARCHITECTURE.md): modules, `.ikigai` package format, rendering, security

## Requirements

- macOS 15 or later
- Xcode 26
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Getting started

```sh
xcodegen generate        # creates Ikigai.xcodeproj from project.yml
open Ikigai.xcodeproj    # run the "Ikigai" scheme; it lives in the menu bar
```

Engine tests:

```sh
swift test --package-path Packages/IkigaiKit
```

The Xcode project is generated, so change `project.yml` rather than the project's settings in Xcode.

## License

Copyright © 2026 invaliderrors. All rights reserved. See [LICENSE](LICENSE).
