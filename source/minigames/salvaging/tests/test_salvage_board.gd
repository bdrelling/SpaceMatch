extends GdUnitTestSuite
## SalvageBoard logic — no scene, no renderer: a seeded field carries the right object count and
## adjacency numbers, reveals/floods/flags correctly, and a seed replays the same field.

const _W: int = 9
const _H: int = 9
const _OBJECTS: int = 10

func _board(seed_value: int) -> SalvageBoard:
	var board := SalvageBoard.new(_W, _H, _OBJECTS)
	board.generate(seed_value)
	return board

func test_field_has_exact_object_count() -> void:
	var board := _board(4242)
	var objects: int = 0
	for y: int in _H:
		for x: int in _W:
			if board.cell_at(x, y).object:
				objects += 1
	assert_int(objects).is_equal(_OBJECTS)

func test_adjacency_counts_match_neighbors() -> void:
	var board := _board(4242)
	for y: int in _H:
		for x: int in _W:
			var cell := board.cell_at(x, y)
			if cell.object:
				continue
			var expected: int = 0
			for dy: int in [-1, 0, 1]:
				for dx: int in [-1, 0, 1]:
					if dx == 0 and dy == 0:
						continue
					var nx: int = x + dx
					var ny: int = y + dy
					if nx >= 0 and nx < _W and ny >= 0 and ny < _H and board.cell_at(nx, ny).object:
						expected += 1
			assert_int(cell.adjacent).override_failure_message(
				"Adjacency at (%d, %d) was %d, expected %d." % [x, y, cell.adjacent, expected]
			).is_equal(expected)

func test_revealing_an_object_returns_object() -> void:
	var board := _board(4242)
	var cell := _first_object(board)
	assert_int(board.reveal(cell)).is_equal(SalvageBoard.Reveal.OBJECT)
	assert_bool(board.cell_at(cell.x, cell.y).revealed).is_true()

func test_revealing_a_safe_cell_floods_and_counts() -> void:
	var board := _board(4242)
	var cell := _first_safe(board)
	assert_int(board.reveal(cell)).is_equal(SalvageBoard.Reveal.SAFE)
	assert_bool(board.cell_at(cell.x, cell.y).revealed).is_true()
	assert_int(board.revealed_safe()).is_greater(0)

func test_flagging_all_objects_reports_solved() -> void:
	var board := _board(4242)
	assert_bool(board.all_objects_flagged()).is_false()
	for y: int in _H:
		for x: int in _W:
			if board.cell_at(x, y).object:
				board.toggle_flag(Vector2i(x, y))
	assert_bool(board.all_objects_flagged()).is_true()

func test_a_false_flag_breaks_the_solve() -> void:
	var board := _board(4242)
	for y: int in _H:
		for x: int in _W:
			if board.cell_at(x, y).object:
				board.toggle_flag(Vector2i(x, y))
	board.toggle_flag(_first_safe(board))
	assert_bool(board.all_objects_flagged()).is_false()

func test_revealing_every_safe_cell_clears_the_field() -> void:
	var board := _board(4242)
	assert_bool(board.is_cleared()).is_false()
	for y: int in _H:
		for x: int in _W:
			if not board.cell_at(x, y).object:
				board.reveal(Vector2i(x, y))
	assert_bool(board.is_cleared()).is_true()

func test_flag_count_tracks_flags() -> void:
	var board := _board(4242)
	assert_int(board.flag_count()).is_equal(0)
	board.toggle_flag(_first_object(board))
	assert_int(board.flag_count()).is_equal(1)

func test_expose_reveals_any_cell_including_objects() -> void:
	var board := _board(4242)
	var object := _first_object(board)
	board.expose(object)
	assert_bool(board.cell_at(object.x, object.y).revealed).is_true()

func test_same_seed_replays_the_same_field() -> void:
	var first := _board(4242)
	var second := _board(4242)
	for y: int in _H:
		for x: int in _W:
			assert_bool(first.cell_at(x, y).object).is_equal(second.cell_at(x, y).object)

func _first_object(board: SalvageBoard) -> Vector2i:
	for y: int in _H:
		for x: int in _W:
			if board.cell_at(x, y).object:
				return Vector2i(x, y)
	return Vector2i(-1, -1)

func _first_safe(board: SalvageBoard) -> Vector2i:
	for y: int in _H:
		for x: int in _W:
			if not board.cell_at(x, y).object:
				return Vector2i(x, y)
	return Vector2i(-1, -1)
