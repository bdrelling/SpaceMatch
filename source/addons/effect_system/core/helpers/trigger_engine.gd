class_name TriggerEngine
extends RefCounted
## Runs the [TriggeredEffect]s an [Entity]'s statuses carry when their [Trigger] fires: a [PhaseTrigger] on a
## phase, a [HookTrigger] on a hook, a [CountTrigger] when a stack reaches a count. Effects run through the
## existing [method Effect.resolve]. Also owns [method matches], the hook-matching rule shared with [DecayEngine].
## Statuses are walked on a copy so an effect that adds/removes a status mid-fire is safe.


## Runs the effects of every [PhaseTrigger] whose phase equals [param phase].
static func fire_phase(entity: Entity, phase: StringName, context: ResolutionContext) -> void:
	if entity == null:
		return
	for stack in entity.statuses.duplicate():
		if stack == null or stack.status == null:
			continue
		for triggered in stack.status.effects:
			if triggered != null and triggered.trigger is PhaseTrigger and (triggered.trigger as PhaseTrigger).phase == phase:
				await _run(triggered.effects, context)


## Runs the effects of every [HookTrigger] whose hook matches [param hook].
static func fire_hook(entity: Entity, hook: Hook, context: ResolutionContext) -> void:
	if entity == null:
		return
	for stack in entity.statuses.duplicate():
		if stack == null or stack.status == null:
			continue
		for triggered in stack.status.effects:
			if triggered != null and triggered.trigger is HookTrigger and matches((triggered.trigger as HookTrigger).hook, hook):
				await _run(triggered.effects, context)


## Runs the effects of every [CountTrigger] whose value the holding stack's count has reached.
static func fire_counts(entity: Entity, context: ResolutionContext) -> void:
	if entity == null:
		return
	for stack in entity.statuses.duplicate():
		if stack == null or stack.status == null:
			continue
		for triggered in stack.status.effects:
			if triggered != null and triggered.trigger is CountTrigger and stack.count >= (triggered.trigger as CountTrigger).value:
				await _run(triggered.effects, context)


## Whether a raised [param raised] hook matches a trigger's [param trigger_hook]: same class, and every non-default
## scalar field on the trigger's hook equals the raised hook's. [Entity]-typed fields are payload, ignored — so a
## bare hook matches any of its class, while a hook with a field set narrows the match to that value.
static func matches(trigger_hook: Hook, raised: Hook) -> bool:
	if trigger_hook == null or raised == null:
		return false
	var script := trigger_hook.get_script()
	if script != raised.get_script():
		return false
	var defaults: Object = (script as GDScript).new() if script != null else null
	for property in trigger_hook.get_property_list():
		if not (int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var field: StringName = property.name
		var expected: Variant = trigger_hook.get(field)
		if expected is Entity:
			continue
		if defaults != null and expected == defaults.get(field):
			continue
		if expected != raised.get(field):
			return false
	return true


## Awaits each effect's resolution in order (an effect may suspend for a player choice).
static func _run(effects: Array[Effect], context: ResolutionContext) -> void:
	for effect in effects:
		if effect != null:
			await effect.resolve(context)
