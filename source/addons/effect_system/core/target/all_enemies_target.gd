class_name AllEnemiesTarget
extends Target
## Every opposing entity.

func resolve(context: ResolutionContext) -> Array[Entity]:
	var result: Array[Entity] = []
	result.assign(context.enemies)
	return result
