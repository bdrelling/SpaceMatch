extends GdUnitTestSuite
## Tests ShipModuleGrid placement against its grid_system silhouette.

func _grid(cells: Array[Vector2i]) -> ShipModuleGrid:
	var generator := ShapedGridGenerator.new()
	generator.width = 3
	generator.height = 3
	generator.usable_cells = cells
	var module_grid := ShipModuleGrid.new()
	module_grid.grid = generator.generate()
	return module_grid

func _module(offsets: Array[Vector2i] = [Vector2i.ZERO]) -> ModuleBlueprint:
	var module := ModuleBlueprint.new()
	module.id = 1
	module.name = "Module"
	module.shape = PieceShape.from_offsets(offsets)
	return module

func test_cell_exists_only_for_silhouette_cells() -> void:
	var grid := _grid([Vector2i(0, 0), Vector2i(1, 0)])
	assert_bool(grid.cell_exists(Vector2i(0, 0))).is_true()
	assert_bool(grid.cell_exists(Vector2i(2, 2))).is_false()
	assert_int(grid.tile_count()).is_equal(2)

func test_columns_and_rows() -> void:
	var grid := _grid([Vector2i.ZERO])
	assert_int(grid.columns).is_equal(3)
	assert_int(grid.rows).is_equal(3)

func test_place_rejects_cell_outside_silhouette() -> void:
	var grid := _grid([Vector2i(0, 0)])
	assert_bool(grid.can_place(PieceShape.from_offsets([Vector2i.ZERO]), Vector2i(1, 0), 0)).is_false()

func test_collision_blocks_second_module() -> void:
	var grid := _grid([Vector2i(0, 0), Vector2i(1, 0)])
	assert_bool(grid.place(_module(), Vector2i(0, 0), 0)).is_true()
	assert_int(grid.filled_cell_count()).is_equal(1)
	assert_bool(grid.can_place(PieceShape.from_offsets([Vector2i.ZERO]), Vector2i(0, 0), 0)).is_false()

func test_module_at_and_remove() -> void:
	var grid := _grid([Vector2i(0, 0), Vector2i(1, 0)])
	var module := _module()
	grid.place(module, Vector2i(1, 0), 0)
	assert_object(grid.module_at(Vector2i(1, 0))).is_same(module)
	assert_object(grid.module_at(Vector2i(0, 0))).is_null()
	assert_object(grid.remove_at(Vector2i(1, 0))).is_same(module)
	assert_int(grid.filled_cell_count()).is_equal(0)
