---
name: review-project-structure
description: Audit the Godot project tree against the project-structure.md spec, resolve discrepancies interactively, then propose doc clarifications for repeated violations.
argument-hint: "[subdir] (optional)"
allowed-tools: Bash, Read, Glob, Grep, Edit, Write, Agent
---

# review-project-structure

Audits the Godot project tree against `armory/docs/godot/project-structure.md`, reports where reality and the spec disagree, resolves each discrepancy with the user, then — only for patterns violated *repeatedly* — proposes tightening the doc so it doesn't recur.

Optional arg: a subdir to scope the review (e.g. `nodes/`, `systems/camera/`). **With no arg, scan the whole project root — never ask for one.**

## Source of truth

@armory/docs/godot/project-structure.md

That doc is the spec — it overrides reality except in step 4 (and only with the user's explicit say-so). Internalize the top-level layout, the **folder-per-type** rule, the **subclass exception**, **asset grouping**, and that **systems mirror the root** (minus a nested `systems/`).

## 1. Scan

First find the project root — the directory containing `project.godot` (that dir *is* `res://`): `find . -name project.godot -not -path '*/.godot/*'`. Don't assume it's named `source/`, and don't rely on git or being in a repo. That dir is the scan root; if a subdir arg was given, scope to `<root>/<subdir>`, else walk the whole root.

Walk it with `find` (or `Glob`). Capture every directory and every `.gd` / `.tscn` / `.tres` / asset path — you need exact, complete listings, so do the walk inline, not via Explore. Exclude `.godot/` (generated), `addons/` (third-party — in the doc but never a violation), and `deprecated/` (out of scope; only note that it exists).

If the tree is large and many `.gd` files need their role classified, hand that bulk read-and-classify to an `Explore` subagent and keep only its verdicts here.

## 2. Classify

Check each path against the spec's rules:

- **Top-level layout** — does the project root have the documented dirs? Flag renamed (`nodes/` vs doc's `entities/`, `test/` vs `tests/`), missing, and extra (`autoloads/`, `constants/`, `reports/`, …) dirs.
- **Folder-per-type** — each node / control / entity / resource that has a `.tscn` or external consumers lives in its own folder named after it, holding `[name].gd` (+ `[name].tscn` if applicable).
- **Subclass exception** — a standalone `.gd` that only `extends` a sibling, with no `.tscn` and no other consumers, may stay flat. A base type + its variants (e.g. `movement_state.gd` + `idle.gd`/`running.gd`) live together in one folder named after the base.
- **Asset grouping** — app-wide assets grouped by type under `assets/`; type-specific assets in an `assets/` dir adjacent to their code.
- **Systems mirror root** — each `systems/<sys>/` has root-like structure with no nested `systems/`.
- **Naming** — descriptive, consistent `snake_case`.

To decide **type (needs a folder) vs subclass (stays flat)**, read the file: a `.gd` with a matching `.tscn`, a `class_name`, or external consumers is a type; a `.gd` that only extends a sibling with no `.tscn` and no other consumers is a subclass.

The doc says "your project may look slightly different" — distinguish a real violation from an intentional deviation; don't manufacture findings.

For every finding record: path, rule, expected shape, and **how many sibling instances share the same violation** — that count drives step 4.

## 3. Report & resolve

Present findings grouped by rule, most-common first. For each group: state the fix in one line and ask. On approval, apply it; if the user calls it intentional, leave it and note it.

Moving or renaming a `.gd` / `.tscn` / `.tres` breaks `res://` and `uid://` references. After any move:

1. Grep the whole project for the old `res://` path **and** the file's `uid://`, and update every reference (scenes, `[ext_resource]`, `preload`/`load`, `.godot` is regenerated so skip it).
2. Run `scripts/godot-import.sh` then `scripts/godot-check.sh`. Don't tell the user to re-import themselves.

Never touch files the user marked intentional. Genuine one-off outliers the user keeps are fine — note and move on.

## 4. Propose doc changes — common violations only

After resolution, look back at what was **common** (many siblings hit the same rule the same way). For those *only* — skip one-off outliers entirely — propose tightening `project-structure.md` so it's unambiguous next time. A repeated violation means the doc was unclear or the convention has moved; let the user pick which:

- **Rule was right but implicit** → add an explicit line or example.
- **Convention has shifted** (the "violation" is the new norm, e.g. `nodes/` over `entities/`) → update the doc to match reality.

Show the exact diff, keep additions in the doc's existing terse style, and apply on approval.

## Guardrails

- Don't invent new top-level dirs or systems — flag, never create (per the doc and AGENTS.md).
- `deprecated/`, `addons/`, `.godot/` are out of scope as violation sources.
- A clean run with zero discrepancies is a valid result — say so and stop; don't pad the doc with changes nothing motivated.
