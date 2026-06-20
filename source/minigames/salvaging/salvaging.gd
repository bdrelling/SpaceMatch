class_name SalvagingMinigame
extends Minigame
## Salvaging minigame, framed on a [BoardCanvas] like every arcade stage. Two playtest variants over
## the same hidden-object field (a [SalvageBoard]), switched live by [member mode]:
##
## DEFAULT (shown as "Minesweeper") — the hidden objects are mines. Uncover one and the run ends; clear
##   every safe tile or flag every mine to win a damaged module.
## SALVAGE — the hidden objects are damaged modules to dig out. Every tap earns scrap, uncovering
##   a module earns triple, and digging out the whole field also yields a damaged module. You get
##   [member action_budget] taps per field.
##
## Either way the field then locks and waits; the player taps Reset for a fresh field. A mine hit
## exposes every mine at once; the old tile-by-tile reveal sweep is gated behind [constant
## _CASCADE_REVEAL_ON_FINISH], off for now. Rewards land in the session [Inventory] (the same economy the overworld and
## recycler read), wired in via [method bind_session]; a private inventory backs the minigame when it
## runs unbound (tests, standalone). The board is all this scene holds — the shell renders the scrap and
## damaged-module totals from [method inventory_chips] and the play feedback from [member status_text].

## Which variant plays. The public selector; SALVAGE is the field shown on load.
enum Mode { DEFAULT, SALVAGE }

const _GRID_WIDTH: int = 12
const _GRID_HEIGHT: int = 12
const _OBJECT_COUNT: int = 10
const _CELL_SIZE: float = 64.0
## Scrap for any tap; uncovering a module pays this times [constant _MODULE_SCRAP_MULTIPLIER].
const _SCRAP_PER_TAP: int = 1
const _MODULE_SCRAP_MULTIPLIER: int = 3
## When a field ends, sweep-reveal every remaining tile one-by-one. Off for now: a mine hit instead
## exposes all mines at once ([method SalvageBoard.reveal_all_objects]) and the field locks without the sweep.
const _CASCADE_REVEAL_ON_FINISH: bool = false

const _SCRAP: ItemBlueprint = preload("res://resources/items/scrap/scrap_item_blueprint.tres")

## Module catalog — a dug-out field yields a damaged module drawn at random from these.
const _MODULES: Array[ItemBlueprint] = [
	preload("res://resources/items/modules/reactor_item_blueprint.tres"),
	preload("res://resources/items/modules/engine_item_blueprint.tres"),
	preload("res://resources/items/modules/thruster_item_blueprint.tres"),
	preload("res://resources/items/modules/fuel_tank_item_blueprint.tres"),
	preload("res://resources/items/modules/cargo_bay_item_blueprint.tres"),
	preload("res://resources/items/modules/life_support_item_blueprint.tres"),
	preload("res://resources/items/modules/armor_plating_item_blueprint.tres"),
	preload("res://resources/items/modules/shield_generator_item_blueprint.tres"),
	preload("res://resources/items/modules/sensor_array_item_blueprint.tres"),
]

@export var mode: Mode = Mode.SALVAGE:
	set(value):
		mode = value
		if is_node_ready() and not _restoring:
			_restart_mode()
## SALVAGE only: uncover taps allowed per field before it ends. Exported to tune by feel.
@export var action_budget: int = 20
## Seconds between tiles in the end-of-field reveal sweep.
@export var reveal_step: float = 0.05
## Non-zero replays the same field on every (re)generation; zero rolls a fresh one each time.
@export var board_seed: int = 0

## Chip swatches in the shell's inventory strip.
const _SCRAP_COLOR := Color(0.78, 0.52, 0.25)
const _MODULE_COLOR := Color(0.55, 0.62, 0.78)

@onready var _canvas: BoardCanvas = %BoardCanvas

var _board: SalvageBoard
var _view: GridBoardView
var _grid: Grid
var _gestures: GestureRecognizer
var _reveal_timer: Timer
var _reveal_queue: Array[Vector2i] = []

# Where rewards go and what the readout counts: the session inventory once bound, otherwise a private
# one so the minigame still works standalone.
var _inventory: Inventory
var _own_inventory: Inventory
var _no_tags: Array[Item.Tag] = []
var _damaged_tags: Array[Item.Tag] = [Item.Tag.DAMAGED]

# Per-field state.
var _playable: bool = true
var _lost: bool = false
var _won: bool = false
var _actions_used: int = 0
var _found_this_field: int = 0

# The arcade session's salvaging state this field mirrors, once bound. _restoring suppresses the mode
# setter's field regeneration while restore stamps loaded values in.
var _field_state: SalvagingState
var _restoring: bool = false

func _ready() -> void:
	_own_inventory = Inventory.new()
	add_child(_own_inventory)
	_inventory = _own_inventory
	_inventory.changed.connect(_on_inventory_changed)

	_board = SalvageBoard.new(_GRID_WIDTH, _GRID_HEIGHT, _OBJECT_COUNT)
	_board.generate(board_seed)

	_view = GridBoardView.new()
	_view.configure(_GRID_WIDTH, _GRID_HEIGHT, _CELL_SIZE)
	_grid = _view.grid
	_canvas.set_board(_view, _view.content_size())

	_gestures = GestureRecognizer.new()
	_gestures.cell_resolver = _grid.cell_at
	_gestures.long_press_enabled = true
	_gestures.tap.connect(_on_reveal)
	_gestures.secondary_tap.connect(_on_flag)
	_gestures.long_press.connect(_on_flag)
	# The canvas feeds pointer events to the recognizer from its _gui_input, so turn off the
	# recognizer's own unhandled-input pass to avoid double dispatch.
	_gestures.set_process_unhandled_input(false)
	add_child(_gestures)
	_canvas.input_handler = _gestures.handle_event

	_reveal_timer = Timer.new()
	_reveal_timer.wait_time = reveal_step
	_reveal_timer.timeout.connect(_on_reveal_tick)
	add_child(_reveal_timer)

	_refresh()

#region View-model

## Reset clears the field; Mode flips the variant (the label shows the current one).
func actions() -> Array[MinigameAction]:
	var mode_label: String = "Mode: Salvage" if mode == Mode.SALVAGE else "Mode: Minesweeper"
	var list: Array[MinigameAction] = [
		MinigameAction.new("Reset", _on_reset_pressed),
		MinigameAction.new(mode_label, _on_mode_pressed),
	]
	return list

func inventory_chips() -> Array[InventoryChip]:
	var chips: Array[InventoryChip] = [
		InventoryChip.new("Scrap", scrap_count(), _SCRAP_COLOR),
		InventoryChip.new("Damaged Modules", damaged_module_count(), _MODULE_COLOR),
	]
	return chips

#endregion

## Wires the minigame to the running game's session inventory — the same economy the overworld and
## recycler read. Called by [MinigameScreen] when the arcade mounts this page; the private fallback
## inventory is dropped in favour of the shared one.
func bind_session(session: GameSession, inventory: Inventory) -> void:
	if inventory == null:
		return
	if _inventory != null and _inventory.changed.is_connected(_on_inventory_changed):
		_inventory.changed.disconnect(_on_inventory_changed)
	if _own_inventory != null:
		_own_inventory.queue_free()
		_own_inventory = null
	_inventory = inventory
	_inventory.changed.connect(_on_inventory_changed)
	_bind_field(session)
	_update_status()

# Binds the dug field to the arcade session's salvaging state so a partly-stripped field survives leaving
# the stage (no re-rolling for better luck). Restores a saved field, or snapshots the fresh _ready one.
func _bind_field(session: GameSession) -> void:
	if session == null or session.state == null:
		return
	# Salvaging lives in the arcade's own slice of the save; the arcade seeds it, but guard for
	# standalone runs (tests) where no arcade set it up.
	if session.state.arcade == null:
		session.state.arcade = ArcadeState.new()
	if session.state.arcade.salvaging == null:
		session.state.arcade.salvaging = SalvagingState.new()
	_field_state = session.state.arcade.salvaging
	if _field_state.has_field():
		_restore_field()
	else:
		_persist()

# Mirrors the live field and run flags into the saved salvaging state. No-op until bound.
func _persist() -> void:
	if _field_state == null:
		return
	_board.capture(_field_state)
	_field_state.mode = mode
	_field_state.playable = _playable
	_field_state.lost = _lost
	_field_state.won = _won
	_field_state.actions_used = _actions_used
	_field_state.found_this_field = _found_this_field

# Rebuilds the field and run flags from the saved salvaging state. Guards the mode assignment so it
# stamps the loaded mode without rolling a fresh field.
func _restore_field() -> void:
	_restoring = true
	mode = _field_state.mode
	_restoring = false
	_board.restore(_field_state)
	_playable = _field_state.playable
	_lost = _field_state.lost
	_won = _field_state.won
	_actions_used = _field_state.actions_used
	_found_this_field = _field_state.found_this_field
	actions_changed.emit()
	_sync_tiles()
	_update_status()

## Scrap on hand.
func scrap_count() -> int:
	return _inventory.count(_SCRAP.id)

## Damaged modules on hand across every module type.
func damaged_module_count() -> int:
	var total: int = 0
	for module: ItemBlueprint in _MODULES:
		total += _inventory.count(module.id, _damaged_tags)
	return total

# A module type drawn at random — what a stripped field rewards.
func _random_module() -> ItemBlueprint:
	return _MODULES[randi() % _MODULES.size()]

func _on_reveal(cell: Vector2i) -> void:
	if not _playable:
		return
	if mode == Mode.SALVAGE:
		_reveal_salvage(cell)
	else:
		_reveal_default(cell)

func _on_flag(cell: Vector2i) -> void:
	# Flagging is a planning marker in both modes; in DEFAULT, all-flagged is also a win.
	if not _playable:
		return
	var data := _board.cell_at(cell.x, cell.y)
	if data == null or data.revealed:
		return
	_board.toggle_flag(cell)
	if mode == Mode.DEFAULT and _board.all_objects_flagged():
		_win_default()
	else:
		_refresh()

# DEFAULT: a mine is fatal; clearing every safe tile (or flagging every mine) wins a damaged module.
func _reveal_default(cell: Vector2i) -> void:
	var data := _board.cell_at(cell.x, cell.y)
	if data == null or data.revealed or data.flagged:
		return
	if _board.reveal(cell) == SalvageBoard.Reveal.OBJECT:
		_lost = true
		_board.reveal_all_objects()
		_finish_field()
	elif _board.is_cleared():
		_win_default()
	else:
		_refresh()

# SALVAGE: every tap earns scrap, a module earns triple, the full field also yields a module. The
# action budget caps the taps per field.
func _reveal_salvage(cell: Vector2i) -> void:
	var data := _board.cell_at(cell.x, cell.y)
	if data == null or data.revealed:
		return
	_actions_used += 1
	_inventory.add_variant(_SCRAP, _no_tags, _SCRAP_PER_TAP)
	# Each tap digs exactly the tapped cell — no flood spill, so every dig spends one of the budgeted taps.
	if _board.reveal_single(cell) == SalvageBoard.Reveal.OBJECT:
		_inventory.add_variant(_SCRAP, _no_tags, _SCRAP_PER_TAP * (_MODULE_SCRAP_MULTIPLIER - 1))
		_found_this_field += 1
		if _found_this_field >= _board.object_count:
			_inventory.add_variant(_random_module(), _damaged_tags, 1)
			_finish_field()
			return
	if _actions_used >= action_budget:
		_finish_field()
	else:
		_refresh()

func _win_default() -> void:
	if _won:
		return
	_won = true
	_inventory.add_variant(_random_module(), _damaged_tags, 1)
	_finish_field()

# Ends the field: locks play and runs the reveal sweep; the player taps Reset for a new field.
func _finish_field() -> void:
	_playable = false
	_reveal_queue.clear()
	if _CASCADE_REVEAL_ON_FINISH:
		for y: int in _GRID_HEIGHT:
			for x: int in _GRID_WIDTH:
				if not _board.cell_at(x, y).revealed:
					_reveal_queue.append(Vector2i(x, y))
	_refresh()
	if not _reveal_queue.is_empty():
		_reveal_timer.start()

# One tile of the end-of-field sweep, left-to-right then top-to-bottom.
func _on_reveal_tick() -> void:
	if _reveal_queue.is_empty():
		_reveal_timer.stop()
		return
	var cell: Vector2i = _reveal_queue[0]
	_reveal_queue.remove_at(0)
	_board.expose(cell)
	_sync_tiles()

func _on_inventory_changed(_inventory_node: Inventory) -> void:
	_update_status()
	inventory_changed.emit()

func _refresh() -> void:
	_sync_tiles()
	_update_status()
	_persist()

## Rebuilds one [SalvageTile] per cell from current state.
func _sync_tiles() -> void:
	var style: SalvageTile.Style = (
		SalvageTile.Style.SALVAGE if mode == Mode.SALVAGE else SalvageTile.Style.HAZARD
	)
	_grid.clear_tiles()
	for y: int in _GRID_HEIGHT:
		for x: int in _GRID_WIDTH:
			var data := _board.cell_at(x, y)
			if data == null:
				continue
			var tile := SalvageTile.new()
			tile.style = style
			tile.revealed = data.revealed
			tile.flagged = data.flagged
			tile.object = data.object
			tile.adjacent = data.adjacent
			tile.lost = _lost
			_grid.place_tile(tile, Vector2i(x, y))

# Composes the shell's status line: the field counter plus a feedback clause for the current state.
func _update_status() -> void:
	if _board == null:
		return
	if mode == Mode.SALVAGE:
		var hunt: String = (
			"Field stripped — Reset for a fresh field." if not _playable
			else "Dig out damaged modules. Every tap earns scrap."
		)
		status_text = "Modules %d/%d · Taps %d/%d — %s" % [
			_found_this_field, _board.object_count, _actions_used, action_budget, hunt
		]
		return
	var sweep: String = "Uncover safe scrap; flag every mine."
	if _won:
		sweep = "Scrap field cleared — recovered a damaged module."
	elif _lost:
		sweep = "Hit a mine. Reset to try again."
	status_text = "Mines %d · Flagged %d — %s" % [_board.object_count, _board.flag_count(), sweep]

# New field, same mode; per-field state clears but the inventory carries over.
func _reset_field() -> void:
	_reveal_timer.stop()
	_reveal_queue.clear()
	_board.generate(board_seed)
	_playable = true
	_lost = false
	_won = false
	_actions_used = 0
	_found_this_field = 0
	_canvas.recenter()
	_refresh()

# Switching variant restarts that mode's field; the inventory carries over and the shell relabels the
# Mode action.
func _restart_mode() -> void:
	actions_changed.emit()
	_reset_field()

func _on_reset_pressed() -> void:
	_reset_field()

func _on_mode_pressed() -> void:
	mode = Mode.DEFAULT if mode == Mode.SALVAGE else Mode.SALVAGE
