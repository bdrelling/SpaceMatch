@abstract
class_name CapacityRule
extends Resource
## What an [Inventory] may hold. Authored config only — contents and placements are runtime
## state owned by the inventory, never the rule, so one rule resource can be shared safely.

## Whether [param amount] units of the blueprint fit alongside the inventory's current
## contents, [param new_stack_count] of which would open new stacks.
@abstract func can_add(state: InventoryState, item_blueprint: ItemBlueprint, amount: int, new_stack_count: int) -> bool

## Capacity readout for display (e.g. "12 / 20").
@abstract func describe(state: InventoryState) -> String
