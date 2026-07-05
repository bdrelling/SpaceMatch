# Debug Menu Mockup

Click-through mockup of the in-game debug editor (the future state of `source/screens/debug_screen/`, per the Debug → In-Game Content Toolkit plan). One self-contained HTML file — inline CSS/JS, no dependencies, no build.

## Viewing & rendering

Reading this README IS the context — you don't need to render anything to understand the design. Render only when a human wants to *look* at a screen.

- Open `index.html` in any browser. Click rows/tiles to navigate; the back link pops the stack.
- PNG renders (Brian sometimes can't view HTML directly) — use the repo helper, which resolves whatever headless browser exists and exits 3 (not a crash) when there's none, e.g. in a cloud container:

  ```sh
  mockups/render.sh debug-menu             # home screen
  mockups/render.sh debug-menu ed_status   # any SCREENS id; add a 3rd arg to scroll (px)
  ```

  Don't hand-roll a `chromium`/`chrome-headless-shell` invocation — `render.sh` is the supported path and dodges the "no chrome binary" trap. Under the hood it drives `screenshot.html`, which wraps `index.html` in an iframe and honors `?screen=<id>` / `?scroll=<px>`. Screen ids come from the `SCREENS` registry.

  **Home gotcha (handled by the helper):** routing `home` through `screenshot.html` calls `go('home')`, which pushes onto a stack already at `['home']` → a stray `‹ DEBUG` back link at the top. `render.sh` with no screen (or `home`) renders `index.html` directly instead, so the capture is the true home.

## Code structure

- `SCREENS` — registry of screen factories; each returns `{ title, action?, rows }`. Navigation is a plain id stack (`go`/`pop`).
- Row/one-liner builders: `list`, `grid`, `scroller`, `chips`, `flow`, `nav`, `tile`, `scalar` (slider/toggle/dropdown/color/text), `seg`, `stepper`, `ref` (catalog reference), `variant` (polymorphic kind), `pickRow`/`pickTile`, `kindTile`.
- `MENUS` generates the kind-picker screens (Target/Condition/Amount/Stacking/Decay/Transform); `menu_action` is hand-built (Match + Core groups).
- Unmocked kind ids fall through to `genericKind()` — a placeholder editor.
- Names/counts mirror real project data (statuses, abilities, stats, resources, rulesets, rule kinds, effect-system subclass menus).

## Design decisions

These are settled — apply them, don't relitigate or re-explain them.


- **Home order is a stated requirement:** settings hero band on top, then sections **Primitives, Content, Config** — grouped by how often each content type changes (Primitives = the world's fixed vocabulary: Stats, Resources, Tiles, Statuses; Content = assembled from primitives: Abilities, Starships, Modules, Module Grids; Config = per-mode tuning: Rules, Rulesets, Match Configs). Never reorder sections Brian has specified.
- **Own design language, not iOS** (game ships on iOS/Android/Steam/PS5): cyan accent (`--accent`), uppercase tracked titles, chamfered top-right tile corners, squared-off toggles/slider thumbs, monospace numerals, `>_` prompt glyph (white) before DEBUG.
- **Flat over cards:** no borders-and-cards (eats padding); grouped lists with hairline separators. Full-bleed bands — a card inset from the screen edge doubles the edge padding.
- **Icons:** bare emoji only. Never colored rounded-square icon chips (forces finding a color for everything).
- **No status bar content** — the space is reserved but empty (it's a game, not the OS shell).
- **Edited-state indicator:** every tile has a 5px left-edge overlay bar — `rgba(0,0,0,.2)` normally, yellow `#dcb63f` when the tile's nested content (all the way down) has unsaved edits vs. what was distributed. This replaced the cyan accent bars on section labels (text-only now).
- **Horizontal scrollers** for the catalog sections — tiles bleed off the right edge so the next one peeks.
- **Naming:** plain names — "Rules" not "Active Rules", "Resources" not "Ability Resources"; "Time Scale" not "Animation Speed" (it's the time factor, cf. Godot `Engine.time_scale`). Counts sit top-right on tiles; unmocked catalogs show `0`.
- **No plan/milestone labels or commentary text inside the artifact** (no "M3", no "NEW", no legends or instructional text). The design is only the design.
- **Match editing happens in the match itself**, not this menu — a Match page was built and deliberately dropped.

## Tried and rejected

- iOS Settings look (colored icon chips, pill toggles, big radii) — too iOS.
- Section-of-pages Game Settings ("General"/"Defaults" subsections) — flattened into the hero band.
- Three top tabs (Game / Match / Data) — collapsed back to a single page.
- Match tab with inline board render, player/opponent starship pickers, and inline rules — cut with the Match page.
- Milestone badges, explanatory notes, and a side legend in the artifact — stripped on feedback.

## Mocked vs. not

Mocked: Statuses (+ status editor with seg/stepper/chips), Abilities (+ ability→effect→action drill with flow tiles), Stats, Resources, Tiles (color swatches), Rulesets (+ ruleset editor, Add Rule kind grid), pickers, all kind menus. Placeholder catalogs (real item names listed, no item editor yet): Starships, Modules, Module Grids, Match Configs — reachable from the tiles and the side nav.
