extends GdUnitTestSuite
## Tests the ItemStack data resource — stacking, merge, and split logic.

func _blueprint(id: int, name := "Item") -> ItemBlueprint:
	var blueprint := ItemBlueprint.new()
	blueprint.id = id
	blueprint.name = name
	return blueprint

func test_create_returns_stack_with_quantity() -> void:
	var stack := ItemStack.create(_blueprint(1), 5)
	assert_object(stack).is_not_null()
	assert_int(stack.quantity).is_equal(5)

func test_create_defaults_quantity_to_one() -> void:
	var stack := ItemStack.create(_blueprint(1))
	assert_int(stack.quantity).is_equal(1)

func test_create_with_null_blueprint_returns_null() -> void:
	assert_object(ItemStack.create(null)).is_null()

func test_add_increases_quantity() -> void:
	var stack := ItemStack.create(_blueprint(1), 2)
	stack.add(3)
	assert_int(stack.quantity).is_equal(5)

func test_remove_decreases_quantity() -> void:
	var stack := ItemStack.create(_blueprint(1), 5)
	stack.remove(2)
	assert_int(stack.quantity).is_equal(3)

func test_remove_clamps_at_zero() -> void:
	var stack := ItemStack.create(_blueprint(1), 2)
	stack.remove(10)
	assert_int(stack.quantity).is_equal(0)

func test_can_merge_same_item() -> void:
	var a := ItemStack.create(_blueprint(7), 1)
	var b := ItemStack.create(_blueprint(7), 1)
	assert_bool(a.can_merge(b)).is_true()

func test_can_merge_same_item_different_tags() -> void:
	var damaged_tags: Array[Item.Tag] = [Item.Tag.DAMAGED]
	var a := ItemStack.create(_blueprint(7), 1)
	var b := ItemStack.create(_blueprint(7), 1, damaged_tags)
	assert_bool(a.can_merge(b)).is_false()

func test_can_merge_same_item_same_tags() -> void:
	var damaged_tags: Array[Item.Tag] = [Item.Tag.DAMAGED]
	var a := ItemStack.create(_blueprint(7), 1, damaged_tags)
	var b := ItemStack.create(_blueprint(7), 1, damaged_tags)
	assert_bool(a.can_merge(b)).is_true()

func test_can_merge_different_item() -> void:
	var a := ItemStack.create(_blueprint(7), 1)
	var b := ItemStack.create(_blueprint(8), 1)
	assert_bool(a.can_merge(b)).is_false()

func test_can_merge_null() -> void:
	var a := ItemStack.create(_blueprint(7), 1)
	assert_bool(a.can_merge(null)).is_false()

func test_merge_sums_quantities() -> void:
	var a := ItemStack.create(_blueprint(7), 2)
	var b := ItemStack.create(_blueprint(7), 3)
	assert_bool(a.merge(b)).is_true()
	assert_int(a.quantity).is_equal(5)

func test_merge_different_items_fails_and_leaves_quantity() -> void:
	var a := ItemStack.create(_blueprint(7), 2)
	var b := ItemStack.create(_blueprint(8), 3)
	assert_bool(a.merge(b)).is_false()
	assert_int(a.quantity).is_equal(2)

func test_split_returns_new_stack_and_reduces_source() -> void:
	var stack := ItemStack.create(_blueprint(7), 5)
	var split := stack.split(2)
	assert_object(split).is_not_null()
	assert_int(split.quantity).is_equal(2)
	assert_int(stack.quantity).is_equal(3)
	assert_int(split.item_blueprint.id).is_equal(7)

func test_split_preserves_tags() -> void:
	var damaged_tags: Array[Item.Tag] = [Item.Tag.DAMAGED]
	var stack := ItemStack.create(_blueprint(7), 5, damaged_tags)
	var split := stack.split(2)
	assert_bool(split.variant_id.equals(stack.variant_id)).is_true()

func test_split_nonpositive_returns_null() -> void:
	var stack := ItemStack.create(_blueprint(7), 5)
	assert_object(stack.split(0)).is_null()
	assert_int(stack.quantity).is_equal(5)

func test_split_whole_or_more_returns_null() -> void:
	var stack := ItemStack.create(_blueprint(7), 5)
	assert_object(stack.split(5)).is_null()
	assert_object(stack.split(6)).is_null()
	assert_int(stack.quantity).is_equal(5)
