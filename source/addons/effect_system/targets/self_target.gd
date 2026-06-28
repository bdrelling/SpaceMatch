class_name SelfTarget
extends Target
## The entity that owns the effect.

func resolve(context: ResolutionContext) -> Array[Entity]:
	var result: Array[Entity] = []
	if context.source != null:
		result.append(context.source)
	return result
