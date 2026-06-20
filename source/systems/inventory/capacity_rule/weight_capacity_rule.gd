class_name WeightCapacityRule
extends CapacityRule
## Caps total weight: the sum of each stack's unit weight times its quantity.

## Maximum total weight. 0 means unbounded.
@export var max_weight: float = 0.0

func can_add(state: InventoryState, item_blueprint: ItemBlueprint, amount: int, _new_stack_count: int) -> bool:
	if max_weight <= 0.0:
		return true
	return state.total_weight() + item_blueprint.weight * amount <= max_weight

func describe(state: InventoryState) -> String:
	return "%.1f / %.1f" % [state.total_weight(), max_weight]
