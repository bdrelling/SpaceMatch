class_name RecipeBlueprint
extends Resource
## Authored data for one [Recipe] — the input stacks it consumes, the output stacks it yields,
## and a label.

@export var inputs: Array[ItemStack] = []
@export var outputs: Array[ItemStack] = []
## Seconds one craft takes.
@export var duration: float = 0.35
## Player-facing label. Optional.
@export var name: String
## Longer description for tooltips/UI. Optional.
@export var description: String
