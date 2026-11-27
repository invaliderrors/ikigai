---
name: Ikigai
description: Live wallpaper engine for macOS; the user is the projectionist and every display is a screen.
colors:
  house: "#17120f"
  house-2: "#1f1915"
  house-3: "#2a221d"
  house-4: "#362c25"
  booth-black: "#0b0908"
  seat: "#3b1519"
  seat-2: "#2a0f12"
  tungsten: "#f2b544"
  tungsten-bright: "#ffd27a"
  tungsten-ink: "#1f1406"
  screen: "#f4efe6"
  screen-2: "rgba(244,239,230,.72)"
  screen-3: "rgba(244,239,230,.6)"
  line: "rgba(244,239,230,.10)"
  line-2: "rgba(244,239,230,.16)"
  tungsten-tint: "rgba(242,181,68,.16)"
  live: "#4fae7a"
  stop: "#ef6a52"
typography:
  display-hero:
    fontFamily: "Big Shoulders Display, Oswald, sans-serif"
    fontSize: "46px"
    fontWeight: 800
    lineHeight: 1
    letterSpacing: "0.06em"
  display-feature:
    fontFamily: "Big Shoulders Display, Oswald, sans-serif"
    fontSize: "30px"
    fontWeight: 800
    lineHeight: 1.02
    letterSpacing: "0.06em"
  display-title:
    fontFamily: "Big Shoulders Display, Oswald, sans-serif"
    fontSize: "24px"
    fontWeight: 800
    lineHeight: 1
    letterSpacing: "0.06em"
  letter-board:
    fontFamily: "Big Shoulders Display, Oswald, sans-serif"
    fontSize: "14px"
    fontWeight: 800
    lineHeight: 1
    letterSpacing: "0.12em"
  title:
    fontFamily: "SF Pro Text, -apple-system, system-ui, sans-serif"
    fontSize: "13px"
    fontWeight: 650
    lineHeight: 1.4
  body:
    fontFamily: "SF Pro Text, -apple-system, system-ui, sans-serif"
    fontSize: "13px"
    fontWeight: 400
    lineHeight: 1.4
  label:
    fontFamily: "SF Pro Text, -apple-system, system-ui, sans-serif"
    fontSize: "12px"
    fontWeight: 400
    lineHeight: 1.4
  detail-term:
    fontFamily: "SF Pro Text, -apple-system, system-ui, sans-serif"
    fontSize: "12px"
    fontWeight: 700
    lineHeight: 1.4
    letterSpacing: "0.06em"
  caption:
    fontFamily: "SF Pro Text, -apple-system, system-ui, sans-serif"
    fontSize: "11.5px"
    fontWeight: 400
    lineHeight: 1.4
rounded:
  tag: "5px"
  panel: "6px"
  control: "8px"
  control-lg: "10px"
  group: "12px"
  strip: "14px"
  window: "16px"
  pill: "11px"
spacing:
  xxs: "4px"
  xs: "6px"
  sm: "8px"
  md: "10px"
  lg: "14px"
  xl: "18px"
  gutter: "20px"
  sheet: "28px"
components:
  button-primary:
    backgroundColor: "{colors.tungsten}"
    textColor: "{colors.tungsten-ink}"
    typography: "{typography.title}"
    rounded: "{rounded.control}"
    padding: "0 13px"
    height: "30px"
  button-primary-lg:
    backgroundColor: "{colors.tungsten}"
    textColor: "{colors.tungsten-ink}"
    rounded: "{rounded.control-lg}"
    padding: "0 18px"
    height: "38px"
  button-secondary:
    backgroundColor: "{colors.house-3}"
    textColor: "{colors.screen}"
    typography: "{typography.body}"
    rounded: "{rounded.control}"
    padding: "0 13px"
    height: "30px"
  button-selected:
    backgroundColor: "{colors.tungsten-tint}"
    textColor: "{colors.tungsten}"
    rounded: "{rounded.control}"
    height: "26px"
  button-danger:
    backgroundColor: "{colors.house-3}"
    textColor: "{colors.stop}"
    rounded: "{rounded.control}"
    height: "30px"
  search-field:
    backgroundColor: "rgba(244,239,230,.07)"
    textColor: "{colors.screen}"
    rounded: "{rounded.control}"
    padding: "0 10px"
    height: "30px"
  segmented-selected:
    backgroundColor: "{colors.house-4}"
    textColor: "{colors.screen}"
    rounded: "{rounded.panel}"
    padding: "4px 11px"
  chip:
    backgroundColor: "rgba(244,239,230,.08)"
    textColor: "{colors.screen-2}"
    typography: "{typography.caption}"
    rounded: "{rounded.pill}"
    padding: "0 9px"
    height: "22px"
  sidebar:
    backgroundColor: "{colors.seat}"
    textColor: "{colors.screen}"
    padding: "14px 10px"
  sidebar-item-selected:
    backgroundColor: "{colors.tungsten-tint}"
    textColor: "{colors.tungsten}"
    rounded: "{rounded.control}"
    padding: "6px 10px"
  letter-board:
    backgroundColor: "{colors.booth-black}"
    textColor: "{colors.screen}"
    typography: "{typography.letter-board}"
    padding: "5px 11px 4px"
  inspector:
    backgroundColor: "{colors.house-2}"
    textColor: "{colors.screen}"
    padding: "18px"
  settings-group:
    backgroundColor: "{colors.house-2}"
    textColor: "{colors.screen}"
    rounded: "{rounded.group}"
    padding: "9px 16px"
---

# Design System: Ikigai

## Overview

**Creative North Star: "The Projection Booth"**

You are the projectionist. Every display the user owns is a screen, and every wallpaper is the feature showing on it. The app is the dark booth behind the glass: warm house-dark charcoal, a deep seat-red sidebar, one tungsten lamp for the action that matters, and screen-white text. The wallpapers are the only saturated light in the room, so the chrome stays warm and dim and lets them carry the colour.

Ikigai is a native macOS app (SwiftUI, macOS 15+). Structure and controls are Apple's: a native `NavigationSplitView` sidebar, a unified toolbar, sheets for New Wallpaper and the one-image wizard, a `MenuBarExtra` panel, and a standard tabbed Settings window. The brand is carried by four things only: the tungsten tint, Big Shoulders Display on letter boards and titles, the letter boards themselves, and the display strip. The HTML mockups stand in for SwiftUI; their CSS custom properties map one to one onto app tokens (see Colors).

The system rejects the category default of a dark Steam-style storefront grid with neon accents, and equally the bland grey utility. Density is that of a Mac productivity app: 13px body, 30px controls, 8px corners.

**Key Characteristics:**
- Warm dark only (house #17120f family); a light appearance is open, not designed.
- One tungsten fill per screen; everything selected is tinted, not filled.
- Big Shoulders Display, uppercase and tracked, only on letter boards and screen or wallpaper titles.
- Neutral shadows; the only coloured light is the wallpaper's own spill under a strip panel.
- Native macOS controls throughout; brand lives in tint, type, letter boards and the display strip.

## Colors

A warm cinema palette: charcoal house tones, a seat-red sidebar, one tungsten lamp, and two signal colours borrowed from the theatre (exit green, changeover red).

**Mapping to the app.** Each frontmatter colour becomes a named colour asset in the asset catalog (`House`, `House2`, `Seat`, `Tungsten`, `TungstenInk`, `Screen`, `Live`, `Stop`, …) exposed through one Swift token enum (for example `Color.ik.tungsten`). The app sets `.tint(Color.ik.tungsten)` at the root so native controls (switches, sliders, focus rings, selection) pick it up instead of system blue. The alpha tokens (`screen-2`, `screen-3`, `line`, `line-2`, `tungsten-tint`) are `screen` or `tungsten` with opacity, not separate assets.

### Primary
- **Tungsten Amber** (tungsten): the projector lamp. Fills the single primary action on a screen, tints the selected sidebar item, selected panel ring, switch-on track, slider fill and links. Text on it is **Tungsten Ink** (tungsten-ink), about 9.9:1.
- **Bright Tungsten** (tungsten-bright): link hover only.
- **Tungsten Tint** (tungsten-tint): tungsten at 16% alpha, the selected and pressed background, always paired with tungsten text or icon.

### Secondary
- **Seat Red** (seat to seat-2): the sidebar only, as a top-to-bottom gradient. Never on content, never on buttons.

### Tertiary (signal)
- **Exit Green** (live): live status (the dot and its label, "Live on 2 of 3 screens"). As in the direction contract.
- **Changeover Red** (stop): destructive actions and errors. Deliberately lighter than the contract's #e0533d, which measures only about 4.9:1 on house and 4.1:1 on house-3; stop measures about 6.1:1 on house and 5.1:1 on house-3, so it holds AA on every surface it sits on.

### Neutral
- **House** (house): window content background.
- **House 2** (house-2): inspector, sheets, menu bar panel, Settings groups and tab bar.
- **House 3** (house-3): secondary buttons, pop-up buttons, Studio effect cards.
- **House 4** (house-4): the selected segment of a segmented control.
- **Booth Black** (booth-black): letter-board face and the dark scrim behind on-image tags and badges.
- **Screen White** (screen): primary text, about 16:1 on house. **screen-2** for secondary text, **screen-3** for placeholders and captions.
- **Line** (line) and **Line 2** (line-2): hairline dividers and 1px inset control strokes; line-2 for ghost buttons.

### Named Rules
**The One Lamp Rule.** Tungsten fills exactly one control per screen: the primary action ("Show on All Screens", "Resume", "Create"). Settings panes have none. A second filled tungsten control on the same screen is a defect.

**The Tint, Not Fill Rule.** Selected and pressed states (sidebar item, Settings tab, Studio layer, toggled tool button) use tungsten at 14–16% alpha with tungsten text and, where needed, a 1px tungsten inset stroke at about 35%. They never use a solid tungsten fill.

## Typography

**Display Font:** Big Shoulders Display 800 (with Oswald, then sans-serif)
**Body Font:** SF Pro (system font; Inter stands in on the mockups only)

**Character:** A condensed, tracked marquee face against Apple's own text face. The marquee announces what is showing; SF Pro does all the work.

**Bundling.** Big Shoulders Display is licensed under the SIL Open Font License and must be bundled in the app (registered via `ATSApplicationFontsPath` or `CTFontManagerRegisterFontsForURL`), with the OFL text included. The mockups load it from Google Fonts; the shipped app never fetches fonts.

### Hierarchy
- **Display Hero** (800, 46px; 34–40px in the wizard, line-height 1, uppercase, 0.06em): the one question on Welcome and wizard steps ("Pick your first wallpaper").
- **Display Feature** (800, 30px, 1.02, uppercase): the selected wallpaper or playlist title in an inspector.
- **Display Title** (800, 24px, 1, uppercase): the window's toolbar title (Library, Playlists, My Creations); 22px in the menu bar panel ("Now Showing").
- **Letter Board** (800, 14px, 1, uppercase, 0.12em; 12px in the menu bar panel): letter-board labels only.
- **Title** (SF Pro 650, 13px): section headings in content ("Starter Pack"); Settings group headings at 12px.
- **Body** (SF Pro 400, 13px, 1.4): all UI text, rows, buttons, fields.
- **Label** (SF Pro 400, 12px): segmented controls, small buttons, counts, live status.
- **Caption** (SF Pro 400, 11.5px): thumbnail metadata, Settings row explanations, chips, Settings tab labels.

In SwiftUI, the SF Pro roles map to `.system(size:weight:)` at these sizes (13pt is macOS `.body`); display roles use `.custom("BigShouldersDisplay-ExtraBold", size:)` with `.textCase(.uppercase)` and `.tracking`.

### Named Rules
**The Marquee Rule.** Big Shoulders Display appears only on letter boards and on screen, sheet or wallpaper titles. Never on buttons, body, rows, labels or numbers.

**The One Size Inspector Rule.** Inspector details (the Showing / Layers / Size / By list, and the "Show on" heading above the screen picker) use one size, 12px, ranked only by weight and case: terms are 700 uppercase tracked 0.06em in screen-2, values are 400 in screen.

## Layout

A three-column Mac window: sidebar (224px), content, inspector (330px). The toolbar is 52px high with the display title at its leading edge, then status, the type filter, search (200px) and an icon button. Content sits on a 20px gutter. The display strip runs across the top of the Library content (about 226px tall); the thumbnail grid below it is four columns of 16:10 thumbnails with 16px column and 18px row gaps.

Sheets and Settings use 28px horizontal padding and 20–22px vertical rhythm between groups. Settings rows are at least 46px with 9px by 16px padding, grouped in rounded containers separated by hairlines. Spacing steps are 4, 6, 8, 10, 14, 18, 20 and 28px; 8 and 10 carry most control gaps, 14 separates inspector blocks.

Welcome and the wizard show one decision at a time: one display-hero question, one set of choices, one primary action.

## Elevation & Depth

Depth is tonal first (house, house-2, house-3, house-4 step up in lightness) and edged by 1px inset hairlines at 8–10% screen-white. Real shadows exist only where macOS itself would cast one: windows, sheets, the menu bar panel, the selected segment and switch knobs. All of them are neutral black.

### Shadow Vocabulary
- **Window** (`0 34px 90px rgba(0,0,0,.6), 0 8px 24px rgba(0,0,0,.35), inset 0 0 0 1px rgba(255,255,255,.08)`): app windows (the native window shadow in the app).
- **Sheet / Panel** (`0 30px 80px rgba(0,0,0,.65), inset 0 0 0 1px rgba(255,255,255,.09)`): sheets; the menu bar panel uses `0 24px 60px rgba(0,0,0,.6)` with a 30px backdrop blur.
- **Control lift** (`0 1px 2px rgba(0,0,0,.4)`): selected segment, switch knob, and under the primary button with a `0 1px 0 rgba(255,255,255,.35) inset` top highlight.
- **Letter-board mount** (`0 0 0 3px #0b0908, 0 3px 8px rgba(0,0,0,.5)`): the board's black frame and drop.
- **Screen light spill** (the panel's own wallpaper, blurred 26px at 50% opacity, extending 18% past each side and starting 70% down the panel): the only coloured light in the system.

### Named Rules
**The No Glow Rule.** Shadows are neutral black. No tungsten, green or red glows. The single exception is the screen light spill, which is the wallpaper's own colour, never a brand colour. Selection rings (2px tungsten plus a 3px ring at 20% tungsten) and the live dot's 3px ring are hard-edged rings, not blurs.

## Shapes

Gently rounded, Mac-native corners that grow with the container: on-image tags 5px, screen panels and segments 6px, controls 8px, large buttons and thumbnails 10px, Settings groups and inspector previews 12px, the display strip and menu bar panel 14px, windows and sheets 16px, chips 11px (pill). The letter board is the one square-cornered object: a hard rectangle with a thin tungsten border, because it is a physical sign. Screen panels keep their display's true aspect ratio, including portrait.

## Components

### Buttons
Native push buttons with the booth palette; quiet by default, one lit.
- **Shape:** 8px corners, 30px tall (38px and 10px corners for the large size).
- **Primary:** tungsten fill, tungsten-ink text at weight 650, one per screen.
- **Secondary:** house-3 with a 1px line inset; icon-only variant is 30px square.
- **Ghost:** transparent with a 1px line-2 inset (sort and filter menus, 26px tall at 12px).
- **Selected / pressed toggle:** tungsten-tint background, tungsten text, 1px tungsten inset at about 45%.
- **Danger:** secondary styling with stop-coloured text.
- **Focus:** 2px tungsten outline offset 2px (the system focus ring once the app tint is tungsten).

### Chips
- **Style:** 22px pills, screen-white at 8% alpha, screen-2 caption text. Descriptive only (type, tags); not interactive filters.

### Cards / Containers
- **Thumbnails:** 16:10, 10px corners, 1px inset white hairline; selected adds a 2px tungsten outline offset 3px. On-image badges sit on booth-black at 85%.
- **Settings groups:** house-2, 12px corners, hairline inset, rows divided by 8% hairlines; a 12px 650 group heading sits above.
- **Choice cards** (wizard looks, New Wallpaper options): house-2, 12–14px corners; chosen card adds a 2px tungsten inset ring over a faint tungsten wash.

### Inputs / Fields
- **Search field:** 30px, 8px corners, screen-white at 7% with a line inset; placeholder in screen-3. In the app, the native `.searchable` toolbar field.
- **Segmented control:** native; the selected segment is house-4 with control lift.
- **Switch:** native; on state takes the tungsten tint.
- **Slider (Studio):** 4px track at 16% screen-white, tungsten fill, white knob.

### Navigation
- **Sidebar:** seat-red gradient, native source list. Section headers (Play, Create, Discover) at 11px 600 in screen at 62%. Items 13px with 16px stroke icons; selected item takes the tungsten tint with tungsten text and icon; counts are tabular 11px.
- **Settings:** native tabbed Settings window (General, Performance, Displays, Library); selected tab takes the tungsten tint.
- **Menu bar panel:** `MenuBarExtra` window style; display-title "Now Showing", a compact strip, recent thumbnails, then native menu rows with shortcuts.

### Status: Live and Intermission
- **Live:** a 7px exit-green dot with a 3px ring, label in live green at 12px ("Live on 2 of 3 screens").
- **Intermission:** the one word for any paused state, always followed by its reason: "Intermission · On battery", "Intermission: on battery.", a panel tagged "Covered". A paused screen's board goes dim and its panel desaturates (grayscale 70%, brightness 45%).

### Display Strip (signature)
Each of the user's screens drawn at its true aspect and relative size, side by side on a dark radial floor (14px corners, hairline inset). Above each panel hangs a letter board ("1 · NEON RAIN", the number in screen-white and the wallpaper name in tungsten); below it the wallpaper's own light spills onto the floor. A dim board (screen-white border at 20%, name in screen-2) marks a paused or previewing screen. A selected panel takes the tungsten selection ring. It appears in the Library header, the menu bar panel, Settings › Displays (as the screen picker) and the Library hover preview, and nowhere it would be decoration.

## Do's and Don'ts

### Do:
- **Do** fill exactly one control per screen with tungsten (#f2b544) and tint every selected state at 14–16% tungsten with tungsten text.
- **Do** use native SwiftUI controls, sidebar, toolbar, sheets and Settings tabs, and carry the brand through the root tint, type, letter boards and the display strip.
- **Do** bundle Big Shoulders Display (OFL) in the app and keep it on letter boards and titles only.
- **Do** say "Intermission" for every paused state and always pair it with its reason.
- **Do** keep inspector details at one size, ranked by weight and case.
- **Do** draw every screen at its true aspect, portrait included.

### Don't:
- **Don't** put a coloured glow on anything; shadows are neutral black, and the screen light spill is the only coloured light.
- **Don't** use Big Shoulders Display for buttons, body copy, rows or numbers.
- **Don't** use #e0533d for destructive text; it fails AA on house-3. Use stop (#ef6a52).
- **Don't** label a paused screen or status "Paused", "Stopped" or "Sleeping", or show Intermission without its reason.
- **Don't** design a light appearance by inverting tokens; it is undecided and needs its own pass.
- **Don't** let the seat red leave the sidebar.
