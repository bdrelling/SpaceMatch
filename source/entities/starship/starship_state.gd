class_name StarshipState
extends Resource
## A starship: its name and the loadout fitted into it.

@export var name: String = ""
## The starship's own base stats — its hull's starting health and any intrinsic bonuses/restrictions, before
## modules. Effective stats are this plus the loadout's profile (see [method effective_stats]).
@export var base_stats: StarshipStats
## The loadout fitted into this starship — its arranged modules and the stat/ability/rule profile they grant
## (see [Loadout]). Persisted here; the match reads its profile each turn.
@export var loadout: Loadout
## The starship's current hull — what depletes as it takes damage in an encounter. At zero the starship is destroyed
## and its pilot loses: the starship itself is the thing that dies, so combat damage lives here rather than on
## a per-side counter. Seeded to [method max_health] when the starship is built (see [method Starship.apply_blueprint]).
@export var health: int = 0
## An optional tile-selection rule this starship forces on its turn, overriding the encounter's default
## (see [SelectionRule]). Null means it plays by the board's default selection.
@export var selection_override: SelectionRule
## Phase rules this starship brings to a match — its extra-turn rule and any module/hull behaviour. On the starship's
## turn these layer over (and override, by [member Rule.rule_name]) the match's default ruleset, the same way
## [member selection_override] overrides the default selection. The match composes starship + module rules per
## turn (see [method MatchGame._effective_ruleset]); modules add more via [method Loadout.rules].
@export var ruleset: Ruleset
## Abilities this starship can use — its hull kit plus whatever its modules grant. Abilities are a property of the
## starship, never the match: the acting starship's set drives its ability bar (player) or AI pick (opponent). Modules
## contribute more via [method Loadout.abilities].
@export var abilities: Array[MatchAbility] = []

## A fight copy of this starship for an encounter: its own [member base_stats] block and [member health], so combat
## and Debug edits stay on the copy and a fresh fight starts fresh. The loadout, ruleset and abilities are shared,
## not deep-copied — the match only reads them (it composes a fresh ruleset per turn), and grid_system's
## [GridState] doesn't survive a deep duplicate.
func clone() -> StarshipState:
	var copy := StarshipState.new()
	copy.name = name
	copy.base_stats = base_stats.duplicate() if base_stats != null else null
	copy.loadout = loadout
	copy.health = health
	copy.selection_override = selection_override
	copy.ruleset = ruleset
	copy.abilities = abilities
	return copy

## The starship's effective stats — its own [member base_stats] plus its loadout's module profile (see [method
## Loadout.stats]). The permanent layer a fresh fight seeds health from; combat stacks the encounter's temporary
## buffs on top of this (see [method EncounterState.effective_stats]).
func effective_stats() -> StarshipStats:
	var total := StarshipStats.new()
	if base_stats != null:
		total.add(base_stats)
	if loadout != null:
		total.add(loadout.stats())
	return total

## The starship's max hull — its effective health (base stat plus every hull module's), the cap [member health]
## starts at and the bar's top. Derived from the starship (stats + modules), so editing the hull stat or slotting
## a hull module raises it. Stable through a fight: disabling a module doesn't lower it.
func max_health() -> int:
	return effective_stats().health
