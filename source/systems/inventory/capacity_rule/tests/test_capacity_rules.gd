extends GdUnitTestSuite
## Tests each CapacityRule subtype against hand-built InventoryState snapshots.

func _blueprint(id: int, weight := 0.0, footprint_cells: Array[Vector2i] = [Vector2i.ZERO]) -> ItemBlueprint:
	var blueprint := ItemBlueprint.new()
	blueprint.id = id
	blueprint.name = "Item %d" % id
	blueprint.weight = weight
	blueprint.footprint_cells = footprint_cells
	return blueprint

func _state(stacks: Array[ItemStack] = [], placements: Array[StackPlacement] = []) -> InventoryState:
	return InventoryState.new(stacks, placements)

#region StackCountCapacityRule

func test_stack_count_blocks_new_stack_at_cap() -> void:
	var rule := StackCountCapacityRule.new()
	rule.max_stacks = 1
	var state := _state([ItemStack.create(_blueprint(1))])
	assert_bool(rule.can_add(state, _blueprint(2), 1, 1)).is_false()

func test_stack_count_allows_top_up_at_cap() -> void:
	var rule := StackCountCapacityRule.new()
	rule.max_stacks = 1
	var held := _blueprint(1)
	var state := _state([ItemStack.create(held)])
	assert_bool(rule.can_add(state, held, 4, 0)).is_true()

func test_stack_count_zero_is_unbounded() -> void:
	var rule := StackCountCapacityRule.new()
	var stacks: Array[ItemStack] = []
	for id in 10:
		stacks.append(ItemStack.create(_blueprint(id)))
	assert_bool(rule.can_add(_state(stacks), _blueprint(99), 1, 1)).is_true()

func test_stack_count_counts_every_new_stack() -> void:
	var rule := StackCountCapacityRule.new()
	rule.max_stacks = 2
	var state := _state([ItemStack.create(_blueprint(1))])
	assert_bool(rule.can_add(state, _blueprint(2), 10, 1)).is_true()
	assert_bool(rule.can_add(state, _blueprint(2), 10, 2)).is_false()

#endregion

#region WeightCapacityRule

func test_weight_blocks_when_over() -> void:
	var rule := WeightCapacityRule.new()
	rule.max_weight = 10.0
	var state := _state([ItemStack.create(_blueprint(1, 3.0), 3)])
	assert_bool(rule.can_add(state, _blueprint(2, 2.0), 1, 1)).is_false()

func test_weight_allows_exactly_full() -> void:
	var rule := WeightCapacityRule.new()
	rule.max_weight = 10.0
	var state := _state([ItemStack.create(_blueprint(1, 3.0), 2)])
	assert_bool(rule.can_add(state, _blueprint(2, 2.0), 2, 1)).is_true()

func test_weight_counts_quantity_times_unit_weight() -> void:
	var rule := WeightCapacityRule.new()
	rule.max_weight = 5.0
	assert_bool(rule.can_add(_state(), _blueprint(1, 2.0), 3, 1)).is_false()
	assert_bool(rule.can_add(_state(), _blueprint(1, 2.0), 2, 1)).is_true()

func test_weightless_items_never_block() -> void:
	var rule := WeightCapacityRule.new()
	rule.max_weight = 1.0
	var state := _state([ItemStack.create(_blueprint(1, 1.0))])
	assert_bool(rule.can_add(state, _blueprint(2, 0.0), 100, 1)).is_true()

func test_weight_zero_is_unbounded() -> void:
	var rule := WeightCapacityRule.new()
	assert_bool(rule.can_add(_state(), _blueprint(1, 1000.0), 1000, 1)).is_true()

#endregion

#region ItemCountCapacityRule

func test_item_count_sums_quantities_not_stacks() -> void:
	var rule := ItemCountCapacityRule.new()
	rule.max_item_count = 10
	var state := _state([ItemStack.create(_blueprint(1), 9)])
	assert_bool(rule.can_add(state, _blueprint(2), 1, 1)).is_true()
	assert_bool(rule.can_add(state, _blueprint(2), 2, 1)).is_false()

func test_item_count_zero_is_unbounded() -> void:
	var rule := ItemCountCapacityRule.new()
	assert_bool(rule.can_add(_state(), _blueprint(1), 9999, 1)).is_true()

#endregion

#region GridCapacityRule

# X .
# X X
const L_TROMINO: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)]

func _grid(width: int, height: int) -> GridCapacityRule:
	var rule := GridCapacityRule.new()
	rule.width = width
	rule.height = height
	return rule

func test_grid_allows_new_stack_when_placement_exists() -> void:
	assert_bool(_grid(2, 2).can_add(_state(), _blueprint(1), 1, 1)).is_true()

func test_grid_blocks_new_stack_when_full() -> void:
	var state := _state([ItemStack.create(_blueprint(1))], [StackPlacement.new(Vector2i.ZERO)])
	assert_bool(_grid(1, 1).can_add(state, _blueprint(2), 1, 1)).is_false()

func test_grid_allows_top_up_when_full() -> void:
	var held := _blueprint(1)
	var state := _state([ItemStack.create(held)], [StackPlacement.new(Vector2i.ZERO)])
	assert_bool(_grid(1, 1).can_add(state, held, 5, 0)).is_true()

func test_grid_rotates_footprint_to_fit() -> void:
	# A 2x2 grid with one corner taken leaves an L of free cells: the tromino only fits rotated.
	var state := _state([ItemStack.create(_blueprint(1))], [StackPlacement.new(Vector2i.ZERO)])
	assert_bool(_grid(2, 2).can_add(state, _blueprint(2), 1, 1)).is_true()
	assert_bool(_grid(2, 2).can_add(state, _blueprint(3, 0.0, L_TROMINO), 1, 1)).is_true()

func test_grid_respects_multi_cell_footprint() -> void:
	# Two opposite corners taken leave only two free cells: no rotation fits three.
	var stacks: Array[ItemStack] = [ItemStack.create(_blueprint(1)), ItemStack.create(_blueprint(2))]
	var placements: Array[StackPlacement] = [StackPlacement.new(Vector2i.ZERO), StackPlacement.new(Vector2i.ONE)]
	var state := _state(stacks, placements)
	assert_bool(_grid(2, 2).can_add(state, _blueprint(3), 1, 1)).is_true()
	assert_bool(_grid(2, 2).can_add(state, _blueprint(4, 0.0, L_TROMINO), 1, 1)).is_false()

func test_grid_finds_placements_for_each_new_stack() -> void:
	var placements := _grid(2, 2).find_placements(_state(), _blueprint(1), 4)
	assert_int(placements.size()).is_equal(4)
	var anchors: Array[Vector2i] = []
	for placement: StackPlacement in placements:
		anchors.append(placement.anchor)
	assert_array(anchors).contains_exactly_in_any_order(
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)])

func test_grid_find_placements_is_all_or_nothing() -> void:
	assert_array(_grid(2, 2).find_placements(_state(), _blueprint(1), 5)).is_empty()
	assert_bool(_grid(2, 1).can_add(_state(), _blueprint(1), 3, 3)).is_false()

func test_grid_occupied_cell_set_uses_placement_rotation() -> void:
	var stack := ItemStack.create(_blueprint(1, 0.0, L_TROMINO))
	var state := _state([stack], [StackPlacement.new(Vector2i(1, 0), 1)])
	var occupied := _grid(3, 3).occupied_cell_set(state)
	# X X        placed at (1, 0):  . X X
	# X .                           . X .
	assert_bool(occupied.has(Vector2i(1, 0))).is_true()
	assert_bool(occupied.has(Vector2i(2, 0))).is_true()
	assert_bool(occupied.has(Vector2i(1, 1))).is_true()
	assert_int(occupied.size()).is_equal(3)

func test_grid_occupied_cell_set_can_exclude_a_stack() -> void:
	var state := _state([ItemStack.create(_blueprint(1))], [StackPlacement.new(Vector2i.ZERO)])
	assert_int(_grid(2, 2).occupied_cell_set(state, 0).size()).is_equal(0)

func test_grid_single_cell_rows_keep_out_multi_cell_footprints() -> void:
	var rule := _grid(2, 2)
	rule.single_cell_rows = 1
	var domino: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
	var placements := rule.find_placements(_state(), _blueprint(1, 0.0, domino), 1)
	assert_int(placements.size()).is_equal(1)
	assert_that(placements[0].anchor).is_equal(Vector2i(0, 1))
	# Nothing below the restricted row fits a vertical domino either — no rotation sneaks in.
	var occupied_row := _state([ItemStack.create(_blueprint(2))], [StackPlacement.new(Vector2i(0, 1))])
	assert_bool(rule.can_add(occupied_row, _blueprint(3, 0.0, domino), 1, 1)).is_false()

func test_grid_single_cell_rows_still_take_single_cells() -> void:
	var rule := _grid(2, 2)
	rule.single_cell_rows = 1
	var placements := rule.find_placements(_state(), _blueprint(1), 1)
	assert_int(placements.size()).is_equal(1)
	assert_that(placements[0].anchor).is_equal(Vector2i.ZERO)

#endregion
