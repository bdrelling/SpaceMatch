class_name Starship
extends Node
## A starship entity — the [Node] that represents a [StarshipState] in the game hierarchy (under [Game] for the
## player's starship, under [Encounter] for the two combatants). Built from a [StarshipBlueprint] via
## [method create], or wrapped around an existing state (a save or a fight clone) via [method with_state].
## Combat and the HUD read the data off [member state]; the node makes the starship inspectable and places it in
## the tree.

const SCENE_PATH := "res://entities/starship/starship.tscn"
const SCENE: PackedScene = preload(SCENE_PATH)

## The starship's persisted state — its name, stats, module grid, hull, ruleset, and abilities. The save reads
## this; combat mutates it. Built by [method apply_blueprint] or supplied by [method with_state].
@export var state: StarshipState

#region Blueprinting


## Builds a fresh [StarshipState] onto this node from [param _blueprint]: copies its base stats, builds its
## module grid, and gives it the hull's ruleset/abilities (or the standard kit when the blueprint authors none).
## The live hull is encounter-scoped (it starts full on the [Combatant]'s health pool), so nothing to seed here.
func apply_blueprint(_blueprint: StarshipBlueprint) -> void:
	if not _blueprint:
		push_error("Unable to apply blueprint; blueprint not found")
		return
	state = StarshipState.new()
	state.name = _blueprint.name
	# Copy the base stat block so each starship owns its own (a shared exported default would let two starships'
	# buffs bleed together). Null authoring means a blank block — no intrinsic stats.
	state.base_stats = _blueprint.stats.duplicate() if _blueprint.stats != null else StarshipStats.new()
	# Build the loadout from the blueprint's grid and persist it, then mount a ModuleGrid child (Starship →
	# ModuleGrid) to represent it in the tree — the node wraps the same loadout the starship holds.
	var loadout := StarshipLoadout.create(_blueprint.module_grid)
	state.loadout = loadout
	add_child(ModuleGrid.with_state(loadout))
	# Rules and abilities are the starship's, not the match's: a hull authors its own, else it gets the standard
	# kit (a match-4 extra turn, the five stat abilities). Modules layer more on at match time.
	state.ruleset = _blueprint.ruleset if _blueprint.ruleset != null else _standard_ruleset()
	state.abilities = _blueprint.abilities.duplicate() if not _blueprint.abilities.is_empty() else _standard_abilities()


static func create(_blueprint: StarshipBlueprint) -> Starship:
	if not _blueprint:
		push_error("Blueprint required to create Starship")
		return null
	var starship: Starship = SCENE.instantiate()
	starship.apply_blueprint(_blueprint)
	return starship


## Wraps [param _state] in a fresh node — the load/clone path, where the data already exists (a saved starship or
## a fight clone) and only needs a node to live in the tree. Mounts a [ModuleGrid] child for the starship's loadout.
static func with_state(_state: StarshipState) -> Starship:
	var starship: Starship = SCENE.instantiate()
	starship.state = _state
	if _state != null and _state.loadout != null:
		starship.add_child(ModuleGrid.with_state(_state.loadout))
	return starship


## The baseline hull kit: a match of four or more keeps the board (the extra-turn rule, now starship-owned).
static func _standard_ruleset() -> Ruleset:
	var ruleset := Ruleset.new()
	var extra_turn := ExtraTurnRule.new()
	extra_turn.min_match = 4
	ruleset.add(extra_turn)
	return ruleset


## The stat resources the standard abilities are priced in — combat / propulsion / science / defense (the four
## stat tiles), preloaded so the kit builds without reaching the catalog autoload.
const _COMBAT: StarshipResource = preload("res://data/ability_resources/combat.tres")
const _PROPULSION: StarshipResource = preload("res://data/ability_resources/propulsion.tres")
const _SCIENCE: StarshipResource = preload("res://data/ability_resources/science.tres")
const _SHIELDS: StarshipResource = preload("res://data/ability_resources/shields.tres")


## The baseline hull abilities: one per stat tile (red/yellow/green/blue), plus a Disruptor that spends green.
##   Red — Target Lock: +1 to your tile damage for the rest of the encounter (stacks).
##   Yellow — Evasive Maneuvers: dodge the next attack (cheap).
##   Green — Siphon: drain 2 of each of the opponent's resources.
##   Blue — Shields: gain 10 shield (absorbed before health).
##   Green — Disruptor: disable one of the opponent's modules for 3 turns.
static func _standard_abilities() -> Array[Ability]:
	return [
		MatchAbilities.damage_buff("Target Lock", _COMBAT, 10, 1),
		MatchAbilities.dodge("Evasive Maneuvers", _PROPULSION, 5),
		MatchAbilities.drain("Siphon", _SCIENCE, 10, 2),
		MatchAbilities.shield("Shields", _SHIELDS, 10, 10),
		MatchAbilities.disable("Disruptor", _SCIENCE, 12, 3),
	]

#endregion
