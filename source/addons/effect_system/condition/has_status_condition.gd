class_name HasStatusCondition
extends Condition
## True when [member target] currently holds the status named [member status].

@export var target: Target
@export var status: StringName


func holds(context: ResolutionContext) -> bool:
	for entity in target.resolve(context):
		for stack in entity.statuses:
			if stack.status != null and stack.status.name == status and stack.count > 0:
				return true
	return false
