class_name InstigatorTarget
extends Target
## The entity that raised the current hook (e.g. whoever caused the change being reacted to).

func resolve(context: ResolutionContext) -> Array[Entity]:
	var result: Array[Entity] = []
	if context.instigator != null:
		result.append(context.instigator)
	return result
