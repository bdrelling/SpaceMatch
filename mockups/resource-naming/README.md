# resource-naming

The game's vocabulary — disciplines, resources, tiles, styles of play, stats.

- `terminology.html` — the settled vocabulary on one page; the copy that moves into the project. Artifact: https://claude.ai/code/artifact/e4f8f409-b6b1-4077-a554-0d18d971e1b8
- `index.html` — the research behind it (candidate sets, word benches, palette validation; a tabbed HTML doc with JS tabs, no SCREENS registry). Reference only; will be deleted eventually. Artifact: https://claude.ai/code/artifact/63f2c823-2805-4ad2-b7ac-3564f475d264

## Settled

- **Canonical order everywhere:** Command · Security · Engineering · Science.
- **Disciplines** (schools of play), 1:1 with **resources** (collected via matching, spent on abilities): Command = offense, Security = defense/sustain, Engineering = growth/speed/economy, Science = control/denial/intel.
- **Tiles** (what gets matched): the four above + Alloy (currency — also repair + upgrade cost, mostly out-of-combat), Antimatter (warp), Damage (direct). Icons only on Security (shield), Science (atom), Damage (crosshair), inline in the tile swatches. The small diamonds used elsewhere are indicators, not icons — leave them alone.
- **Styles of Play** (formerly "Systems") — six pairwise discipline combos, conceptual only:
  Combat (Command+Security), Propulsion (Engineering+Command), Tactics (Command+Science), Damage Control (Security+Engineering), Countermeasures (Security+Science), Logic (Science+Engineering).
- **Countermeasures** is settled for the Security+Science slot: the reactive kit (decoys, point-defense) is the outlast/attrition side, counter-acting their systems (jamming) is the denial side. Rejected for that slot: Suppression, Disruption, Interference, Interdiction, Electronic Warfare, Shields, Sensors.
- **Shields word budget:** module = Shield Generator, buff = Shields. No "Block".
- **Palette:** option A on the Palette tab — core pink/blue/gold/green + damage orange, alloy tan, warp purple. CVD-validated (Machado simulation), light and dark themes.
- **Energy** = module slots ("0/3 energy used"), colorless.
- **Stats** (ship properties that echo their discipline): Targeting (Command), Protection (Security), Computing (Engineering), Diagnostics (Science); plus Firepower (damage), Armor (alloy), Warp (antimatter), Energy (slots). Engineering's stat reads engine-room, not movement — Mobility and the movement words are dead.

## Naming tests used (reuse when resuming)

- Collect/spend sentences: "You collected 3 X!", "You spent 4 X to…", "All power to the ___ systems!"
- Closed set, no leftovers; a word can only mean one thing in the game.
- No franchise-owned words (Trek technobabble banned); no MTG jargon — Hearthstone/StS/Across-the-Obelisk vocabulary only.
- Doc prose stays count-free (no "the four schools…") so it can't go stale.
