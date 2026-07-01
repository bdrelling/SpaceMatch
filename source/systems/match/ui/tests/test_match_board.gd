extends MatchTestCase
## Board fill and portrait stat-readout layout.


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


# The portraits show only the four colored stat tiles — scrap, warp, and damage aren't starship stats.
func test_portrait_shows_only_four_stat_readouts() -> void:
	var game := _make()
	await await_idle_frame()
	assert_int(game._player_readouts().size()).is_equal(4)
	assert_int(game._opponent_readouts().size()).is_equal(4)
	game.queue_free()
