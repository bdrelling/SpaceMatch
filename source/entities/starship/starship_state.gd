class_name StarshipState
extends Resource
## A ship: its name and the module grid loaded into it.

@export var name: String = ""
## The ship's own base stats — its hull's starting health and any intrinsic bonuses/restrictions, before
## modules. Effective stats are this plus the module grid's profile (see [method EncounterState.effective_stats]).
@export var stats: StatBlock
@export var module_grid: ModuleGrid
## The ship's current hull — what depletes as it takes damage in an encounter. At zero the ship is destroyed
## and its pilot loses: the starship itself is the thing that dies, so combat damage lives here rather than on
## a per-side counter. Seeded to [method max_health] when the ship is generated (see [StarshipGenerator]).
@export var health: int = 0
## An optional tile-selection rule this ship forces on its turn, overriding the encounter's default
## (see [SelectionRule]). Null means it plays by the board's default selection.
@export var selection_override: SelectionRule
## Phase rules this ship brings to a match — its extra-turn rule and any module/hull behaviour. On the ship's
## turn these layer over (and override, by [member Rule.rule_name]) the match's default ruleset, the same way
## [member selection_override] overrides the default selection. The match composes ship + module rules per
## turn (see [method MatchMinigame._effective_ruleset]); modules add more via [method ModuleGrid.rules].
@export var ruleset: Ruleset
## Abilities this ship can use — its hull kit plus whatever its modules grant. Abilities are a property of the
## ship, never the match: the acting ship's set drives its ability bar (player) or AI pick (opponent). Modules
## contribute more via [method ModuleGrid.abilities].
@export var abilities: Array[MatchAbility] = []

## A fight copy of this ship for an encounter: its own [member stats] block and [member health], so combat and
## Debug edits stay on the copy and a fresh fight starts fresh. The module grid, ruleset and abilities are
## shared, not deep-copied — the match only reads them (it composes a fresh ruleset per turn), and grid_system's
## [GridState] doesn't survive a deep duplicate.
func clone() -> StarshipState:
	var copy := StarshipState.new()
	copy.name = name
	copy.stats = stats.duplicate() if stats != null else null
	copy.module_grid = module_grid
	copy.health = health
	copy.selection_override = selection_override
	copy.ruleset = ruleset
	copy.abilities = abilities
	return copy

## The ship's max hull — its base health stat plus every hull module's, the cap [member health] starts at and
## the bar's top. Derived from the ship (stats + modules), so editing the hull stat or slotting a hull module
## raises it. Stable through a fight: disabling a module doesn't lower it.
func max_health() -> int:
	var total: int = stats.health if stats != null else 0
	if module_grid != null:
		total += module_grid.profile().health
	return total
