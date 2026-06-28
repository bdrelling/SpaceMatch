class_name Encounter
extends Node
## The active fight entity — the [Node] that represents an [EncounterState] in the game hierarchy (a child of
## [Game], absent when no encounter is running). Owns the two combatant [Starship] children; combat logic
## reads and mutates the data off [member state]. Built via [method create], which clones the player's ship
## into the fight and builds the opponent from its blueprint so combat damage never touches a saved ship.

const SCENE_PATH := "res://entities/encounter/encounter.tscn"
const SCENE: PackedScene = preload(SCENE_PATH)

## The computer opponent's default ship — distinct from the player's (no warp core, so the AI can't Jump).
const _DEFAULT_OPPONENT := preload("res://resources/starships/computer_default_starship_blueprint.tres")
## The player's fight ship when no session seeds one (the standalone match scene and unit tests).
const _DEFAULT_PLAYER := preload("res://resources/starships/default_starship_blueprint.tres")

@export var state: EncounterState

## Builds an encounter with its two combatant [Starship] children. [param player_state] is the player's fight
## ship — a clone of the persistent ship in a real game; null builds the standalone default. The opponent is
## built from [param opponent_blueprint] (the computer default).
static func create(player_state: StarshipState = null, opponent_blueprint: StarshipBlueprint = _DEFAULT_OPPONENT) -> Encounter:
	var encounter: Encounter = SCENE.instantiate()
	var player_ship: Starship = Starship.with_state(player_state) if player_state != null else Starship.create(_DEFAULT_PLAYER)
	var opponent_ship: Starship = Starship.create(opponent_blueprint)
	player_ship.name = "Player"
	opponent_ship.name = "Opponent"
	encounter.add_child(player_ship)
	encounter.add_child(opponent_ship)
	var enc := EncounterState.new()
	# Each combatant fights as an encounter-scoped ship that also carries its banked resources and turn budget.
	enc.player = EncounterStarshipState.for_combatant(player_ship.state)
	enc.opponent = EncounterStarshipState.for_combatant(opponent_ship.state)
	encounter.state = enc
	return encounter
