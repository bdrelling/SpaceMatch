extends GdUnitTestSuite
## FabricatingMinigame (grid packing). Choosing a recipe arms its per-component requirements and lays an
## empty build grid; picking a component and placing it on the grid packs its footprint, counts that
## requirement down, and forbids overlaps/out-of-bounds. Packing every component fabricates the module
## into the salvage yard.

func _make() -> FabricatingMinigame:
	var scene: PackedScene = load("res://minigames/fabricating/fabricating.tscn")
	var game: FabricatingMinigame = scene.instantiate()
	add_child(game)
	return game

# Pick a component kind and drop it at a cell (the tap-to-hold then drag-and-release flow).
func _place(game: FabricatingMinigame, kind: int, cell: Vector2i) -> void:
	game._on_component_picked(kind)
	game._try_place(cell)

func test_choosing_a_recipe_arms_its_requirements_and_empties_the_grid() -> void:
	var game := _make()
	await await_idle_frame()
	# Engine needs 2 panel (2), 2 tube (1), 1 gear (4).
	game._on_recipe_chosen(game._recipes[1])
	assert_int(game._remaining[2]).is_equal(2)
	assert_int(game._remaining[1]).is_equal(2)
	assert_int(game._remaining[4]).is_equal(1)
	assert_int(game._board.filled_cell_count()).is_equal(0)
	game.queue_free()

func test_placing_a_component_packs_it_and_counts_it_down() -> void:
	var game := _make()
	await await_idle_frame()
	game._on_recipe_chosen(game._recipes[0])  # Reactor: 2 wire, 2 panel, 1 coil
	_place(game, 0, Vector2i(0, 0))  # wire is 1x1
	assert_int(game._remaining[0]).is_equal(1)
	assert_int(game._board.filled_cell_count()).is_equal(1)
	# Coil is 1x2 — placing it claims two cells.
	_place(game, 5, Vector2i(0, 1))
	assert_int(game._remaining[5]).is_equal(0)
	assert_int(game._board.filled_cell_count()).is_equal(3)
	game.queue_free()

func test_cannot_place_overlapping() -> void:
	var game := _make()
	await await_idle_frame()
	game._on_recipe_chosen(game._recipes[0])
	_place(game, 0, Vector2i(0, 0))
	# A second wire on the same cell can't be placed; the count holds.
	_place(game, 0, Vector2i(0, 0))
	assert_int(game._remaining[0]).is_equal(1)
	assert_int(game._board.filled_cell_count()).is_equal(1)
	game.queue_free()

func test_pulling_a_placed_piece_returns_it_to_the_tray() -> void:
	var game := _make()
	await await_idle_frame()
	game._on_recipe_chosen(game._recipes[0])
	_place(game, 0, Vector2i(0, 0))
	assert_int(game._remaining[0]).is_equal(1)
	# Pull it back: the cell empties and the requirement goes back up.
	game._pull_piece(game._board.index_at(Vector2i(0, 0)))
	assert_int(game._remaining[0]).is_equal(2)
	assert_int(game._board.filled_cell_count()).is_equal(0)
	game.queue_free()

func test_completing_a_recipe_deposits_a_module_in_the_salvage_yard() -> void:
	var game := _make()
	await await_idle_frame()
	var yard := Inventory.new()
	game.add_child(yard)
	game._salvage_yard = yard
	game._on_recipe_chosen(game._recipes[0])
	# Drain the requirements and trigger the completion check via a final placement attempt.
	for kind: int in game._remaining.size():
		game._remaining[kind] = 0
	game._after_change()
	var stacks: Array[ItemStack] = yard.get_stacks()
	assert_int(stacks.size()).is_equal(1)
	assert_int(stacks[0].item_blueprint.id).is_equal(game._recipes[0].module.id)
	game.queue_free()
