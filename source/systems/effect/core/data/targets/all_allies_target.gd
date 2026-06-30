class_name AllAlliesTarget
extends Target
## Every entity on the source's own side, including the source.

func resolve(context: ResolutionContext) -> Array[Entity]:
	var result: Array[Entity] = []
	result.assign(context.allies)
	return result
