class_name AllOpponentsTarget
extends Target
## Every opposing entity.

func resolve(context: ResolutionContext) -> Array[Entity]:
	var result: Array[Entity] = []
	result.assign(context.opponents)
	return result
