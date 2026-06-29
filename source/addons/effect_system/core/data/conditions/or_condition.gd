class_name OrCondition
extends Condition
## Holds when at least one wrapped condition holds. The disjunction the base conditions can't express — "target
## has poison OR bleed". An empty list does not hold.

@export var conditions: Array[Condition] = []


## True as soon as any wrapped condition holds. Null entries are ignored.
func holds(context: ResolutionContext) -> bool:
	for condition in conditions:
		if condition != null and condition.holds(context):
			return true
	return false
