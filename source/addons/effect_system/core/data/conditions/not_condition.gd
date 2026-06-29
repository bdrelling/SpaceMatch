class_name NotCondition
extends Condition
## Holds when its wrapped [member condition] does not. The negation the base conditions can't express on their
## own — "target does NOT have shield", "source is NOT below half hull".

@export var condition: Condition


## True when [member condition] is present and fails to hold; a missing inner condition leaves the gate open.
func holds(context: ResolutionContext) -> bool:
	return not (condition != null and condition.holds(context))
