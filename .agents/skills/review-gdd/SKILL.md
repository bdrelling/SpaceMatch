---
name: review-gdd
description: Read-only health check of the GDD — readiness %, top priorities, code drift, quick fixes, as a one-screen summary.
argument-hint: "[expand | expand <area>]"
model: inherit
effort: high
allowed-tools: Read, Glob, Grep, Bash, Agent
---

# review-gdd

Read-only. Propose fixes; never apply them. Never edit the GDD or code.

## Inputs

- **GDD:** read `docs/gdd/game-design-document.md` once — the compiled doc is every section concatenated, so one read beats touring section files.
- **Code (drift only):** enumerate shipping systems under `source/` (use the Explore agent). Exclude `demos/`, `deprecated/`, `test/`, `tools/`, `addons/`.

## Readiness

Score each leaf section (every `###`/`####` heading, excluding the TOC): stub or `TBD` = 0 · one-liner = 0.5 · substantive = 1.0.

- **Fill rate** = sections with content past the header ÷ total.
- **Depth-weighted** = mean score.
- **Readiness** = a holistic % (lead with this) plus a one-line profile of what's strong vs empty.

## Drift rules — don't repeat past mistakes

- Compare the GDD only to shipping code (exclusions above). A demo is not a shipping mechanic.
- Don't force a 1:1 map. Code system missing from the GDD → "backfill" (note once). GDD concept missing from code → forward-looking, **ignore** — the GDD leads the code.
- Flag a **contradiction** only when shipping code does the literal opposite of an explicit GDD statement about the *same* thing. Two different systems (e.g. two vehicles) are not a contradiction. Unsure → not drift.

## Output — this exact shape, every run

```
**GDD Review — SpaceMatch · Readiness ~NN%** (XX% filled; <one-line profile>)

<1–2 sentence TL;DR.>

**Top 3**
1. <priority — why, §ref>
2. <priority — why, §ref>
3. <priority — why, §ref>

**Drift** <count> — <the one needing a decision, if any>. Rest: doc lagging code, backfill later.

**Quick fixes** <count> objective: <terse · terse · terse>

*Reply `expand` (or `expand drift` / `expand gaps` / `expand fixes`) for detail.*
```

One line per line. Detail is pull, not push — keep the default to one screen.

## expand

`expand` → full breakdown. `expand <area>` (drift | gaps | fixes | priorities) → just that block. Stay concise even expanded: bullets, not prose.
