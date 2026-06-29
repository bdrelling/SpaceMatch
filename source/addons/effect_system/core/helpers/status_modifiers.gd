class_name StatusModifiers
extends RefCounted
## Folds an entity's active-status [Modifier]s onto a [StatBlock] the GAME supplies from its own stat
## computation. This is the engine's only hand in stats: it stores no derived block — the game owns the
## base → effective → current layering and calls this to layer status modifiers in. A modifier applies once
## per stack, so a status at N stacks contributes its modifier N times.


## Layers every active status's modifiers onto [param into], in place, matched by stat name. Stats the block
## does not declare are skipped. [member Modifier.operation] ADD adds amount × count; MULTIPLY multiplies by
## amount, count times. Integer stats are rounded; other stats keep their type.
static func apply(entity: Entity, into: StatBlock) -> void:
	if entity == null or into == null:
		return
	var names := into.stat_names()
	for stack in entity.statuses:
		if stack == null or stack.status == null:
			continue
		for modifier in stack.status.modifiers:
			if modifier == null or modifier.stat not in names:
				continue
			var current: Variant = into.get_stat(modifier.stat)
			var result := float(current)
			match modifier.operation:
				Modifier.Operation.ADD:
					result = float(current) + modifier.amount * stack.count
				Modifier.Operation.MULTIPLY:
					result = float(current) * pow(modifier.amount, stack.count)
			if typeof(current) == TYPE_INT:
				into.set_stat(modifier.stat, int(round(result)))
			else:
				into.set_stat(modifier.stat, result)
