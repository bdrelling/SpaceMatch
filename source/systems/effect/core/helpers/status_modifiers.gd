class_name StatusModifiers
extends RefCounted
## Folds an entity's active-status [Modifier]s onto a [EntityStats] the GAME supplies from its own stat
## computation. This is the engine's only hand in stats: it stores no derived block — the game owns the
## base → effective → current layering and calls this to layer status modifiers in. A modifier applies once
## per stack, so a status at N stacks contributes its modifier N times.


## Layers every active status's modifiers onto [param into], in place, matched by [EntityStat].
## [member Modifier.operation] ADD adds amount × count; MULTIPLY multiplies by amount, count times. The result is
## rounded to the integer the stat holds.
static func apply(entity: Entity, into: EntityStats) -> void:
	if entity == null or into == null:
		return
	for stack in entity.statuses:
		if stack == null or stack.status == null:
			continue
		for modifier in stack.status.modifiers:
			if modifier == null or modifier.stat == null:
				continue
			var current := into.get_stat(modifier.stat)
			var result := float(current)
			match modifier.operation:
				Modifier.Operation.ADD:
					result = float(current) + modifier.amount * stack.count
				Modifier.Operation.MULTIPLY:
					result = float(current) * pow(modifier.amount, stack.count)
			into.set_stat(modifier.stat, roundi(result))
