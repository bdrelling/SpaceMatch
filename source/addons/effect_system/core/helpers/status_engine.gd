class_name StatusEngine
extends RefCounted
## Applies, stacks, and removes [Status]es on an [Entity]. Apply honours the status's [StackRule] (sum vs
## keep-highest) and its [member Status.cap]; decay reduces a stack and drops it at zero. [ApplyStatusAction] /
## [RemoveStatusAction] delegate here. This owns the status LIST only — stat changes are folded separately by
## [StatusModifiers], and reactions (hooks) are raised by [EffectRuntime].


## Applies [param count] stacks of [param status] to [param entity], merging into an existing stack of the same
## name per its [StackRule] and clamping to [member Status.cap]. Returns the live [StatusStack].
static func apply_status(entity: Entity, status: Status, count: int, _context: ResolutionContext) -> StatusStack:
	if entity == null or status == null:
		return null
	var existing := find_stack(entity, status.name)
	if existing != null:
		existing.count = _combine(status.stack_rule, existing.count, count, status.cap)
		return existing
	var stack := StatusStack.new()
	stack.status = status
	stack.count = _clamp_cap(count, status.cap)
	entity.statuses.append(stack)
	return stack


## Removes every stack of the status named [param status_name] from [param entity].
static func remove_status(entity: Entity, status_name: StringName) -> void:
	if entity == null:
		return
	for index in range(entity.statuses.size() - 1, -1, -1):
		var stack := entity.statuses[index]
		if stack != null and stack.status != null and stack.status.name == status_name:
			entity.statuses.remove_at(index)


## The live stack for [param status_name] on [param entity], or null if absent.
static func find_stack(entity: Entity, status_name: StringName) -> StatusStack:
	if entity == null:
		return null
	for stack in entity.statuses:
		if stack != null and stack.status != null and stack.status.name == status_name:
			return stack
	return null


## Reduces [param stack]'s count by [param quantity], removing it from [param entity] when it reaches zero.
static func reduce_stack(entity: Entity, stack: StatusStack, quantity: int) -> void:
	if entity == null or stack == null:
		return
	stack.count -= quantity
	if stack.count <= 0:
		entity.statuses.erase(stack)


## Combines an existing count with an incoming one per [param rule] (keep-highest takes the max, otherwise sum),
## clamped to [param cap].
static func _combine(rule: StackRule, existing: int, incoming: int, cap: int) -> int:
	var combined := maxi(existing, incoming) if rule is KeepHighestStackRule else existing + incoming
	return _clamp_cap(combined, cap)


## Clamps [param value] to [param cap] when cap is positive; zero or less means uncapped.
static func _clamp_cap(value: int, cap: int) -> int:
	return mini(value, cap) if cap > 0 else value
