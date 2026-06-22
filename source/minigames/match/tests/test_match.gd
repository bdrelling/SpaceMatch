extends GdUnitTestSuite
## MatchMinigame (match-3). The board is an equal-frequency generator, so it always lays down a full
## field of tiles.

func _make(rules: MatchRules = null, mode := MatchBoardView.InputMode.SWAP) -> MatchMinigame:
	var scene: PackedScene = load("res://minigames/match/match.tscn")
	var game: MatchMinigame = scene.instantiate()
	game.board_seed = 4242
	game.input_mode = mode
	# Insulate the existing behaviour tests from the spawn weights and extra-turn rule: a neutral
	# ruleset (no extra turns, uniform spawn) unless a test asks for a specific one.
	game.rules = rules if rules != null else MatchRules.new()
	add_child(game)
	return game

func test_board_fills_completely() -> void:
	var game := _make()
	await await_idle_frame()
	var state: GridState = game._session.state
	var placed: int = 0
	for y: int in 8:
		for x: int in 8:
			if state.get_object_at(0, x, y) != null:
				placed += 1
	assert_int(placed).is_equal(64)
	game.queue_free()

# Combat (kind 0) is a stat readout, so its number includes the matched-tile tally.
const _COMBAT_KIND: int = 0
const _SCRAP_KIND: int = 4
const _ANOMALY_KIND: int = 5
const _DAMAGE_KIND: int = 6

# The portraits show only the four colored stat tiles — scrap, anomaly, and damage aren't ship stats.
func test_portrait_shows_only_four_stat_readouts() -> void:
	var game := _make()
	await await_idle_frame()
	assert_int(game._player_readouts().size()).is_equal(4)
	assert_int(game._opponent_readouts().size()).is_equal(4)
	game.queue_free()

# Matching scrap tiles on the player's turn banks scrap into the wallet (the nav-bar currency).
func test_scrap_match_earns_wallet() -> void:
	var game := _make()
	game.bind_session(GameSession.new_game())
	await await_idle_frame()
	var board: GridState = game._session.state
	var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	_force_kind(board, cells, _SCRAP_KIND)
	var before: int = game._game_session.state.wallet.scrap
	# Turn 1 is the player's — scrap goes to their wallet.
	game._on_cells_cleared(board, cells)
	assert_int(game._game_session.state.wallet.scrap).is_equal(before + 3)
	game.queue_free()

# Matching damage tiles on the player's turn deals that much damage to the opponent's health.
func test_damage_match_hurts_opponent() -> void:
	var game := _make()
	await await_idle_frame()
	var board: GridState = game._session.state
	var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
	_force_kind(board, cells, _DAMAGE_KIND)
	var max_health: int = game._encounter.max_health
	# Turn 1 is the player's — their damage hits the opponent.
	game._on_cells_cleared(board, cells)
	assert_int(game._encounter.opponent_health).is_equal(max_health - 4)
	assert_int(game._encounter.player_health).is_equal(max_health)
	game.queue_free()

# Anomaly tiles are inert for now — matching them touches no wallet, health, or tally.
func test_anomaly_match_does_nothing() -> void:
	var game := _make()
	await await_idle_frame()
	var board: GridState = game._session.state
	var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	_force_kind(board, cells, _ANOMALY_KIND)
	var health_before: int = game._encounter.opponent_health
	game._on_cells_cleared(board, cells)
	assert_int(game._encounter.opponent_health).is_equal(health_before)
	assert_int(game._player_tally[_ANOMALY_KIND]).is_equal(0)
	game.queue_free()

# A combatant's tally must only move its own portrait's readouts — the player's matches never show up
# under the opponent (the routing bug: a shared readout builder added the player tally to both).
func test_player_tally_banks_only_into_player_readout() -> void:
	var game := _make()
	await await_idle_frame()
	var player_before: int = int(game._player_readouts()[_COMBAT_KIND])
	var opponent_before: int = int(game._opponent_readouts()[_COMBAT_KIND])
	game._player_tally[_COMBAT_KIND] += 5
	assert_int(int(game._player_readouts()[_COMBAT_KIND])).is_equal(player_before + 5)
	assert_int(int(game._opponent_readouts()[_COMBAT_KIND])).is_equal(opponent_before)
	game.queue_free()

func test_opponent_tally_banks_only_into_opponent_readout() -> void:
	var game := _make()
	await await_idle_frame()
	var player_before: int = int(game._player_readouts()[_COMBAT_KIND])
	var opponent_before: int = int(game._opponent_readouts()[_COMBAT_KIND])
	game._opponent_tally[_COMBAT_KIND] += 5
	assert_int(int(game._opponent_readouts()[_COMBAT_KIND])).is_equal(opponent_before + 5)
	assert_int(int(game._player_readouts()[_COMBAT_KIND])).is_equal(player_before)
	game.queue_free()

# Cleared stat tiles bank into whichever combatant's turn it is, never the other's.
func test_clear_banks_to_active_combatant() -> void:
	var game := _make()
	await await_idle_frame()
	var board: GridState = game._session.state
	var cells: Array[Vector2i] = [Vector2i(0, 0)]
	var kind: int = _COMBAT_KIND
	_force_kind(board, cells, kind)

	# Turn 1 is the player's.
	assert_int(game._encounter.active_combatant()).is_equal(EncounterState.Combatant.PLAYER)
	game._on_cells_cleared(board, cells)
	assert_int(game._player_tally[kind]).is_equal(1)
	assert_int(game._opponent_tally[kind]).is_equal(0)

	# After a turn flips to the opponent, the same clear banks to them instead.
	game._encounter.advance_turn()
	assert_int(game._encounter.active_combatant()).is_equal(EncounterState.Combatant.OPPONENT)
	game._on_cells_cleared(board, cells)
	assert_int(game._opponent_tally[kind]).is_equal(1)
	assert_int(game._player_tally[kind]).is_equal(1)
	game.queue_free()

# The encounter opens on the player (turn 1), and after the player moves the AI
# opponent takes its own turn unprompted, rolling play into round 2.
func test_opponent_takes_its_turn_automatically() -> void:
	var game := _make()
	game.opponent_move_delay = 0.0
	await await_idle_frame()
	# The board pours in on ready (drop_in marks the view busy for ~0.6s); wait it
	# out so the player's move isn't swallowed as input-during-animation.
	var settle_ms: int = 0
	while game._match_view._busy and settle_ms < 2000:
		await await_millis(50)
		settle_ms += 50
	assert_int(game._encounter.active_combatant()).is_equal(EncounterState.Combatant.PLAYER)
	# Play the player's turn with the same solver the AI uses for its own.
	var swap := game._session.find_interaction(GridInteraction.Gesture.SWIPE) as SwapInteraction
	var move: Array[Vector2i] = SwapSolver.best_move(game._session.state, swap)
	assert_array(move).is_not_empty()
	await game._match_view.perform_move(move)
	# The opponent now plays on its own; wait for its move and cascade to settle.
	var waited_ms: int = 0
	while game._encounter.round_number < 2 and waited_ms < 4000:
		await await_millis(100)
		waited_ms += 100
	assert_int(game._encounter.round_number).is_equal(2)
	assert_int(game._encounter.active_combatant()).is_equal(EncounterState.Combatant.PLAYER)
	game.queue_free()

# --- Rules: spawn weights and the extra-turn rule ---

# The standard ruleset matches the designed config: a run of four grants another turn, and the anomaly
# (kind 5) is rarer than every one of the four stat tiles.
func test_default_rules_match_the_designed_config() -> void:
	var rules := MatchRules.default()
	assert_int(rules.extra_turn_min_match).is_equal(4)
	for stat_kind: int in 4:
		assert_int(rules.weight_for(_ANOMALY_KIND)).is_less(rules.weight_for(stat_kind))

# A run of four or more keeps the board with the mover (the extra-turn rule), so the turn doesn't pass.
func test_match_of_four_grants_another_turn() -> void:
	var rules := MatchRules.new()
	rules.extra_turn_min_match = 4
	var game := _make(rules)
	await await_idle_frame()
	assert_int(game._encounter.active_combatant()).is_equal(EncounterState.Combatant.PLAYER)
	game._move_max_run = 4
	game._on_move_resolved(true, 4)
	assert_int(game._encounter.active_combatant()).is_equal(EncounterState.Combatant.PLAYER)
	assert_int(game._encounter.round_number).is_equal(1)
	game.queue_free()

# A run shorter than the threshold passes the turn as normal. Line-shift mode keeps the AI from auto-
# playing the handed-off turn, so the assertion sees the bare turn advance.
func test_match_below_threshold_passes_the_turn() -> void:
	var rules := MatchRules.new()
	rules.extra_turn_min_match = 4
	var game := _make(rules, MatchBoardView.InputMode.LINE_SHIFT)
	await await_idle_frame()
	game._move_max_run = 3
	game._on_move_resolved(true, 3)
	assert_int(game._encounter.active_combatant()).is_equal(EncounterState.Combatant.OPPONENT)
	game.queue_free()

# _longest_run measures the largest straight line in a cleared batch, not the cell count — four in a row
# is a match-4, while an L of four cells whose longest line is three is only a match-3.
func test_longest_run_measures_the_largest_straight_line() -> void:
	var game := _make()
	await await_idle_frame()
	var board: GridState = game._session.state
	var row: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
	_force_kind(board, row, 0)
	assert_int(game._longest_run(board, row)).is_equal(4)
	# An L: three across, one down off the end — longest straight line is three.
	var ell: Array[Vector2i] = [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(2, 3)]
	_force_kind(board, ell, 0)
	assert_int(game._longest_run(board, ell)).is_equal(3)
	game.queue_free()

# Spawn weights bias the pool: with the default ruleset the weight-5 anomaly is drawn far less often
# than a weight-20 stat tile over many refills.
func test_spawn_weights_bias_the_pool() -> void:
	var game := _make(MatchRules.default())
	await await_idle_frame()
	var anomaly: int = 0
	var combat: int = 0
	for _i: int in 800:
		var kind: int = game._pick_kind()
		if kind == _ANOMALY_KIND:
			anomaly += 1
		elif kind == 0:
			combat += 1
	assert_int(anomaly).is_less(combat)
	game.queue_free()

# Overwrites the kind of each given cell's tile in place — for building a known run to measure.
func _force_kind(board: GridState, cells: Array[Vector2i], kind: int) -> void:
	for cell: Vector2i in cells:
		var tile: GridObjectState = board.get_object_at(0, cell.x, cell.y)
		tile.set("kind", kind)
		tile.state["kind"] = kind

# The solver returns a swap that the match condition agrees is a match.
func test_solver_finds_a_matching_swap() -> void:
	var condition := MatchLineCondition.new()
	condition.min_run_length = 3
	# Rows R R G / B G R / G B R — swapping (2,0) with (2,1) completes R R R on top.
	var state := _board(3, 3, "RRGBGRGBR")
	var swap := SwapInteraction.new()
	swap.match_condition = condition
	var move: Array[Vector2i] = SwapSolver.best_move(state, swap)
	assert_array(move).is_not_empty()
	assert_bool(_swap_makes_match(state, condition, move[0], move[1])).is_true()

# A board too small for any run returns no move (the dead-board signal to pass).
func test_solver_returns_empty_when_no_swap_matches() -> void:
	var condition := MatchLineCondition.new()
	condition.min_run_length = 3
	var state := _board(2, 2, "RGBY")
	var swap := SwapInteraction.new()
	swap.match_condition = condition
	assert_array(SwapSolver.best_move(state, swap)).is_empty()

const _KIND_IDS := {"R": 0, "G": 1, "B": 2, "Y": 3}

# Builds a single-layer GridState from a row-major string of kind letters
# (index 0 is cell (0, 0), filling left-to-right then top-to-bottom).
func _board(width: int, height: int, kinds: String) -> GridState:
	var state := GridState.new(width, height, 1)
	for i: int in kinds.length():
		var cells: Array[Vector2i] = [Vector2i(i % width, i / width)]
		state.place_object(0, GridObjectState.new(cells, {"kind": _KIND_IDS[kinds[i]]}))
	return state

# Whether swapping the two cells' kinds forms a match at either — mirrors the
# solver's own gate, used to re-validate the move it picked.
func _swap_makes_match(state: GridState, condition: MatchLineCondition, a: Vector2i, b: Vector2i) -> bool:
	var object_a: GridObjectState = state.get_object_at(0, a.x, a.y)
	var object_b: GridObjectState = state.get_object_at(0, b.x, b.y)
	var kind_a: Variant = object_a.state.get("kind")
	var kind_b: Variant = object_b.state.get("kind")
	object_a.state["kind"] = kind_b
	object_b.state["kind"] = kind_a
	var matches: Array[Vector2i] = condition.find_matches(state)
	object_a.state["kind"] = kind_a
	object_b.state["kind"] = kind_b
	return matches.has(a) or matches.has(b)
