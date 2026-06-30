class_name RemoveStatusAction
extends Action
## Removes the status named [member status] from the target.

@export var status: StringName


## Removes the named status from the target via [StatusEngine].
func resolve(_context: ResolutionContext, target: Entity) -> void:
	if target != null:
		StatusEngine.remove_status(target, status)
