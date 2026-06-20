class_name InventoryBlueprint
extends Resource
## Configuration for an [Inventory].

@export var capacity_rule: CapacityRule
## Starting contents as authored data. The live [ItemStack]s are copied from these in
## [method Inventory.apply_blueprint] — the blueprint never holds runtime stacks itself.
@export var item_stacks: Array[ItemStack] = []
