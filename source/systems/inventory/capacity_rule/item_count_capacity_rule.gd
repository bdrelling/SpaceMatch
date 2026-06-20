class_name ItemCountCapacityRule
extends CapacityRule
## Caps total units held: the sum of every stack's quantity, regardless of variant.

## Maximum total units. 0 means unbounded.
@export var max_item_count: int = 0

func can_add(state: InventoryState, _item_blueprint: ItemBlueprint, amount: int, _new_stack_count: int) -> bool:
	if max_item_count <= 0:
		return true
	return state.total_item_count() + amount <= max_item_count

func describe(state: InventoryState) -> String:
	return "%d / %d" % [state.total_item_count(), max_item_count]
