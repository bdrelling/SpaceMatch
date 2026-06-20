@abstract
class_name GridInventoryPanel
extends OverlayPanel
## Grid inventory panel: stacks sit on a cell grid, multi-cell footprints render as one tile.
## Click a tile to pick it up, click a destination to place it, rotate while holding, click
## the backdrop to drop one unit. Abstract — behavior only, no scene or presentation of its
## own: a subclass owns the scene (which must provide %View, %Capacity, and %Backdrop),
## resolves its owner's inventory, and overrides [method _drop_stack]; see
## [PlayerGridInventoryPanel].

var inventory: Inventory

var _held_stack: ItemStack
var _held_rotation_steps: int = 0
var _hovered_cell := Vector2i(-1, -1)

@onready var _view: InventoryGridView = %View
@onready var _capacity: Label = %Capacity
@onready var _backdrop: ColorRect = %Backdrop

func _ready() -> void:
	super._ready()
	_view.cell_pressed.connect(_on_cell_pressed)
	_view.cell_hovered.connect(_on_cell_hovered)
	_view.mouse_exited.connect(_on_view_mouse_exited)
	_backdrop.gui_input.connect(_on_backdrop_input)
	opened.connect(_on_opened)
	closed.connect(_on_closed)
	if inventory:
		_view.register(inventory)
		_refresh_capacity()

## Sets the [Inventory] to display. Pass null to clear. Subclasses call this once they've
## resolved their owner's inventory.
func register(value: Inventory) -> void:
	if inventory == value:
		return
	if inventory and inventory.changed.is_connected(_on_inventory_changed):
		inventory.changed.disconnect(_on_inventory_changed)
	inventory = value
	if inventory and not inventory.changed.is_connected(_on_inventory_changed):
		inventory.changed.connect(_on_inventory_changed)
	if is_node_ready():
		_view.register(inventory)
		_refresh_capacity()

# The backdrop is an invisible click-catcher (drop held stack / close on an off-panel click);
# it only exists while the panel is open so it never eats clicks when closed.
func _on_opened() -> void:
	_backdrop.visible = true

func _on_closed() -> void:
	_backdrop.visible = false
	_cancel_hold()

func _on_inventory_changed(_inventory: Inventory) -> void:
	_refresh_capacity()
	# Dropping the held stack's last unit erases it; release the ghost with it.
	if _held_stack != null and inventory.placement_of(_held_stack) == null:
		_cancel_hold()

func _refresh_capacity() -> void:
	_capacity.text = inventory.describe_capacity() if inventory else ""

func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		super._unhandled_input(event)
		return
	# While open this panel claims BLOCK_ALL, which silences its own actions through
	# ManagedInput — open-state paths read the event directly instead (the documented
	# pairing in [member OverlayPanel.input_policy]).
	if event.is_action_pressed(&"ui_cancel") \
			or (not toggle_action.is_empty() and event.is_action_pressed(toggle_action)):
		if _held_stack != null:
			_cancel_hold()
		else:
			close()
		get_viewport().set_input_as_handled()
	elif _held_stack != null and event.is_action_pressed(InputAction.ROTATE_ITEM):
		_held_rotation_steps = (_held_rotation_steps + 1) % 4
		if _hovered_cell.x != -1:
			_show_preview(_hovered_cell)
		get_viewport().set_input_as_handled()

func _on_cell_pressed(cell: Vector2i) -> void:
	if inventory == null:
		return
	if _held_stack == null:
		var stack := inventory.stack_at_cell(cell)
		if stack != null:
			_hold(stack)
		return
	# Invalid spots just keep holding — the preview already reads red.
	if inventory.move_stack(_held_stack, cell, _held_rotation_steps):
		_release_hold()

func _on_cell_hovered(cell: Vector2i) -> void:
	_hovered_cell = cell
	if _held_stack != null:
		_show_preview(cell)

func _on_view_mouse_exited() -> void:
	_hovered_cell = Vector2i(-1, -1)
	_view.clear_preview()

func _on_backdrop_input(event: InputEvent) -> void:
	var mouse_button := event as InputEventMouseButton
	if mouse_button == null or not mouse_button.pressed or mouse_button.button_index != MOUSE_BUTTON_LEFT:
		return
	if _held_stack != null:
		_drop_stack(_held_stack)
	else:
		close()
	accept_event()

func _show_preview(cell: Vector2i) -> void:
	var cells := GridGeometry.occupied_cells(
		_held_stack.item_blueprint.footprint_cells, cell, _held_rotation_steps)
	_view.set_preview(cells, inventory.can_place(_held_stack, cell, _held_rotation_steps))

func _hold(stack: ItemStack) -> void:
	var placement := inventory.placement_of(stack)
	if placement == null:
		return
	_held_stack = stack
	_held_rotation_steps = placement.rotation_steps
	_view.set_held_stack(stack)

func _release_hold() -> void:
	_held_stack = null
	_view.set_held_stack(null)

func _cancel_hold() -> void:
	_release_hold()

## Drops one unit of [param stack]. The base panel just removes it from the inventory; an
## owner-aware subclass overrides this to eject the item into the world instead.
func _drop_stack(stack: ItemStack) -> void:
	if inventory and stack:
		inventory.remove_from_stack(stack, 1)
