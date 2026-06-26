extends GdUnitTestSuite
## Tests ModuleGridState placement against its grid_system silhouette.

func _grid(cells: Array[Vector2i]) -> ModuleGridState:
	var grid := ModuleGridState.new(3, 3, 1)
	for cell: Vector2i in cells:
		grid.usable_cells[cell] = true
	return grid

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
	assert_bool(grid.can_place_module(PieceShape.from_offsets([Vector2i.ZERO]), Vector2i(1, 0), 0)).is_false()

func test_collision_blocks_second_module() -> void:
	var grid := _grid([Vector2i(0, 0), Vector2i(1, 0)])
	assert_bool(grid.place(_module(), Vector2i(0, 0), 0)).is_true()
	assert_int(grid.filled_cell_count()).is_equal(1)
	assert_bool(grid.can_place_module(PieceShape.from_offsets([Vector2i.ZERO]), Vector2i(0, 0), 0)).is_false()

func test_module_at_and_remove() -> void:
	var grid := _grid([Vector2i(0, 0), Vector2i(1, 0)])
	var module := _module()
	grid.place(module, Vector2i(1, 0), 0)
	assert_object(grid.module_at(Vector2i(1, 0))).is_same(module)
	assert_object(grid.module_at(Vector2i(0, 0))).is_null()
	assert_object(grid.remove_at(Vector2i(1, 0))).is_same(module)
	assert_int(grid.filled_cell_count()).is_equal(0)

func _full_grid() -> ModuleGridState:
	return _grid([
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
		Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
		Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)])

func test_placed_at_returns_footprint_for_any_covered_cell() -> void:
	var grid := _full_grid()
	var module := _module([Vector2i(0, 0), Vector2i(1, 0)])
	grid.place(module, Vector2i(0, 0), 0)
	var placed := grid.state_at(Vector2i(1, 0))
	assert_object(placed).is_not_null()
	assert_object(placed.blueprint).is_same(module)
	assert_int(grid.cells_of(placed).size()).is_equal(2)
	assert_object(grid.state_at(Vector2i(2, 2))).is_null()

func test_move_translates_module_to_empty_cell() -> void:
	var grid := _full_grid()
	var module := _module()
	grid.place(module, Vector2i(0, 0), 0)
	assert_bool(grid.move(Vector2i(0, 0), Vector2i(2, 2))).is_true()
	assert_object(grid.module_at(Vector2i(2, 2))).is_same(module)
	assert_object(grid.module_at(Vector2i(0, 0))).is_null()
	assert_int(grid.filled_cell_count()).is_equal(1)

func test_move_preserves_multi_cell_footprint() -> void:
	var grid := _full_grid()
	var module := _module([Vector2i(0, 0), Vector2i(1, 0)])
	grid.place(module, Vector2i(0, 0), 0)
	assert_bool(grid.move(Vector2i(0, 0), Vector2i(0, 1))).is_true()
	assert_object(grid.module_at(Vector2i(0, 1))).is_same(module)
	assert_object(grid.module_at(Vector2i(1, 1))).is_same(module)
	assert_object(grid.module_at(Vector2i(0, 0))).is_null()

func test_move_allows_overlap_with_own_footprint() -> void:
	# Sliding a domino one cell along its own axis overlaps a cell it already occupies — valid, because
	# a module never collides with itself.
	var grid := _full_grid()
	var module := _module([Vector2i(0, 0), Vector2i(1, 0)])
	grid.place(module, Vector2i(0, 0), 0)
	assert_bool(grid.move(Vector2i(0, 0), Vector2i(1, 0))).is_true()
	assert_object(grid.module_at(Vector2i(1, 0))).is_same(module)
	assert_object(grid.module_at(Vector2i(2, 0))).is_same(module)
	assert_object(grid.module_at(Vector2i(0, 0))).is_null()

func test_move_blocked_by_another_module_leaves_grid_unchanged() -> void:
	var grid := _full_grid()
	var first := _module()
	var second := _module()
	grid.place(first, Vector2i(0, 0), 0)
	grid.place(second, Vector2i(1, 0), 0)
	assert_bool(grid.can_move(Vector2i(0, 0), Vector2i(1, 0))).is_false()
	assert_bool(grid.move(Vector2i(0, 0), Vector2i(1, 0))).is_false()
	assert_object(grid.module_at(Vector2i(0, 0))).is_same(first)
	assert_object(grid.module_at(Vector2i(1, 0))).is_same(second)

func test_move_off_silhouette_is_rejected() -> void:
	var grid := _grid([Vector2i(0, 0), Vector2i(1, 0)])
	var module := _module()
	grid.place(module, Vector2i(0, 0), 0)
	assert_bool(grid.can_move(Vector2i(0, 0), Vector2i(0, 1))).is_false()
	assert_bool(grid.move(Vector2i(0, 0), Vector2i(0, 1))).is_false()
	assert_object(grid.module_at(Vector2i(0, 0))).is_same(module)

func test_disabled_cell_drops_its_module_from_the_profile() -> void:
	var grid := _full_grid()
	var powered := _module()
	powered.stats = StatBlock.new()
	powered.stats.power = 5
	grid.place(powered, Vector2i(0, 0), 0)
	# No disabled cells: the module is enabled and counts.
	assert_int(grid.profile().power).is_equal(5)
	assert_bool(grid.enabled(grid.modules[0])).is_true()
	# Disable the cell it sits on: the module deactivates and stops counting.
	var disabled: Array[Vector2i] = [Vector2i(0, 0)]
	assert_int(grid.profile(disabled).power).is_equal(0)
	assert_bool(grid.enabled(grid.modules[0], disabled)).is_false()

func test_disabling_any_cell_deactivates_a_multi_cell_module() -> void:
	# "Only modules with all enabled cells count" — disabling one cell of a two-cell module kills the whole thing.
	var grid := _full_grid()
	var module := _module([Vector2i(0, 0), Vector2i(1, 0)])
	module.stats = StatBlock.new()
	module.stats.shields = 3
	grid.place(module, Vector2i(0, 0), 0)
	assert_int(grid.profile().shields).is_equal(3)
	assert_int(grid.profile([Vector2i(1, 0)]).shields).is_equal(0)
	assert_bool(grid.enabled(grid.modules[0], [Vector2i(1, 0)])).is_false()

# A module grants its ship abilities and phase rules while enabled — the "modules contribute" path, same
# "all cells enabled to count" rule as the stat profile. Disable its cell and it contributes nothing.
func test_module_contributes_abilities_and_rules_while_enabled() -> void:
	var grid := _full_grid()
	var module := _module()
	module.abilities = [MatchAbility.make("Repair", AbilityCost.make(0, 5), ShieldEffect.make(5))]
	var rule := ExtraTurnRule.new()
	rule.min_match = 3
	module.rules = [rule]
	grid.place(module, Vector2i(0, 0), 0)
	# Enabled: the module's ability and rule are part of the grid's contribution.
	assert_int(grid.abilities().size()).is_equal(1)
	assert_str(grid.abilities()[0].ability_name).is_equal("Repair")
	assert_int(grid.rules().size()).is_equal(1)
	# Disable its cell: the module deactivates and contributes nothing, just like the stat profile.
	var disabled: Array[Vector2i] = [Vector2i(0, 0)]
	assert_int(grid.abilities(disabled).size()).is_equal(0)
	assert_int(grid.rules(disabled).size()).is_equal(0)

func test_generator_stamps_blueprint_modules() -> void:
	var placement := ModulePlacement.new()
	placement.module = _module([Vector2i(0, 0), Vector2i(1, 0)])
	placement.origin = Vector2i(1, 1)
	var blueprint := ModuleGridBlueprint.new()
	blueprint.columns = 3
	blueprint.rows = 3
	var placements: Array[ModulePlacement] = [placement]
	blueprint.modules = placements
	var grid := auto_free(ModuleGrid.create(blueprint)).state
	assert_int(grid.modules.size()).is_equal(1)
	assert_object(grid.module_at(Vector2i(1, 1))).is_same(placement.module)
	assert_object(grid.module_at(Vector2i(2, 1))).is_same(placement.module)
