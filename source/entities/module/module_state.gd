class_name ModuleState
extends Resource
## A module's runtime state — one instance of a [ModuleBlueprint] type. The blueprint's authored profile is copied
## onto this state once, at creation (see [method create]), so nothing reads the blueprint at runtime: the state is
## self-sufficient, like [StarshipState] is to [StarshipBlueprint]. Position is NOT here: a module can exist outside
## a grid (a shop, the player's inventory), so where it sits is the grid's concern (see [member
## ModuleGridState.placements]), not the module's. Shared by reference with the [Module] node that represents it, so
## an edit through either is the same edit (no clone).

## The id of the module type this is an instance of — its stable identity, for telling one module type from another
## without holding the blueprint.
@export var id: int = -1
@export var name: String = ""
@export var color: Color = Color.WHITE
## The stat profile this module contributes to its starship while enabled (summed by [method StarshipLoadout.stats]). Its
## own copy, so two instances of one module type never share a mutable block.
@export var stats: StarshipStats
## Abilities this module grants its starship while enabled (aggregated by [method StarshipLoadout.abilities]).
@export var abilities: Array[Ability] = []
## Phase rules this module grants its starship while enabled (aggregated by [method StarshipLoadout.rules]).
@export var rules: Array[Rule] = []


## Builds a module state from [param _blueprint], copying its authored profile once — the blueprint is factory
## input, never held or read afterwards. A null blueprint yields an empty state. Mirrors [method
## Starship.apply_blueprint].
static func create(_blueprint: ModuleBlueprint) -> ModuleState:
	var state := ModuleState.new()
	if _blueprint == null:
		return state
	state.id = _blueprint.id
	state.name = _blueprint.name
	state.color = _blueprint.color
	# Copy the stat block so each instance owns its own — a shared exported default would let two modules' edits bleed.
	state.stats = _blueprint.stats.duplicate() if _blueprint.stats != null else StarshipStats.new()
	state.abilities = _blueprint.abilities.duplicate()
	state.rules = _blueprint.rules.duplicate()
	return state
