class_name CraftingStationState
extends Resource
## A crafting station's saved state — its inventory now, upgrades or in-progress work later — keyed by
## [member id] and held in the game session so the 3D game and the minigames share it. A station carries this
## state regardless of its crafting minigame: a physics board (Plinko) need not be snapshotted for the
## station to still have saved data. Created at runtime, serialized into saves — never a `.tres`.

@export var id: StringName = &""

## The station's own inventory, when it has one; null otherwise.
@export var inventory: InventoryState

func _init(_id: StringName = &"") -> void:
	id = _id
