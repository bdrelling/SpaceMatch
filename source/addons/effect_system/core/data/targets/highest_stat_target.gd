class_name HighestStatTarget
extends Target
## The single entity with the highest value of [member stat] among those [member from] selects. Side-agnostic by
## composition: point [member from] at opponents to pick the toughest foe, at allies to pick the healthiest
## friend. Purely a targeting relation — it names which entity a change lands on, not a strategic decision.

## The pool to choose from (e.g. an [AllOpponentsTarget] or [AllAlliesTarget]). Entities without a stat block
## are skipped.
@export var from: Target
## The stat compared across the pool.
@export var stat: StringName


## Resolves [member from], then returns the one entity whose [member stat] is largest. Empty when the pool is
## empty or no candidate carries a stat block. [member from] may be async (a chooser), so it is awaited.
func resolve(context: ResolutionContext) -> Array[Entity]:
	var result: Array[Entity] = []
	if from == null:
		return result
	var best: Entity = null
	var best_value := 0
	for entity in await from.resolve(context):
		if entity == null or entity.current_stats == null:
			continue
		var value := int(entity.current_stats.get_stat(stat))
		if best == null or value > best_value:
			best = entity
			best_value = value
	if best != null:
		result.append(best)
	return result
