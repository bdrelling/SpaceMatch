class_name Starship
extends Node
## A ship entity — the [Node] that represents a [StarshipState] in the game hierarchy (under [Game] for the
## player's ship, under [Encounter] for the two combatants). Built from a [StarshipBlueprint] via
## [method create], or wrapped around an existing state (a save or a fight clone) via [method with_state].
## Combat and the HUD read the data off [member state]; the node makes the ship inspectable and places it in
## the tree.

const SCENE_PATH := "res://entities/starship/starship.tscn"
const SCENE: PackedScene = preload(SCENE_PATH)

## The ship's persisted state — its name, stats, module grid, hull, ruleset, and abilities. The save reads
## this; combat mutates it. Built by [method apply_blueprint] or supplied by [method with_state].
@export var state: StarshipState

#region Blueprinting

## Builds a fresh [StarshipState] onto this node from [param _blueprint]: copies its base stats, builds its
## module grid, and gives it the hull's ruleset/abilities (or the standard kit when the blueprint authors
## none). Seeds [member StarshipState.health] to full — derivable now from the assembled stats and modules.
func apply_blueprint(_blueprint: StarshipBlueprint) -> void:
	if not _blueprint:
		push_error("Unable to apply blueprint; blueprint not found")
		return
	state = StarshipState.new()
	state.name = _blueprint.name
	# Copy the base stat block so each ship owns its own (a shared exported default would let two ships'
	# buffs bleed together). Null authoring means a blank block — no intrinsic stats.
	state.stats = _blueprint.stats.duplicate() if _blueprint.stats != null else StarshipStats.new()
	# Build the module grid as a child node (Starship → ModuleGrid) and persist its state on the ship.
	var grid := ModuleGrid.create(_blueprint.module_grid)
	add_child(grid)
	state.module_grid = grid.state
	# Rules and abilities are the ship's, not the match's: a hull authors its own, else it gets the standard
	# kit (a match-4 extra turn, the five stat abilities). Modules layer more on at match time.
	state.ruleset = _blueprint.ruleset if _blueprint.ruleset != null else _standard_ruleset()
	state.abilities = _blueprint.abilities.duplicate() if not _blueprint.abilities.is_empty() else _standard_abilities()
	# A fresh ship starts at full hull — its max is derived from its stats and modules, so this is known now.
	state.health = state.max_health()

static func create(_blueprint: StarshipBlueprint) -> Starship:
	if not _blueprint:
		push_error("Blueprint required to create Starship")
		return null
	var starship: Starship = SCENE.instantiate()
	starship.apply_blueprint(_blueprint)
	return starship

## Wraps [param _state] in a fresh node — the load/clone path, where the data already exists (a saved ship or
## a fight clone) and only needs a node to live in the tree. Mounts a [ModuleGrid] child for the ship's grid.
static func with_state(_state: StarshipState) -> Starship:
	var starship: Starship = SCENE.instantiate()
	starship.state = _state
	if _state != null and _state.module_grid != null:
		starship.add_child(ModuleGrid.with_state(_state.module_grid))
	return starship

## The baseline hull kit: a match of four or more keeps the board (the extra-turn rule, now ship-owned).
static func _standard_ruleset() -> Ruleset:
	var ruleset := Ruleset.new()
	var extra_turn := ExtraTurnRule.new()
	extra_turn.min_match = 4
	ruleset.add(extra_turn)
	return ruleset

## The baseline hull abilities: one per stat tile (red/yellow/green/blue), plus a Disruptor that spends green.
##   Red — Target Lock: +1 to your tile damage for the rest of the encounter (stacks).
##   Yellow — Evasive Maneuvers: dodge the next attack (cheap).
##   Green — Siphon: drain 2 of each of the opponent's resources.
##   Blue — Shields: gain 10 shield (absorbed before health).
##   Green — Disruptor: disable one of the opponent's modules for 3 turns.
static func _standard_abilities() -> Array[MatchAbility]:
	return [
		MatchAbility.make("Target Lock", AbilityCost.make(0, 10), DamageBuffEffect.make(1)),
		MatchAbility.make("Evasive Maneuvers", AbilityCost.make(1, 5), DodgeEffect.make()),
		MatchAbility.make("Siphon", AbilityCost.make(2, 10), DrainEffect.make(2)),
		MatchAbility.make("Shields", AbilityCost.make(3, 10), ShieldEffect.make(10)),
		MatchAbility.make("Disruptor", AbilityCost.make(2, 12), DisableEffect.make(3)),
	]

#endregion
