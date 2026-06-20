class_name StackCountCapacityRule
extends CapacityRule
## Caps the number of stacks; topping up existing stacks is always allowed.

## Maximum number of stacks. 0 means unbounded.
@export var max_stacks: int = 0

func can_add(state: InventoryState, _item_blueprint: ItemBlueprint, _amount: int, new_stack_count: int) -> bool:
	if max_stacks <= 0:
		return true
	return state.stacks.size() + new_stack_count <= max_stacks

func describe(state: InventoryState) -> String:
	return "%d / %d" % [state.stacks.size(), max_stacks]
