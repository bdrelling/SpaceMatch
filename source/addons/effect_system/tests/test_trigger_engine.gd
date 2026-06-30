extends GdUnitTestSuite
## Tests [TriggerEngine]: phase/hook/count triggers fire their effects, and the hook-matching rule matches by
## class and scalar fields (e.g. a hook's tag).

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
	trigger.hook = StatModifiedHook.new()
	var entity := _entity_with_trigger(trigger, spy)
	await TriggerEngine.fire_hook(entity, StatModifiedHook.new(), _context(entity))
	assert_int(spy.ran).is_equal(1)


func test_hook_match_respects_scalar_fields() -> void:
	var spy := _SpyAction.new()
	var trigger_hook := StatModifiedHook.new()
	trigger_hook.tag = &"damage"
	var trigger := HookTrigger.new()
	trigger.hook = trigger_hook
	var entity := _entity_with_trigger(trigger, spy)

	var heal := StatModifiedHook.new()
	heal.tag = &"heal"
	await TriggerEngine.fire_hook(entity, heal, _context(entity))
	assert_int(spy.ran).is_equal(0)

	var damage := StatModifiedHook.new()
	damage.tag = &"damage"
	await TriggerEngine.fire_hook(entity, damage, _context(entity))
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
	assert_bool(TriggerEngine.matches(StatModifiedHook.new(), StatModifiedHook.new())).is_true()


func test_matches_different_class_fails() -> void:
	assert_bool(TriggerEngine.matches(OnApplyHook.new(), StatModifiedHook.new())).is_false()
