class_name StarshipGenerator
extends RefCounted
## Stateless factory: builds a [StarshipState] from a [StarshipBlueprint], using a [ModuleGridGenerator]
## for its module grid.

static func generate(blueprint: StarshipBlueprint) -> StarshipState:
	var starship := StarshipState.new()
	if blueprint == null:
		return starship
	starship.name = blueprint.name
	starship.module_grid = ModuleGridGenerator.generate(blueprint.module_grid)
	return starship
