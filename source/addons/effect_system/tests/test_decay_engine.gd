extends GdUnitTestSuite
## Tests [DecayEngine]: each [DecayRule] subtype reduces (and removes) the right statuses — timing on a matching
## phase, trigger on a matching hook, threshold at a count.

func _entity_with_decay(name: StringName, rule: DecayRule, count: int) -> Entity:
	var status := Status.new()
	status.name = name
	status.decay_rule = rule
	var stack := StatusStack.new()
	stack.status = status
	stack.count = count
	var entity := Entity.new()
	entity.statuses.append(stack)
	return entity


func test_timing_decay_reduces_on_matching_phase() -> void:
	var rule := TimingDecayRule.new()
	rule.phase = &"turn_end"
	rule.quantity = 1
	var entity := _entity_with_decay(&"poison", rule, 2)
	DecayEngine.tick_phase(entity, &"turn_end")
	assert_int(StatusEngine.find_stack(entity, &"poison").count).is_equal(1)


func test_timing_decay_ignores_other_phases() -> void:
	var rule := TimingDecayRule.new()
	rule.phase = &"turn_end"
	rule.quantity = 1
	var entity := _entity_with_decay(&"poison", rule, 2)
	DecayEngine.tick_phase(entity, &"turn_start")
	assert_int(StatusEngine.find_stack(entity, &"poison").count).is_equal(2)


func test_trigger_decay_consumes_on_matching_hook() -> void:
	var rule := TriggerDecayRule.new()
	rule.hook = DamageReceivedHook.new()
	rule.quantity = 1
	var entity := _entity_with_decay(&"dodge", rule, 1)
	DecayEngine.tick_hook(entity, DamageReceivedHook.new())
	assert_int(entity.statuses.size()).is_equal(0)


func test_trigger_decay_ignores_other_hooks() -> void:
	var rule := TriggerDecayRule.new()
	rule.hook = DamageReceivedHook.new()
	rule.quantity = 1
	var entity := _entity_with_decay(&"dodge", rule, 1)
	DecayEngine.tick_hook(entity, OnApplyHook.new())
	assert_int(entity.statuses.size()).is_equal(1)


func test_threshold_decay_removes_at_value() -> void:
	var rule := ThresholdDecayRule.new()
	rule.value = 3
	rule.quantity = 3
	var entity := _entity_with_decay(&"charge", rule, 3)
	DecayEngine.tick_thresholds(entity)
	assert_int(entity.statuses.size()).is_equal(0)


func test_threshold_decay_holds_below_value() -> void:
	var rule := ThresholdDecayRule.new()
	rule.value = 3
	rule.quantity = 3
	var entity := _entity_with_decay(&"charge", rule, 2)
	DecayEngine.tick_thresholds(entity)
	assert_int(StatusEngine.find_stack(entity, &"charge").count).is_equal(2)
