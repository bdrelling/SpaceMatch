class_name StatThresholdCondition
extends Condition
## True when [member target]'s [member stat] compares against [member value] per [member comparison].

enum Comparison {
	LESS,
	EQUAL,
	GREATER,
}

@export var target: Target
@export var stat: StringName
@export var comparison: Comparison = Comparison.GREATER
@export var value: int = 0


## True when the first resolved target's [member stat] satisfies the comparison against [member value].
func holds(context: ResolutionContext) -> bool:
	var entities := target.resolve(context)
	if entities.is_empty() or entities[0].current_stats == null:
		return false
	var current := int(entities[0].current_stats.get_stat(stat))
	match comparison:
		Comparison.LESS:
			return current < value
		Comparison.EQUAL:
			return current == value
		Comparison.GREATER:
			return current > value
	return false
