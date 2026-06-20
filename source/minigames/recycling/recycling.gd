class_name RecyclingMinigame
extends Minigame
## Recycling minigame (match-3). A board of component tiles: grab a tile and drag it toward a neighbour
## to swap ([[SwapInteraction]]), line up three-or-more of one component and it pops ([[MatchClearPassive]]),
## recycling those components into the session inventory — longer runs and cascades yield more. Tiles fall
## and fresh ones stream in ([[GravityPassive]]); the board is an equal-frequency generator, so it never
## stalls. Each tile is a real component [[ItemBlueprint]] (wire, tube, panel, bolt, gear, coil). Scrap as
## the board's fuel (the world's small/medium/large scrap converted into a single scrap count) is a later
## hook — for now the board runs freely.

const _BOARD_WIDTH: int = 8
const _BOARD_HEIGHT: int = 8
const _CELL_SIZE: float = 64.0
const _MIN_RUN: int = 3
const _KIND_COUNT: int = RecyclingTile.KIND_COUNT

## Component catalog, indexed by tile kind — the single source for each kind's identity and colour.
const _COMPONENTS: Array[ItemBlueprint] = [
	preload("res://resources/items/components/wire_item_blueprint.tres"),
	preload("res://resources/items/components/tube_item_blueprint.tres"),
	preload("res://resources/items/components/panel_item_blueprint.tres"),
	preload("res://resources/items/components/bolt_item_blueprint.tres"),
	preload("res://resources/items/components/gear_item_blueprint.tres"),
	preload("res://resources/items/components/coil_item_blueprint.tres"),
]

## Forwarded to the blueprint as the board's seed. Zero rolls a fresh board each generation.
@export var board_seed: int = 0

## Chip swatches in the shell's inventory strip.
const _SCRAP_COLOR := Color(0.78, 0.52, 0.25)
const _COMPONENT_COLOR := Color(0.45, 0.72, 0.55)
const _MODULE_COLOR := Color(0.55, 0.62, 0.78)

@onready var _canvas: BoardCanvas = %BoardCanvas

var _message: String = ""

var _session: GridSession
var _view: GridBoardView
var _grid: Grid
var _match_view: MatchBoardView
var _rng := RandomNumberGenerator.new()

# The running game's session inventory recycled components land in — the shared economy.
var _inventory: Inventory

var _detail: ScrollContainer
var _detail_list: VBoxContainer

func _ready() -> void:
	var blueprint := RecyclingBlueprint.new()
	blueprint.rng_seed = board_seed
	_session = GridSession.create(blueprint)
	_session.generator = CallableBoardGenerator.create(_generate_board)
	_wire_rules()
	_session.rules_rebuilt.connect(_wire_rules)

	_view = GridBoardView.new()
	_view.configure(_BOARD_WIDTH, _BOARD_HEIGHT, _CELL_SIZE)
	_grid = _view.grid
	_match_view = MatchBoardView.new()
	_view.add_child(_match_view)
	_canvas.set_board(_view, _view.content_size())
	_match_view.setup(_session, _grid, _make_tile, _spawn_tile)
	_match_view.move_resolved.connect(_on_move_resolved)
	# The canvas feeds pointer events to the view from its _gui_input.
	_canvas.input_handler = _match_view.handle_event

	_session.regenerated.connect(_on_regenerated)
	_session.regenerate()
	_message = "Match components to recycle them. %d-in-a-row clears." % _MIN_RUN
	_compose_status()

## Reset redraws the board with a fresh layout.
func actions() -> Array[MinigameAction]:
	var list: Array[MinigameAction] = [
		MinigameAction.new("Reset Board", _on_reset_pressed),
	]
	return list

## Wires the minigame to the running game's session inventory — the same economy the overworld reads.
## Called by [MinigameScreen] when the arcade mounts this page.
func bind_session(_game_session: GameSession, inventory: Inventory) -> void:
	if _inventory != null and _inventory.changed.is_connected(_on_inventory_changed):
		_inventory.changed.disconnect(_on_inventory_changed)
	_inventory = inventory
	if _inventory != null:
		_inventory.changed.connect(_on_inventory_changed)
	_refresh_inventory()

func _on_inventory_changed(_inventory_node: Inventory) -> void:
	_refresh_inventory()

#region Match-3

func _compose_status() -> void:
	status_text = _message

## Re-injects the clear hook into the session's owned rule copies — after instantiation and again
## whenever the session rebuilds its rules.
func _wire_rules() -> void:
	for rule: Variant in _session.find_rules(MatchClearPassive):
		var clearer: MatchClearPassive = rule
		clearer.on_clear = _on_clear

# Recycles each cleared run into the inventory — read here, before the passive removes the tiles. A run
# of a component yields that component, by length (3→1, 4→2, 5→3, then Fibonacci upward). Fires once
# per cascade pass, so cascades recycle too.
func _on_clear(board: GridBoardState, cells: Array[Vector2i]) -> void:
	_award_runs(board, cells)

# Re-derives the flat clear list into maximal same-kind runs (the clear callback drops run grouping) and
# recycles each. A run is credited once from its start cell; a T/L overlap credits its row run and its
# column run both.
func _award_runs(board: GridBoardState, cells: Array[Vector2i]) -> void:
	var in_clear: Dictionary = {}
	for cell: Vector2i in cells:
		in_clear[cell] = true
	_award_scan(board, in_clear, Vector2i(1, 0))
	_award_scan(board, in_clear, Vector2i(0, 1))

func _award_scan(board: GridBoardState, in_clear: Dictionary, step: Vector2i) -> void:
	for cell: Vector2i in in_clear:
		var kind: int = _kind_at(board, cell.x, cell.y)
		if kind < 0:
			continue
		var previous: Vector2i = cell - step
		if in_clear.has(previous) and _kind_at(board, previous.x, previous.y) == kind:
			continue  # not the start of a run in this direction
		var length: int = 0
		var walker: Vector2i = cell
		while in_clear.has(walker) and _kind_at(board, walker.x, walker.y) == kind:
			length += 1
			walker += step
		_award(kind, _match_points(length))

func _award(kind: int, quantity: int) -> void:
	if quantity <= 0 or _inventory == null or kind < 0 or kind >= _COMPONENTS.size():
		return
	var no_tags: Array[Item.Tag] = []
	_inventory.add_variant(_COMPONENTS[kind], no_tags, quantity)

# Components recycled from one cleared run, by length, on a Fibonacci curve: 3→1, 4→2, 5→3, 6→5, 7→8…
func _match_points(run_length: int) -> int:
	if run_length < _MIN_RUN:
		return 0
	var previous: int = 1
	var current: int = 2
	for _step: int in range(run_length - _MIN_RUN):
		var next: int = previous + current
		previous = current
		current = next
	return previous

func _on_move_resolved(made_match: bool, cells_cleared: int) -> void:
	if not made_match:
		_message = "No match — try another swap."
	elif cells_cleared > 0:
		_message = "Recycled %d component(s)." % cells_cleared
	else:
		_message = "Swapped."
	_compose_status()
	_refresh_inventory()

func _make_tile(object: BoardObjectState) -> Node2D:
	var tile := RecyclingTile.new()
	var component := object as _TileState
	var kind: int = component.kind if component != null else 0
	tile.kind = kind
	tile.tint = _COMPONENTS[kind].color
	return tile

func _spawn_tile(_board: GridBoardState, cell: Vector2i) -> BoardObjectState:
	var cells: Array[Vector2i] = [cell]
	return _TileState.new(cells, _pick_kind())

func _generate_board() -> GridBoardState:
	var state := GridBoardState.new(_BOARD_WIDTH, _BOARD_HEIGHT, 1)
	# One stream feeds generation and refills.
	_rng.seed = _session.derive_seed("tiles")
	for y: int in _BOARD_HEIGHT:
		for x: int in _BOARD_WIDTH:
			var cells: Array[Vector2i] = [Vector2i(x, y)]
			state.place_object(0, _TileState.new(cells, _pick_kind_avoiding_runs(state, x, y)))
	return state

# An equal-frequency kind for a refill — the board is a generator, so it can't stall and a refill may
# roll a fresh match (the cascades).
func _pick_kind() -> int:
	return _rng.randi_range(0, _KIND_COUNT - 1)

# A kind for cell (x, y) that doesn't complete a 3-run there, so a freshly generated board starts
# stable; equal-frequency among the safe kinds.
func _pick_kind_avoiding_runs(state: GridBoardState, x: int, y: int) -> int:
	var safe: Array[int] = []
	for kind: int in _KIND_COUNT:
		if not _would_complete_run(state, x, y, kind):
			safe.append(kind)
	if safe.is_empty():
		return _pick_kind()
	return safe[_rng.randi_range(0, safe.size() - 1)]

func _would_complete_run(state: GridBoardState, x: int, y: int, kind: int) -> bool:
	if x >= 2 and _kind_at(state, x - 1, y) == kind and _kind_at(state, x - 2, y) == kind:
		return true
	if y >= 2 and _kind_at(state, x, y - 1) == kind and _kind_at(state, x, y - 2) == kind:
		return true
	return false

func _kind_at(state: GridBoardState, x: int, y: int) -> int:
	var tile := state.get_object_at(0, x, y) as _TileState
	if tile == null:
		return -1
	return tile.kind

func _on_regenerated() -> void:
	if _grid == null:
		return
	_canvas.recenter()
	_match_view.drop_in()
	_refresh_inventory()

func _on_reset_pressed() -> void:
	_session.regenerate()
	_message = "Match components to recycle them. %d-in-a-row clears." % _MIN_RUN
	_compose_status()

#endregion

#region View-model

func _refresh_inventory() -> void:
	_rebuild_detail()
	inventory_changed.emit()

func inventory_chips() -> Array[InventoryChip]:
	var chips: Array[InventoryChip] = []
	if _inventory == null:
		return chips
	var scrap: int = 0
	var components: int = 0
	var modules: int = 0
	for stack: ItemStack in _inventory.get_stacks():
		if stack.item_blueprint == null:
			continue
		match stack.item_blueprint.category:
			Item.Category.SCRAP:
				scrap += stack.quantity
			Item.Category.COMPONENT:
				components += stack.quantity
			Item.Category.MODULE:
				modules += stack.quantity
	chips.append(InventoryChip.new("Scrap", scrap, _SCRAP_COLOR))
	chips.append(InventoryChip.new("Components", components, _COMPONENT_COLOR))
	chips.append(InventoryChip.new("Modules", modules, _MODULE_COLOR))
	return chips

# Tap-to-expand: the full per-stack breakdown the strip can't fit, in a scrolling list.
func inventory_detail() -> Control:
	if _detail == null:
		_detail = ScrollContainer.new()
		_detail.custom_minimum_size = Vector2(0, 360)
		_detail.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_detail_list = VBoxContainer.new()
		_detail_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_detail.add_child(_detail_list)
		_rebuild_detail()
	return _detail

func _rebuild_detail() -> void:
	if _detail_list == null:
		return
	for child: Node in _detail_list.get_children():
		child.queue_free()
	if _inventory == null:
		return
	for stack: ItemStack in _inventory.get_stacks():
		if stack.item_blueprint == null or stack.quantity <= 0:
			continue
		var row := Label.new()
		row.text = "%s  ×%d" % [stack.display_name, stack.quantity]
		_detail_list.add_child(row)

#endregion

## Single-cell component tile. `kind` doubles into `state["kind"]`, which is what [[MatchCondition]]'s
## default resolver matches on.
class _TileState extends BoardObjectState:
	var kind: int

	func _init(occupied_cells: Array[Vector2i] = [], tile_kind: int = 0) -> void:
		super (occupied_cells)
		kind = tile_kind
		state["kind"] = tile_kind
