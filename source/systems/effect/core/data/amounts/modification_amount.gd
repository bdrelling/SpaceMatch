class_name ModificationAmount
extends Amount
## Reads the magnitude of the change currently in flight — the [Modification] a reaction is responding to.
## Lets an effect fired off a change reuse what just happened (reflect the damage dealt, heal for the heal).
## Zero when there is no change in context.

func evaluate(context: ResolutionContext) -> int:
	if context.modification == null:
		return 0
	return context.modification.amount
