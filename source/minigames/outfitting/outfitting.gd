class_name OutfittingMinigame
extends Minigame
## Outfitting: arrange modules from the inventory onto the ship's module grid. The grid (the board, in a
## [BoardCanvas]) is a [ShipModuleGrid] carried on the game's [ShipState], so placements persist across
## sessions. The bottom strip ([ModuleStrip]) shows the inventory's healthy modules as their footprints;
## packing IS the interface here, so the shell pins it open.
##
## Tap a module in the strip to pick it up, then drag a finger across the grid to position its footprint
## preview and lift to slot it (drawing one from the inventory). While a module is held, a second-finger
## tap rotates it (desktop uses [code]rotate_item[/code]). Tap a slotted module with nothing held to
## return it to the inventory.

## Ship grid layout, authored as a [ShipModuleGridBlueprint]: a 6x6 bounds carved into a hull silhouette
## (28 usable cells), irregular but always solvable.
const _SHIP_GRID_BLUEPRINT := preload("res://resources/starships/default_module_grid_blueprint.tres")
const _SHIP_CELL_SIZE: float = 96.0

# Starter modules seeded into an empty inventory so there's something to place.
const _STARTER_MODULES: Array[String] = [
	"res://resources/items/modules/reactor_item_blueprint.tres",
	"res://resources/items/modules/engine_item_blueprint.tres",
	"res://resources/items/modules/fuel_tank_item_blueprint.tres",
	"res://resources/items/modules/cargo_bay_item_blueprint.tres",
	"res://resources/items/modules/thruster_item_blueprint.tres",
]

## Chip swatch in the shell's inventory strip.
const _MODULE_COLOR := Color(0.55, 0.62, 0.78)

@onready var _canvas: BoardCanvas = %BoardCanvas

var _ship: ShipModuleGrid
var _ship_view: ShipGridView
var _modules: Inventory

var _strip: ModuleStrip

var _held_stack: ItemStack
var _held_rotation: int = 0
var _hovered_cell := Vector2i(-1, -1)
# True between a board press and its release while a module is held — the finger is dragging the ghost.
var _positioning: bool = false
# A finger-0 touch is driving the board, so the emulated mouse it generates is ignored as a duplicate.
var _touch_active: bool = false

func _ready() -> void:
	_update_status()

#region View-model

func actions() -> Array[MinigameAction]:
	var list: Array[MinigameAction] = []
	return list

func inventory_chips() -> Array[InventoryChip]:
	var chips: Array[InventoryChip] = [
		InventoryChip.new("Modules", _module_count(), _MODULE_COLOR),
	]
	return chips

# The inventory's healthy modules ARE the detail; the shell pins this strip open below the grid.
func inventory_detail() -> Control:
	if _strip == null:
		_strip = ModuleStrip.new()
		_strip.module_pressed.connect(_on_module_pressed)
		_rebuild_modules()
	return _strip

func inventory_pinned() -> bool:
	return true

#endregion

## Binds the minigame to the running game: it packs modules drawn from the shared [InventoryState] onto
## the ship's persistent [ShipModuleGrid], seeding a few modules when the inventory has none. Called by
## [MinigameScreen] when the arcade mounts this page.
func bind_session(session: GameSession, _inventory: Inventory) -> void:
	if session == null or session.state == null:
		return
	var ship_state: ShipState = session.state.ship
	if ship_state.module_grid == null:
		ship_state.module_grid = _SHIP_GRID_BLUEPRINT.create()
	_ship = ship_state.module_grid
	_ship_view = ShipGridView.new()
	_ship_view.configure(_ship, _SHIP_CELL_SIZE)
	_canvas.set_board(_ship_view, _ship_view.content_size())
	_canvas.input_handler = _on_ship_input
	if _modules == null:
		_modules = Inventory.new()
		add_child(_modules)
		_modules.changed.connect(_on_modules_changed)
	_modules.bind(session.state.inventory)
	_seed_starter_modules()
	_rebuild_modules()
	_update_status()

func _seed_starter_modules() -> void:
	if _modules == null:
		return
	for stack: ItemStack in _modules.get_stacks():
		if stack.item_blueprint != null and stack.item_blueprint.category == Item.Category.MODULE:
			return
	for path: String in _STARTER_MODULES:
		var blueprint: ItemBlueprint = load(path)
		_modules.add_variant(blueprint, [], 1)

#region Module strip

func _on_modules_changed(_inventory: Inventory) -> void:
	_rebuild_modules()
	_update_status()

# Feeds the strip the inventory's fully healthy modules and re-lights the held one.
func _rebuild_modules() -> void:
	if _strip == null:
		return
	var modules: Array[ItemStack] = []
	if _modules != null:
		for stack: ItemStack in _modules.get_stacks():
			if _is_healthy_module(stack):
				modules.append(stack)
	_strip.set_modules(modules)
	_strip.set_selected(_held_stack)

func _on_module_pressed(stack: ItemStack) -> void:
	if _held_stack == stack:
		_cancel_hold()
	else:
		_hold(stack)

# A fully healthy module: a MODULE-category stack with units and no DAMAGED variant tag.
func _is_healthy_module(stack: ItemStack) -> bool:
	return stack != null and stack.item_blueprint != null \
		and stack.item_blueprint.category == Item.Category.MODULE \
		and stack.quantity > 0 and not (Item.Tag.DAMAGED in stack.tags)

func _module_count() -> int:
	if _modules == null:
		return 0
	var total: int = 0
	for stack: ItemStack in _modules.get_stacks():
		if _is_healthy_module(stack):
			total += stack.quantity
	return total

func _hold(stack: ItemStack) -> void:
	_held_stack = stack
	_held_rotation = 0
	_rebuild_modules()
	_update_status()

func _cancel_hold() -> void:
	_held_stack = null
	_positioning = false
	if _ship_view != null:
		_ship_view.clear_preview()
	_rebuild_modules()
	_update_status()

#endregion

#region Ship board input

# Pointer events forwarded from the BoardCanvas (positions already in global space). A held module is
# dragged across the grid with finger 0 and slotted on release; with nothing held, a press pulls the
# slotted module back to the inventory. Second-finger rotate is handled in [method _input].
func _on_ship_input(event: InputEvent) -> bool:
	var touch := event as InputEventScreenTouch
	if touch != null and touch.index == 0:
		_touch_active = touch.pressed
		var cell := _ship_view.cell_at(touch.position)
		return _board_press(cell) if touch.pressed else _board_release(cell)
	var drag := event as InputEventScreenDrag
	if drag != null and drag.index == 0:
		_board_move(_ship_view.cell_at(drag.position))
		return _positioning
	# Finger 0 already drove the board; ignore the emulated mouse it generates as a duplicate.
	if _touch_active:
		return false
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		var cell := _ship_view.cell_at(button.position)
		return _board_press(cell) if button.pressed else _board_release(cell)
	var motion := event as InputEventMouseMotion
	if motion != null:
		var cell := _ship_view.cell_at(motion.position)
		if _positioning:
			_board_move(cell)
		else:
			_hover_ship(cell)
		return false
	return false

# Press: begin dragging a held module's ghost, or pull a slotted module when nothing is held.
func _board_press(cell: Vector2i) -> bool:
	if _held_stack != null:
		_positioning = true
		_board_move(cell)
		return true
	if cell.x == -1:
		return false
	_pull_module(cell)
	return true

func _board_move(cell: Vector2i) -> void:
	_hover_ship(cell)

# Release: slot the held module at the lifted cell when it fits; an invalid drop keeps it held.
func _board_release(cell: Vector2i) -> bool:
	if not _positioning:
		return false
	_positioning = false
	if _held_stack != null and cell.x != -1:
		_try_place(cell)
	return true

func _hover_ship(cell: Vector2i) -> void:
	_hovered_cell = cell
	if _held_stack == null:
		return
	if cell.x == -1:
		_ship_view.clear_preview()
		return
	var footprint := _held_stack.item_blueprint.footprint_cells
	_ship_view.set_preview(
		GridGeometry.occupied_cells(footprint, cell, _held_rotation),
		_ship.can_place(footprint, cell, _held_rotation))

func _try_place(cell: Vector2i) -> void:
	var blueprint := _held_stack.item_blueprint
	if not _ship.can_place(blueprint.footprint_cells, cell, _held_rotation):
		return
	_ship.place(blueprint, cell, _held_rotation)
	_modules.remove_from_stack(_held_stack, 1)
	_cancel_hold()
	_update_status()

func _pull_module(cell: Vector2i) -> void:
	var index := _ship.index_at(cell)
	if index == -1:
		return
	var blueprint := _ship.remove_at_index(index)
	if _modules != null and blueprint != null:
		_modules.add_variant(blueprint, [], 1)
	_update_status()

# Second-finger tap rotates the held module — index runs the board, the other hand spins the piece.
func _input(event: InputEvent) -> void:
	if _held_stack == null:
		return
	var touch := event as InputEventScreenTouch
	if touch != null and touch.index >= 1 and touch.pressed:
		_rotate_held()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if _held_stack != null and event.is_action_pressed(InputAction.ROTATE_ITEM):
		_rotate_held()
		get_viewport().set_input_as_handled()

func _rotate_held() -> void:
	_held_rotation = (_held_rotation + 1) % 4
	if _hovered_cell.x != -1:
		_hover_ship(_hovered_cell)

#endregion

func _update_status() -> void:
	if _ship == null:
		status_text = ""
		inventory_changed.emit()
		return
	if _held_stack != null:
		status_text = "Placing %s — drag on the grid, two-finger tap to rotate, lift to slot." % _held_stack.item_blueprint.name
	else:
		status_text = "Ship: %d / %d cells filled. Tap a module below to pick it up." % [
			_ship.filled_cell_count(), _ship.tile_count()]
	inventory_changed.emit()
