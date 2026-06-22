class_name MatchMinigame
extends Minigame
## Match-3 minigame. A board of tiles: grab a tile and drag it toward a neighbour to swap
## ([[SwapInteraction]]), line up three-or-more of one kind and they pop ([[MatchClearPassive]]). Tiles
## fall and fresh ones stream in ([[GravityPassive]]); the board is an equal-frequency generator, so it
## never stalls. The board owns its tiles and rules; the encounter HUD around it (the two portraits)
## reads the bound game's starship stats and [Wallet] once a session is bound.

const _BOARD_WIDTH: int = 8
const _BOARD_HEIGHT: int = 8
const _CELL_SIZE: float = 64.0
const _MIN_RUN: int = 3
const _KIND_COUNT: int = MatchTile.KIND_COUNT

# Tile kind → the starship stat shown beneath the player portrait, in [MatchTile] kind order. Scrap
# (kind 4) shows the currency balance instead; the sixth tile (anomaly) has no stat yet (TBD).
const _STAT_FOR_KIND := {
	0: Stat.Type.POWER,    # combat — red
	1: Stat.Type.SPEED,    # propulsion — yellow
	2: Stat.Type.SENSORS,  # science — green
	3: Stat.Type.SHIELDS,  # defense — blue
}
const _SCRAP_KIND: int = 4

## Forwarded to the blueprint as the board's seed. Zero rolls a fresh board each generation.
@export var board_seed: int = 0

## How the player moves tiles: swap a neighbour, slide a run, or trace a path.
@export var input_mode: MatchBoardView.InputMode = MatchBoardView.InputMode.SWAP
## Count diagonals as adjacent (matches, swaps, connect steps). The one knob.
@export var allow_diagonal: bool = false

@onready var _canvas: BoardCanvas = %BoardCanvas
@onready var _player_portrait: PortraitPanel = %PlayerPortrait
@onready var _opponent_portrait: PortraitPanel = %OpponentPortrait
@onready var _round_label: Label = %RoundLabel
@onready var _turn_label: Label = %TurnLabel

var _message: String = ""
var _game_session: GameSession
var _encounter: EncounterState

var _session: GridSession
var _view: GridView
var _grid: Grid
var _match_view: MatchBoardView
var _gravity: MatchGravity
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

	# The "unlock" mechanic: an idle physics overlay mounted alongside the board, woken by a keypress.
	_gravity = MatchGravity.new()
	_gravity.setup(_CELL_SIZE, _BOARD_WIDTH, _BOARD_HEIGHT, _session, _spawn_tile)
	_canvas.add_child(_gravity)

	_session.regenerated.connect(_on_regenerated)
	_session.regenerate()
	_message = _prompt_for_mode()
	_compose_status()

	# Tapping your own portrait drills into Outfitting (read-only viewing is TBD); tapping the opponent
	# opens their intel (TBD — no opponent entity yet). The board names no destination — it just asks the
	# shell to drill (see [signal Minigame.drill_requested]).
	_player_portrait.pressed.connect(func() -> void: drill_requested.emit())
	_opponent_portrait.pressed.connect(_on_opponent_pressed)

	# A transient encounter so the screen stands alone (e.g. running match.tscn directly); a bound
	# session swaps in its own in [method bind_session].
	if _encounter == null:
		_encounter = EncounterState.new()
	_refresh_portraits()
	_refresh_turn_tracker()

func actions() -> Array[MinigameAction]:
	var none: Array[MinigameAction] = []
	return none

#region Portraits

## Binds the running game so the portraits can read each ship's stats and the player's [Wallet], and
## the top row can track the encounter's turns. Called by [MinigameScreen] when the game mounts this
## page. Adopts the session's [EncounterState] (creating one if the encounter hasn't started).
func bind_session(session: GameSession) -> void:
	_game_session = session
	if _game_session.state.encounter == null:
		_game_session.state.encounter = EncounterState.new()
	_encounter = _game_session.state.encounter
	_refresh_portraits()
	_refresh_turn_tracker()

func _refresh_portraits() -> void:
	if _player_portrait != null:
		_player_portrait.set_readouts(_player_readouts())
	if _opponent_portrait != null:
		_opponent_portrait.set_readouts(_opponent_readouts())

# The six readouts beneath the player portrait, tile-kind ordered: four starship stats, the scrap
# balance, and the anomaly placeholder.
func _player_readouts() -> PackedStringArray:
	var scrap: int = 0
	var starship: StarshipState = null
	if _game_session != null and _game_session.state != null:
		starship = _game_session.state.starship
		if _game_session.state.wallet != null:
			scrap = _game_session.state.wallet.scrap
	return _readouts_for(_profile_for(starship), scrap)

# The opponent's readouts, read from the encounter's ship. It owns no [Wallet], so scrap shows "—".
func _opponent_readouts() -> PackedStringArray:
	var starship: StarshipState = _encounter.opponent if _encounter != null else null
	return _readouts_for(_profile_for(starship), -1)

# Lays a stat profile out as the six tile-kind-ordered readouts: four stats, scrap (negative ⇒ "—",
# for combatants with no wallet), and the anomaly placeholder.
func _readouts_for(profile: StatBlock, scrap: int) -> PackedStringArray:
	var out := PackedStringArray()
	for kind: int in MatchTile.KIND_COUNT:
		if kind == _SCRAP_KIND:
			out.append(str(scrap) if scrap >= 0 else "—")
		elif _STAT_FOR_KIND.has(kind):
			var stat: Stat.Type = _STAT_FOR_KIND[kind]
			out.append(str(profile.value(stat)))
		else:
			out.append("—")  # anomaly — no stat yet (TBD)
	return out

# A starship's summed stat profile (zeros when null or no modules are slotted). Summed here in the
# view rather than on [ModuleGrid] — the grid is owned elsewhere; this just reads it.
func _profile_for(starship: StarshipState) -> StatBlock:
	var total := StatBlock.new()
	if starship == null or starship.module_grid == null:
		return total
	for placed: PlacedModule in starship.module_grid.placed_modules():
		if placed.module != null:
			total.add(placed.module.stats)
	return total

# Tapping the opponent will open their intel (module layout / skills / hints) — TBD, no opponent yet.
func _on_opponent_pressed() -> void:
	_message = "Opponent intel — TBD."
	_compose_status()

#endregion

# Press G to unlock gravity — the tiles fall off the board into a physics heap. One-way for now.
func _unhandled_key_input(event: InputEvent) -> void:
	if _gravity == null or _gravity.is_active():
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_G:
		_unlock()
		get_viewport().set_input_as_handled()

# Mount the overlay on the board's current on-screen framing, hand physics the tiles, and kill swap input.
func _unlock() -> void:
	_gravity.position = _view.position
	_gravity.unlock(_grid, _view.scale.x)
	_canvas.input_handler = func(_event: InputEvent) -> bool: return false
	_message = "Gravity unlocked — the tiles broke free."
	_compose_status()

#region Match-3

func _compose_status() -> void:
	status_text = _message

# A resolved move ends the active combatant's turn and hands the board to the next (both human for
# now — same board, just whose turn it is). A failed swap doesn't burn a turn.
func _on_move_resolved(made_match: bool, cells_cleared: int) -> void:
	if not made_match:
		_message = "No match — try another move."
		_compose_status()
		return
	var mover: String = _active_name()
	if _encounter != null:
		_encounter.advance_turn()
		_refresh_turn_tracker()
	if cells_cleared > 0:
		_message = "%s cleared %d tiles — %s's turn." % [mover, cells_cleared, _active_name()]
	else:
		_message = "%s moved — %s's turn." % [mover, _active_name()]
	_compose_status()

# Repaints the top row (round, turn-of-round, whose turn) and highlights the active portrait.
func _refresh_turn_tracker() -> void:
	if _encounter == null:
		return
	if _round_label != null:
		_round_label.text = "ROUND %d" % _encounter.round_number
	if _turn_label != null:
		var who: String = _name_for(_encounter.active_combatant()).to_upper()
		_turn_label.text = "TURN %d / %d · %s" % [_encounter.turn_in_round, EncounterState.TURNS_PER_ROUND, who]
	if _player_portrait != null:
		_player_portrait.set_active(_encounter.active_combatant() == EncounterState.Combatant.PLAYER)
	if _opponent_portrait != null:
		_opponent_portrait.set_active(_encounter.active_combatant() == EncounterState.Combatant.OPPONENT)

# The display name of the combatant whose turn it currently is.
func _active_name() -> String:
	if _encounter == null:
		return _player_portrait.portrait_name
	return _name_for(_encounter.active_combatant())

func _name_for(combatant: EncounterState.Combatant) -> String:
	if combatant == EncounterState.Combatant.OPPONENT:
		return _opponent_portrait.portrait_name
	return _player_portrait.portrait_name

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
