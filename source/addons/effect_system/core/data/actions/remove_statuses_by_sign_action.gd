class_name RemoveStatusesBySignAction
extends Action
## Removes every status on the target whose [member Status.sign] matches [member sign] — a blanket cleanse of
## debuffs or dispel of buffs, rather than naming one status like [RemoveStatusAction].

## Which statuses to strip: [constant Status.Sign.NEGATIVE] cleanses debuffs, [constant Status.Sign.POSITIVE]
## dispels buffs.
@export var sign: Status.Sign = Status.Sign.NEGATIVE


## Collects the names of the target's statuses matching [member sign], then removes each through [StatusEngine].
## Names are gathered before removal so mutating the status list mid-walk is safe.
func resolve(_context: ResolutionContext, target: Entity) -> void:
	if target == null:
		return
	var names: Array[StringName] = []
	for stack in target.statuses:
		if stack != null and stack.status != null and stack.status.sign == sign:
			names.append(stack.status.name)
	for name in names:
		StatusEngine.remove_status(target, name)
