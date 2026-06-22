extends GdUnitTestSuite
## MatchMinigame (match-3). The board is an equal-frequency generator, so it always lays down a full
## field of tiles.

func _make() -> MatchMinigame:
	var scene: PackedScene = load("res://minigames/match/match.tscn")
	var game: MatchMinigame = scene.instantiate()
	game.board_seed = 4242
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
# Scrap (kind 4) is the currency readout — it must accumulate matched tiles too (player), but the
# wallet-less opponent shows "—".
const _SCRAP_KIND: int = 4

# Matching scrap tiles banks into the player's scrap readout (regression: the scrap slot skipped the
# tally, so scrap matches never counted).
func test_scrap_tally_banks_into_player_readout() -> void:
	var game := _make()
	await await_idle_frame()
	var before: int = int(game._player_readouts()[_SCRAP_KIND])
	game._player_tally[_SCRAP_KIND] += 3
	assert_int(int(game._player_readouts()[_SCRAP_KIND])).is_equal(before + 3)
	game.queue_free()

# The wallet-less opponent always shows "—" for scrap, tally or not.
func test_opponent_scrap_stays_dashed() -> void:
	var game := _make()
	await await_idle_frame()
	assert_str(game._opponent_readouts()[_SCRAP_KIND]).is_equal("—")
	game._opponent_tally[_SCRAP_KIND] += 3
	assert_str(game._opponent_readouts()[_SCRAP_KIND]).is_equal("—")
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

# Cleared tiles bank into whichever combatant's turn it is, never the other's.
func test_clear_banks_to_active_combatant() -> void:
	var game := _make()
	await await_idle_frame()
	var board: GridState = game._session.state
	var cells: Array[Vector2i] = [Vector2i(0, 0)]
	var kind: int = game._kind_at(board, 0, 0)

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
