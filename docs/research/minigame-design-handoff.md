# Minigame Design — Conversation Handoff

Locked per-minigame facts and the shared match-3 mechanics live in `docs/gdd/3-gameplay/11-minigames.md` — read that first. This doc captures what isn't in the GDD: open threads, rejected directions, and the intent behind the decisions.

## Design intent (load-bearing)

- The match-3 exists to **tie 3D-world gathering into crafting**: components come from inventory, so the minigame is finite (bounded by what you've gathered) yet feels infinite when well-stocked.
- Rarity should **feel good** (landing a scarce component is satisfying) and abundance should **feel like junk** ("ugh, recycle it again"). This comes from inventory pool depth, not an artificial rarity stat.

## Open (undecided)

- **Commit vs. refund:** when a build consumes components, are they committed to the half-built module (can't reclaim) or refundable on cancel? Committed = a stalled rare-ingredient build ties up your commons (tension); refundable = inventory stays fluid (forgiving).
- **Refurbishing's damaged-tile mechanic:** "clear damaged tiles" is settled in principle; exact behavior (how damage clears, how it gates completion) is not.
- **Component set:** the 4–8 cap is set; the actual component types are not.
- **Recycling, Salvaging, Outfitting:** only the one-line descriptions exist; no deeper mechanics yet.

## Rejected (don't revisit unless reopened)

- **Pipedream / wire game** for Fabricating/Refurbishing — match-3 chosen instead.
- **Fabricating and Refurbishing as separate minigames** — they are one shared game.
- **Splitting by theme** (pipe for repair, match-3 for build) — rejected.
- **Proportional-to-inventory board seeding** — drowns rare components; replaced by recipe-seeded + inventory-as-cap.
- **Raising the match threshold** (e.g. "need 10–20") to dodge gridlock — rejected; solved structurally via free tile movement.
- **A separate rarity/weighting system** — rejected; rarity = inventory pool depth.
- Table cruft: **"possibly merged with X"** notes and the **Tetris / attaché-case** framing for Outfitting.
