class_name GameSession
extends RefCounted
## The live runtime of one running game: holds a [GameState] and binds nodes to it. One per running
## game — never an autoload, so tests spin up fresh games.

var state: GameState

func _init(_state: GameState = null) -> void:
	state = _state if _state != null else GameState.new()

## A fresh game — an empty inventory and a default ship.
static func new_game() -> GameSession:
	return GameSession.new()

## Points [param inventory] (a node) at the game's [InventoryState] so the node operates on the saved
## data in place. Apply the inventory's blueprint first for a new game's defaults; binding a loaded
## game keeps its saved contents.
func bind_inventory(inventory: Inventory) -> void:
	if inventory == null or state == null:
		return
	inventory.bind(state.inventory)
