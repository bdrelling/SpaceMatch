class_name InventoryPanel
extends OverlayPanel
## Generic inventory drawer — presentation (slide-from-right, via [OverlayPanel]) plus a
## vertical list of item rows, sorted by name. The list view for non-grid inventories
## (a chest, an NPC, …); grid inventories use [GridInventoryPanel]. It has no inventory
## source of its own: a subclass targets a specific owner and feeds it an [Inventory]
## via [method register].
##
## Each row's drop button drops one unit from its stack (see [method _drop_stack]).
## Drag-to-rearrange is out of scope (DC-132).

const SCENE_PATH := "res://systems/inventory/ui/inventory_panel/inventory_panel.tscn"
const SCENE: PackedScene = preload(SCENE_PATH)

var inventory: Inventory

@onready var _grid: GridContainer = %Grid

func _ready() -> void:
	super._ready()

## Sets the [Inventory] to display, (re)connecting the [signal Inventory.changed] listener
## and rebuilding the grid. Pass null to clear. Subclasses call this once they've resolved
## their owner's inventory.
func register(value: Inventory) -> void:
	if inventory == value:
		return

	if inventory and inventory.changed.is_connected(_on_inventory_changed):
		inventory.changed.disconnect(_on_inventory_changed)

	inventory = value

	if inventory and not inventory.changed.is_connected(_on_inventory_changed):
		inventory.changed.connect(_on_inventory_changed)

	if is_node_ready():
		_rebuild()

func _on_inventory_changed(_inventory: Inventory) -> void:
	_rebuild()

func _rebuild() -> void:
	for child in _grid.get_children():
		child.queue_free()

	if not inventory:
		return

	var stacks := inventory.get_stacks()
	stacks.sort_custom(_sort_by_name)

	for stack in stacks:
		var view := ItemStackView.create(stack)
		_grid.add_child(view)
		view.drop_requested.connect(_drop_stack)

func _sort_by_name(a: ItemStack, b: ItemStack) -> bool:
	return a.display_name.naturalnocasecmp_to(b.display_name) < 0

## Drops one unit of [param stack]. The base panel just removes it from the inventory; an
## owner-aware subclass overrides this to eject the item into
## the world instead.
func _drop_stack(stack: ItemStack) -> void:
	if inventory and stack and stack.item_blueprint:
		inventory.remove(stack.item_blueprint.id, 1, stack.tags)

static func create() -> InventoryPanel:
	return SCENE.instantiate()
