extends ResolutionTestCase
## Resolution tests for the [OnRemoveHook] / [OnExpireHook] status lifecycle hooks added alongside the core
## defaults — a reactor status that damages its holder when removed or when it decays to zero.


func test_remove_status_raises_on_remove_hook() -> void:
	var entity := _entity(20)
	entity.statuses.append(_stack(_reactor(&"watcher", OnRemoveHook.new(), 5), 1))
	StatusEngine.apply_status(entity, _status(&"poison"), 1, null)
	var allies: Array[Entity] = [entity]
	var opponents: Array[Entity] = []
	await EffectRuntime.new().remove_status(entity, &"poison", allies, opponents)
	assert_int(entity.current_stats.get_stat(_stat(&"health"))).is_equal(15)


func test_remove_status_skips_the_hook_when_nothing_was_there() -> void:
	var entity := _entity(20)
	entity.statuses.append(_stack(_reactor(&"watcher", OnRemoveHook.new(), 5), 1))
	var allies: Array[Entity] = [entity]
	var opponents: Array[Entity] = []
	await EffectRuntime.new().remove_status(entity, &"absent", allies, opponents)
	assert_int(entity.current_stats.get_stat(_stat(&"health"))).is_equal(20)


func test_phase_decay_to_zero_raises_on_expire_hook() -> void:
	var entity := _entity(20)
	entity.statuses.append(_stack(_reactor(&"watcher", OnExpireHook.new(), 4), 1))
	var fading := _status(&"shield")
	var decay := TimingDecayRule.new()
	decay.phase = &"turn_end"
	decay.quantity = 1
	fading.decay_rule = decay
	entity.statuses.append(_stack(fading, 1))
	var allies: Array[Entity] = [entity]
	var opponents: Array[Entity] = []
	await EffectRuntime.new().tick_phase(entity, allies, opponents, &"turn_end")
	assert_bool(StatusEngine.find_stack(entity, &"shield") == null).is_true()
	assert_int(entity.current_stats.get_stat(_stat(&"health"))).is_equal(16)
