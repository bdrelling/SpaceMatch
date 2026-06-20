# Minigame Design — Reference Games

Existing games to mine for each station minigame's mechanics, organized **per minigame**, with **current** availability (June 2026) on the four platforms that matter: **Steam, Mac App Store, iPhone, iPad**. "Available" means purchasable and running on current OS *today* — delisted or abandoned apps don't count. Each entry says what to steal and is tied to the minigame it informs (see `docs/gdd/3-gameplay/11-minigames/`). Re-verify against live storefronts before any planning checkpoint.

Availability was verified against live `store.steampowered.com` / `apps.apple.com` pages (and Apple's lookup API), not aggregator sites. Platforms are listed only where the game is actually available now. Each section closes with **Rejected** — games considered and ruled out (year/platforms in parens).

> Migration in progress: availability is verified for every game below, and the merge/combine games are now filed under the minigame they best inform. **Salvaging** has had its full research + Rejected pass; the other sections still need their own "what to steal" / Rejected pass.

## Salvaging — mine-clearing / deduction

Reveal-and-deduce: read the revealed numbers, mark the hazards, never guess. The reference set is the "no bad luck" lineage — boards solvable by logic alone.

**References**

- **Hexcells Plus** (2014) (Steam) — solvable by logic alone, zero guessing: the no-bad-luck version of the deduction loop. The whole trilogy (Hexcells / Plus / Infinite) is on Steam. ⚠️ The iOS ports were **delisted** — it's Steam/PC only now.
- **Minesweeper Classic: Retro** (iPhone, iPad) — the canonical deduction-from-revealed-numbers core Salvaging is built on. No single canonical Steam/Mac product exists; this free app (or Netflix's *Minesweeper*) is the concrete mobile pick.
- **Tametsi** (2017) (Steam) — no-guess logic on non-square tilings, 40+ hours of hand-built boards: the deduction core taken to its limit.
- **14 Minesweeper Variants** (2022) (Steam) — each variant layers one new *rule* onto the core, so the same board demands a different deduction. The model for extending one mechanic with modifiers. (Sequel 2024.)

**Rejected**

- **Good Sudoku** (2020, iPhone/iPad) — number-deduction is adjacent, but the sudoku framing isn't the salvage fantasy.
- **Wordoku** (various, iPhone/iPad) — sudoku-with-letters; same reason.

## Fabricating — match-3

_Availability verified; full what-to-steal / Rejected pass still pending._

**References**

- **Bejeweled 3** (2010) (Steam) — special-gem juice: 4/5-matches spawn flame/star/hypercube; reward over-fills, not just clears. (Mobile equivalent is *Bejeweled Classic* on iPhone / *Bejeweled Classic HD* on iPad, free + IAP.)
- **Candy Crush Saga** (2012) (iPhone, iPad) — per-level win-condition swap (clear jelly / drop ingredients) reframes the same board without new mechanics. (Not on Steam.)
- **Puzzle Quest 3** (2022) (Steam, Mac App Store, iPhone, iPad) — matches charge resources/abilities; clears feed a second system instead of just scoring.
- **Threes!** (2014) (Steam, Mac App Store, iPhone, iPad) — _merge_ — every tile previews-slides under your finger before commit: tactile weight on a 4×4.
- **2048** (2014) (iPhone, iPad) — _merge_ — doubling-merge readability: value sets color/scale so progress is legible at a glance. (Cirulli lineage, now published by Solebon; no canonical Steam.)
- **Triple Town** (2012) (Steam, iPhone, iPad) — _merge_ — tiered chains (grass→bush→tree→hut): plan placement for multi-step upgrade cascades, not just pairs.

## Outfitting — grid-packing

_Availability verified; full what-to-steal / Rejected pass still pending._

**References**

- **Backpack Hero** (2023) (Steam) — adjacency bonuses: an item's value changes by what it's packed next to, so packing becomes optimization, not just fit. (Steam/console only — no iOS; beware same-name App Store decoys.)
- **Tetris Effect: Connected** (2021) (Steam) — ghost-piece drop preview + line-clear flash: show the landing footprint before commit. (For mobile Tetris, the current official app is *Tetris* by PlayStudios on iPhone/iPad.)
- **Save Room — Organization Puzzle** (2022) (Steam) — pure rotate-and-fit, no timer; irregular shapes + "consume to free space" make inventory a self-contained puzzle. (Steam only.)

## Recycling — pachinko / slots

_Availability verified; full what-to-steal / Rejected pass still pending (Peggle → Rejected, add Peglin)._

**References**

- **Luck be a Landlord** (2023) (Steam, iPhone, iPad) — symbol-adjacency synergies on a 5×4 slot grid: each spin's payout depends on what landed next to what — deterministic combos under a random draw.
- **Suika Game** (2021) (iPhone, iPad) — _merge_ — drop-and-settle physics: the gravity cascade after a merge is the hook, parts fall and jostle, never snap. (Not on Steam — only clones there.)
- **Peggle Deluxe** (2007) (Steam) — genre anchor only, not a clone target: aim once, watch the uncontrolled ricochet pay off — one input, long physics payout. (On iOS only as the free-to-play *Peggle Blast*.)

## Cut (no minigame)

- **Mini Metro** — route-drawing / network optimization; no overlap with any station minigame.

---

Sources: live Steam store pages, Apple App Store pages, SteamDB, and Apple's iTunes lookup API. Each availability call checked against the live listing, June 2026.
