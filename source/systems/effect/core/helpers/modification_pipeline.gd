class_name ModificationPipeline
extends RefCounted
## Runs a [Modification] through every [ModificationStep] the source and target contribute, lowest
## [method ModificationStep.order] first, and returns the final magnitude to apply. Centralising the order
## here is the "do it right up front" move: every source of a change (an action, a reflected hit, a status
## tick) resolves through the same pipeline, so it is transformed identically no matter who launched it.
##
## Within one order value the source's steps run before the target's, and steps keep their status authoring
## order; the result is floored at zero.

## Transforms [param modification] in place and returns its final, non-negative magnitude.
static func resolve(modification: Modification, context: ResolutionContext) -> int:
	var entries: Array[Dictionary] = []
	_collect(modification.source, 0, modification, entries)
	_collect(modification.target, 1, modification, entries)
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.order != b.order:
			return a.order < b.order
		if a.side != b.side:
			return a.side < b.side
		return a.seq < b.seq)
	for entry: Dictionary in entries:
		var step: ModificationStep = entry.step
		step.modify(modification, context)
	modification.amount = maxi(0, modification.amount)
	return modification.amount


## Appends every applicable step on [param owner]'s active statuses, tagged with its [param side] (0 = source,
## 1 = target) and an insertion sequence so equal-order steps keep a stable order.
static func _collect(owner: Entity, side: int, modification: Modification, entries: Array[Dictionary]) -> void:
	if owner == null:
		return
	for stack in owner.statuses:
		if stack.status == null:
			continue
		for step in stack.status.transforms:
			if step.applies_to(modification):
				entries.append({order = step.order(), side = side, seq = entries.size(), step = step})
