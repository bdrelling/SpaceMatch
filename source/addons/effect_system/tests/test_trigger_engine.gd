extends GdUnitTestSuite
## Tests [TriggerEngine]: phase/hook/count triggers fire their effects, and the hook-matching rule respects scalar
## fields while ignoring [Entity] payload.

## Records how many times it resolved — stands in for an effect's action.
class _SpyAction extends Action:
	var ran: int = 0
	func resolve(_context: ResolutionContext, _target: Entity) -> void:
		ran += 1


func _entity_with_trigger(trigger: Trigger, action: Action, count: int = 1) -> Entity:
	var effect := Effect.new()
	effect.target = SelfTarget.new()
	effect.action = action
	var triggered := TriggeredEffect.new()
	triggered.trigger = trigger
	triggered.effects = [effect]
	var status := Status.new()
	status.name = &"source"
	status.effects = [triggered]
	var stack := StatusStack.new()
	stack.status = status
	stack.count = count
	var entity := Entity.new()
	entity.statuses.append(stack)
	return entity


func _context(source: Entity) -> ResolutionContext:
	var allies: Array[Entity] = [source]
	var opponents: Array[Entity] = []
	return ResolutionContext.create(source, allies, opponents, 0, null)


func test_phase_trigger_fires_on_matching_phase() -> void:
	var spy := _SpyAction.new()
	var trigger := PhaseTrigger.new()
	trigger.phase = &"turn_start"
	var entity := _entity_with_trigger(trigger, spy)
	await TriggerEngine.fire_phase(entity, &"turn_start", _context(entity))
	assert_int(spy.ran).is_equal(1)


func test_phase_trigger_skips_other_phase() -> void:
	var spy := _SpyAction.new()
	var trigger := PhaseTrigger.new()
	trigger.phase = &"turn_start"
	var entity := _entity_with_trigger(trigger, spy)
	await TriggerEngine.fire_phase(entity, &"turn_end", _context(entity))
	assert_int(spy.ran).is_equal(0)


func test_hook_trigger_fires_on_matching_hook() -> void:
	var spy := _SpyAction.new()
	var trigger := HookTrigger.new()
	trigger.hook = DamageReceivedHook.new()
	var entity := _entity_with_trigger(trigger, spy)
	await TriggerEngine.fire_hook(entity, DamageReceivedHook.new(), _context(entity))
	assert_int(spy.ran).is_equal(1)


func test_hook_match_respects_scalar_fields() -> void:
	var spy := _SpyAction.new()
	var trigger_hook := DamageReceivedHook.new()
	trigger_hook.damage_type = &"kinetic"
	var trigger := HookTrigger.new()
	trigger.hook = trigger_hook
	var entity := _entity_with_trigger(trigger, spy)

	var plasma := DamageReceivedHook.new()
	plasma.damage_type = &"plasma"
	await TriggerEngine.fire_hook(entity, plasma, _context(entity))
	assert_int(spy.ran).is_equal(0)

	var kinetic := DamageReceivedHook.new()
	kinetic.damage_type = &"kinetic"
	await TriggerEngine.fire_hook(entity, kinetic, _context(entity))
	assert_int(spy.ran).is_equal(1)


func test_hook_match_ignores_entity_payload() -> void:
	var spy := _SpyAction.new()
	var trigger_hook := DamageReceivedHook.new()
	trigger_hook.attacker = Entity.new()
	var trigger := HookTrigger.new()
	trigger.hook = trigger_hook
	var entity := _entity_with_trigger(trigger, spy)

	var raised := DamageReceivedHook.new()
	raised.attacker = Entity.new()  # a different attacker still matches
	await TriggerEngine.fire_hook(entity, raised, _context(entity))
	assert_int(spy.ran).is_equal(1)


func test_count_trigger_fires_when_count_reached() -> void:
	var spy := _SpyAction.new()
	var trigger := CountTrigger.new()
	trigger.value = 3
	var entity := _entity_with_trigger(trigger, spy, 3)
	await TriggerEngine.fire_counts(entity, _context(entity))
	assert_int(spy.ran).is_equal(1)


func test_count_trigger_holds_below_value() -> void:
	var spy := _SpyAction.new()
	var trigger := CountTrigger.new()
	trigger.value = 3
	var entity := _entity_with_trigger(trigger, spy, 2)
	await TriggerEngine.fire_counts(entity, _context(entity))
	assert_int(spy.ran).is_equal(0)


func test_matches_bare_hook_matches_any_of_class() -> void:
	assert_bool(TriggerEngine.matches(DamageReceivedHook.new(), DamageReceivedHook.new())).is_true()


func test_matches_different_class_fails() -> void:
	assert_bool(TriggerEngine.matches(OnApplyHook.new(), DamageReceivedHook.new())).is_false()
