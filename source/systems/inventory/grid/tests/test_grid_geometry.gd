extends GdUnitTestSuite
## Tests GridGeometry — footprint rotation, occupancy, and first-fit placement math.

const SINGLE: Array[Vector2i] = [Vector2i.ZERO]

# X .
# X X
const L_TROMINO: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)]

# X X X
const LINE_OF_THREE: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]

func _occupied(cells: Array[Vector2i] = []) -> Dictionary[Vector2i, bool]:
	var occupied: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in cells:
		occupied[cell] = true
	return occupied

func test_rotate_single_cell_is_unchanged() -> void:
	for steps in 4:
		assert_array(GridGeometry.rotate_cells(SINGLE, steps)).contains_exactly([Vector2i.ZERO])

func test_rotate_l_tromino_through_each_orientation() -> void:
	# X X
	# X .
	assert_array(GridGeometry.rotate_cells(L_TROMINO, 1)) \
		.contains_exactly_in_any_order([Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)])
	# X X
	# . X
	assert_array(GridGeometry.rotate_cells(L_TROMINO, 2)) \
		.contains_exactly_in_any_order([Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)])
	# . X
	# X X
	assert_array(GridGeometry.rotate_cells(L_TROMINO, 3)) \
		.contains_exactly_in_any_order([Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)])

func test_rotate_four_steps_returns_original() -> void:
	assert_array(GridGeometry.rotate_cells(L_TROMINO, 4)).contains_exactly(L_TROMINO)

func test_rotate_normalizes_to_zero_minimum() -> void:
	for steps in 4:
		var minimum := Vector2i.MAX
		for cell: Vector2i in GridGeometry.rotate_cells(L_TROMINO, steps):
			minimum = Vector2i(mini(minimum.x, cell.x), mini(minimum.y, cell.y))
		assert_that(minimum).is_equal(Vector2i.ZERO)

func test_occupied_cells_offsets_by_anchor() -> void:
	assert_array(GridGeometry.occupied_cells(L_TROMINO, Vector2i(2, 3), 0)) \
		.contains_exactly_in_any_order([Vector2i(2, 3), Vector2i(2, 4), Vector2i(3, 4)])

func test_occupied_cells_combines_rotation_and_anchor() -> void:
	assert_array(GridGeometry.occupied_cells(LINE_OF_THREE, Vector2i(1, 1), 1)) \
		.contains_exactly_in_any_order([Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3)])

func test_fits_inside_bounds() -> void:
	assert_bool(GridGeometry.fits(LINE_OF_THREE, Vector2i.ZERO, 0, 3, 1, _occupied())).is_true()

func test_fits_rejects_out_of_bounds() -> void:
	assert_bool(GridGeometry.fits(LINE_OF_THREE, Vector2i(1, 0), 0, 3, 1, _occupied())).is_false()
	assert_bool(GridGeometry.fits(SINGLE, Vector2i(-1, 0), 0, 3, 3, _occupied())).is_false()
	assert_bool(GridGeometry.fits(SINGLE, Vector2i(0, 3), 0, 3, 3, _occupied())).is_false()

func test_fits_rejects_collision() -> void:
	var taken: Array[Vector2i] = [Vector2i(1, 1)]
	assert_bool(GridGeometry.fits(L_TROMINO, Vector2i.ZERO, 0, 2, 2, _occupied(taken))).is_false()
	assert_bool(GridGeometry.fits(SINGLE, Vector2i(1, 0), 0, 2, 2, _occupied(taken))).is_true()

func test_find_placement_on_empty_grid_is_origin() -> void:
	var placement := GridGeometry.find_placement(L_TROMINO, 3, 3, _occupied())
	assert_that(placement.anchor).is_equal(Vector2i.ZERO)
	assert_int(placement.rotation_steps).is_equal(0)

func test_find_placement_scans_row_major() -> void:
	var taken: Array[Vector2i] = [Vector2i(0, 0)]
	var placement := GridGeometry.find_placement(SINGLE, 2, 2, _occupied(taken))
	assert_that(placement.anchor).is_equal(Vector2i(1, 0))

func test_find_placement_prefers_authored_orientation() -> void:
	var placement := GridGeometry.find_placement(LINE_OF_THREE, 3, 3, _occupied())
	assert_int(placement.rotation_steps).is_equal(0)

func test_find_placement_rotates_when_needed() -> void:
	var placement := GridGeometry.find_placement(LINE_OF_THREE, 1, 3, _occupied())
	assert_that(placement.anchor).is_equal(Vector2i.ZERO)
	assert_int(placement.rotation_steps).is_equal(1)

func test_find_placement_returns_null_when_nothing_fits() -> void:
	var taken: Array[Vector2i] = [Vector2i.ZERO]
	assert_object(GridGeometry.find_placement(SINGLE, 1, 1, _occupied(taken))).is_null()
	assert_object(GridGeometry.find_placement(LINE_OF_THREE, 2, 2, _occupied())).is_null()
