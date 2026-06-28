class_name AttackerTarget
extends Target
## The entity that raised the current hook (e.g. whoever dealt the damage being reacted to).

func resolve(context: ResolutionContext) -> Array[Entity]:
	var result: Array[Entity] = []
	if context.attacker != null:
		result.append(context.attacker)
	return result
