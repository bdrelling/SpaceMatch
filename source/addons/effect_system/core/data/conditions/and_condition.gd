class_name AndCondition
extends Condition
## Holds only when every wrapped condition holds. An [Effect] already ANDs its own condition list; this is for
## building compound gates that nest inside an [OrCondition] or [NotCondition]. An empty list holds.

@export var conditions: Array[Condition] = []


## True when no wrapped condition fails. Null entries are ignored.
func holds(context: ResolutionContext) -> bool:
	for condition in conditions:
		if condition != null and not condition.holds(context):
			return false
	return true
