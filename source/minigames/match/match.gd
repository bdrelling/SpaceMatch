class_name MatchMinigame
extends Minigame
## Match-3 minigame. A board of tiles: grab a tile and drag it toward a neighbour to swap
## ([[SwapInteraction]]), line up three-or-more of one kind and they pop ([[MatchClearPassive]]). Tiles
## fall and fresh ones stream in ([[GravityPassive]]); the board is an equal-frequency generator, so it
## never stalls. Self-contained — it owns its tiles and rules and references nothing outside this folder.

const _BOARD_WIDTH: int = 8
const _BOARD_HEIGHT: int = 8
const _CELL_SIZE: float = 64.0
const _MIN_RUN: int = 3
const _KIND_COUNT: int = MatchTile.KIND_COUNT

## Forwarded to the blueprint as the board's seed. Zero rolls a fresh board each generation.
@export var board_seed: int = 0

## How the player moves tiles: swap a neighbour, slide a run, or trace a path.
@export var input_mode: MatchBoardView.InputMode = MatchBoardView.InputMode.SWAP
## Count diagonals as adjacent (matches, swaps, connect steps). The one knob.
@export var allow_diagonal: bool = false

@onready var _canvas: BoardCanvas = %BoardCanvas

var _message: String = ""

var _session: GridSession
var _view: GridView
var _grid: Grid
var _match_view: MatchBoardView
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	var blueprint := MatchBlueprint.new()
	blueprint.rng_seed = board_seed
	blueprint.input_mode = input_mode
	blueprint.allow_diagonal = allow_diagonal
	blueprint.build()
	_session = GridSession.create(blueprint)
	_session.generator = CallableGridGenerator.create(_generate_board)

	_view = GridView.new()
	_view.configure(_BOARD_WIDTH, _BOARD_HEIGHT, _CELL_SIZE)
	_grid = _view.grid
	_match_view = MatchBoardView.new()
	_match_view.input_mode = input_mode
	_view.add_child(_match_view)
	_canvas.set_board(_view, _view.content_size())
	_match_view.setup(_session, _grid, _make_tile, _spawn_tile)
	_match_view.move_resolved.connect(_on_move_resolved)
	# The canvas feeds pointer events to the view from its _gui_input.
	_canvas.input_handler = _match_view.handle_event

	_session.regenerated.connect(_on_regenerated)
	_session.regenerate()
	_message = _prompt_for_mode()
	_compose_status()

	# The "Player" box in the HUD drills into Outfitting. The board names no destination — it just asks
	# the shell to drill (see [signal Minigame.drill_requested]).
	(%PlayerBox as Button).pressed.connect(func() -> void: drill_requested.emit())

func actions() -> Array[MinigameAction]:
	var none: Array[MinigameAction] = []
	return none

#region Match-3

func _compose_status() -> void:
	status_text = _message

func _on_move_resolved(made_match: bool, cells_cleared: int) -> void:
	if not made_match:
		_message = "No match — try another move."
	elif cells_cleared > 0:
		_message = "Cleared %d tiles." % cells_cleared
	else:
		_message = "Moved."
	_compose_status()

## The how-to-play line for the active input mode.
func _prompt_for_mode() -> String:
	match input_mode:
		MatchBoardView.InputMode.CONNECT:
			return "Drag through %d+ matching tiles to clear them." % _MIN_RUN
		MatchBoardView.InputMode.LINE_SHIFT:
			return "Slide a tile along a row or column to match %d." % _MIN_RUN
		_:
			return "Match %d in a row to clear." % _MIN_RUN

func _make_tile(object: GridObjectState) -> Node2D:
	var tile := MatchTile.new()
	var tile_state := object as _TileState
	tile.kind = tile_state.kind if tile_state != null else 0
	return tile

func _spawn_tile(_board: GridState, cell: Vector2i) -> GridObjectState:
	var cells: Array[Vector2i] = [cell]
	return _TileState.new(cells, _pick_kind())

func _generate_board() -> GridState:
	var state := GridState.new(_BOARD_WIDTH, _BOARD_HEIGHT, 1)
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
func _pick_kind_avoiding_runs(state: GridState, x: int, y: int) -> int:
	var safe: Array[int] = []
	for kind: int in _KIND_COUNT:
		if not _would_complete_run(state, x, y, kind):
			safe.append(kind)
	if safe.is_empty():
		return _pick_kind()
	return safe[_rng.randi_range(0, safe.size() - 1)]

func _would_complete_run(state: GridState, x: int, y: int, kind: int) -> bool:
	if x >= 2 and _kind_at(state, x - 1, y) == kind and _kind_at(state, x - 2, y) == kind:
		return true
	if y >= 2 and _kind_at(state, x, y - 1) == kind and _kind_at(state, x, y - 2) == kind:
		return true
	return false

func _kind_at(state: GridState, x: int, y: int) -> int:
	var tile := state.get_object_at(0, x, y) as _TileState
	if tile == null:
		return -1
	return tile.kind

func _on_regenerated() -> void:
	if _grid == null:
		return
	_canvas.recenter()
	_match_view.drop_in()

#endregion

## Single-cell tile. `kind` doubles into `state["kind"]`, which is what [[MatchCondition]]'s default
## resolver matches on.
class _TileState extends GridObjectState:
	var kind: int

	func _init(occupied_cells: Array[Vector2i] = [], tile_kind: int = 0) -> void:
		super (occupied_cells)
		kind = tile_kind
		state["kind"] = tile_kind
