# Handoff: Split `Tile` out of `AbilityResource`

## Goal

Today a board tile *is* a resource: `StarshipResource extends AbilityResource` carries the tile's identity (`id` = tile kind) and art (`label`, `color`, `texture`). Spawning and rewards both key off `resource.id`. We want the board piece to be its own thing — a `Tile` — that does **not** know about AbilityResources. The tile→reward link moves into an explicit rule.

This is the enabling step so that **later** (not in this task) Damage, Warp, and Currency can stop being modelled as AbilityResources — once tiles don't depend on resources, those three can reward something other than an AbilityResource without touching the tile or spawn layers.

Scope of *this* task: `Tile` type, `/data/tiles/`, `TileCatalog`, rename `SpawnResourceRule` → `TileSpawnRule`, add `TileMatchRule` (tile → AbilityResource reward, one per tile), and a default `DefaultTileMatchRuleset`. Keep behavior identical to today.

## Current state (the coupling to undo)

- `source/entities/starship/starship_resource.gd` — `StarshipResource extends AbilityResource` with `id: int` (the tile kind; -1 = not a tile), `label`, `color`, `texture`. **The tile's identity + art live here.**
- The grid stores an **int tile kind** per cell (`_TileState.kind`, see `match_game.gd`). `kind == StarshipResource.id` everywhere. This int is the single identity threaded through the match: `ON_CLEAR` `counts`/`centers` dicts keyed by kind, capacity `resource_maximums` indexed by kind, `Stats.for_tile(kind)`, `_split_board_resources()` routing, match popups.
- `source/resources/catalog/ability_resource_catalog.gd` — `tile_kinds()` and `for_tile(kind)` resolve a `StarshipResource` by `id`. `MatchTile.texture_of/color_of/name_of(kind)` (`source/systems/match/match_tile.gd`) read art off that resource.
- `source/systems/match/rules/spawn_resource_rule.gd` — `SpawnResourceRule` (resource + weight); `combine_key()` = `resource.id`; `spawn_contribution()` = `{resource.id: weight}`.
- Reward-on-match rules (`ON_CLEAR`): `resource_grant_rule.gd` (banks the 4 stat resources, reading `counts[resource.id]`), `scrap_grant_rule.gd`, `warp_rule.gd`, `damage_rule.gd`. Each is keyed to a `StarshipResource` whose `.id` is the tile kind.
- Default pool: a nested **"Spawn"** `Ruleset` of 7 `SpawnResourceRule`s inside `source/data/rulesets/default.tres` and `alternate.tres`.
- Catalogs autoload: `source/autoloads/catalogs.gd` loads each `data/catalogs/<x>_catalog_all.tres` (auto-built by the `catalog_generator` plugin), falling back to a code default.

## Build this

1. **`Tile` type** — `source/systems/match/tile.gd` (`class_name Tile extends Resource`). Fields: `kind: int` (the grid's int identity; -1 = none), `label: String`, `color: Color`, `texture: Texture2D`. This is data only; the renderer stays `MatchTile` (the `GridTile` Node2D). No link to any AbilityResource.

2. **`/data/tiles/`** — one `Tile` `.tres` per board piece. Migrate the 7 current ones (combat, propulsion, science, defense, scrap, warp, damage), copying `id→kind`, `label`, `color`, `texture` from the matching `data/ability_resources/*.tres`. Keep the same `kind` ints (0–6) so nothing else shifts.

3. **`TileCatalog`** — `source/resources/catalog/tile_catalog.gd`, modelled on `AbilityResourceCatalog`: directory-backed over `res://data/tiles`, with `tile_kinds()` and `for_kind(kind) -> Tile`. Add `var tiles: TileCatalog` to the Catalogs autoload (loads `data/catalogs/tile_catalog_all.tres`, falls back to `TileCatalog.default`). The `catalog_generator` plugin should produce the `_all.tres` — verify it picks up the new folder.

4. **Repoint the renderer + kind universe to tiles** — `MatchTile._resource_for/texture_of/color_of/name_of/names()/bake_collision_outlines()` read from `TileCatalog`/`Tile` instead of the resource catalog. `MatchGame._tile_kinds()` → `Catalogs.tiles.tile_kinds()`. Remove `AbilityResourceCatalog.tile_kinds()/for_tile()` once nothing uses them.

5. **`SpawnResourceRule` → `TileSpawnRule`** — `source/systems/match/rules/tile_spawn_rule.gd`. Field becomes `tile: Tile` + `weight`. `combine_key()` = `tile.kind`; `spawn_contribution()` = `{tile.kind: weight}`; `stacked()` sums weight (unchanged). Rename the test `tests/test_spawn_resource_rule.gd` → `test_tile_spawn_rule.gd` and update it.

6. **`TileMatchRule`** — `source/systems/match/rules/tile_match_rule.gd` (`extends Rule`, phase `ON_CLEAR`). Fields: `tile: Tile` + `reward: AbilityResource`. On apply: `count = counts[tile.kind]`; bank `reward_for(count) + stat bonus` of the `reward` resource into the mover's starship (same math as `ResourceGrantRule`). `combine_key()` = `tile.kind` (one reward rule per tile; override/stack like every rule). **One per rewarding tile** — decompose the 4-in-one `ResourceGrantRule` into 4 `TileMatchRule`s (one per stat tile).

7. **`DefaultTileMatchRuleset`** — the basic setup as a named nested `Ruleset` (`ruleset_name = "Tiles"` or similar): the 7 `TileSpawnRule`s + the stat-tile `TileMatchRule`s. Replace the current nested "Spawn" set in `default.tres`/`alternate.tres` with it. (Nested rulesets, `flattened()`/`resolved()`, and `combine_mode` already exist — see `addons/grid_system/rules/ruleset.gd` + `rule.gd`.) A standalone `data/rulesets/...tres` is fine too if you want it reusable across modes; nested sub-resource matches the current shape.

## Keep special for now (the later-decoupling targets)

Damage, Warp, and Currency (scrap) are **still AbilityResources** after this task. Leave `damage_rule.gd`, `warp_rule.gd`, `scrap_grant_rule.gd` doing their special work (deal damage / charge the meter / pay the wallet) — they are not "reward an AbilityResource into the pool," so they don't fold into `TileMatchRule`. Re-point them so they get their **kind from a `Tile`** (not `resource.id`); they can still carry the AbilityResource they consume/produce. These three are exactly what a follow-up will decouple from AbilityResource — don't do it here.

## Gotchas

- **The int kind is the linchpin — keep it.** The grid stores an int kind; `counts`/`centers`/`resource_maximums`/`Stats.for_tile(kind)`/`_split_board_resources()` all key off it. Don't make the grid hold `Tile` objects. `Tile.kind` simply *becomes* the owner of that int (today `StarshipResource.id` owns it). Keep kinds 0–6 unchanged to avoid touching capacity arrays and stat mappings.
- **Starship resource pools key off `resource.id` today** (`encounter_starship_state.gd`: `resource_maximums[resource.id]`, `_RESOURCE_DEFINITIONS` per kind; `add_resource` clamps by id). Once tile fields leave `StarshipResource`, decide the pool's key: keep an `id` on the resource purely as a pool index, or re-key by resource `name`. Whichever — `TileMatchRule` is the only thing that maps a tile kind to the reward resource; the pool itself should no longer assume `kind == resource.id`.
- **`StarshipResource` after the move**: with `id/label/color/texture` gone it may be near-empty (just an `AbilityResource` with `name`). Don't delete it blindly — it's referenced by `ability_cost.gd`, `encounter_starship_state.gd`, abilities, etc. Strip the tile fields; keep the class (or collapse to `AbilityResource`) only if every reference still compiles.
- **Class names are free**: no existing `class_name Tile / TileCatalog / TileSpawnRule / TileMatchRule / DefaultTileMatchRuleset` (checked). `GridTile` (matchbox) is the render base and stays. Re-check before adding (grid_system owns several `class_name`s).
- **Symlinks**: the `Rule`/`Ruleset` base types live in the matchbox addon (`matchbox/source/addons/grid_system/rules/`); search symlinked trees with `rg --follow` / `find -L`, not Glob.
- **`.tres` references move** from `data/ability_resources/*.tres` to `data/tiles/*.tres` in the spawn/match rules and the default ruleset. Get the new `Tile` `.tres` uids and reference them by `type="Resource"` with uid+path (see how `default.tres` references the ability resources now).
- **Don't break the `RuleCatalog` mode list**: it's directory-backed over `data/rulesets/`. If you author `DefaultTileMatchRuleset` as its own file there, it'll show up as a playable mode — put it in a subfolder or keep it a nested sub-resource.
- **Run `scripts/godot-import.sh` before the parse check** (new files + new `data/tiles/` dir), then verify a headless boot — parse-check won't catch a `.tres` pointing at a moved/missing path.

## Done =

- Parse-check clean; the match/rules test suites pass (spawn tests updated to tiles; new `TileMatchRule` coverage added).
- Board spawns and rewards **exactly as before** (4 stat tiles at weight 20, scrap/damage 10, warp 2; matches still bank/deal/charge the same amounts).
- A new tile can be added by dropping a `Tile` into `/data/tiles/` and a `TileSpawnRule` weight into a ruleset — with **no** AbilityResource needed for it to render and drop.
