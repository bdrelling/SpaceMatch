class_name Recipe
extends Resource
## A crafting transformation: consumes [member inputs], yields [method produce]. Any later
## behaviour — gating on player context, skills — belongs here, not on the blueprint.

@export var inputs: Array[ItemStack] = []
@export var outputs: Array[ItemStack] = []
## Seconds one craft takes.
@export var duration: float = 0.35
@export var name: String
@export var description: String

## Weighted pool of possible yields, copied from a [WeightedRecipeBlueprint]; null for plain
## recipes. When set, [method produce] rolls from it instead of returning [member outputs].
var weighted_outputs: WeightedCollection

## Whether [param inventory] holds every input this recipe consumes.
func can_craft(inventory: Inventory) -> bool:
	if inventory == null:
		return false
	for ingredient: ItemStack in inputs:
		if ingredient == null or ingredient.item_blueprint == null:
			continue
		if inventory.count(ingredient.item_blueprint.id, ingredient.tags) < ingredient.quantity:
			return false
	return true

## The stacks one craft of this recipe yields — [member outputs] verbatim, or one stack rolled
## from [member weighted_outputs] when this recipe is weighted.
func produce() -> Array[ItemStack]:
	if weighted_outputs == null:
		return outputs
	var products: Array[ItemStack] = []
	var product: ItemStack = weighted_outputs.pick() as ItemStack
	if product != null:
		products.append(product)
	return products

func apply_blueprint(_blueprint: RecipeBlueprint) -> void:
	if not _blueprint:
		Log.error("Unable to apply blueprint; blueprint not found")
		return

	inputs = _blueprint.inputs.duplicate()
	outputs = _blueprint.outputs.duplicate()
	duration = _blueprint.duration
	var weighted := _blueprint as WeightedRecipeBlueprint
	weighted_outputs = weighted.weighted_outputs if weighted != null else null
	name = _blueprint.name
	description = _blueprint.description

static func create(_blueprint: RecipeBlueprint) -> Recipe:
	if not _blueprint:
		Log.error("Blueprint required to create Recipe")
		return null

	var recipe := Recipe.new()
	recipe.apply_blueprint(_blueprint)
	return recipe
