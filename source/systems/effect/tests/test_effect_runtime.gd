extends GdUnitTestSuite
## Integration tests for [EffectRuntime], the host entry: modifier folding, the hook bus, status apply raising
## [OnApplyHook], a phase tick that fires-then-decays, the [ApplyStatusAction] catalog seam, and the dodge status
## end-to-end (negate the next hit, then expire).

func _stat(name: StringName) -> EntityStat:
	var stat := EntityStat.new()
	stat.name = name
	return stat


func _entity(health: int = 20) -> Entity:
	var stats := EntityStats.new()
	stats.set_stat(_stat(&"health"), health)
	stats.set_stat(_stat(&"max_health"), 20)
	var entity := Entity.new()
	entity.current_stats = stats
	return entity


func _stack(status: Status, count: int) -> StatusStack:
	var stack := StatusStack.new()
	stack.status = status
	stack.count = count
	return stack


func _damage_action(value: int) -> ModifyStatAction:
	var amount := ConstantAmount.new()
	amount.value = value
	var action := ModifyStatAction.new()
	action.stat = _stat(&"health")
	action.tag = &"damage"
	action.subtracts = true
	action.amount = amount
	return action


func _self_damage_effect(value: int) -> Effect:
	var effect := Effect.new()
	effect.target = SelfTarget.new()
	effect.action = _damage_action(value)
	return effect


func _dodge_status() -> Status:
	var clamp := ClampStep.new()
	clamp.tag = &"damage"
	clamp.minimum = 0
	clamp.maximum = 0
	var decay := TriggerDecayRule.new()
	decay.hook = StatModifiedHook.new()
	decay.quantity = 1
	var status := Status.new()
	status.name = &"dodge"
	status.cap = 1
	status.transforms = [clamp]
	status.decay_rule = decay
	return status


func _context_for(entity: Entity) -> ResolutionContext:
	var allies: Array[Entity] = [entity]
	var opponents: Array[Entity] = []
	return ResolutionContext.create(entity, allies, opponents, 0, null)


func test_apply_modifiers_folds_a_stacking_damage_buff() -> void:
	var damage := _stat(&"damage")
	var entity := _entity()
	var buff := Status.new()
	buff.name = &"target_lock"
	var modifier := Modifier.new()
	modifier.stat = damage
	modifier.operation = Modifier.Operation.ADD
	modifier.amount = 2.0
	buff.modifiers = [modifier]
	entity.statuses.append(_stack(buff, 3))
	var into := EntityStats.new()
	into.set_stat(damage, 1)
	EffectRuntime.new().apply_modifiers(entity, into)
	assert_int(into.get_stat(damage)).is_equal(7)  # 1 + 2 * 3


func test_apply_status_raises_on_apply_hook() -> void:
	# A status that reacts to OnApplyHook by damaging self proves the bus fired the moment it was applied.
	var reactor := Status.new()
	reactor.name = &"reactor"
	var triggered := TriggeredEffect.new()
	var trigger := HookTrigger.new()
	trigger.hook = OnApplyHook.new()
	triggered.trigger = trigger
	triggered.effects = [_self_damage_effect(5)]
	reactor.effects = [triggered]

	var entity := _entity(20)
	var allies: Array[Entity] = [entity]
	var opponents: Array[Entity] = []
	await EffectRuntime.new().apply_status(entity, allies, opponents, reactor, 1)
	assert_int(entity.current_stats.get_stat(_stat(&"health"))).is_equal(15)


func test_tick_phase_fires_trigger_then_decays() -> void:
	var burn := Status.new()
	burn.name = &"burn"
	var triggered := TriggeredEffect.new()
	var trigger := PhaseTrigger.new()
	trigger.phase = &"turn_start"
	triggered.trigger = trigger
	triggered.effects = [_self_damage_effect(3)]
	burn.effects = [triggered]
	var decay := TimingDecayRule.new()
	decay.phase = &"turn_start"
	decay.quantity = 1
	burn.decay_rule = decay

	var entity := _entity(20)
	entity.statuses.append(_stack(burn, 2))
	var allies: Array[Entity] = [entity]
	var opponents: Array[Entity] = []
	await EffectRuntime.new().tick_phase(entity, allies, opponents, &"turn_start")
	assert_int(entity.current_stats.get_stat(_stat(&"health"))).is_equal(17)  # fired once: -3
	assert_int(StatusEngine.find_stack(entity, &"burn").count).is_equal(1)  # decayed 2 -> 1


func test_apply_status_action_resolves_through_catalog() -> void:
	var poison := Status.new()
	poison.name = &"poison"
	var action := ApplyStatusAction.new()
	action.status = &"poison"
	action.count = 2
	var target := _entity()
	var context := _context_for(target)
	context.status_catalog = {&"poison": poison}
	action.resolve(context, target)
	assert_int(StatusEngine.find_stack(target, &"poison").count).is_equal(2)


func test_dodge_negates_next_hit_then_expires() -> void:
	var health := _stat(&"health")
	var entity := _entity(20)
	entity.statuses.append(_stack(_dodge_status(), 1))
	var runtime := EffectRuntime.new()
	var context := _context_for(entity)

	# First hit: the dodge's clamp zeroes the damage.
	_damage_action(10).resolve(context, entity)
	assert_int(entity.current_stats.get_stat(health)).is_equal(20)

	# Raising the damage hook consumes the dodge.
	var allies: Array[Entity] = [entity]
	var opponents: Array[Entity] = []
	await runtime.raise_hook(entity, allies, opponents, StatModifiedHook.new(), null)
	assert_int(entity.statuses.size()).is_equal(0)

	# Second hit lands in full.
	_damage_action(10).resolve(context, entity)
	assert_int(entity.current_stats.get_stat(health)).is_equal(10)
