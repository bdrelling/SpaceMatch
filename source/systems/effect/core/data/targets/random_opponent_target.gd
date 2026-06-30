class_name RandomOpponentTarget
extends Target
## One opposing entity chosen at random. Reads the context's seeded RNG, so the same seed always picks the
## same foe — the example that exercises randomness in target selection.

func resolve(context: ResolutionContext) -> Array[Entity]:
	var result: Array[Entity] = []
	if context.opponents.is_empty():
		return result
	var index := context.rng.randi_range(0, context.opponents.size() - 1)
	result.append(context.opponents[index])
	return result
