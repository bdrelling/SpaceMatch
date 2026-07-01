extends MatchTestCase
## Match-size measurement (runs, paths, diagonals) and spawn weighting.


# _largest_match is the single way a match's size is measured — every consumer uses it. In line mode a match
# is a straight run, and runs that share a cell merge: an L is 5, a T (4-arm + 3-arm) is 6. Two parallel runs
# that share no cell (a 3x2 block) stay two 3s — NOT a 6, which a blind flood-fill would wrongly report.
func test_match_size_merges_intersecting_runs_not_parallel_ones() -> void:
	var game := _make()
	await await_idle_frame()
	var board: GridState = game._session.state
	# A straight run of four is four of a kind.
	var row: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
	_force_kind(board, row, 0)
	assert_int(game._largest_match(board, row, false)).is_equal(4)
	# An L — three across, two down sharing the corner — is five of a kind (its longest arm is only three).
	var ell: Array[Vector2i] = [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(2, 3), Vector2i(2, 4)]
	_force_kind(board, ell, 0)
	assert_int(game._largest_match(board, ell, false)).is_equal(5)
	# A T — a 4-run crossing a 3-run at a shared cell — is six total tiles.
	var tee: Array[Vector2i] = [Vector2i(0, 6), Vector2i(1, 6), Vector2i(2, 6), Vector2i(3, 6), Vector2i(1, 5), Vector2i(1, 7)]
	_force_kind(board, tee, 0)
	assert_int(game._largest_match(board, tee, false)).is_equal(6)
	# A 3x2 block: two parallel 3-runs that share no cell. In line mode it's a match-3, never a 6.
	var block: Array[Vector2i] = [Vector2i(5, 0), Vector2i(6, 0), Vector2i(7, 0), Vector2i(5, 1), Vector2i(6, 1), Vector2i(7, 1)]
	_force_kind(board, block, 0)
	assert_int(game._largest_match(board, block, false)).is_equal(3)
	game.queue_free()


# Same six cells, cleared two ways: dragged whole (is_path) the path IS the match, so it's a 6; cleared as
# straight lines it's two 3s. The size must come from how it was cleared, never from re-reading the cells.
func test_match_size_path_clears_count_the_whole_path() -> void:
	var game := _make()
	await await_idle_frame()
	var board: GridState = game._session.state
	var block: Array[Vector2i] = [Vector2i(5, 0), Vector2i(6, 0), Vector2i(7, 0), Vector2i(5, 1), Vector2i(6, 1), Vector2i(7, 1)]
	_force_kind(board, block, 0)
	assert_int(game._largest_match(board, block, true)).is_equal(6)  # drag: the path is one match-6
	assert_int(game._largest_match(board, block, false)).is_equal(3)  # line: two parallel 3-runs
	game.queue_free()


# A diagonal run is a match only when the board matches along diagonals (the one allow_diagonal knob);
# orthogonally those cells form no run at all, so they read as singletons.
func test_match_size_diagonal_runs_follow_the_knob() -> void:
	var game := _make()
	await await_idle_frame()
	var board: GridState = game._session.state
	var diag: Array[Vector2i] = [Vector2i(4, 2), Vector2i(5, 3), Vector2i(6, 4)]
	_force_kind(board, diag, 0)
	game.allow_diagonal = false
	assert_int(game._largest_match(board, diag, false)).is_equal(1)
	game.allow_diagonal = true
	assert_int(game._largest_match(board, diag, false)).is_equal(3)
	game.queue_free()


# Spawn weights bias the pool: with the default ruleset the weight-2 warp tile is drawn far less often
# than a weight-20 stat tile over many refills.
func test_spawn_weights_bias_the_pool() -> void:
	var game := _make(RuleCatalog.default_ruleset())
	await await_idle_frame()
	var warp: int = 0
	var combat: int = 0
	for _i: int in 800:
		var kind: int = game._pick_kind()
		if kind == _WARP_KIND:
			warp += 1
		elif kind == 0:
			combat += 1
	assert_int(warp).is_less(combat)
	game.queue_free()
