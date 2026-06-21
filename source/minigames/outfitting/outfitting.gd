class_name OutfittingMinigame
extends Minigame
## Outfitting: arrange modules onto the ship's module grid. The grid (the board, in a [BoardCanvas]) is a
## [ShipModuleGrid] carried on the game's [ShipState], so placements persist across sessions. A starter
## set of modules is available to pack; packing IS the interface here.
##
## Tap a module in the strip to pick it up, then drag a finger across the grid to position its footprint
## preview and lift to slot it. While a module is held, a second-finger tap rotates it (desktop uses
## [code]rotate_item[/code]). Tap a slotted module with nothing held to return it to the available set.

## Ship grid silhouette, authored as a [ShapedGridGenerator]: a 6x6 bounds carved into a hull shape
## (28 usable cells), irregular but always solvable.
const _SHIP_GRID := preload("res://resources/starships/default_module_grid_blueprint.tres")
const _SHIP_CELL_SIZE: float = 96.0

# Starter modules available to place.
const _STARTER_MODULES: Array[String] = [
	"res://resources/items/modules/reactor_item_blueprint.tres",
	"res://resources/items/modules/engine_item_blueprint.tres",
	"res://resources/items/modules/fuel_tank_item_blueprint.tres",
	"res://resources/items/modules/cargo_bay_item_blueprint.tres",
	"res://resources/items/modules/thruster_item_blueprint.tres",
]

@onready var _canvas: BoardCanvas = %BoardCanvas

var _ship: ShipModuleGrid
var _ship_view: ShipGridView

var _strip: ModuleStrip

# Modules available to place — the starter set, minus whatever is currently slotted on the ship.
var _available: Array[ModuleBlueprint] = []
var _held_module: ModuleBlueprint
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

# The module strip is suppressed for now: Outfitting shows its own stats panel at the bottom of the
# screen instead, and modules live only on the ship. The placement code below is untouched — it's just
# no longer surfaced as a shell strip.
func inventory_chips() -> Array[InventoryChip]:
	var none: Array[InventoryChip] = []
	return none

func inventory_detail() -> Control:
	return null

func inventory_pinned() -> bool:
	return false

#endregion

## Binds the minigame to the running game: it packs modules onto the ship's persistent [ShipModuleGrid],
## seeding a starter set to place. Called by [MinigameScreen] when the game mounts this page.
func bind_session(session: GameSession) -> void:
	if session == null or session.state == null:
		return
	var ship_state: ShipState = session.state.ship
	if ship_state.module_grid == null:
		var module_grid := ShipModuleGrid.new()
		module_grid.grid = _SHIP_GRID.generate()
		ship_state.module_grid = module_grid
	_ship = ship_state.module_grid
	_ship_view = ShipGridView.new()
	_ship_view.configure(_ship, _SHIP_CELL_SIZE)
	_canvas.set_board(_ship_view, _ship_view.content_size())
	_canvas.input_handler = _on_ship_input
	_seed_starter_modules()
	_rebuild_modules()
	_update_status()

func _seed_starter_modules() -> void:
	if not _available.is_empty():
		return
	for path: String in _STARTER_MODULES:
		var module: ModuleBlueprint = load(path)
		if module != null:
			_available.append(module)

#region Module strip

# Feeds the strip the available modules and re-lights the held one.
func _rebuild_modules() -> void:
	if _strip == null:
		return
	_strip.set_modules(_available)
	_strip.set_selected(_held_module)

func _on_module_pressed(module: ModuleBlueprint) -> void:
	if _held_module == module:
		_cancel_hold()
	else:
		_hold(module)

func _hold(module: ModuleBlueprint) -> void:
	_held_module = module
	_held_rotation = 0
	_rebuild_modules()
	_update_status()

func _cancel_hold() -> void:
	_held_module = null
	_positioning = false
	if _ship_view != null:
		_ship_view.clear_preview()
	_rebuild_modules()
	_update_status()

#endregion

#region Ship board input

# Pointer events forwarded from the BoardCanvas (positions already in global space). A held module is
# dragged across the grid with finger 0 and slotted on release; with nothing held, a press pulls the
# slotted module back to the available set. Second-finger rotate is handled in [method _input].
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
	if _held_module != null:
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
	if _held_module != null and cell.x != -1:
		_try_place(cell)
	return true

func _hover_ship(cell: Vector2i) -> void:
	_hovered_cell = cell
	if _held_module == null:
		return
	if cell.x == -1:
		_ship_view.clear_preview()
		return
	_ship_view.set_preview(
		_held_module.shape.cells_at(cell, _held_rotation),
		_ship.can_place(_held_module.shape, cell, _held_rotation))

func _try_place(cell: Vector2i) -> void:
	if not _ship.can_place(_held_module.shape, cell, _held_rotation):
		return
	_ship.place(_held_module, cell, _held_rotation)
	_available.erase(_held_module)
	_cancel_hold()
	_update_status()

func _pull_module(cell: Vector2i) -> void:
	var module := _ship.remove_at(cell)
	if module != null:
		_available.append(module)
	_rebuild_modules()
	_update_status()

# Second-finger tap rotates the held module — index runs the board, the other hand spins the piece.
func _input(event: InputEvent) -> void:
	if _held_module == null:
		return
	var touch := event as InputEventScreenTouch
	if touch != null and touch.index >= 1 and touch.pressed:
		_rotate_held()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if _held_module != null and event.is_action_pressed(InputAction.ROTATE_ITEM):
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
	if _held_module != null:
		status_text = "Placing %s — drag on the grid, two-finger tap to rotate, lift to slot." % _held_module.name
	else:
		status_text = "Ship: %d / %d cells filled. Tap a module below to pick it up." % [
			_ship.filled_cell_count(), _ship.tile_count()]
	inventory_changed.emit()
