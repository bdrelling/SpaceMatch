extends GdUnitTestSuite
## Tests RecipeBook.find_for / has_recipe_for (input matching by id, misses, null input) and
## create()'s flattening of nested books into one de-duplicated recipe list.

func _item(id: int) -> ItemBlueprint:
	var blueprint := ItemBlueprint.new()
	blueprint.id = id
	blueprint.name = "Item %d" % id
	return blueprint

func _stack(item_blueprint: ItemBlueprint, quantity: int = 1) -> ItemStack:
	return ItemStack.create(item_blueprint, quantity)

func _recipe(input: ItemBlueprint, output: ItemBlueprint) -> Recipe:
	var recipe := Recipe.new()
	recipe.inputs.append(_stack(input))
	recipe.outputs.append(_stack(output))
	return recipe

func _book(recipes: Array[Recipe]) -> RecipeBook:
	var book := RecipeBook.new()
	book.recipes = recipes
	return book

func _recipe_blueprint(input: ItemBlueprint, output: ItemBlueprint) -> RecipeBlueprint:
	var blueprint := RecipeBlueprint.new()
	blueprint.inputs.append(_stack(input))
	blueprint.outputs.append(_stack(output))
	return blueprint

func _book_blueprint(recipes: Array[RecipeBlueprint], books: Array[RecipeBookBlueprint]) -> RecipeBookBlueprint:
	var blueprint := RecipeBookBlueprint.new()
	blueprint.recipes = recipes
	blueprint.books = books
	return blueprint

func test_empty_book_finds_nothing() -> void:
	var recipes: Array[Recipe] = []
	assert_object(_book(recipes).find_for(_item(1))).is_null()

func test_null_input_finds_nothing() -> void:
	var recipes: Array[Recipe] = [_recipe(_item(1), _item(2))]
	assert_object(_book(recipes).find_for(null)).is_null()

func test_find_for_matches_input_id() -> void:
	# A different ItemBlueprint instance with the same id still matches.
	var out := _item(5)
	var recipes: Array[Recipe] = [_recipe(_item(2), out)]
	var found: Recipe = _book(recipes).find_for(_item(2))
	assert_object(found).is_not_null()
	assert_object(found.outputs[0].item_blueprint).is_same(out)

func test_find_for_returns_null_when_no_recipe_matches() -> void:
	var recipes: Array[Recipe] = [_recipe(_item(2), _item(5))]
	assert_object(_book(recipes).find_for(_item(99))).is_null()

func test_has_recipe_for_reflects_find_for() -> void:
	var recipes: Array[Recipe] = [_recipe(_item(2), _item(5))]
	var book := _book(recipes)
	assert_bool(book.has_recipe_for(_item(2))).is_true()
	assert_bool(book.has_recipe_for(_item(99))).is_false()

func test_book_keeps_nested_books_and_flattens_on_read() -> void:
	var own: Array[RecipeBlueprint] = [_recipe_blueprint(_item(1), _item(2))]
	var nested_recipes: Array[RecipeBlueprint] = [_recipe_blueprint(_item(3), _item(4))]
	var no_books: Array[RecipeBookBlueprint] = []
	var nested := _book_blueprint(nested_recipes, no_books)
	var children: Array[RecipeBookBlueprint] = [nested]

	var book := RecipeBook.create(_book_blueprint(own, children))
	# The runtime mirrors the blueprint tree: own recipe stays on the book, nested book is preserved.
	assert_int(book.recipes.size()).is_equal(1)
	assert_int(book.books.size()).is_equal(1)
	# Flattening happens on read.
	assert_int(book.all_recipes().size()).is_equal(2)
	assert_bool(book.has_recipe_for(_item(1))).is_true()
	assert_bool(book.has_recipe_for(_item(3))).is_true()

func test_all_recipes_dedupes_recipe_shared_across_books() -> void:
	# The same RecipeBlueprint reached through two books is built once.
	var shared := _recipe_blueprint(_item(1), _item(2))
	var no_books: Array[RecipeBookBlueprint] = []
	var nested_recipes: Array[RecipeBlueprint] = [shared]
	var nested := _book_blueprint(nested_recipes, no_books)
	var own: Array[RecipeBlueprint] = [shared]
	var children: Array[RecipeBookBlueprint] = [nested]

	var book := RecipeBook.create(_book_blueprint(own, children))
	assert_int(book.all_recipes().size()).is_equal(1)

func test_all_recipes_tolerates_cyclic_nesting() -> void:
	# Without the visited guards this would recurse forever on build and on read.
	var a_recipes: Array[RecipeBlueprint] = [_recipe_blueprint(_item(1), _item(2))]
	var b_recipes: Array[RecipeBlueprint] = [_recipe_blueprint(_item(3), _item(4))]
	var no_books: Array[RecipeBookBlueprint] = []
	var a := _book_blueprint(a_recipes, no_books)
	var b := _book_blueprint(b_recipes, no_books)
	var a_books: Array[RecipeBookBlueprint] = [b]
	var b_books: Array[RecipeBookBlueprint] = [a]
	a.books = a_books
	b.books = b_books

	var book := RecipeBook.create(a)
	assert_int(book.all_recipes().size()).is_equal(2)
