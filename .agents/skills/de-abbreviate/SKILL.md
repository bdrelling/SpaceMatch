---
name: de-abbreviate
description: Find chopped-word shorthand in GDScript identifiers (pos, src, rect, obj, cmd, cndtn…) and spell them out as full words. Leaves real words, acronyms, math/unit notation, and engine API names alone.
argument-hint: "[subdir] (optional)"
allowed-tools: Bash, Read, Grep, Glob, Edit, Agent
---

# de-abbreviate

Rename identifiers that are **words with letters chopped out** to the full word.
GDScript only (`.gd`). Optional arg scopes to a subdir (e.g. `systems/camera/`); with no
arg, scan the whole project root (the dir holding `project.godot`) — never ask for one.

## The decision rule (the whole point)

For each declared identifier, look at each `snake_case` segment. **Spell it out only if it
is a real word with letters removed.** Keep it as-is if it is any of:

- **A real word**, even an informal/clipped one you'd say aloud: `config`, `stats`, `info`,
  `sync`, `app`, `demo`, `auto`. These are words, not shorthand — leave them.
- **An acronym / initialism**: `id`, `uid`, `aabb`, `rgb`/`rgba`, `hsv`, `ui`, `hud`, `npc`,
  `ai`, `fps`, `url`, `uri`, `json`, `csv`, `db`, `gpu`, `cpu`, `dof`, `hdr`, `lod`, `fov`.
- **Standard math / loop / coordinate notation**: `i` `j` `k`, `x` `y` `z`, `u` `v` `w`, `t`,
  `n`, `sin` `cos` `tan`, `abs`, `min` `max`, `sqrt`, `delta`, `yaw` `pitch` `roll`.
- **A standard unit symbol**: `px`, `ms`, `hz`, `kg`.
- **An engine / library API name you don't own**: `Rect2`, `ColorRect`, `deg_to_rad`,
  `get_global_rect`, `distance_squared_to`, `Cond_Always`, `FORMAT_RF`. (You can't rename
  these anyway, and your local var should match the type/method it mirrors only when that
  name is itself spelled out.)

Everything else that is a truncated word gets spelled out. Common offenders:
`pos`→position, `src`→source, `dir`→directory *or* direction (read the type), `coord`→coordinate,
`obj`→object, `cmd`→command, `btn`→button, `idx`→index, `img`→image, `vp`→viewport,
`clr`→color, `rect`→rectangle, `dim`→dimension, `mat`→material, `tex`→texture, `ref`→reference,
`attr`→attribute, `xform`→transform, `prev`→previous, `dest`→destination, `dist`→distance,
`sq`→squared, `num`→number, `cnt`→count, `len`→length, `val`→value, `tmp`/`temp`→temporary,
`msg`→message, `vel`→velocity, `rot`→rotation/rotated, `deg`→degrees, `rad`→radians,
`accel`→acceleration, `decel`→deceleration, `calc`→calculate, `elem`→element, `desc`→description,
`reg`→registry/register (read context), `ctx`→context, `anim`→animation, `diff`→difference,
`verts`→vertices, `cndtn`→condition. The list isn't exhaustive — apply the rule, not the list.

When unsure whether a segment is "a real word" or "a chopped word": say it out loud. If it's
pronounceable as the word people actually use (`config`), keep it. If it's letters standing in
for a word you'd never speak that way (`cndtn`, `vp`, `attr`), spell it out.

## Scope

- Scan **declared** identifiers: `var`, `const`, `@export`/`@onready var`, function names,
  parameters, `for` loop vars, `signal`, `enum` values.
- **Skip** `addons/` (third-party), `deprecated/`, and vendored demo code copied from an
  addon (e.g. a Terrain3D example project — tell by foreign style like `MOVE_SPEED` exports).
- **Do not** rename scene node names or engine node types (`ColorRect`, `TextureRect`).
  This skill is about code identifiers, not the scene tree.

## Steps

1. **Scan.** Find the project root: `find . -name project.godot -not -path '*/.godot/*'`.
   Walk `.gd` files under it (or `<root>/<subdir>`), excluding the skip list. Grep declaration
   sites for chopped-word segments — bare-word and `_segment_` boundaries both, since `target_pos`
   hides `pos`. For a large tree, hand the scan to an `Explore` agent and keep only the verdicts.
   Build a deduplicated list: identifier · file · kind (local/param/member/func/const/signal).
2. **Decide.** Apply the decision rule to each. Drop the keeps. Pick the full word from context
   (read the file — `dir` as `DirAccess` is directory, as a vector is direction).
3. **Rename.** For each kept rename, update the declaration **and every in-scope usage**:
   - Local / param / loop var / private (`_name`) member or func → contained to the file; rename in place.
   - Public member / method / signal used cross-file → grep the project and update all callers.
   - An `@export` whose name appears in a `.tscn`/`.tres` → update those serialized files too,
     or skip it and say why (renaming a serialized property without updating the resource breaks it).
   - Also fix paired single-letter shorthand exposed by the rename (e.g. `prev_c`/`last_c`
     where `c` = center → `previous_center`/`last_center`).
4. **Style rule.** Ensure `armory/docs/languages/gdscript/style.md` states the no-shorthand
   rule with the keep-list categories above. Add it if missing; don't duplicate.
5. **Verify.** Re-run the scan → zero chopped-word identifiers outside the skip list. If any
   files were created/renamed run `scripts/godot-import.sh`, then `scripts/godot-check.sh`
   (must parse clean), then the `test-runner` agent on the touched suites. Never tell the user
   to re-import themselves.

## Guardrails

- Don't expand a genuine word because it's short. `config`/`stats`/`info`/`sync` stay.
- Don't touch engine/API names or `.godot/` (regenerated).
- A clean scan with nothing to rename is a valid result — say so and stop.
