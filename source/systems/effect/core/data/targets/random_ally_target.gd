class_name RandomAllyTarget
extends Target
## One entity from the source's own side chosen at random. Reads the context's seeded RNG, so the same seed
## always picks the same ally. The source is among the candidates.

func resolve(context: ResolutionContext) -> Array[Entity]:
	var result: Array[Entity] = []
	if context.allies.is_empty():
		return result
	var index := context.rng.randi_range(0, context.allies.size() - 1)
	result.append(context.allies[index])
	return result
