class_name GameState
extends Resource
## One running game's runtime state: the [InventoryState] and the player's [ShipState]. This is what a
## save serializes; a [GameSession] holds it live. Never a project `.tres`.

@export var inventory: InventoryState
@export var ship: ShipState

## The game's own slice of state, serialized with the one save.
@export var minigames: MinigamesState

func _init() -> void:
	if inventory == null:
		inventory = InventoryState.new()
	if ship == null:
		ship = ShipState.new()
