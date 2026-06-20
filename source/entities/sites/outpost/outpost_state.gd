class_name OutpostState
extends Resource
## The outpost: its name, its landing pads, the salvage yard pooling its resources, and its crafting
## stations' saved state.

@export var name: String = ""
@export var landing_pads: Array[LandingPadState] = []
@export var salvage_yard: InventoryState

## Saved state for the outpost's crafting stations, keyed by [member CraftingStationState.id].
@export var crafting_stations: Array[CraftingStationState] = []

func _init() -> void:
	if salvage_yard == null:
		salvage_yard = InventoryState.new()
