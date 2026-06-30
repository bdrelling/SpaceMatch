class_name AllEntitiesTarget
extends Target
## Every entity in the encounter — both sides at once. The pool an effect that hits everyone (a field-wide
## blast, an all-combatants cleanse) resolves against.

func resolve(context: ResolutionContext) -> Array[Entity]:
	var result: Array[Entity] = []
	result.assign(context.allies)
	result.append_array(context.opponents)
	return result
