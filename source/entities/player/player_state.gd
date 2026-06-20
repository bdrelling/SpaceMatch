class_name PlayerState
extends Resource
## A player's runtime state: their [InventoryState] and currency. Seeded from blueprints on a new
## game and replaced wholesale when a save loads — never authored as a `.tres`.

@export var inventory: InventoryState
@export var currency: int = 0

func _init() -> void:
	if inventory == null:
		inventory = InventoryState.new()
