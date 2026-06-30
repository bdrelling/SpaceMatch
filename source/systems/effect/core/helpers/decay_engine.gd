class_name DecayEngine
extends RefCounted
## Ticks the [DecayRule] on each of an [Entity]'s statuses at the moments the host drives. Timing decay fires on
## a matching phase, trigger decay on a matching hook, threshold decay when a stack's count reaches a value. Each
## reduces through [method StatusEngine.reduce_stack], so removal stays in one place. Statuses are walked on a
## copy so removal mid-tick is safe. Each tick returns the [Status]es whose last stack fell off, so the caller
## ([EffectRuntime]) can raise an [OnExpireHook] for them.


## Reduces every status whose [TimingDecayRule] phase equals [param phase]. Returns the statuses that expired.
static func tick_phase(entity: Entity, phase: StringName) -> Array[Status]:
	var expired: Array[Status] = []
	if entity == null:
		return expired
	for stack: StatusStack in entity.statuses.duplicate():
		var rule := _rule_of(stack)
		if rule is TimingDecayRule and (rule as TimingDecayRule).phase == phase:
			StatusEngine.reduce_stack(entity, stack, (rule as TimingDecayRule).quantity)
			if stack.count <= 0:
				expired.append(stack.status)
	return expired


## Reduces every status whose [TriggerDecayRule] hook matches [param hook] (see [method TriggerEngine.matches]).
## Returns the statuses that expired.
static func tick_hook(entity: Entity, hook: Hook) -> Array[Status]:
	var expired: Array[Status] = []
	if entity == null:
		return expired
	for stack: StatusStack in entity.statuses.duplicate():
		var rule := _rule_of(stack)
		if rule is TriggerDecayRule and TriggerEngine.matches((rule as TriggerDecayRule).hook, hook):
			StatusEngine.reduce_stack(entity, stack, (rule as TriggerDecayRule).quantity)
			if stack.count <= 0:
				expired.append(stack.status)
	return expired


## Reduces every status whose [ThresholdDecayRule] value its stack count has reached. Returns the statuses that
## expired.
static func tick_thresholds(entity: Entity) -> Array[Status]:
	var expired: Array[Status] = []
	if entity == null:
		return expired
	for stack: StatusStack in entity.statuses.duplicate():
		var rule := _rule_of(stack)
		if rule is ThresholdDecayRule and stack.count >= (rule as ThresholdDecayRule).value:
			StatusEngine.reduce_stack(entity, stack, (rule as ThresholdDecayRule).quantity)
			if stack.count <= 0:
				expired.append(stack.status)
	return expired


## The decay rule on [param stack]'s status, or null when absent.
static func _rule_of(stack: StatusStack) -> DecayRule:
	return stack.status.decay_rule if stack != null and stack.status != null else null
