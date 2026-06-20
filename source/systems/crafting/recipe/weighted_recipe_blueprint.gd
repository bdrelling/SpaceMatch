class_name WeightedRecipeBlueprint
extends RecipeBlueprint
## Authored data for a weighted [Recipe] — a pool of yield stacks rolled once per craft in place
## of the fixed [member outputs].

## The weighted pool; its entries' values are [ItemStack]s, so an entry can carry variant tags
## and a quantity.
@export var weighted_outputs: WeightedCollection
