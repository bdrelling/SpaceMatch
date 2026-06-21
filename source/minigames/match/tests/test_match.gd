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
