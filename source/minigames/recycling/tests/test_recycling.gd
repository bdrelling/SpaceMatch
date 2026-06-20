extends GdUnitTestSuite
## RecyclingMinigame (match-3). Matching a run of a component recycles that component into the bound
## inventory, by run length — 1 / 2 / 3 / 5 / 8… (Fibonacci) — and every cascade pass recycles too. The
## board is an equal-frequency generator, so it always lays down a full field.

const _WIRE: String = "res://resources/items/components/wire_item_blueprint.tres"

func _make() -> RecyclingMinigame:
	var scene: PackedScene = load("res://minigames/recycling/recycling.tscn")
	var game: RecyclingMinigame = scene.instantiate()
	game.board_seed = 4242
	add_child(game)
	return game

# A 1-row board of `length` tiles of one kind, plus the matching flat clear list.
func _kind_run(kind: int, length: int) -> GridBoardState:
	var board := GridBoardState.new(length, 1, 1)
	for x: int in length:
		var occupied: Array[Vector2i] = [Vector2i(x, 0)]
		board.place_object(0, RecyclingMinigame._TileState.new(occupied, kind))
	return board

func _run_cells(length: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x: int in length:
		cells.append(Vector2i(x, 0))
	return cells

func test_match_points_follow_fibonacci() -> void:
	var game := _make()
	await await_idle_frame()
	assert_int(game._match_points(2)).is_equal(0)
	assert_int(game._match_points(3)).is_equal(1)
	assert_int(game._match_points(4)).is_equal(2)
	assert_int(game._match_points(5)).is_equal(3)
	assert_int(game._match_points(6)).is_equal(5)
	assert_int(game._match_points(7)).is_equal(8)
	game.queue_free()

func test_board_fills_completely() -> void:
	var game := _make()
	await await_idle_frame()
	var state: GridBoardState = game._session.state
	var placed: int = 0
	for y: int in 8:
		for x: int in 8:
			if state.get_object_at(0, x, y) != null:
				placed += 1
	assert_int(placed).is_equal(64)
	game.queue_free()

func test_clearing_a_run_recycles_that_component() -> void:
	var game := _make()
	await await_idle_frame()
	var inventory := Inventory.new()
	game.add_child(inventory)
	game._inventory = inventory
	var wire: ItemBlueprint = load(_WIRE)
	# A 3-run of wire (kind 0) recycles 1 wire into the inventory.
	game._on_clear(_kind_run(0, 3), _run_cells(3))
	assert_int(inventory.count(wire.id)).is_equal(1)
	# A 4-run recycles 2 (the next Fibonacci step) — total now 3.
	game._on_clear(_kind_run(0, 4), _run_cells(4))
	assert_int(inventory.count(wire.id)).is_equal(3)
	game.queue_free()

func test_cascades_recycle_too() -> void:
	var game := _make()
	await await_idle_frame()
	var inventory := Inventory.new()
	game.add_child(inventory)
	game._inventory = inventory
	var wire: ItemBlueprint = load(_WIRE)
	# Every clear pass recycles — the move's own match and the cascade passes that follow it alike.
	game._on_clear(_kind_run(0, 3), _run_cells(3))  # direct
	game._on_clear(_kind_run(0, 3), _run_cells(3))  # cascade
	assert_int(inventory.count(wire.id)).is_equal(2)
	game.queue_free()
