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

# The four colored stat tiles (combat, propulsion, science, defense) whose match counts show as
# resources beneath the portraits, in [MatchTile] kind order — index-aligned with PortraitPanel's strip.
# The other three kinds route elsewhere: scrap (kind 4) banks into the wallet, damage (kind 6) depletes
# the opposing combatant's health, and anomaly (kind 5) is inert for now.
const _STAT_KINDS: Array[int] = [0, 1, 2, 3]
const _SCRAP_KIND: int = 4
const _ANOMALY_KIND: int = 5
const _DAMAGE_KIND: int = 6

## Forwarded to the blueprint as the board's seed. Zero rolls a fresh board each generation.
@export var board_seed: int = 0

## How the player moves tiles: swap a neighbour, slide a run, or trace a path.
@export var input_mode: MatchBoardView.InputMode = MatchBoardView.InputMode.SWAP
## Count diagonals as adjacent (matches, swaps, connect steps). The one knob.
@export var allow_diagonal: bool = false
## How long the AI opponent "thinks" before playing its swap, so the move reads as
## a deliberate beat rather than an instant jump. Zero plays immediately.
@export var opponent_move_delay: float = 0.6
## The swappable rules for this encounter — spawn weights and the extra-turn threshold. Left unset, the
## board falls back to [method MatchRules.default] (the standard SpaceMatch set) so it plays standalone.
@export var rules: MatchRules

@onready var _canvas: BoardCanvas = %BoardCanvas
@onready var _player_portrait: PortraitPanel = %PlayerPortrait
@onready var _opponent_portrait: PortraitPanel = %OpponentPortrait
@onready var _round_label: Label = %RoundLabel
@onready var _turn_label: Label = %TurnLabel
@onready var _actions: HBoxContainer = %Actions

var _message: String = ""
var _game_session: GameSession
var _encounter: EncounterState

# Running per-kind count of tiles cleared by each combatant this encounter; added onto the portrait
# stat readouts so matches visibly bank into the numbers.
var _player_tally := PackedInt32Array()
var _opponent_tally := PackedInt32Array()

var _session: GridSession
var _view: GridView
var _grid: Grid
var _match_view: MatchBoardView
var _gravity: MatchGravity
var _rng := RandomNumberGenerator.new()

# Every tile kind, cached as the default spawn pool so refills don't rebuild the list each cascade step.
var _all_kinds: Array[int] = []
# The longest straight run cleared during the move in progress, accumulated across its cascade steps in
# [method _on_cells_cleared] and read by [method _on_move_resolved] for the extra-turn rule.
var _move_max_run: int = 0

func _ready() -> void:
	# Fall back to the standard ruleset so the board plays when mounted without one (e.g. standalone).
	if rules == null:
		rules = MatchRules.default()
	for kind: int in _KIND_COUNT:
		_all_kinds.append(kind)

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
	# The canvas feeds pointer events to the view from its _gui_input, gated so the
	# human can't move during the AI opponent's turn.
	_canvas.input_handler = _on_board_input

	# Tally cleared tiles by kind: hook each clear pass so every popped tile banks into the active
	# combatant's readouts (SWAP / LINE_SHIFT modes use a MatchClearPassive; CONNECT clears inline, so it won't tally).
	_player_tally.resize(_KIND_COUNT)
	_opponent_tally.resize(_KIND_COUNT)
	for clearer: MatchClearPassive in _session.find_rules(MatchClearPassive):
		clearer.on_clear = _on_cells_cleared

	# The "unlock" mechanic: an idle physics overlay mounted alongside the board, woken by a keypress.
	_gravity = MatchGravity.new()
	_gravity.setup(_CELL_SIZE, _BOARD_WIDTH, _BOARD_HEIGHT, _session, _spawn_tile)
	_canvas.add_child(_gravity)

	_session.regenerated.connect(_on_regenerated)
	_session.regenerate()
	_message = _prompt_for_mode()
	_compose_status()

	# Tapping a portrait drills into that combatant's module grid. The board names no screen — it just
	# asks the shell to drill and hands it whose ship to show (see [signal Minigame.drill_requested]).
	_player_portrait.pressed.connect(_on_player_pressed)
	_opponent_portrait.pressed.connect(_on_opponent_pressed)

	# A transient encounter so the screen stands alone (e.g. running match.tscn directly); a bound
	# session swaps in its own in [method bind_session].
	if _encounter == null:
		_encounter = EncounterState.new()
	_refresh_portraits()
	_refresh_turn_tracker()

	# The four action buttons under the board are placeholders — each just reports itself for now.
	for button: Button in _actions.get_children():
		button.pressed.connect(_on_action_pressed.bind(button.text))

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
		_player_portrait.set_module_grid(_grid_of(_player_starship()))
	if _opponent_portrait != null:
		_opponent_portrait.set_readouts(_opponent_readouts())
		_opponent_portrait.set_module_grid(_grid_of(_opponent_starship()))
	_refresh_health()

# Repaints both portraits' health bars from the encounter's current health.
func _refresh_health() -> void:
	if _encounter == null:
		return
	if _player_portrait != null:
		_player_portrait.set_health(_encounter.player_health, _encounter.max_health)
	if _opponent_portrait != null:
		_opponent_portrait.set_health(_encounter.opponent_health, _encounter.max_health)

# The four resource readouts beneath the player portrait, in [constant _STAT_KINDS] order (combat,
# propulsion, science, defense): the tiles the player has matched of each kind this encounter. Starts at
# zero — these are matched-this-fight resources, not the ship's base stats (those live on the stats screen).
func _player_readouts() -> PackedStringArray:
	return _readouts_for(_player_tally)

# The opponent's four resource readouts — its own matched-this-encounter tally.
func _opponent_readouts() -> PackedStringArray:
	return _readouts_for(_opponent_tally)

# Lays a combatant's tally out as the four stat-tile readouts: the count matched of each kind this fight.
func _readouts_for(tally: PackedInt32Array) -> PackedStringArray:
	var out := PackedStringArray()
	for kind: int in _STAT_KINDS:
		out.append(str(_tally_at(tally, kind)))
	return out

# A kind's running matched-tile count from a combatant's tally (zero before the tally is sized in _ready).
func _tally_at(tally: PackedInt32Array, kind: int) -> int:
	if kind < 0 or kind >= tally.size():
		return 0
	return tally[kind]

# Drills into a combatant's module grid: hands the shell that combatant's ship so the Outfitting stage
# opens it. No ship (e.g. running this scene standalone, no bound session) ⇒ no drill.
func _on_player_pressed() -> void:
	var starship: StarshipState = _player_starship()
	if starship != null:
		drill_requested.emit(starship)

func _on_opponent_pressed() -> void:
	var starship: StarshipState = _opponent_starship()
	if starship != null:
		drill_requested.emit(starship)

# The player's ship (the game's persistent starship) and the opponent's (the encounter's), null-safe.
func _player_starship() -> StarshipState:
	if _game_session != null and _game_session.state != null:
		return _game_session.state.starship
	return null

func _opponent_starship() -> StarshipState:
	return _encounter.opponent if _encounter != null else null

func _grid_of(starship: StarshipState) -> ModuleGrid:
	return starship.module_grid if starship != null else null

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

# A resolved move ends the active combatant's turn and hands the board to the next — unless the move
# cleared a run long enough for the [member MatchRules.extra_turn_min_match] rule, which keeps the board
# with the mover for another go. The player and the AI opponent both resolve through here — the
# opponent's swap re-enters this on completion, handing the turn back (or taking another), so the volley
# stops once it's the player's turn again. A failed swap doesn't burn a turn. Tallied matches bank into
# the portrait readouts and update between turns.
func _on_move_resolved(made_match: bool, cells_cleared: int) -> void:
	if not made_match:
		_move_max_run = 0
		_message = "No match — try another move."
		_compose_status()
		return
	var mover: String = _active_name()
	# Read and reset the move's longest run before the next move starts accumulating into it.
	var max_run: int = _move_max_run
	_move_max_run = 0
	# The tally grew during the cascade (via _on_cells_cleared) — fold the new totals into the readouts.
	_refresh_portraits()
	# The extra-turn rule: a long enough run lets the mover keep the board instead of passing it.
	var go_again: bool = rules.extra_turn_min_match > 0 and max_run >= rules.extra_turn_min_match
	if _encounter != null and not go_again:
		_encounter.advance_turn()
		_refresh_turn_tracker()
	if go_again:
		_message = "%s cleared %d tiles — match-%d, go again!" % [mover, cells_cleared, max_run]
	elif cells_cleared > 0:
		_message = "%s cleared %d tiles — %s's turn." % [mover, cells_cleared, _active_name()]
	else:
		_message = "%s moved — %s's turn." % [mover, _active_name()]
	_compose_status()
	_take_opponent_turn_if_needed()

#region AI opponent

# Routes pointer events to the board, but only when the human may act — the AI
# opponent's turn (its think beat and its move) is hands-off so the player can't
# move on its behalf.
func _on_board_input(event: InputEvent) -> bool:
	if not _accepts_player_input():
		return false
	return _match_view.handle_event(event)

func _accepts_player_input() -> bool:
	if _encounter == null or not _ai_controls_opponent():
		return true
	return _encounter.active_combatant() == EncounterState.Combatant.PLAYER

# The AI plays the opponent only on a swap board for now; the other input modes
# keep the opponent human-controlled on the shared board.
func _ai_controls_opponent() -> bool:
	return input_mode == MatchBoardView.InputMode.SWAP

# When the turn has passed to the AI opponent, think for a beat, then play the best
# swap the solver can find. Fire-and-forget: the resulting move re-enters
# [method _on_move_resolved], which hands the turn back to the player.
func _take_opponent_turn_if_needed() -> void:
	if not _ai_controls_opponent() or _match_view == null:
		return
	if _encounter == null or _encounter.active_combatant() != EncounterState.Combatant.OPPONENT:
		return
	if opponent_move_delay > 0.0:
		await get_tree().create_timer(opponent_move_delay).timeout
	# State can shift during the think beat (e.g. gravity unlocked) — re-check before moving.
	if _encounter.active_combatant() != EncounterState.Combatant.OPPONENT:
		return
	if _gravity != null and _gravity.is_active():
		return
	var swap := _session.find_interaction(GridInteraction.Gesture.SWIPE) as SwapInteraction
	var move: Array[Vector2i] = SwapSolver.best_move(_session.state, swap)
	if move.is_empty():
		_pass_opponent_turn()
		return
	await _match_view.perform_move(move)

# A dead board (no swap makes a match) — skip the opponent's move so play doesn't
# stall, handing the turn straight back to the player.
func _pass_opponent_turn() -> void:
	var passer: String = _active_name()
	if _encounter != null:
		_encounter.advance_turn()
		_refresh_turn_tracker()
	_message = "%s has no move — %s's turn." % [passer, _active_name()]
	_compose_status()

#endregion

# Per-clear hook on the [MatchClearPassive]: bank each popped tile into the active combatant's
# running tally. Fires once per cascade step with the cells about to be removed, so the kinds are
# still readable on the board.
func _on_cells_cleared(board: GridState, cells: Array[Vector2i]) -> void:
	# Track the longest straight run this move clears (across cascade steps) for the extra-turn rule.
	_move_max_run = maxi(_move_max_run, _longest_run(board, cells))
	if _encounter == null:
		return
	var active: int = _encounter.active_combatant()
	var scrap_cleared: int = 0
	var damage_cleared: int = 0
	for cell: Vector2i in cells:
		var kind: int = _kind_at(board, cell.x, cell.y)
		match kind:
			_SCRAP_KIND:
				scrap_cleared += 1
			_DAMAGE_KIND:
				damage_cleared += 1
			_ANOMALY_KIND:
				pass  # anomaly is inert for now — matched, but wired to nothing
			_:
				_bank_stat_tile(active, kind)
	# Scrap banks into the player's wallet (the opponent has none); damage depletes the other's health.
	if scrap_cleared > 0 and active == EncounterState.Combatant.PLAYER:
		_earn_scrap(scrap_cleared)
	if damage_cleared > 0:
		_encounter.deal_damage(_encounter.opponent_of(active), damage_cleared)
		# Apply to the bar immediately, on the match — not deferred to when the move resolves.
		_refresh_health()

# Banks one matched stat tile into the active combatant's running tally (the portrait readouts).
func _bank_stat_tile(active: int, kind: int) -> void:
	if kind < 0 or kind >= _player_tally.size():
		return
	if active == EncounterState.Combatant.PLAYER:
		_player_tally[kind] += 1
	else:
		_opponent_tally[kind] += 1

# Adds matched scrap to the player's wallet (a no-op without a bound session, e.g. the standalone scene).
func _earn_scrap(amount: int) -> void:
	if _game_session != null and _game_session.state != null and _game_session.state.wallet != null:
		_game_session.state.wallet.earn(amount)

func _on_action_pressed(action_name: String) -> void:
	_message = "%s — TBD." % action_name
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

# A weighted kind for a refill — the board is a generator, so it can't stall and a refill may roll a
# fresh match (the cascades). Weights come from the encounter [member rules].
func _pick_kind() -> int:
	return _weighted_choice(_all_kinds)

# A kind for cell (x, y) that doesn't complete a 3-run there, so a freshly generated board starts
# stable; weighted (per the rules) among the safe kinds.
func _pick_kind_avoiding_runs(state: GridState, x: int, y: int) -> int:
	var safe: Array[int] = []
	for kind: int in _KIND_COUNT:
		if not _would_complete_run(state, x, y, kind):
			safe.append(kind)
	if safe.is_empty():
		return _pick_kind()
	return _weighted_choice(safe)

# Roulette-wheel pick over [param candidates], each kind weighted by the rules' spawn weight and drawn
# from the board's seeded stream so generation stays reproducible. Falls back to a uniform pick when the
# candidates carry no weight at all.
func _weighted_choice(candidates: Array[int]) -> int:
	var total: int = 0
	for kind: int in candidates:
		total += rules.weight_for(kind)
	if total <= 0:
		return candidates[_rng.randi_range(0, candidates.size() - 1)]
	var roll: int = _rng.randi_range(0, total - 1)
	for kind: int in candidates:
		roll -= rules.weight_for(kind)
		if roll < 0:
			return kind
	return candidates[candidates.size() - 1]

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

# The length of the longest straight same-kind run within a cleared batch — what the extra-turn rule
# measures a "match-N" by. Walks each axis from the cells that start a run (no same-kind predecessor),
# so every maximal run is counted once. Diagonals are included for boards that match along them.
func _longest_run(board: GridState, cells: Array[Vector2i]) -> int:
	if cells.is_empty():
		return 0
	var kinds: Dictionary[Vector2i, int] = {}
	for cell: Vector2i in cells:
		kinds[cell] = _kind_at(board, cell.x, cell.y)
	var axes: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]
	var best: int = 1
	for cell: Vector2i in cells:
		var kind: int = kinds[cell]
		for axis: Vector2i in axes:
			if kinds.get(cell - axis, -1) == kind:
				continue  # not this run's head along the axis — it's measured from the head
			var length: int = 1
			var probe: Vector2i = cell + axis
			while kinds.get(probe, -1) == kind:
				length += 1
				probe += axis
			best = maxi(best, length)
	return best

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
