class_name ApplyStatusAction
extends Action
## Applies [member count] stacks of the status named [member status] to the target.

@export var status: StringName
@export var count: int = 1


## Resolves the status name through [member ResolutionContext.status_catalog] and applies it via [StatusEngine].
func resolve(context: ResolutionContext, target: Entity) -> void:
	if target == null:
		return
	var resolved: Status = context.status_catalog.get(status, null)
	if resolved != null:
		StatusEngine.apply_status(target, resolved, count, context)
