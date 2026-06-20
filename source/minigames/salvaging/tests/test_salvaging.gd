extends GdUnitTestSuite
## SalvagingMinigame controller, both variants, over a seeded field. Instantiates the real scene so the
## renderer/canvas wiring runs too. DEFAULT: a mine ends the run, flagging every mine wins a module.
## SALVAGE: every tap earns scrap, a module earns triple, the whole field also yields a module, and
## the action budget ends the field. Rewards land in the bound inventory (a private one until bound).

const _W: int = 12
const _H: int = 12

func _make(seed_value: int, mode: SalvagingMinigame.Mode, budget: int = 15) -> SalvagingMinigame:
	var scene: PackedScene = load("res://minigames/salvaging/salvaging.tscn")
	var game: SalvagingMinigame = scene.instantiate()
	game.mode = mode
	game.board_seed = seed_value
	game.action_budget = budget
	add_child(game)
	return game

# --- Default ---

func test_default_revealing_a_mine_ends_the_field() -> void:
	var game := _make(4242, SalvagingMinigame.Mode.DEFAULT)
	await await_idle_frame()
	game._on_reveal(_first_object(game))
	assert_bool(game._lost).is_true()
	assert_bool(game._playable).is_false()
	game.queue_free()

func test_default_mine_hit_exposes_every_mine_but_no_cascade() -> void:
	var game := _make(4242, SalvagingMinigame.Mode.DEFAULT)
	await await_idle_frame()
	game._on_reveal(_first_object(game))
	# Every mine is revealed at once...
	for cell: Vector2i in _object_cells(game, 10):
		assert_bool(game._board.cell_at(cell.x, cell.y).revealed).is_true()
	# ...but the cascade is off, so a safe tile stays hidden.
	var safe := _first_numbered(game)
	assert_bool(game._board.cell_at(safe.x, safe.y).revealed).is_false()
	game.queue_free()

func test_default_safe_reveal_keeps_playing() -> void:
	var game := _make(4242, SalvagingMinigame.Mode.DEFAULT)
	await await_idle_frame()
	var safe := _first_numbered(game)
	game._on_reveal(safe)
	assert_bool(game._board.cell_at(safe.x, safe.y).revealed).is_true()
	assert_bool(game._lost).is_false()
	assert_bool(game._playable).is_true()
	game.queue_free()

func test_default_flagging_every_mine_wins_a_module() -> void:
	var game := _make(4242, SalvagingMinigame.Mode.DEFAULT)
	await await_idle_frame()
	for y: int in _H:
		for x: int in _W:
			if game._board.cell_at(x, y).object:
				game._on_flag(Vector2i(x, y))
	assert_bool(game._won).is_true()
	assert_int(game.damaged_module_count()).is_equal(1)
	assert_bool(game._playable).is_false()
	game.queue_free()

# --- Salvage ---

func test_salvage_safe_tap_earns_one_scrap() -> void:
	var game := _make(4242, SalvagingMinigame.Mode.SALVAGE)
	await await_idle_frame()
	game._on_reveal(_first_numbered(game))
	assert_int(game.scrap_count()).is_equal(1)
	assert_int(game._actions_used).is_equal(1)
	assert_int(game.damaged_module_count()).is_equal(0)
	game.queue_free()

func test_salvage_tap_reveals_only_the_tapped_cell() -> void:
	var game := _make(4242, SalvagingMinigame.Mode.SALVAGE, 20)
	await await_idle_frame()
	# An empty cell (no adjacent objects) would flood-open its whole neighbourhood under default-mode
	# rules; salvage mode must dig only the one cell.
	game._on_reveal(_first_empty(game))
	assert_int(_revealed_count(game)).is_equal(1)
	game.queue_free()

func test_salvage_module_tap_earns_triple_scrap() -> void:
	var game := _make(4242, SalvagingMinigame.Mode.SALVAGE)
	await await_idle_frame()
	game._on_reveal(_first_object(game))
	assert_int(game.scrap_count()).is_equal(3)
	assert_int(game._found_this_field).is_equal(1)
	game.queue_free()

func test_salvage_digging_out_every_module_yields_a_damaged_module() -> void:
	var game := _make(4242, SalvagingMinigame.Mode.SALVAGE, 20)
	await await_idle_frame()
	for cell: Vector2i in _object_cells(game, 10):
		game._on_reveal(cell)
	assert_int(game.damaged_module_count()).is_equal(1)
	assert_int(game.scrap_count()).is_equal(30)
	assert_bool(game._playable).is_false()
	game.queue_free()

func test_salvage_spending_the_budget_ends_the_field() -> void:
	var game := _make(4242, SalvagingMinigame.Mode.SALVAGE, 3)
	await await_idle_frame()
	for cell: Vector2i in _object_cells(game, 3):
		game._on_reveal(cell)
	# Three module taps == the budget: the field ends without all ten dug out, so no damaged module.
	assert_bool(game._playable).is_false()
	assert_int(game.scrap_count()).is_equal(9)
	assert_int(game.damaged_module_count()).is_equal(0)
	game.queue_free()

func test_reset_keeps_inventory_but_refreshes_the_field() -> void:
	var game := _make(4242, SalvagingMinigame.Mode.SALVAGE, 3)
	await await_idle_frame()
	for cell: Vector2i in _object_cells(game, 3):
		game._on_reveal(cell)
	game._on_reset_pressed()
	assert_bool(game._playable).is_true()
	assert_int(game._actions_used).is_equal(0)
	assert_int(game.scrap_count()).is_equal(9)
	game.queue_free()

func test_bind_session_routes_rewards_to_the_bound_inventory() -> void:
	var game := _make(4242, SalvagingMinigame.Mode.SALVAGE)
	await await_idle_frame()
	var shared := Inventory.new()
	add_child(shared)
	game.bind_session(null, shared)
	game._on_reveal(_first_object(game))
	assert_bool(game._inventory == shared).is_true()
	assert_int(game.scrap_count()).is_equal(3)
	game.queue_free()
	shared.queue_free()

func test_field_persists_across_rebind_to_same_session() -> void:
	var session := GameSession.new_game()
	var shared := Inventory.new()
	add_child(shared)

	var first := _make(4242, SalvagingMinigame.Mode.SALVAGE, 20)
	await await_idle_frame()
	first.bind_session(session, shared)
	# Strip part of the field, then "leave" the stage.
	for cell: Vector2i in _object_cells(first, 3):
		first._on_reveal(cell)
	var dug := _revealed_count(first)
	var found := first._found_this_field

	# A fresh stage bound to the same session resumes the saved field — no re-roll for better luck.
	var second := _make(4242, SalvagingMinigame.Mode.SALVAGE, 20)
	await await_idle_frame()
	second.bind_session(session, shared)
	assert_int(_revealed_count(second)).is_equal(dug)
	assert_int(second._found_this_field).is_equal(found)
	assert_bool(second._playable).is_equal(first._playable)

	first.queue_free()
	second.queue_free()
	shared.queue_free()

# --- Helpers ---

func _first_object(game: SalvagingMinigame) -> Vector2i:
	return _object_cells(game, 1)[0]

func _object_cells(game: SalvagingMinigame, count: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y: int in _H:
		for x: int in _W:
			if game._board.cell_at(x, y).object:
				cells.append(Vector2i(x, y))
				if cells.size() == count:
					return cells
	return cells

func _first_numbered(game: SalvagingMinigame) -> Vector2i:
	for y: int in _H:
		for x: int in _W:
			var cell := game._board.cell_at(x, y)
			if not cell.object and cell.adjacent > 0:
				return Vector2i(x, y)
	return Vector2i(-1, -1)

func _first_empty(game: SalvagingMinigame) -> Vector2i:
	for y: int in _H:
		for x: int in _W:
			var cell := game._board.cell_at(x, y)
			if not cell.object and cell.adjacent == 0:
				return Vector2i(x, y)
	return Vector2i(-1, -1)

func _revealed_count(game: SalvagingMinigame) -> int:
	var total: int = 0
	for y: int in _H:
		for x: int in _W:
			if game._board.cell_at(x, y).revealed:
				total += 1
	return total
