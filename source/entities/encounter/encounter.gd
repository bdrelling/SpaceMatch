class_name Encounter
extends Node
## The active fight entity — the [Node] that represents an [EncounterState] in the game hierarchy (a child of
## [Game], absent when no encounter is running). Owns the two combatant [Starship] children; combat logic
## reads and mutates the data off [member state]. Built via [method create] from two ready combatant states —
## the player's is a clone of the persistent starship so combat damage never touches a saved starship. The
## states themselves are chosen and built by [GameCoordinator]; this entity owns no content defaults.

const SCENE_PATH := "res://entities/encounter/encounter.tscn"
const SCENE: PackedScene = preload(SCENE_PATH)

@export var state: EncounterState

## Builds an encounter with its two combatant [Starship] children from the two fight states. [param player_state]
## is the player's fight starship (a clone of the persistent starship in a real game); [param opponent_state] is
## the opponent's. Both are required — [GameCoordinator] owns which starships fight and supplies them.
static func create(player_state: StarshipState, opponent_state: StarshipState) -> Encounter:
	var encounter: Encounter = SCENE.instantiate()
	var player_starship: Starship = Starship.with_state(player_state)
	var opponent_starship: Starship = Starship.with_state(opponent_state)
	player_starship.name = "Player"
	opponent_starship.name = "Opponent"
	encounter.add_child(player_starship)
	encounter.add_child(opponent_starship)
	var enc := EncounterState.new()
	# Each combatant fights as an encounter-scoped starship that also carries its banked resources and turn budget.
	enc.player = EncounterStarshipState.for_combatant(player_starship.state)
	enc.opponent = EncounterStarshipState.for_combatant(opponent_starship.state)
	encounter.state = enc
	return encounter
