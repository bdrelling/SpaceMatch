extends GdUnitTestSuite
## Tests ShipModuleGrid placement against its blueprint silhouette.

func _grid(cells: Array[Vector2i]) -> ShipModuleGrid:
	var blueprint := ShipModuleGridBlueprint.new()
	blueprint.columns = 3
	blueprint.rows = 3
	blueprint.cells = cells
	return blueprint.create()

func _module(footprint_cells: Array[Vector2i] = [Vector2i.ZERO]) -> ItemBlueprint:
	var module := ItemBlueprint.new()
	module.id = 1
	module.name = "Module"
	module.footprint_cells = footprint_cells
	return module

func test_cell_exists_only_for_blueprint_cells() -> void:
	var grid := _grid([Vector2i(0, 0), Vector2i(1, 0)])
	assert_bool(grid.cell_exists(Vector2i(0, 0))).is_true()
	assert_bool(grid.cell_exists(Vector2i(2, 2))).is_false()
	assert_int(grid.tile_count()).is_equal(2)

func test_columns_and_rows_read_from_blueprint() -> void:
	var grid := _grid([Vector2i.ZERO])
	assert_int(grid.columns).is_equal(3)
	assert_int(grid.rows).is_equal(3)

func test_place_rejects_missing_cell() -> void:
	var grid := _grid([Vector2i(0, 0)])
	assert_bool(grid.can_place([Vector2i.ZERO], Vector2i(1, 0), 0)).is_false()

func test_collision_blocks_second_module() -> void:
	var grid := _grid([Vector2i(0, 0), Vector2i(1, 0)])
	assert_bool(grid.place(_module(), Vector2i(0, 0), 0)).is_true()
	assert_int(grid.filled_cell_count()).is_equal(1)
	assert_bool(grid.can_place([Vector2i.ZERO], Vector2i(0, 0), 0)).is_false()

func test_index_at_and_remove() -> void:
	var grid := _grid([Vector2i(0, 0), Vector2i(1, 0)])
	var module := _module()
	grid.place(module, Vector2i(1, 0), 0)
	assert_int(grid.index_at(Vector2i(1, 0))).is_equal(0)
	assert_int(grid.index_at(Vector2i(0, 0))).is_equal(-1)
	assert_object(grid.remove_at_index(0)).is_same(module)
	assert_int(grid.filled_cell_count()).is_equal(0)
