class_name StatAmount
extends Amount
## Reads the value from the source entity's [member stat].

@export var stat: EntityStat


## Reads [member stat] from the source's current stats. Zero when there is no source or stat block.
func evaluate(context: ResolutionContext) -> int:
	if context.source == null or context.source.current_stats == null:
		return 0
	return context.source.current_stats.get_stat(stat)
