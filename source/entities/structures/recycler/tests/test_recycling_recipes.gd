extends GdUnitTestSuite
## Guards the recycler's recipe data: every recycling recipe is weighted, breaking scrap down
## into components most of the time with a rare damaged module — never working modules (the
## refurbisher's job) and never scrap. Catches the regression where recycling deterministically
## turned every scrap into a module.

const _BOOK_PATH := "res://resources/recipe_books/recycling_recipe_book.tres"

func test_recycling_recipes_yield_components_or_damaged_module() -> void:
	var book_blueprint: RecipeBookBlueprint = load(_BOOK_PATH)
	assert_object(book_blueprint).is_not_null()
	assert_array(book_blueprint.recipes).is_not_empty()

	for recipe_blueprint: RecipeBlueprint in book_blueprint.recipes:
		var weighted := recipe_blueprint as WeightedRecipeBlueprint
		assert_object(weighted).is_not_null()

		var entries: Array[WeightedEntry] = weighted.weighted_outputs.entries
		assert_array(entries).is_not_empty()

		var component_weight := 0.0
		var module_weight := 0.0
		var damaged_modules := 0
		for entry: WeightedEntry in entries:
			var stack := entry.value as ItemStack
			var category: Item.Category = stack.item_blueprint.category
			assert_bool(category == Item.Category.COMPONENT or category == Item.Category.MODULE).is_true()
			if category == Item.Category.COMPONENT:
				assert_array(stack.tags).is_empty()
				component_weight += entry.weight
			else:
				# The module outcome is always damaged — recycling never yields a working module.
				assert_bool(stack.tags.has(Item.Tag.DAMAGED)).is_true()
				damaged_modules += 1
				module_weight += entry.weight

		assert_int(damaged_modules).is_equal(1)
		# The damaged module stays the rare outcome.
		assert_float(module_weight).is_less(component_weight)
