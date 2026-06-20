extends GdUnitTestSuite
## Tests Recipe.produce(): plain recipes yield their authored outputs verbatim; recipes built
## from a [WeightedRecipeBlueprint] roll one stack from the pool, variant tags riding along.

func _item(id: int) -> ItemBlueprint:
	var blueprint := ItemBlueprint.new()
	blueprint.id = id
	blueprint.name = "Item %d" % id
	return blueprint

func _entry(stack: ItemStack, weight: float) -> WeightedEntry:
	var entry := WeightedEntry.new()
	entry.value = stack
	entry.weight = weight
	return entry

func _pool(entries: Array[WeightedEntry]) -> WeightedCollection:
	var collection := WeightedCollection.new()
	collection.entries = entries
	return collection

func test_plain_recipe_produces_outputs_verbatim() -> void:
	var blueprint := RecipeBlueprint.new()
	blueprint.inputs.append(ItemStack.create(_item(1)))
	blueprint.outputs.append(ItemStack.create(_item(2)))

	var recipe := Recipe.create(blueprint)
	assert_object(recipe.weighted_outputs).is_null()
	assert_array(recipe.produce()).is_equal(recipe.outputs)

func test_weighted_recipe_rolls_one_stack_from_pool() -> void:
	var damaged: Array[Item.Tag] = [Item.Tag.DAMAGED]
	var stack := ItemStack.create(_item(2), 1, damaged)
	var entries: Array[WeightedEntry] = [_entry(stack, 1.0)]

	var blueprint := WeightedRecipeBlueprint.new()
	blueprint.inputs.append(ItemStack.create(_item(1)))
	blueprint.weighted_outputs = _pool(entries)

	var recipe := Recipe.create(blueprint)
	var products: Array[ItemStack] = recipe.produce()
	assert_int(products.size()).is_equal(1)
	# The rolled stack is the authored entry itself, tags intact.
	assert_object(products[0]).is_same(stack)
	assert_bool(products[0].tags.has(Item.Tag.DAMAGED)).is_true()

func test_duration_defaults() -> void:
	var blueprint := RecipeBlueprint.new()
	assert_float(blueprint.duration).is_equal(0.35)
	assert_float(Recipe.create(blueprint).duration).is_equal(0.35)

func test_duration_copied_from_blueprint() -> void:
	var blueprint := RecipeBlueprint.new()
	blueprint.duration = 1.5
	assert_float(Recipe.create(blueprint).duration).is_equal(1.5)

func test_weighted_recipe_never_falls_back_to_outputs() -> void:
	var blueprint := WeightedRecipeBlueprint.new()
	blueprint.outputs.append(ItemStack.create(_item(2)))
	blueprint.weighted_outputs = _pool([] as Array[WeightedEntry])

	var recipe := Recipe.create(blueprint)
	assert_array(recipe.produce()).is_empty()
