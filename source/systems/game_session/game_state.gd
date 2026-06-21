class_name GameState
extends Resource
## One running game's runtime state: the player's [ShipState] and the active [EncounterState]. This is
## what a save serializes; a [GameSession] holds it live. Never a project `.tres`.

@export var ship: ShipState

## The active encounter's state, or null when no encounter is running. Serialized with the one save.
@export var encounter: EncounterState

func _init() -> void:
	if ship == null:
		ship = ShipState.new()
