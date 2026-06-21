extends GdUnitTestSuite
## Tests the Inventory node — the keyed add/remove/has/count store, capacity rules, stack
## size caps, grid placements, and the changed signal.

func _blueprint(id: int, name := "Item", max_stack_size := 0, footprint_cells: Array[Vector2i] = [Vector2i.ZERO]) -> ItemBlueprint:
	var blueprint := ItemBlueprint.new()
	blueprint.id = id
	blueprint.name = name
	blueprint.max_stack_size = max_stack_size
	blueprint.footprint_cells = footprint_cells
	return blueprint

func _item_of(blueprint: ItemBlueprint) -> Item:
	var item: Item = auto_free(Item.new())
	item.apply_blueprint(blueprint)
	return item

func _item(id: int, name := "Item") -> Item:
	return _item_of(_blueprint(id, name))

func _inventory(rule: CapacityRule = null) -> Inventory:
	var inventory: Inventory = auto_free(Inventory.new())
	inventory.capacity_rule = rule
	return inventory

func _stack_rule(max_stacks: int) -> StackCountCapacityRule:
	var rule := StackCountCapacityRule.new()
	rule.max_stacks = max_stacks
	return rule

func _grid_rule(width: int, height: int) -> GridCapacityRule:
	var rule := GridCapacityRule.new()
	rule.width = width
	rule.height = height
	return rule

# changed is emitted synchronously inside add/remove, so monitor_signals is unreliable
# here (see test_modifier_injection.gd). Count emissions via a direct connection instead.
func _emit_counter(inventory: Inventory) -> Array[int]:
	var count: Array[int] = [0]
	inventory.changed.connect(func(_i: Inventory) -> void: count[0] += 1)
	return count

func test_add_new_item_creates_stack() -> void:
	var inventory := _inventory()
	assert_bool(inventory.add(_item(1), 3)).is_true()
	assert_bool(inventory.has(1)).is_true()
	assert_int(inventory.count(1)).is_equal(3)
	assert_int(inventory.size).is_equal(1)

func test_add_existing_item_merges() -> void:
	var inventory := _inventory()
	var scrap := _blueprint(1)
	inventory.add(_item_of(scrap), 2)
	inventory.add(_item_of(scrap), 3)
	assert_int(inventory.count(1)).is_equal(5)
	assert_int(inventory.size).is_equal(1)

func test_add_null_item_returns_false() -> void:
	var inventory := _inventory()
	assert_bool(inventory.add(null)).is_false()
	assert_int(inventory.size).is_equal(0)

func test_add_nonpositive_amount_returns_false() -> void:
	var inventory := _inventory()
	assert_bool(inventory.add(_item(1), 0)).is_false()
	assert_bool(inventory.add(_item(1), -2)).is_false()
	assert_int(inventory.size).is_equal(0)

func test_add_emits_changed() -> void:
	var inventory := _inventory()
	var emits := _emit_counter(inventory)
	inventory.add(_item(1))
	assert_int(emits[0]).is_equal(1)

func test_remove_decrements_count() -> void:
	var inventory := _inventory()
	inventory.add(_item(1), 5)
	inventory.remove(1, 2)
	assert_int(inventory.count(1)).is_equal(3)

func test_remove_to_zero_erases_stack() -> void:
	var inventory := _inventory()
	inventory.add(_item(1), 2)
	inventory.remove(1, 2)
	assert_bool(inventory.has(1)).is_false()
	assert_int(inventory.count(1)).is_equal(0)
	assert_int(inventory.size).is_equal(0)

func test_remove_emits_changed() -> void:
	var inventory := _inventory()
	inventory.add(_item(1), 2)
	var emits := _emit_counter(inventory)
	inventory.remove(1)
	assert_int(emits[0]).is_equal(1)

func test_remove_missing_item_is_noop() -> void:
	var inventory := _inventory()
	var emits := _emit_counter(inventory)
	inventory.remove(99)
	assert_int(emits[0]).is_equal(0)
	assert_int(inventory.size).is_equal(0)

func test_count_absent_returns_zero() -> void:
	assert_int(_inventory().count(42)).is_equal(0)

func test_capacity_rule_limits_stacks() -> void:
	var inventory := _inventory(_stack_rule(1))
	assert_bool(inventory.add(_item(1))).is_true()
	# Second distinct item has no slot.
	assert_bool(inventory.add(_item(2))).is_false()
	# But an existing stack can still grow past capacity-of-slots.
	assert_bool(inventory.add(_item(1), 4)).is_true()
	assert_int(inventory.count(1)).is_equal(5)
	assert_int(inventory.size).is_equal(1)

func test_no_capacity_rule_is_unbounded() -> void:
	var inventory := _inventory()
	for i in 10:
		inventory.add(_item(i))
	assert_int(inventory.size).is_equal(10)

func test_get_stacks_returns_snapshot() -> void:
	var inventory := _inventory()
	inventory.add(_item(1))
	inventory.add(_item(2))
	var stacks := inventory.get_stacks()
	assert_int(stacks.size()).is_equal(2)
	# Mutating the snapshot must not affect the inventory.
	stacks.clear()
	assert_int(inventory.size).is_equal(2)

func test_tagged_variant_stacks_separately() -> void:
	var inventory := _inventory()
	var module := _blueprint(5, "Module")
	var working := _item_of(module)
	var damaged := _item_of(module)
	damaged.add_tag(Item.Tag.DAMAGED)
	var damaged_tags: Array[Item.Tag] = [Item.Tag.DAMAGED]
	inventory.add(working)
	inventory.add(damaged)
	assert_int(inventory.size).is_equal(2)
	assert_int(inventory.count(5)).is_equal(1)
	assert_int(inventory.count(5, damaged_tags)).is_equal(1)
	inventory.remove(5, 1, damaged_tags)
	assert_bool(inventory.has(5, damaged_tags)).is_false()
	assert_int(inventory.count(5)).is_equal(1)

#region Stack size caps

func test_add_overflows_into_new_stack_at_max_stack_size() -> void:
	var inventory := _inventory()
	var capped := _blueprint(1, "Scrap", 5)
	inventory.add(_item_of(capped), 4)
	assert_bool(inventory.add(_item_of(capped), 3)).is_true()
	assert_int(inventory.count(1)).is_equal(7)
	assert_int(inventory.size).is_equal(2)
	var quantities: Array[int] = []
	for stack: ItemStack in inventory.get_stacks():
		quantities.append(stack.quantity)
	assert_array(quantities).contains_exactly_in_any_order([5, 2])

func test_add_is_all_or_nothing_when_overflow_has_no_room() -> void:
	var inventory := _inventory(_stack_rule(1))
	var capped := _blueprint(1, "Scrap", 5)
	inventory.add(_item_of(capped), 4)
	assert_bool(inventory.add(_item_of(capped), 3)).is_false()
	assert_int(inventory.count(1)).is_equal(4)
	assert_int(inventory.size).is_equal(1)

func test_remove_drains_across_stacks() -> void:
	var inventory := _inventory()
	var capped := _blueprint(1, "Scrap", 5)
	inventory.add(_item_of(capped), 8)
	assert_int(inventory.size).is_equal(2)
	inventory.remove(1, 6)
	assert_int(inventory.count(1)).is_equal(2)
	assert_int(inventory.size).is_equal(1)

#endregion

#region Grid placements

func test_grid_add_auto_places_each_stack() -> void:
	var inventory := _inventory(_grid_rule(2, 2))
	inventory.add(_item(1))
	inventory.add(_item(2))
	var placements := inventory.get_placements()
	assert_int(placements.size()).is_equal(2)
	assert_that(placements[0].anchor).is_equal(Vector2i(0, 0))
	assert_that(placements[1].anchor).is_equal(Vector2i(1, 0))

func test_grid_add_fails_when_nothing_fits() -> void:
	var inventory := _inventory(_grid_rule(1, 1))
	assert_bool(inventory.add(_item(1))).is_true()
	assert_bool(inventory.add(_item(2))).is_false()
	assert_int(inventory.size).is_equal(1)

func test_grid_places_multi_cell_footprint() -> void:
	var tromino: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)]
	var inventory := _inventory(_grid_rule(2, 2))
	assert_bool(inventory.add(_item_of(_blueprint(1, "Module", 0, tromino)))).is_true()
	# One free cell remains for a single, then the grid is exhausted.
	assert_bool(inventory.add(_item(2))).is_true()
	assert_bool(inventory.add(_item(3))).is_false()

func test_grid_remove_erases_matching_placement() -> void:
	var inventory := _inventory(_grid_rule(2, 2))
	inventory.add(_item(1))
	inventory.add(_item(2))
	inventory.remove(1)
	assert_int(inventory.size).is_equal(1)
	assert_int(inventory.get_placements().size()).is_equal(1)
	var remaining_stack := inventory.get_stacks()[0]
	assert_that(inventory.placement_of(remaining_stack).anchor).is_equal(Vector2i(1, 0))

func test_move_stack_to_open_cell() -> void:
	var inventory := _inventory(_grid_rule(2, 2))
	inventory.add(_item(1))
	var stack := inventory.get_stacks()[0]
	var emits := _emit_counter(inventory)
	assert_bool(inventory.move_stack(stack, Vector2i(1, 1))).is_true()
	assert_that(inventory.placement_of(stack).anchor).is_equal(Vector2i(1, 1))
	assert_int(emits[0]).is_equal(1)

func test_move_stack_rejects_collision_and_bounds() -> void:
	var inventory := _inventory(_grid_rule(2, 1))
	inventory.add(_item(1))
	inventory.add(_item(2))
	var first := inventory.get_stacks()[0]
	assert_bool(inventory.move_stack(first, Vector2i(1, 0))).is_false()
	assert_bool(inventory.move_stack(first, Vector2i(2, 0))).is_false()
	assert_that(inventory.placement_of(first).anchor).is_equal(Vector2i(0, 0))

func test_move_stack_allows_rotation_in_place() -> void:
	var line: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	var inventory := _inventory(_grid_rule(3, 3))
	inventory.add(_item_of(_blueprint(1, "Module", 0, line)))
	var stack := inventory.get_stacks()[0]
	assert_bool(inventory.move_stack(stack, Vector2i.ZERO, 1)).is_true()
	assert_int(inventory.placement_of(stack).rotation_steps).is_equal(1)

func test_move_stack_requires_grid_rule() -> void:
	var inventory := _inventory()
	inventory.add(_item(1))
	assert_bool(inventory.move_stack(inventory.get_stacks()[0], Vector2i.ZERO)).is_false()

func test_stack_at_cell_covers_footprint() -> void:
	var tromino: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)]
	var inventory := _inventory(_grid_rule(2, 2))
	inventory.add(_item_of(_blueprint(1, "Module", 0, tromino)))
	var stack := inventory.get_stacks()[0]
	assert_object(inventory.stack_at_cell(Vector2i(0, 1))).is_same(stack)
	assert_object(inventory.stack_at_cell(Vector2i(1, 0))).is_null()

func test_can_place_previews_without_mutating() -> void:
	var inventory := _inventory(_grid_rule(2, 1))
	inventory.add(_item(1))
	inventory.add(_item(2))
	var first := inventory.get_stacks()[0]
	assert_bool(inventory.can_place(first, Vector2i(0, 0))).is_true()
	assert_bool(inventory.can_place(first, Vector2i(1, 0))).is_false()
	assert_that(inventory.placement_of(first).anchor).is_equal(Vector2i(0, 0))

func test_remove_from_stack_targets_that_stack() -> void:
	var inventory := _inventory(_grid_rule(3, 1))
	# Cap 2, five units: spills into stacks of 2 / 2 / 1.
	inventory.add(_item_of(_blueprint(1, "Scrap", 2)), 5)
	var stacks := inventory.get_stacks()
	assert_int(stacks.size()).is_equal(3)
	# Variant-blind remove() would drain the newest stack; this drains the addressed one.
	assert_bool(inventory.remove_from_stack(stacks[0], 1)).is_true()
	assert_int(stacks[0].quantity).is_equal(1)
	assert_int(stacks[2].quantity).is_equal(1)
	# Emptying the addressed stack erases it and its placement, arrays staying parallel.
	assert_bool(inventory.remove_from_stack(stacks[0], 1)).is_true()
	assert_int(inventory.get_stacks().size()).is_equal(2)
	assert_int(inventory.get_placements().size()).is_equal(2)
	assert_bool(inventory.remove_from_stack(stacks[0], 1)).is_false()

func test_move_stack_respects_single_cell_rows() -> void:
	var rule := _grid_rule(2, 2)
	rule.single_cell_rows = 1
	var domino: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
	var inventory := _inventory(rule)
	inventory.add(_item_of(_blueprint(1, "Module", 0, domino)))
	inventory.add(_item(2))
	var module := inventory.get_stacks()[0]
	var single := inventory.get_stacks()[1]
	# The multi-cell stack auto-placed below the restricted row and can't be moved into it.
	assert_that(inventory.placement_of(module).anchor).is_equal(Vector2i(0, 1))
	assert_bool(inventory.can_place(module, Vector2i(0, 0))).is_false()
	# A 1x1 moves into the restricted row freely.
	assert_bool(inventory.move_stack(single, Vector2i(1, 0))).is_true()

#endregion

#region Transfer

func _weight_rule(max_weight: float) -> WeightCapacityRule:
	var rule := WeightCapacityRule.new()
	rule.max_weight = max_weight
	return rule

func test_transfer_to_moves_whole_stack() -> void:
	var source := _inventory()
	var target := _inventory()
	source.add(_item(1), 5)
	var stack := source.get_stacks()[0]
	assert_bool(source.transfer_to(target, stack)).is_true()
	assert_int(source.count(1)).is_equal(0)
	assert_int(source.size).is_equal(0)
	assert_int(target.count(1)).is_equal(5)

func test_transfer_to_partial_amount_decrements_source() -> void:
	var source := _inventory()
	var target := _inventory()
	source.add(_item(1), 5)
	var stack := source.get_stacks()[0]
	assert_bool(source.transfer_to(target, stack, 2)).is_true()
	assert_int(source.count(1)).is_equal(3)
	assert_int(target.count(1)).is_equal(2)

func test_transfer_to_preserves_variant_tags() -> void:
	var damaged_tags: Array[Item.Tag] = [Item.Tag.DAMAGED]
	var source := _inventory()
	var target := _inventory()
	var item := _item(1)
	item.add_tag(Item.Tag.DAMAGED)
	source.add(item, 2)
	assert_bool(source.transfer_to(target, source.get_stacks()[0])).is_true()
	assert_int(target.count(1, damaged_tags)).is_equal(2)
	assert_int(target.count(1)).is_equal(0)

func test_transfer_to_grid_target_replaces_per_own_rule() -> void:
	var source := _inventory(_grid_rule(3, 1))
	var target := _inventory(_grid_rule(2, 2))
	source.add(_item(1), 2)
	var stack := source.get_stacks()[0]
	source.move_stack(stack, Vector2i(2, 0))
	assert_bool(source.transfer_to(target, stack)).is_true()
	# The source placement (2, 0) is out of the 2x2 target's bounds; the target found its own.
	assert_int(target.get_placements().size()).is_equal(1)
	assert_that(target.get_placements()[0].anchor).is_equal(Vector2i(0, 0))
	assert_int(source.get_stacks().size()).is_equal(0)
	assert_int(source.get_placements().size()).is_equal(0)

func test_transfer_to_grid_target_rejects_when_full() -> void:
	var source := _inventory()
	var target := _inventory(_grid_rule(1, 1))
	target.add(_item(2))
	source.add(_item(1), 3)
	var stack := source.get_stacks()[0]
	assert_bool(source.transfer_to(target, stack)).is_false()
	assert_int(source.count(1)).is_equal(3)
	assert_int(target.count(1)).is_equal(0)

func test_transfer_to_weight_target_is_all_or_nothing() -> void:
	var heavy := _blueprint(1, "Plate")
	heavy.weight = 2.0
	var source := _inventory()
	var target := _inventory(_weight_rule(5.0))
	source.add(_item_of(heavy), 3)
	var stack := source.get_stacks()[0]
	# 3 plates weigh 6 > 5; nothing moves.
	assert_bool(source.transfer_to(target, stack)).is_false()
	assert_int(source.count(1)).is_equal(3)
	# A partial transfer within the limit succeeds.
	assert_bool(source.transfer_to(target, stack, 2)).is_true()
	assert_int(source.count(1)).is_equal(1)
	assert_int(target.count(1)).is_equal(2)

func test_transfer_to_stack_count_target_rejects_when_full() -> void:
	var source := _inventory()
	var target := _inventory(_stack_rule(1))
	target.add(_item(2))
	source.add(_item(1))
	assert_bool(source.transfer_to(target, source.get_stacks()[0])).is_false()
	assert_int(source.count(1)).is_equal(1)

func test_transfer_to_rejects_foreign_stack_and_self() -> void:
	var source := _inventory()
	var target := _inventory()
	source.add(_item(1))
	var stack := source.get_stacks()[0]
	var foreign := ItemStack.create(_blueprint(9), 1)
	assert_bool(source.transfer_to(target, foreign)).is_false()
	assert_bool(source.transfer_to(source, stack)).is_false()
	assert_bool(source.transfer_to(null, stack)).is_false()
	assert_int(source.count(1)).is_equal(1)

#endregion

#region Blueprinting

func test_apply_blueprint_copies_stacks() -> void:
	var template := InventoryBlueprint.new()
	template.capacity_rule = _stack_rule(5)
	var stacks: Array[ItemStack] = [ItemStack.create(_blueprint(1), 4)]
	template.item_stacks = stacks
	var inventory := _inventory()
	inventory.apply_blueprint(template)
	assert_object(inventory.capacity_rule).is_same(template.capacity_rule)
	assert_int(inventory.count(1)).is_equal(4)
	# The live inventory owns its quantities — growing it must not touch the blueprint template.
	inventory.add(_item(1), 3)
	assert_int(inventory.count(1)).is_equal(7)
	assert_int(template.item_stacks[0].quantity).is_equal(4)

func test_apply_blueprint_copies_tagged_stack_variant() -> void:
	var damaged_tags: Array[Item.Tag] = [Item.Tag.DAMAGED]
	var template := InventoryBlueprint.new()
	var stacks: Array[ItemStack] = [ItemStack.create(_blueprint(5), 2, damaged_tags)]
	template.item_stacks = stacks
	var inventory := _inventory()
	inventory.apply_blueprint(template)
	assert_int(inventory.count(5, damaged_tags)).is_equal(2)
	assert_int(inventory.count(5)).is_equal(0)

func test_apply_blueprint_with_grid_rule_places_authored_stacks() -> void:
	var template := InventoryBlueprint.new()
	template.capacity_rule = _grid_rule(2, 2)
	var stacks: Array[ItemStack] = [ItemStack.create(_blueprint(1), 4), ItemStack.create(_blueprint(2), 1)]
	template.item_stacks = stacks
	var inventory := _inventory()
	inventory.apply_blueprint(template)
	assert_int(inventory.size).is_equal(2)
	assert_int(inventory.get_placements().size()).is_equal(2)

#endregion
