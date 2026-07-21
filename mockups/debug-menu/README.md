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

  Captures are the **device screen only** (390×844): `screenshot.html` strips the page chrome (side nav, body padding, shadow) so the PNG is exactly the phone — that's all Brian wants from a screenshot. It also handles the home gotcha (calling `deepLink('home')` on a stack already at `['home']` would push a stray `‹ DEBUG` back link, so `home` skips the eval).

## Code structure

- Three screen archetypes: **menu** (root `home`), **catalog** (`cat_*` — a data type's list of authored items), **editor** (`ed_*` — one item from a catalog). Kept distinct from **pickers** (`pick_*` and the `menu_*` kind menus): those are the transient selection UIs opened *inside* an editor to choose a value or kind — never catalogs. Catalogs/editors are hand-built per type (mostly unique), not a shared template.
- Editors follow a fixed section order: **Identity** (ID, Filename) → **Information** (Name, Description) → **Display** (Color / Texture / Hidden) → a type-specific **Configuration**, then any sub-sections (Modifiers / Effects / Transforms, Costs, Rules). Lightweight `section()` headers over grouped `list()`s.
- Every row (`.cell`) and tile carries the left-edge edit bar: translucent black normally, yellow (`.edited`) when its nested content has unsaved edits. Group boxes (`.list`, `.tile`) use the tile silhouette — three square corners, top-right slope — so the bar reads as one straight line.
- `SCREENS` — registry of screen factories returning `{ title, action?, rows }`. Navigation is a plain id stack (`go`/`pop`); back returns to the immediate previous screen. `deepLink(id)` rebuilds the full parent chain via `PARENTS` so a deep-linked screen's back label is correct.
- Left **side nav** (`.sidenav`, `NAV`) is a viewer aid outside the phone — jumps to any catalog, mirrors the home sections, highlights the active one; `>_ DEBUG` returns home. Not part of the shipped phone UI.
- Row/one-liner builders: `list`, `grid`, `scroller`, `chips`, `flow`, `divider`, `nav`, `tile`, `statusTile` (symbol + tinted color), `scalar` (slider/toggle/dropdown/color/text — sliders carry a number box; min/max can toggle to "None"/unbounded), `seg`, `stepper`, `ref`, `variant` (polymorphic kind, optional subtitle), `descField`, `textureField`, `clearBtn`, `pickRow`/`pickTile` (pickTile takes an emoji), `optRow`/`optNav` (described picker options), `kindTile`, `newRow` (a picker's ＋ New footer row), `addBtn` (create-mode submit: adds to the catalog and, when reached through a picker, selects the new instance and returns to the caller).
- `MENUS` generates the kind pickers; `MENU_DESCS` + `KIND_DESCS` add per-option descriptions shown both in the picker and on the kind's page. `menu_action` (effect actions) is hand-built. `genericKind()` renders an unmocked kind as its description + a Clear button.
- Names reflect the **planned** design, not all of current `source/data/`: resources are Tactics / Security / Science / Engineering / Antimatter / Alloy; stats are ship systems (Health, Armor, Shields, Weapons, Engines, Computers, Sensors, Energy); tiles pair 1:1 with resources plus an Attack tile. Real values are used where they exist (tile colors, module names, selection rules, `Modifier.Operation` = Add/Multiply).

## Design decisions

These are settled — apply them, don't relitigate or re-explain them.


- **Home order is a stated requirement:** settings hero band on top, then sections **Primitives, Building Blocks, Content, Config**. Primitives = the world's fixed vocabulary (Resources, Tiles, Stats, Statuses). Building Blocks = reusable effect-system pieces referenced when authoring other content (Adjustments, Effects, Transforms) — each a real instance catalog, **not** a kind picker. Content = assembled entities (Abilities, Starships, Modules, Loadouts). Config = per-mode tuning (Rules, Rulesets, Match Configs). Never reorder sections Brian has specified.
- **Catalog ≠ picker:** a catalog browses authored instances (each opens an editor); a picker is an in-editor selection of a value or kind. Never point a catalog tile at a kind picker.
- **Editor section order** is settled: Identity → Information → Display → Configuration. `Hidden` lives under Display, never Configuration.
- **A Modifier is a picked reusable Adjustment + Amount** — the Stat/Applies-To/Operation triple lives in the Adjustment (a Building Block), not inline in the modifier.
- **Module Grids are "Loadouts."** A Starship picks its Loadout, and a Loadout picks its Modules — the same composable reference system as abilities ↔ effects.
- **Starship/Loadout instances are "Player Default" / "Opponent Default"** — the default per seat; ships themselves aren't tied to who controls them (never name a ship "Computer").
- **Building Blocks are referenced, never built inline — everything is composable.** Wherever content uses an Adjustment/Effect/Transform, it's picked from that type's catalog via a picker. Every picker ends with a **＋ New** row that opens the type's editor in create mode; **Add** inserts the instance into the catalog, selects it, and pops back to wherever the picker was opened. A catalog's own `+` opens the same create-mode editor.
- **Own design language, not iOS** (game ships on iOS/Android/Steam/PS5): cyan accent (`--accent`), uppercase tracked titles, chamfered top-right tile corners, squared-off toggles/slider thumbs, monospace numerals, `>_` prompt glyph (white) before DEBUG.
- **Flat over cards:** no borders-and-cards (eats padding); grouped lists with hairline separators. Full-bleed bands — a card inset from the screen edge doubles the edge padding.
- **Icons:** bare emoji only, never colored rounded-square icon chips — **except statuses**, whose symbol sits on a chip tinted with the status's own color (that color is meaningful). Visual catalogs (Tiles, Abilities, Starships, Modules, Module Grids, Statuses) use emoji/color tiles; abstract building-block catalogs stay lists.
- **No status bar content** — the space is reserved but empty (it's a game, not the OS shell).
- **Edited-state indicator:** every row and tile has a 5px left-edge bar — `rgba(0,0,0,.2)` normally, yellow `#dcb63f` when its nested content (all the way down) has unsaved edits vs. what was distributed. No rounded boxes anywhere (three corners, one slope).
- **Controls:** sliders pair with an editable number box (slide or type for precision); a stat's Minimum/Maximum can toggle to **None** (unbounded). Sub-editors that live inside their parent (a Modifier's Adjustment + Amount, a Cost's Resource + Amount) end with a small **Clear** button in its own footer section (close-button style, not full width); catalog editors don't.
- **Horizontal scrollers** for the home catalog sections — tiles bleed off the right edge so the next one peeks.
- **Naming:** plain, spelled-out words, no abbreviations ("Maximum Stacks" not "Cap"); "Rules" not "Active Rules"; "Time Scale" not "Animation Speed" (cf. Godot `Engine.time_scale`). The status Buff/Debuff field is **Type**. Catalogs show display Names; the `Filename` (unique id) shows in the editor's Identity section. Counts sit top-right on tiles.
- **No plan/milestone labels or commentary text inside the artifact** (no "M3", no "NEW", no legends or instructional text). The design is only the design.
- **Match editing happens in the match itself**, not this menu — a Match page was built and deliberately dropped.

## Tried and rejected

- iOS Settings look (colored icon chips, pill toggles, big radii) — too iOS.
- Section-of-pages Game Settings ("General"/"Defaults" subsections) — flattened into the hero band.
- Three top tabs (Game / Match / Data) — collapsed back to a single page.
- Match tab with inline board render, player/opponent starship pickers, and inline rules — cut with the Match page.
- Milestone badges, explanatory notes, and a side legend in the artifact — stripped on feedback.

## Mocked vs. not

Fully mocked with editors:

- **Statuses** — Buffs/Debuffs symbol grid; editor has Type / Maximum Stacks / Stacking / Decay plus Modifiers / Effects / Transforms. Shield is set up as the worked example (no modifier; damage soak is the picked **Shield Absorb** transform).
- **Abilities** — visual grid; editor picks **Effects** from the catalog (chips → picker) and drills ability → cost. The effect editor itself carries the target/action flow tiles.
- **Stats** — ship systems, with a Hidden (not shown to players) group and Minimum/Maximum "None".
- **Resources** — 2×2 ability resources + a divider + Antimatter (special) / Alloy (currency); color lives on the resource editor.
- **Tiles** — color grid; a 2D texture field on the tile editor.
- **Rulesets** — editor + Add Rule kind grid.
- **Building Blocks** — Adjustments (reusable Stat + Applies To + Operation, e.g. `+Armor`), Effects (Attack Opponent, Restore Health, Apply Shield, Apply Dodge, Apply Target Lock — one per shipped ability) and Transforms (Shield Absorb, Armor Plating, Lock Amplify). Each is an instance catalog + editor + picker, with a create-mode editor reached from the catalog's `+` or any picker's ＋ New.
- **All pickers and kind menus** — Stacking / Decay / Transform / Action options carry descriptions.

Visual placeholder catalogs (icon grids, no item editor yet): Starships, Modules, Module Grids. List placeholder: Match Configs.
