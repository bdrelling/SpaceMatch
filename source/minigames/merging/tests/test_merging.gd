extends GdUnitTestSuite

func test_default_ladder_spans_base_to_largest() -> void:
	var ladder := MergeItemBlueprint.default_ladder(11, 30.0, 216.0)
	assert_float(ladder[0].radius).is_equal_approx(30.0, 0.5)
	assert_float(ladder[ladder.size() - 1].radius).is_equal_approx(216.0, 0.5)

func test_size_curve_keeps_endpoints_and_monotonic() -> void:
	var ladder := MergeItemBlueprint.default_ladder(11, 18.0, 180.0, 0.78)
	assert_float(ladder[0].radius).is_equal_approx(18.0, 0.5)
	assert_float(ladder[ladder.size() - 1].radius).is_equal_approx(180.0, 0.5)
	for index: int in range(1, ladder.size()):
		assert_float(ladder[index].radius).is_greater(ladder[index - 1].radius)

func test_default_ladder_area_grows_geometrically() -> void:
	var ladder := MergeItemBlueprint.default_ladder()
	assert_int(ladder.size()).is_greater(1)
	var step := (ladder[1].radius * ladder[1].radius) / (ladder[0].radius * ladder[0].radius)
	assert_float(step).is_greater(1.0)
	for index: int in range(2, ladder.size()):
		var ratio := (ladder[index].radius * ladder[index].radius) / (ladder[index - 1].radius * ladder[index - 1].radius)
		assert_float(ratio).is_equal_approx(step, 0.01)

func test_merge_promotes_two_equal_items_to_next_tier() -> void:
	var board := _make_board()
	var a := _spawn(board, 0, Vector2(200.0, 500.0))
	var b := _spawn(board, 0, Vector2(240.0, 500.0))
	var promoted := board._merge(a, b)
	assert_bool(promoted != null).is_true()
	assert_int(promoted.tier).is_equal(1)
	assert_int(board.score).is_equal(1)
	assert_bool(a.consumed).is_true()
	assert_bool(b.consumed).is_true()
	board.queue_free()

func test_top_tier_clears_without_promoting() -> void:
	var board := _make_board()
	var top := board.tiers.size() - 1
	var a := _spawn(board, top, Vector2(200.0, 500.0))
	var b := _spawn(board, top, Vector2(240.0, 500.0))
	var promoted := board._merge(a, b)
	assert_bool(promoted == null).is_true()
	assert_int(board.score).is_equal(top + 1)
	board.queue_free()

func test_settled_item_with_centre_above_line_ends_run() -> void:
	var board := _make_board()
	var ball := _spawn(board, 0, Vector2(360.0, 100.0))  # centre y=100, above the 150 danger line
	ball.linear_velocity = Vector2.ZERO
	board._pending = null
	board._physics_process(0.016)
	assert_bool(board.alive).is_false()
	board.queue_free()

func test_falling_item_above_line_does_not_end_run() -> void:
	var board := _make_board()
	var ball := _spawn(board, 0, Vector2(360.0, 100.0))
	ball.linear_velocity = Vector2(0.0, 600.0)  # still moving — not settled
	board._pending = null
	board._physics_process(0.016)
	assert_bool(board.alive).is_true()
	board.queue_free()

func test_drop_is_blocked_until_the_dropped_item_lands() -> void:
	var board := _make_board()
	await await_idle_frame()
	var first := board._held
	board.drop()
	assert_bool(board._pending == first).is_true()
	var next_held := board._held
	board.drop()  # blocked: previous drop hasn't touched anything yet
	assert_bool(board._held == next_held).is_true()
	assert_bool(board._pending == first).is_true()
	board.queue_free()

func test_non_pvp_merge_leaves_item_unowned() -> void:
	var board := _make_board()
	var a := _spawn(board, 0, Vector2(200.0, 500.0))
	var b := _spawn(board, 0, Vector2(240.0, 500.0))
	var promoted := board._merge(a, b)
	assert_float(promoted.owner_color.a).is_equal(0.0)
	board.queue_free()

func test_pvp_matched_pair_keeps_their_color() -> void:
	var board := _make_board()
	board.pvp = true
	var a := _spawn(board, 0, Vector2(200.0, 500.0))
	var b := _spawn(board, 0, Vector2(240.0, 500.0))
	a.owner_color = MergeBoard.PLAYER_RED
	b.owner_color = MergeBoard.PLAYER_RED
	board._active_player = MergeBoard.PLAYER_BLUE  # even with blue active, a matched red pair stays red
	var promoted := board._merge(a, b)
	assert_bool(promoted.owner_color == MergeBoard.PLAYER_RED).is_true()
	board.queue_free()

func test_pvp_split_pair_goes_to_active_player() -> void:
	var board := _make_board()
	board.pvp = true
	var a := _spawn(board, 0, Vector2(200.0, 500.0))
	var b := _spawn(board, 0, Vector2(240.0, 500.0))
	a.owner_color = MergeBoard.PLAYER_RED
	b.owner_color = MergeBoard.PLAYER_BLUE
	board._active_player = MergeBoard.PLAYER_BLUE
	var promoted := board._merge(a, b)
	assert_bool(promoted.owner_color == MergeBoard.PLAYER_BLUE).is_true()
	board.queue_free()

func test_pvp_turn_alternates_and_colors_held() -> void:
	var board := _make_board()
	board.pvp = true
	board.reset()
	await await_idle_frame()
	assert_bool(board.current_player() == MergeBoard.PLAYER_RED).is_true()
	assert_bool(board._held.owner_color == MergeBoard.PLAYER_RED).is_true()
	board.drop()
	assert_bool(board.current_player() == MergeBoard.PLAYER_BLUE).is_true()
	assert_bool(board._held.owner_color == MergeBoard.PLAYER_BLUE).is_true()
	# The dropped (red) ball still owns the merges it triggers while it resolves.
	assert_bool(board._active_player == MergeBoard.PLAYER_RED).is_true()
	board.queue_free()

func _make_board() -> MergeBoard:
	var board := MergeBoard.new()
	add_child(board)
	board.build(MergeItemBlueprint.default_ladder(), 1)
	return board

func _spawn(board: MergeBoard, tier: int, position: Vector2) -> MergeItem:
	var item := MergeItem.create(tier, board.tiers[tier])
	item.position = position
	board._items.add_child(item)
	return item
