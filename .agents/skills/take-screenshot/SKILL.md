---
name: take-screenshot
description: Screenshot the running game — launches a scene, renders, saves PNGs, returns paths. Triggers "take a screenshot", "screenshot the game", "show me what it looks like".
argument-hint: optional scene path
model: haiku
effort: low
---

# take-screenshot

Run the game, capture screenshots, return the paths so you can `Read` the PNGs.

## Usage

```bash
./scripts/playtest.sh
```

Screenshots land in `.playtests/<ISO8601-timestamp>/` (e.g. `.playtests/2026-06-16T17-13-33/`). `Read` any PNG to see the rendered frame.

Defaults: interval=1s, duration=1s, delay=0s.

## Output layout — fixed, do not improvise

- **Repo-root `.playtests/`, always.** The engine resolves the path to the repo root; runs land time-sorted under it and old runs auto-prune (last 9 kept).
- **ISO 8601 timestamp** (`:` → `-`, since colons are illegal in paths). Lexical sort = chronological order — never rename or reformat it.
- **Label is optional, your call.** Add `--screenshot-label=<kebab-label>` whenever it helps you find a run later; it's a **suffix after the timestamp** (`.playtests/2026-06-16T17-13-33-arcade-ipad/`), never a replacement or a parent folder.

### Hard rules

- **Always run through `scripts/playtest.sh`.** Never `godot ... -s some_shot.gd` or any ad-hoc capture — relative paths from `source/` drift into `source/.playtests/` and fragment everything.
- **Never pass `--screenshot-dir`.** That flag is for the *user* to redirect output by hand; the agent leaves it alone so captures always land in the canonical repo-root `.playtests/`. To name a run, use `--screenshot-label`.

## Args

Engine args go before `--`, screenshot args go after:

| Arg | Purpose | Default |
|-----|---------|---------|
| `--screenshot-interval` | Seconds between captures | `1` |
| `--screenshot-duration` | Seconds to capture, then quit | `1` |
| `--screenshot-delay` | Seconds to wait before first capture | `0` |
| `--screenshot-label` | Kebab-case suffix on the run dir | none |

Do **not** use `--screenshot-dir` (user-only override).

## Examples

One screenshot (default):
```bash
./scripts/playtest.sh
```

Five screenshots over 5 seconds:
```bash
./scripts/playtest.sh -- --screenshot-duration=5
```

Screenshot a specific scene:
```bash
./scripts/playtest.sh res://screens/demo/demo.tscn
```

## After capture

1. Find the latest run: `ls .playtests/ | sort | tail -1`
2. `Read` the PNG files to see what rendered.
