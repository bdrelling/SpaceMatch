extends MatchTestCase
## Match lifecycle: end/restart/rebind and the swap solver.


# A lethal match ends the Quick Match: the encounter is over and play is frozen.
func test_lethal_match_ends_the_quick_match() -> void:
	var game := _make()  # quick_match defaults true
	await await_idle_frame()
	game._encounter.opponent_health = 1
	var board: GridState = game._session.state
	var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	_force_kind(board, cells, _DAMAGE_KIND)
	game._on_cells_cleared(board, cells)  # deals 3, opponent to 0
	game._on_move_resolved(true, 3)
	assert_bool(game._encounter.is_over()).is_true()
	assert_bool(game._game_over).is_true()
	game.queue_free()


# Restart clears the game-over state, resets the encounter, and zeroes both tallies.
func test_restart_resets_the_encounter() -> void:
	var game := _make()
	await await_idle_frame()
	game._encounter.player.resources[0].amount = 9
	game._encounter.player_health = 3
	game._encounter.add_shield(game._encounter.player, 5)
	game._game_over = true
	game._restart_encounter()
	assert_int(game._encounter.player_health).is_equal(game._encounter.player_max_health)
	assert_int(game._encounter.shield_of(game._encounter.player)).is_equal(0)
	assert_int(game._encounter.player.resources[0].amount).is_equal(0)
	assert_bool(game._game_over).is_false()
	game.queue_free()


# The Settings-menu Restart rebuilds the session and rebinds every screen. A re-bind after a game-over has to
# clear the game-over/ended flags and adopt the fresh encounter — the menu Restart that used to do nothing
# because bind_session only swapped the encounter and left the frozen board (and _game_over) standing.
func test_rebind_restarts_a_finished_match() -> void:
	var game := _make()
	_host_bind(game)  # initial mount
	await await_idle_frame()
	game._encounter.player_health = 3
	game._game_over = true
	game._ended = true
	# The shell reopens the encounter and rebinds on Restart.
	_host_bind(game)
	await await_idle_frame()
	assert_bool(game._game_over).is_false()
	assert_bool(game._ended).is_false()
	assert_int(game._encounter.player_health).is_equal(game._encounter.player_max_health)
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


# count_moves reports how many adjacent swaps make a match — at least one on a board with a ready move.
func test_count_moves_counts_available_swaps() -> void:
	var condition := MatchLineCondition.new()
	condition.min_run_length = 3
	# RRGBGRGBR — swapping (2,0) with (2,1) completes RRR on the top row, so a move exists.
	var state := _board(3, 3, "RRGBGRGBR")
	var swap := SwapInteraction.new()
	swap.match_condition = condition
	assert_int(SwapSolver.count_moves(state, swap)).is_greater(0)


# A board too small for any run has zero moves — the dead-board signal that triggers a reshuffle.
func test_count_moves_zero_on_dead_board() -> void:
	var condition := MatchLineCondition.new()
	condition.min_run_length = 3
	var state := _board(2, 2, "RGBY")
	var swap := SwapInteraction.new()
	swap.match_condition = condition
	assert_int(SwapSolver.count_moves(state, swap)).is_equal(0)
