class_name RecipeBook
extends Resource
## Runtime mirror of a [RecipeBookBlueprint]: holds the [Recipe]s authored on the book plus the
## nested [RecipeBook]s built from the blueprint's nested books, preserving that structure. The
## flattened, de-duplicated recipe set is computed on read ([method all_recipes]) rather than baked
## in at apply time, so callers can layer ordering/filtering on top later. A station holds one and
## queries it.

## Recipes authored directly on this book (not its nested books).
var recipes: Array[Recipe] = []
## Books nested under this one, mirroring [member RecipeBookBlueprint.books].
var books: Array[RecipeBook] = []

## Flattened, de-duplicated recipes across this book and every nested book — computed fresh on each
## call, not cached. A recipe reached through multiple books appears once (a shared source
## [RecipeBlueprint] yields one shared [Recipe]). Cyclic nesting is walked safely.
func all_recipes() -> Array[Recipe]:
	var result: Array[Recipe] = []
	_gather_recipes(result, {}, {})
	return result

# [param seen] and [param visited] are Dictionary-backed sets (O(1) membership) so the walk stays
# linear in recipes + books; [param result] preserves first-seen order.
func _gather_recipes(result: Array[Recipe], seen: Dictionary, visited: Dictionary) -> void:
	if visited.has(self):
		return
	visited[self] = true
	for recipe: Recipe in recipes:
		if recipe != null and not seen.has(recipe):
			seen[recipe] = true
			result.append(recipe)
	for book: RecipeBook in books:
		if book != null:
			book._gather_recipes(result, seen, visited)

## Returns the first recipe — across this book and its nested books — that consumes
## [param input] (matched by id), or null when none does.
func find_for(input: ItemBlueprint) -> Recipe:
	if input == null:
		return null

	for recipe: Recipe in all_recipes():
		if recipe == null:
			continue
		for ingredient: ItemStack in recipe.inputs:
			if ingredient != null and ingredient.item_blueprint != null and ingredient.item_blueprint.id == input.id:
				return recipe

	return null

## Whether this book (or a nested one) has a recipe that consumes [param input].
func has_recipe_for(input: ItemBlueprint) -> bool:
	return find_for(input) != null

func apply_blueprint(_blueprint: RecipeBookBlueprint) -> void:
	_apply_blueprint(_blueprint, {})

# Mirrors the blueprint tree onto runtime objects. [param cache] maps each source blueprint (recipe
# or book) to the single runtime instance built for it, so a resource shared across the tree is
# built once, and cyclic nesting resolves to shared references instead of recursing forever (each
# book registers itself before descending into its own nested books).
func _apply_blueprint(_blueprint: RecipeBookBlueprint, cache: Dictionary) -> void:
	if not _blueprint:
		Log.error("Unable to apply blueprint; blueprint not found")
		return
	cache[_blueprint] = self

	recipes.clear()
	for recipe_blueprint: RecipeBlueprint in _blueprint.recipes:
		if recipe_blueprint == null:
			continue
		var recipe: Recipe = cache.get(recipe_blueprint)
		if recipe == null:
			recipe = Recipe.create(recipe_blueprint)
			if recipe != null:
				cache[recipe_blueprint] = recipe
		if recipe != null and not recipes.has(recipe):
			recipes.append(recipe)

	books.clear()
	for book_blueprint: RecipeBookBlueprint in _blueprint.books:
		if book_blueprint == null:
			continue
		var book: RecipeBook = cache.get(book_blueprint)
		if book == null:
			book = RecipeBook.new()
			book._apply_blueprint(book_blueprint, cache)
		if not books.has(book):
			books.append(book)

static func create(_blueprint: RecipeBookBlueprint) -> RecipeBook:
	if not _blueprint:
		Log.error("Blueprint required to create RecipeBook")
		return null

	var book := RecipeBook.new()
	book.apply_blueprint(_blueprint)
	return book
