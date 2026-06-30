class_name StatusCountAmount
extends Amount
## The source's current stack count of the status named [member status]. Scales a change by a status the source
## holds — "deal damage equal to your charge", "heal per stack of regeneration". Zero when the source lacks the
## status.

@export var status: StringName


## Reads the source's live stack count for [member status] via [StatusEngine]. Zero when there is no source or
## the status is absent.
func evaluate(context: ResolutionContext) -> int:
	if context.source == null:
		return 0
	var stack := StatusEngine.find_stack(context.source, status)
	return stack.count if stack != null else 0
