class_name InventoryState
extends Resource
## An [Inventory]'s runtime state: the live stacks (and, for grid inventories, their
## [StackPlacement]s). Seeded from an [InventoryBlueprint] on apply and swappable wholesale by a
## save load — never authored as a `.tres`; it's created at runtime and serialized into saves.
## Also handed to [CapacityRule] checks so rules read plain data instead of the live node.

@export var stacks: Array[ItemStack] = []

## Parallel to [member stacks]; populated only by grid inventories.
@export var placements: Array[StackPlacement] = []

func _init(_stacks: Array[ItemStack] = [], _placements: Array[StackPlacement] = []) -> void:
	stacks = _stacks
	placements = _placements

func total_weight() -> float:
	var total := 0.0
	for stack: ItemStack in stacks:
		if stack.item_blueprint != null:
			total += stack.item_blueprint.weight * stack.quantity
	return total

func total_item_count() -> int:
	var total := 0
	for stack: ItemStack in stacks:
		total += stack.quantity
	return total
