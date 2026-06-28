class_name OpponentTarget
extends Target
## The owning entity's opponent.

## The first opposing entity (the primary foe in a one-on-one matchup).
func resolve(context: ResolutionContext) -> Array[Entity]:
	var result: Array[Entity] = []
	if not context.opponents.is_empty():
		result.append(context.opponents[0])
	return result
