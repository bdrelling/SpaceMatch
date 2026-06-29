class_name DecayEngine
extends RefCounted
## Ticks the [DecayRule] on each of an [Entity]'s statuses at the moments the host drives. Timing decay fires on
## a matching phase, trigger decay on a matching hook, threshold decay when a stack's count reaches a value. Each
## reduces through [method StatusEngine.reduce_stack], so removal stays in one place. Statuses are walked on a
## copy so removal mid-tick is safe.


## Reduces every status whose [TimingDecayRule] phase equals [param phase].
static func tick_phase(entity: Entity, phase: StringName) -> void:
	if entity == null:
		return
	for stack in entity.statuses.duplicate():
		var rule := _rule_of(stack)
		if rule is TimingDecayRule and (rule as TimingDecayRule).phase == phase:
			StatusEngine.reduce_stack(entity, stack, (rule as TimingDecayRule).quantity)


## Reduces every status whose [TriggerDecayRule] hook matches [param hook] (see [method TriggerEngine.matches]).
static func tick_hook(entity: Entity, hook: Hook) -> void:
	if entity == null:
		return
	for stack in entity.statuses.duplicate():
		var rule := _rule_of(stack)
		if rule is TriggerDecayRule and TriggerEngine.matches((rule as TriggerDecayRule).hook, hook):
			StatusEngine.reduce_stack(entity, stack, (rule as TriggerDecayRule).quantity)


## Reduces every status whose [ThresholdDecayRule] value its stack count has reached.
static func tick_thresholds(entity: Entity) -> void:
	if entity == null:
		return
	for stack in entity.statuses.duplicate():
		var rule := _rule_of(stack)
		if rule is ThresholdDecayRule and stack.count >= (rule as ThresholdDecayRule).value:
			StatusEngine.reduce_stack(entity, stack, (rule as ThresholdDecayRule).quantity)


## The decay rule on [param stack]'s status, or null when absent.
static func _rule_of(stack: StatusStack) -> DecayRule:
	return stack.status.decay_rule if stack != null and stack.status != null else null
